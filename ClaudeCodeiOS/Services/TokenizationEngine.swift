import Foundation
import CryptoKit
import NaturalLanguage

@MainActor
class TokenizationEngine: ObservableObject {
    @Published var isProcessing = false
    @Published var cacheStats = CacheStats()
    
    private let maxTokensPerFile = 8000
    private let maxContextTokens = 100000
    private let cacheManager: CacheManager
    
    init(cacheManager: CacheManager) {
        self.cacheManager = cacheManager
    }
    
    // MARK: - File Tokenization
    
    func tokenizeFile(_ file: WorkspaceFile) async -> TokenizedFile {
        guard !file.isDirectory else {
            return TokenizedFile(fileId: file.id, content: "", tokens: [], embeddings: [], lastUpdated: Date(), checksum: "")
        }
        
        // Check cache first
        let checksum = await calculateFileChecksum(file)
        if let cached = await cacheManager.getCachedTokenizedFile(fileId: file.id, checksum: checksum) {
            return cached
        }
        
        do {
            let content = try await readFileContent(file)
            let tokens = await tokenizeContent(content, fileType: file.type)
            let embeddings = await generateEmbeddings(for: tokens)
            
            let tokenizedFile = TokenizedFile(
                fileId: file.id,
                content: content,
                tokens: tokens,
                embeddings: embeddings,
                lastUpdated: Date(),
                checksum: checksum
            )
            
            // Cache the result
            await cacheManager.cacheTokenizedFile(tokenizedFile)
            
            return tokenizedFile
        } catch {
            print("Failed to tokenize file \(file.displayName): \(error)")
            return TokenizedFile(fileId: file.id, content: "", tokens: [], embeddings: [], lastUpdated: Date(), checksum: checksum)
        }
    }
    
    func updateTokenizedFile(_ file: WorkspaceFile, changes: [TextChange]) async -> TokenizedFile {
        let existingTokenized = await tokenizeFile(file)
        
        // For now, re-tokenize the entire file
        // TODO: Implement incremental tokenization for large files
        return await tokenizeFile(file)
    }
    
    // MARK: - Context Building
    
    func buildProjectContext(
        for repository: Repository,
        activeFiles: Set<WorkspaceFile>,
        query: String? = nil,
        tokenBudget: Int = 50000
    ) async -> ProjectContext {
        
        var contextFiles: [TokenizedFile] = []
        var remainingTokens = tokenBudget
        
        // Prioritize active files
        for file in activeFiles {
            guard remainingTokens > 1000 else { break }
            
            let tokenized = await tokenizeFile(file)
            let tokenCount = tokenized.tokens.count
            
            if tokenCount <= remainingTokens {
                contextFiles.append(tokenized)
                remainingTokens -= tokenCount
            }
        }
        
        // Add relevant files based on query if provided
        if let query = query, remainingTokens > 2000 {
            let relevantFiles = await findRelevantFiles(
                in: repository,
                for: query,
                excluding: Set(contextFiles.map { $0.fileId }),
                tokenLimit: remainingTokens
            )
            
            for file in relevantFiles {
                let tokenized = await tokenizeFile(file)
                let tokenCount = tokenized.tokens.count
                
                if tokenCount <= remainingTokens {
                    contextFiles.append(tokenized)
                    remainingTokens -= tokenCount
                }
            }
        }
        
        return ProjectContext(
            repository: repository,
            files: contextFiles,
            totalTokens: tokenBudget - remainingTokens,
            query: query,
            timestamp: Date()
        )
    }
    
    func getRelevantTokens(for query: String, in repository: Repository, limit: Int = 10000) async -> [Token] {
        let queryEmbedding = await generateQueryEmbedding(query)
        
        // Find files with similar embeddings
        let similarFiles = await findSimilarFiles(
            to: queryEmbedding,
            in: repository,
            limit: 20
        )
        
        var relevantTokens: [Token] = []
        var tokenCount = 0
        
        for file in similarFiles {
            let tokenized = await tokenizeFile(file)
            
            // Get most relevant tokens from this file
            let fileTokens = await selectRelevantTokens(
                from: tokenized.tokens,
                for: query,
                limit: min(1000, limit - tokenCount)
            )
            
            relevantTokens.append(contentsOf: fileTokens)
            tokenCount += fileTokens.count
            
            if tokenCount >= limit {
                break
            }
        }
        
        return relevantTokens
    }
    
    func estimateTokenCount(for files: [WorkspaceFile]) async -> Int {
        var totalTokens = 0
        
        for file in files {
            guard !file.isDirectory else { continue }
            
            // Quick estimation based on file size and type
            let estimatedTokens = estimateTokensFromFileSize(file.size, type: file.type)
            totalTokens += estimatedTokens
        }
        
        return totalTokens
    }
    
    // MARK: - Private Methods
    
    private func readFileContent(_ file: WorkspaceFile) async throws -> String {
        let data = try Data(contentsOf: file.path)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func tokenizeContent(_ content: String, fileType: FileType) async -> [Token] {
        // Use appropriate tokenization strategy based on file type
        switch fileType {
        case .swift, .javascript, .typescript, .python:
            return await tokenizeCodeContent(content, language: fileType)
        case .markdown, .text:
            return await tokenizeTextContent(content)
        case .json, .yaml, .xml:
            return await tokenizeStructuredContent(content, format: fileType)
        default:
            return await tokenizeGenericContent(content)
        }
    }
    
    private func tokenizeCodeContent(_ content: String, language: FileType) async -> [Token] {
        // Basic code tokenization - in production, would use Tree-sitter
        let lines = content.components(separatedBy: .newlines)
        var tokens: [Token] = []
        
        for (lineNumber, line) in lines.enumerated() {
            let words = line.components(separatedBy: CharacterSet.whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            
            for (wordIndex, word) in words.enumerated() {
                let token = Token(
                    id: UUID(),
                    content: word,
                    type: determineTokenType(word, language: language),
                    position: TokenPosition(
                        line: lineNumber,
                        column: wordIndex,
                        offset: 0
                    ),
                    metadata: ["language": language.rawValue]
                )
                tokens.append(token)
            }
        }
        
        return tokens
    }
    
    private func tokenizeTextContent(_ content: String) async -> [Token] {
        let words = content.components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        return words.enumerated().map { index, word in
            Token(
                id: UUID(),
                content: word,
                type: .word,
                position: TokenPosition(line: 0, column: index, offset: 0),
                metadata: [:]
            )
        }
    }
    
    private func tokenizeStructuredContent(_ content: String, format: FileType) async -> [Token] {
        // Basic structured content tokenization
        return await tokenizeGenericContent(content)
    }
    
    private func tokenizeGenericContent(_ content: String) async -> [Token] {
        let words = content.components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        return words.enumerated().map { index, word in
            Token(
                id: UUID(),
                content: word,
                type: .word,
                position: TokenPosition(line: 0, column: index, offset: 0),
                metadata: [:]
            )
        }
    }
    
    private func generateEmbeddings(for tokens: [Token]) async -> [Float] {
        // Simplified embedding generation
        // In production, would use a proper embedding model
        let content = tokens.map { $0.content }.joined(separator: " ")
        return await generateTextEmbedding(content)
    }
    
    private func generateTextEmbedding(_ text: String) async -> [Float] {
        // Generate deterministic embeddings based on text content
        // This creates consistent 384-dimensional embeddings for semantic similarity
        let data = text.data(using: .utf8) ?? Data()
        let hash = SHA256.hash(data: data)
        
        // Create 384-dimensional embedding from hash
        var embedding: [Float] = []
        let hashBytes = Array(hash)
        
        // Generate 384 floats from the 32-byte hash
        for i in 0..<384 {
            let byteIndex = i % hashBytes.count
            let byte1 = hashBytes[byteIndex]
            let byte2 = hashBytes[(byteIndex + 1) % hashBytes.count]
            
            // Combine bytes and normalize to [-1, 1]
            let combined = (Int(byte1) << 8) | Int(byte2)
            let normalized = (Float(combined) / 65535.0) * 2.0 - 1.0
            embedding.append(normalized)
        }
        
        // Normalize the embedding vector
        let magnitude = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
        return embedding.map { $0 / magnitude }
    }
    
    private func generateQueryEmbedding(_ query: String) async -> [Float] {
        return await generateTextEmbedding(query)
    }
    
    private func findSimilarFiles(to embedding: [Float], in repository: Repository, limit: Int) async -> [WorkspaceFile] {
        // Implementation would use vector similarity search
        // For now, return empty array
        return []
    }
    
    private func selectRelevantTokens(from tokens: [Token], for query: String, limit: Int) async -> [Token] {
        let queryWords = Set(query.lowercased().components(separatedBy: CharacterSet.whitespacesAndNewlines))
        
        let relevantTokens = tokens.filter { token in
            queryWords.contains(token.content.lowercased())
        }
        
        return Array(relevantTokens.prefix(limit))
    }
    
    private func findRelevantFiles(
        in repository: Repository,
        for query: String,
        excluding excludedIds: Set<UUID>,
        tokenLimit: Int
    ) async -> [WorkspaceFile] {
        // Implementation would search through repository files
        // For now, return empty array
        return []
    }
    
    private func calculateFileChecksum(_ file: WorkspaceFile) async -> String {
        do {
            let data = try Data(contentsOf: file.path)
            let hash = SHA256.hash(data: data)
            return hash.compactMap { String(format: "%02x", $0) }.joined()
        } catch {
            return UUID().uuidString
        }
    }
    
    private func determineTokenType(_ word: String, language: FileType) -> TokenType {
        // Basic token type detection
        let keywords = getKeywords(for: language)
        
        if keywords.contains(word.lowercased()) {
            return .keyword
        } else if word.hasPrefix("\"") && word.hasSuffix("\"") {
            return .string
        } else if Int(word) != nil || Float(word) != nil {
            return .number
        } else if word.hasPrefix("//") || word.hasPrefix("/*") {
            return .comment
        } else {
            return .identifier
        }
    }
    
    private func getKeywords(for language: FileType) -> Set<String> {
        switch language {
        case .swift:
            return ["class", "struct", "func", "var", "let", "if", "else", "for", "while", "import", "return"]
        case .javascript, .typescript:
            return ["function", "var", "let", "const", "if", "else", "for", "while", "return", "import", "export"]
        case .python:
            return ["def", "class", "if", "else", "for", "while", "import", "return", "try", "except"]
        default:
            return []
        }
    }
    
    private func estimateTokensFromFileSize(_ size: Int64, type: FileType) -> Int {
        // Rough estimation: 4 characters per token on average
        let estimatedChars = Int(size)
        return estimatedChars / 4
    }
}

// MARK: - Supporting Types

struct TokenizedFile: Identifiable, Codable {
    var id = UUID()
    let fileId: UUID
    let content: String
    let tokens: [Token]
    let embeddings: [Float]
    let lastUpdated: Date
    let checksum: String
    
    var tokenCount: Int {
        return tokens.count
    }
}

struct Token: Identifiable, Codable {
    let id: UUID
    let content: String
    let type: TokenType
    let position: TokenPosition
    let metadata: [String: String]
}

enum TokenType: String, Codable {
    case word = "word"
    case keyword = "keyword"
    case identifier = "identifier"
    case string = "string"
    case number = "number"
    case comment = "comment"
    case operatorToken = "operator"
    case punctuation = "punctuation"
    case whitespace = "whitespace"
}

struct TokenPosition: Codable {
    let line: Int
    let column: Int
    let offset: Int
}

struct TextChange: Codable {
    let range: NSRange
    let replacementText: String
    let timestamp: Date
}

struct ProjectContext {
    let repository: Repository
    let files: [TokenizedFile]
    let totalTokens: Int
    let query: String?
    let timestamp: Date
    
    var relevantContent: String {
        return files.map { file in
            "// File: \(file.fileId)\n\(file.content)"
        }.joined(separator: "\n\n")
    }
}

struct CacheStats {
    var totalFiles: Int = 0
    var cachedFiles: Int = 0
    var totalSize: Int64 = 0
    var hitRate: Double = 0.0
    var lastUpdated: Date = Date()
}