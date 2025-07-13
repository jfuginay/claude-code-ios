import Foundation
import Combine
import CryptoKit

#if canImport(Darwin)
import Darwin
#endif

@MainActor
class FileSystemManager: ObservableObject {
    @Published var workspaceFiles: [WorkspaceFile] = []
    @Published var isScanning = false
    @Published var error: FileSystemError?
    
    private let fileManager = FileManager.default
    private var fileWatcher: DirectoryWatcher?
    private var changeSubject = PassthroughSubject<FileChange, Never>()
    
    var fileChanges: AnyPublisher<FileChange, Never> {
        changeSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Repository Scanning
    
    func scanRepository(_ repository: Repository) async -> [WorkspaceFile] {
        isScanning = true
        defer { isScanning = false }
        
        do {
            let files = try await scanDirectory(
                at: repository.localPath,
                basePath: repository.localPath,
                ignoringPaths: getIgnoredPaths(for: repository)
            )
            
            await MainActor.run {
                self.workspaceFiles = files
            }
            
            return files
        } catch {
            await MainActor.run {
                self.error = .scanningFailed(error.localizedDescription)
            }
            return []
        }
    }
    
    private func scanDirectory(at url: URL, basePath: URL, ignoringPaths: Set<String>) async throws -> [WorkspaceFile] {
        let resourceKeys: [URLResourceKey] = [
            .isDirectoryKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .isHiddenKey
        ]
        
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        )
        
        var files: [WorkspaceFile] = []
        
        for fileURL in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let relativePath = String(fileURL.path.dropFirst(basePath.path.count + 1))
            
            // Skip ignored paths
            if ignoringPaths.contains(relativePath) || shouldIgnorePath(relativePath) {
                continue
            }
            
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            let isDirectory = resourceValues.isDirectory ?? false
            let fileSize = resourceValues.fileSize ?? 0
            let modificationDate = resourceValues.contentModificationDate ?? Date()
            
            let fileType = FileType(from: fileURL.pathExtension, fileName: fileURL.lastPathComponent)
            
            var children: [WorkspaceFile]?
            if isDirectory {
                children = try await scanDirectory(at: fileURL, basePath: basePath, ignoringPaths: ignoringPaths)
            }
            
            let checksum = !isDirectory ? try await calculateChecksum(for: fileURL) : nil
            
            let workspaceFile = WorkspaceFile(
                path: fileURL,
                relativePath: relativePath,
                type: fileType,
                size: Int64(fileSize),
                isDirectory: isDirectory,
                children: children
            )
            
            files.append(workspaceFile)
        }
        
        return files
    }
    
    // MARK: - File Operations
    
    func readFile(at path: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try Data(contentsOf: path)
                    let content = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: content)
                } catch {
                    continuation.resume(throwing: FileSystemError.readFailed(error.localizedDescription))
                }
            }
        }
    }
    
    func writeFile(content: String, to path: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try content.write(to: path, atomically: true, encoding: .utf8)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: FileSystemError.writeFailed(error.localizedDescription))
                }
            }
        }
    }
    
    func createFile(name: String, content: String, in directory: URL) async throws -> WorkspaceFile {
        let fileURL = directory.appendingPathComponent(name)
        
        guard !fileManager.fileExists(atPath: fileURL.path) else {
            throw FileSystemError.fileAlreadyExists
        }
        
        try await writeFile(content: content, to: fileURL)
        
        let fileType = FileType(from: fileURL.pathExtension, fileName: name)
        return WorkspaceFile(
            path: fileURL,
            relativePath: name,
            type: fileType,
            size: Int64(content.count),
            isDirectory: false
        )
    }
    
    func createDirectory(name: String, in parentDirectory: URL) async throws -> WorkspaceFile {
        let directoryURL = parentDirectory.appendingPathComponent(name)
        
        guard !fileManager.fileExists(atPath: directoryURL.path) else {
            throw FileSystemError.fileAlreadyExists
        }
        
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: false)
        
        return WorkspaceFile(
            path: directoryURL,
            relativePath: name,
            type: .folder,
            size: 0,
            isDirectory: true
        )
    }
    
    func deleteFile(_ file: WorkspaceFile) async throws {
        try fileManager.removeItem(at: file.path)
    }
    
    func moveFile(_ file: WorkspaceFile, to destination: URL) async throws -> WorkspaceFile {
        let newURL = destination.appendingPathComponent(file.path.lastPathComponent)
        try fileManager.moveItem(at: file.path, to: newURL)
        
        return WorkspaceFile(
            path: newURL,
            relativePath: file.relativePath,
            type: file.type,
            size: file.size,
            isDirectory: file.isDirectory,
            children: file.children
        )
    }
    
    func copyFile(_ file: WorkspaceFile, to destination: URL) async throws -> WorkspaceFile {
        let newURL = destination.appendingPathComponent(file.path.lastPathComponent)
        try fileManager.copyItem(at: file.path, to: newURL)
        
        return WorkspaceFile(
            path: newURL,
            relativePath: file.relativePath,
            type: file.type,
            size: file.size,
            isDirectory: file.isDirectory,
            children: file.children
        )
    }
    
    // MARK: - File Watching
    
    func watchFileChanges(in repository: Repository) -> AsyncStream<FileChange> {
        return AsyncStream<FileChange> { continuation in
            fileWatcher = DirectoryWatcher(path: repository.localPath.path) { changedPaths in
                Task { @MainActor [weak self] in
                    for path in changedPaths {
                        let fileURL = URL(fileURLWithPath: path)
                        let relativePath = String(path.dropFirst(repository.localPath.path.count + 1))
                        
                        let changeType = self?.determineChangeType(for: fileURL) ?? .modified
                        let workspaceFile = WorkspaceFile(
                            path: fileURL,
                            relativePath: relativePath,
                            type: FileType(from: fileURL.pathExtension, fileName: fileURL.lastPathComponent),
                            size: 0,
                            isDirectory: fileURL.hasDirectoryPath
                        )
                        
                        let fileChange = FileChange(
                            file: workspaceFile,
                            changeType: changeType,
                            timestamp: Date()
                        )
                        
                        continuation.yield(fileChange)
                        self?.changeSubject.send(fileChange)
                    }
                }
            }
            
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor in
                    self?.fileWatcher?.stop()
                }
            }
        }
    }
    
    // MARK: - Utility Functions
    
    private func getIgnoredPaths(for repository: Repository) -> Set<String> {
        var ignoredPaths: Set<String> = [".git", ".DS_Store", "node_modules", ".build"]
        
        // Read .gitignore file if it exists
        let gitignorePath = repository.localPath.appendingPathComponent(".gitignore")
        if let gitignoreContent = try? String(contentsOf: gitignorePath) {
            let lines = gitignoreContent.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                    ignoredPaths.insert(trimmed)
                }
            }
        }
        
        return ignoredPaths
    }
    
    private func shouldIgnorePath(_ path: String) -> Bool {
        let ignoredPatterns = [
            ".git/", ".DS_Store", "node_modules/", ".build/",
            "*.tmp", "*.log", ".env", ".env.*"
        ]
        
        for pattern in ignoredPatterns {
            if pattern.contains("*") {
                let regex = pattern.replacingOccurrences(of: "*", with: ".*")
                if path.range(of: regex, options: .regularExpression) != nil {
                    return true
                }
            } else if path.contains(pattern) {
                return true
            }
        }
        
        return false
    }
    
    private func calculateChecksum(for url: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let data = try Data(contentsOf: url)
                    let hash = SHA256.hash(data: data)
                    let checksum = hash.compactMap { String(format: "%02x", $0) }.joined()
                    continuation.resume(returning: checksum)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func determineChangeType(for url: URL) -> FileChangeType {
        if fileManager.fileExists(atPath: url.path) {
            return .modified
        } else {
            return .deleted
        }
    }
    
    func searchFiles(in repository: Repository, query: String) async -> [WorkspaceFile] {
        let allFiles = await getAllFiles(from: workspaceFiles)
        return allFiles.filter { file in
            file.displayName.localizedCaseInsensitiveContains(query) ||
            file.relativePath.localizedCaseInsensitiveContains(query)
        }
    }
    
    private func getAllFiles(from files: [WorkspaceFile]) -> [WorkspaceFile] {
        var allFiles: [WorkspaceFile] = []
        
        for file in files {
            allFiles.append(file)
            if let children = file.children {
                allFiles.append(contentsOf: getAllFiles(from: children))
            }
        }
        
        return allFiles
    }
    
    func getRecentFiles(in repository: Repository, limit: Int = 10) -> [WorkspaceFile] {
        let allFiles = getAllFiles(from: workspaceFiles)
            .filter { !$0.isDirectory && $0.type.isEditable }
            .sorted { $0.lastModified > $1.lastModified }
        
        return Array(allFiles.prefix(limit))
    }
    
    func getCodeFiles(in repository: Repository) -> [WorkspaceFile] {
        return getAllFiles(from: workspaceFiles).filter { $0.isCodeFile }
    }
}

// MARK: - Supporting Types

struct FileChange: Identifiable {
    let id = UUID()
    let file: WorkspaceFile
    let changeType: FileChangeType
    let timestamp: Date
}

enum FileChangeType {
    case created
    case modified
    case deleted
    case moved
}

// MARK: - Directory Watcher

class DirectoryWatcher {
    private let path: String
    private let callback: ([String]) -> Void
    private var source: DispatchSourceFileSystemObject?
    private let queue = DispatchQueue(label: "DirectoryWatcher")
    
    init(path: String, callback: @escaping ([String]) -> Void) {
        self.path = path
        self.callback = callback
        start()
    }
    
    private func start() {
        let fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: queue
        )
        
        source?.setEventHandler { [weak self] in
            self?.handleFileSystemEvent()
        }
        
        source?.setCancelHandler {
            close(fileDescriptor)
        }
        
        source?.resume()
    }
    
    private func handleFileSystemEvent() {
        // Simplified: just notify that something changed
        callback([path])
    }
    
    func stop() {
        source?.cancel()
        source = nil
    }
    
    deinit {
        stop()
    }
}

// MARK: - Error Types

enum FileSystemError: LocalizedError {
    case scanningFailed(String)
    case readFailed(String)
    case writeFailed(String)
    case fileNotFound
    case fileAlreadyExists
    case permissionDenied
    case diskFull
    case invalidPath
    
    var errorDescription: String? {
        switch self {
        case .scanningFailed(let message):
            return "Failed to scan directory: \(message)"
        case .readFailed(let message):
            return "Failed to read file: \(message)"
        case .writeFailed(let message):
            return "Failed to write file: \(message)"
        case .fileNotFound:
            return "File not found"
        case .fileAlreadyExists:
            return "File already exists"
        case .permissionDenied:
            return "Permission denied"
        case .diskFull:
            return "Disk full"
        case .invalidPath:
            return "Invalid file path"
        }
    }
}