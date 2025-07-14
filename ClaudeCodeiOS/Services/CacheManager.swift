import Foundation
import CryptoKit

@MainActor
class CacheManager: ObservableObject {
    @Published var stats = CacheStats()
    @Published var isOptimizing = false
    
    private let fileManager = FileManager.default
    private let cacheURL: URL
    private let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500MB
    private let maxFileAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
    // Cache directories
    private let tokenizedCacheURL: URL
    private let embeddingsCacheURL: URL
    private let contextsCacheURL: URL
    
    init() {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.cacheURL = documentsURL.appendingPathComponent("ClaudeCode/cache")
        
        self.tokenizedCacheURL = cacheURL.appendingPathComponent("tokenized")
        self.embeddingsCacheURL = cacheURL.appendingPathComponent("embeddings")
        self.contextsCacheURL = cacheURL.appendingPathComponent("contexts")
        
        createCacheDirectories()
        _Concurrency.Task {
            await updateCacheStats()
        }
    }
    
    // MARK: - Tokenized File Cache
    
    func cacheTokenizedFile(_ tokenizedFile: TokenizedFile) async {
        let fileName = "\(tokenizedFile.fileId.uuidString)_\(tokenizedFile.checksum).json"
        let fileURL = tokenizedCacheURL.appendingPathComponent(fileName)
        
        do {
            let data = try JSONEncoder().encode(tokenizedFile)
            try data.write(to: fileURL)
            
            await updateCacheStats()
        } catch {
            print("Failed to cache tokenized file: \(error)")
        }
    }
    
    func getCachedTokenizedFile(fileId: UUID, checksum: String) async -> TokenizedFile? {
        let fileName = "\(fileId.uuidString)_\(checksum).json"
        let fileURL = tokenizedCacheURL.appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let tokenizedFile = try JSONDecoder().decode(TokenizedFile.self, from: data)
            
            // Update access time for LRU
            try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
            
            return tokenizedFile
        } catch {
            print("Failed to load cached tokenized file: \(error)")
            // Remove corrupted cache file
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
    }
    
    func removeCachedTokenizedFile(fileId: UUID) async {
        let directory = tokenizedCacheURL
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            let filesToRemove = contents.filter { $0.lastPathComponent.hasPrefix(fileId.uuidString) }
            
            for file in filesToRemove {
                try fileManager.removeItem(at: file)
            }
            
            await updateCacheStats()
        } catch {
            print("Failed to remove cached files: \(error)")
        }
    }
    
    // MARK: - Embeddings Cache
    
    func cacheEmbeddings(_ embeddings: [Float], for fileId: UUID, checksum: String) async {
        let fileName = "\(fileId.uuidString)_\(checksum).bin"
        let fileURL = embeddingsCacheURL.appendingPathComponent(fileName)
        
        do {
            let data = Data(bytes: embeddings, count: embeddings.count * MemoryLayout<Float>.size)
            try data.write(to: fileURL)
        } catch {
            print("Failed to cache embeddings: \(error)")
        }
    }
    
    func getCachedEmbeddings(for fileId: UUID, checksum: String) async -> [Float]? {
        let fileName = "\(fileId.uuidString)_\(checksum).bin"
        let fileURL = embeddingsCacheURL.appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let floatCount = data.count / MemoryLayout<Float>.size
            let embeddings = data.withUnsafeBytes { bytes in
                Array(bytes.bindMemory(to: Float.self).prefix(floatCount))
            }
            
            // Update access time
            try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
            
            return embeddings
        } catch {
            print("Failed to load cached embeddings: \(error)")
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
    }
    
    // MARK: - Context Cache
    
    func cacheProjectContext(_ context: ProjectContext, key: String) async {
        let fileName = "\(key.hash).json"
        let fileURL = contextsCacheURL.appendingPathComponent(fileName)
        
        do {
            let cacheEntry = ContextCacheEntry(
                key: key,
                context: context,
                timestamp: Date()
            )
            
            let data = try JSONEncoder().encode(cacheEntry)
            try data.write(to: fileURL)
        } catch {
            print("Failed to cache project context: \(error)")
        }
    }
    
    func getCachedProjectContext(key: String) async -> ProjectContext? {
        let fileName = "\(key.hash).json"
        let fileURL = contextsCacheURL.appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let cacheEntry = try JSONDecoder().decode(ContextCacheEntry.self, from: data)
            
            // Check if cache is still valid (not older than 1 hour)
            let ageLimit: TimeInterval = 60 * 60 // 1 hour
            if Date().timeIntervalSince(cacheEntry.timestamp) > ageLimit {
                try fileManager.removeItem(at: fileURL)
                return nil
            }
            
            // Update access time
            try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
            
            return cacheEntry.context
        } catch {
            print("Failed to load cached context: \(error)")
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
    }
    
    // MARK: - Cache Management
    
    func optimizeCache() async {
        isOptimizing = true
        defer { isOptimizing = false }
        
        // Remove old files
        await removeOldCacheFiles()
        
        // Enforce size limit
        await enforceSizeLimit()
        
        // Remove corrupted files
        await removeCorruptedFiles()
        
        await updateCacheStats()
    }
    
    func clearCache() async {
        do {
            // Remove all cache directories and recreate them
            try fileManager.removeItem(at: cacheURL)
            createCacheDirectories()
            await updateCacheStats()
        } catch {
            print("Failed to clear cache: \(error)")
        }
    }
    
    func getCacheSize() async -> Int64 {
        return await calculateDirectorySize(cacheURL)
    }
    
    func evictOldCache(olderThan date: Date) async {
        let directories = [tokenizedCacheURL, embeddingsCacheURL, contextsCacheURL]
        
        for directory in directories {
            await evictFilesOlderThan(date, in: directory)
        }
        
        await updateCacheStats()
    }
    
    // MARK: - Private Methods
    
    private func createCacheDirectories() {
        let directories = [tokenizedCacheURL, embeddingsCacheURL, contextsCacheURL]
        
        for directory in directories {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
    
    private func updateCacheStats() async {
        let tokenizedFiles = await countFiles(in: tokenizedCacheURL)
        let embeddingFiles = await countFiles(in: embeddingsCacheURL)
        let contextFiles = await countFiles(in: contextsCacheURL)
        let totalSize = await getCacheSize()
        
        stats = CacheStats(
            totalFiles: tokenizedFiles + embeddingFiles + contextFiles,
            cachedFiles: tokenizedFiles,
            totalSize: totalSize,
            hitRate: calculateHitRate(),
            lastUpdated: Date()
        )
    }
    
    private func countFiles(in directory: URL) async -> Int {
        do {
            let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            return contents.count
        } catch {
            return 0
        }
    }
    
    private func calculateDirectorySize(_ directory: URL) async -> Int64 {
        var totalSize: Int64 = 0
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            
            for file in contents {
                let resourceValues = try file.resourceValues(forKeys: [.fileSizeKey])
                if let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        } catch {
            print("Failed to calculate directory size: \(error)")
        }
        
        return totalSize
    }
    
    private func removeOldCacheFiles() async {
        let cutoffDate = Date().addingTimeInterval(-maxFileAge)
        let directories = [tokenizedCacheURL, embeddingsCacheURL, contextsCacheURL]
        
        for directory in directories {
            await evictFilesOlderThan(cutoffDate, in: directory)
        }
    }
    
    private func evictFilesOlderThan(_ date: Date, in directory: URL) async {
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            for file in contents {
                let resourceValues = try file.resourceValues(forKeys: [.contentModificationDateKey])
                if let modificationDate = resourceValues.contentModificationDate,
                   modificationDate < date {
                    try fileManager.removeItem(at: file)
                }
            }
        } catch {
            print("Failed to evict old cache files: \(error)")
        }
    }
    
    private func enforceSizeLimit() async {
        let currentSize = await getCacheSize()
        
        guard currentSize > maxCacheSize else { return }
        
        // Get all cache files sorted by last access time
        var allFiles: [(URL, Date)] = []
        let directories = [tokenizedCacheURL, embeddingsCacheURL, contextsCacheURL]
        
        for directory in directories {
            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )
                
                for file in contents {
                    let resourceValues = try file.resourceValues(forKeys: [.contentModificationDateKey])
                    if let modificationDate = resourceValues.contentModificationDate {
                        allFiles.append((file, modificationDate))
                    }
                }
            } catch {
                print("Failed to enumerate cache files: \(error)")
            }
        }
        
        // Sort by access time (oldest first)
        allFiles.sort { $0.1 < $1.1 }
        
        // Remove oldest files until under size limit
        var removedSize: Int64 = 0
        let targetReduction = currentSize - maxCacheSize
        
        for (file, _) in allFiles {
            guard removedSize < targetReduction else { break }
            
            do {
                let resourceValues = try file.resourceValues(forKeys: [.fileSizeKey])
                let fileSize = Int64(resourceValues.fileSize ?? 0)
                
                try fileManager.removeItem(at: file)
                removedSize += fileSize
            } catch {
                print("Failed to remove cache file: \(error)")
            }
        }
    }
    
    private func removeCorruptedFiles() async {
        // Remove any files that can't be properly decoded
        await removeCorruptedFilesIn(tokenizedCacheURL, type: TokenizedFile.self)
        await removeCorruptedFilesIn(contextsCacheURL, type: ContextCacheEntry.self)
    }
    
    private func removeCorruptedFilesIn<T: Decodable>(_ directory: URL, type: T.Type) async {
        do {
            let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            
            for file in contents {
                guard file.pathExtension == "json" else { continue }
                
                do {
                    let data = try Data(contentsOf: file)
                    _ = try JSONDecoder().decode(type, from: data)
                } catch {
                    // File is corrupted, remove it
                    try? fileManager.removeItem(at: file)
                }
            }
        } catch {
            print("Failed to check for corrupted files: \(error)")
        }
    }
    
    private func calculateHitRate() -> Double {
        // Simple hit rate calculation - in production, would track actual hits/misses
        return 0.75 // Mock value
    }
}

// MARK: - Cache Entry Types

private struct ContextCacheEntry: Codable {
    let key: String
    let context: ProjectContext
    let timestamp: Date
}

// MARK: - Extensions

extension ProjectContext: Codable {
    enum CodingKeys: String, CodingKey {
        case repository, files, totalTokens, query, timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        repository = try container.decode(Repository.self, forKey: .repository)
        files = try container.decode([TokenizedFile].self, forKey: .files)
        totalTokens = try container.decode(Int.self, forKey: .totalTokens)
        query = try container.decodeIfPresent(String.self, forKey: .query)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(repository, forKey: .repository)
        try container.encode(files, forKey: .files)
        try container.encode(totalTokens, forKey: .totalTokens)
        try container.encodeIfPresent(query, forKey: .query)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

extension String {
    var hash: Int {
        return self.hashValue
    }
}