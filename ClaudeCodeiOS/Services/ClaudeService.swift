import Foundation
import Combine

struct TokenUsage {
    let inputTokens: Int
    let outputTokens: Int
    
    var totalTokens: Int {
        inputTokens + outputTokens
    }
}

@MainActor
class ClaudeService: ObservableObject {
    @Published var isProcessing = false
    @Published var currentContext: ProjectContext?
    @Published var error: ClaudeError?
    @Published var conversationHistory: [ClaudeMessage] = []
    @Published var processingStatus = "Ready"
    @Published var currentTokenUsage: TokenUsage?
    @Published var lastResponse: String?
    
    private let apiKey: String?
    private let baseURL = "https://api.anthropic.com/v1"
    private let model = "claude-3-5-sonnet-20241022"
    private let maxTokens = 4096
    
    private let tokenizationEngine: TokenizationEngine
    private let cacheManager: CacheManager
    private let gitManager: GitManager
    private let fileSystemManager: FileSystemManager
    
    // Git MCP Integration
    private var mcpServer: GitMCPServer?
    private var gitHooksEnabled = false
    
    init(
        tokenizationEngine: TokenizationEngine,
        cacheManager: CacheManager,
        gitManager: GitManager,
        fileSystemManager: FileSystemManager
    ) {
        self.tokenizationEngine = tokenizationEngine
        self.cacheManager = cacheManager
        self.gitManager = gitManager
        self.fileSystemManager = fileSystemManager
        
        // Load API key from secure storage
        self.apiKey = UserDefaults.standard.string(forKey: "claude_api_key")
        
        // Load conversation history
        self.loadConversationHistory()
        
        // Initialize MCP server
        self.mcpServer = GitMCPServer(
            gitManager: gitManager,
            fileSystemManager: fileSystemManager,
            claudeService: self
        )
    }
    
    // MARK: - Claude API Integration
    
    func sendMessage(
        _ message: String,
        in repository: Repository? = nil,
        activeFiles: Set<WorkspaceFile> = [],
        useContext: Bool = true
    ) async throws -> ClaudeMessage {
        
        isProcessing = true
        defer { isProcessing = false }
        
        var context: ProjectContext?
        
        if useContext, let repository = repository {
            context = await buildContext(
                for: repository,
                activeFiles: activeFiles,
                query: message
            )
        }
        
        // Process command syntax and file references
        let processedMessage = processCommand(message)
        
        let userMessage = ClaudeMessage(
            id: UUID(),
            role: .user,
            content: processedMessage,
            timestamp: Date(),
            repository: repository,
            context: context
        )
        
        conversationHistory.append(userMessage)
        saveConversationHistory()
        
        do {
            let response = try await callClaudeAPI(
                message: message,
                context: context,
                conversationHistory: Array(conversationHistory.suffix(10))
            )
            
            let assistantMessage = ClaudeMessage(
                id: UUID(),
                role: .assistant,
                content: response,
                timestamp: Date(),
                repository: repository,
                context: context
            )
            
            conversationHistory.append(assistantMessage)
            saveConversationHistory()
            lastResponse = response  // Update for TaskMaster
            return assistantMessage
            
        } catch {
            self.error = .apiError(error.localizedDescription)
            throw error
        }
    }
    
    func streamMessage(
        _ message: String,
        in repository: Repository? = nil,
        activeFiles: Set<WorkspaceFile> = []
    ) -> AsyncStream<String> {
        
        return AsyncStream<String> { continuation in
            Task {
                do {
                    await MainActor.run {
                        self.processingStatus = "Building context..."
                        self.currentTokenUsage = nil as TokenUsage?
                    }
                    
                    let context = repository != nil ? await buildContext(
                        for: repository!,
                        activeFiles: activeFiles,
                        query: message
                    ) : nil
                    
                    await MainActor.run {
                        self.processingStatus = "Connecting to Claude..."
                    }
                    
                    let stream = try await streamClaudeAPI(
                        message: processCommand(message),
                        context: context,
                        conversationHistory: Array(conversationHistory.suffix(10))
                    )
                    
                    await MainActor.run {
                        self.processingStatus = "Processing response..."
                    }
                    
                    for await chunk in stream {
                        continuation.yield(chunk)
                    }
                    
                    await MainActor.run {
                        self.processingStatus = "Ready"
                    }
                    
                    continuation.finish()
                } catch {
                    await MainActor.run {
                        self.error = .apiError(error.localizedDescription)
                        self.processingStatus = "Error: \(error.localizedDescription)"
                    }
                    continuation.finish()
                }
            }
        }
    }
    
    // MARK: - Repository Analysis
    
    func analyzeRepository(_ repository: Repository) async throws -> RepositoryAnalysis {
        isProcessing = true
        defer { isProcessing = false }
        
        // Scan repository structure
        let files = await fileSystemManager.scanRepository(repository)
        
        // Get Git status
        let gitChanges = try await gitManager.getFileStatus(for: repository)
        
        // Build analysis context
        let codeFiles = files.filter { $0.isCodeFile }
        let context = await tokenizationEngine.buildProjectContext(
            for: repository,
            activeFiles: Set(codeFiles.prefix(20)), // Limit for initial analysis
            tokenBudget: 50000
        )
        
        // Generate analysis using Claude
        let analysisPrompt = buildRepositoryAnalysisPrompt(
            repository: repository,
            files: files,
            gitChanges: gitChanges
        )
        
        let response = try await callClaudeAPI(
            message: analysisPrompt,
            context: context,
            conversationHistory: []
        )
        
        return RepositoryAnalysis(
            repository: repository,
            summary: response,
            fileCount: files.count,
            codeFileCount: codeFiles.count,
            languages: detectLanguages(in: codeFiles),
            uncommittedChanges: gitChanges.count,
            recommendations: extractRecommendations(from: response),
            timestamp: Date()
        )
    }
    
    func generateCommitMessage(for files: [WorkspaceFile]) async throws -> String {
        guard !files.isEmpty else {
            throw ClaudeError.invalidInput("No files provided for commit message generation")
        }
        
        // Get diffs for the files
        var diffs: [String] = []
        
        for file in files.prefix(10) { // Limit to prevent context overflow
            if let repository = gitManager.currentRepository {
                do {
                    let diff = try await gitManager.getFileDiff(for: file, in: repository)
                    if !diff.isEmpty {
                        diffs.append("File: \(file.relativePath)\n\(diff)")
                    }
                } catch {
                    // Skip files that can't be diffed
                    continue
                }
            }
        }
        
        let prompt = buildCommitMessagePrompt(diffs: diffs)
        
        let response = try await callClaudeAPI(
            message: prompt,
            context: nil,
            conversationHistory: []
        )
        
        return extractCommitMessage(from: response)
    }
    
    // MARK: - Git MCP Integration
    
    func enableGitHooks(for repository: Repository) async throws {
        guard let mcpServer = mcpServer else {
            throw ClaudeError.mcpError("MCP server not initialized")
        }
        
        try await mcpServer.setupGitHooks(for: repository)
        gitHooksEnabled = true
    }
    
    func updateContext(with changes: [GitChange]) async {
        guard let repository = gitManager.currentRepository else { return }
        
        // Update tokenization for changed files
        for change in changes {
            let _ = await tokenizationEngine.tokenizeFile(change.file)
        }
        
        // Rebuild context if significant changes
        if changes.count > 5 {
            currentContext = await buildContext(
                for: repository,
                activeFiles: Set(changes.map { $0.file }),
                query: nil
            )
        }
    }
    
    // MARK: - Context Management
    
    private func buildContext(
        for repository: Repository,
        activeFiles: Set<WorkspaceFile>,
        query: String?
    ) async -> ProjectContext {
        
        // Check cache first
        let cacheKey = buildContextCacheKey(
            repository: repository,
            activeFiles: activeFiles,
            query: query
        )
        
        if let cachedContext = await cacheManager.getCachedProjectContext(key: cacheKey) {
            return cachedContext
        }
        
        // Build new context
        let context = await tokenizationEngine.buildProjectContext(
            for: repository,
            activeFiles: activeFiles,
            query: query,
            tokenBudget: 80000 // Leave room for conversation history
        )
        
        // Cache the context
        await cacheManager.cacheProjectContext(context, key: cacheKey)
        
        return context
    }
    
    private func buildContextCacheKey(
        repository: Repository,
        activeFiles: Set<WorkspaceFile>,
        query: String?
    ) -> String {
        let fileIds = activeFiles.map { $0.id.uuidString }.sorted().joined(separator: ",")
        let queryHash = query?.hash ?? 0
        return "\(repository.id.uuidString)_\(fileIds.hash)_\(queryHash)"
    }
    
    // MARK: - API Communication
    
    private func callClaudeAPI(
        message: String,
        context: ProjectContext?,
        conversationHistory: [ClaudeMessage]
    ) async throws -> String {
        
        guard let apiKey = apiKey else {
            throw ClaudeError.missingAPIKey
        }
        
        let systemPrompt = buildSystemPrompt(context: context)
        let messages = buildAPIMessages(
            userMessage: message,
            conversationHistory: conversationHistory
        )
        
        let requestBody = ClaudeAPIRequest(
            model: model,
            max_tokens: maxTokens,
            system: systemPrompt,
            messages: messages
        )
        
        guard let url = URL(string: "\(baseURL)/messages") else {
            throw ClaudeError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeError.apiError("API returned status \(httpResponse.statusCode): \(errorMessage)")
        }
        
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(ClaudeAPIResponse.self, from: data)
        
        // Update token usage from API response
        if let usage = apiResponse.usage {
            await MainActor.run {
                self.currentTokenUsage = TokenUsage(
                    inputTokens: usage.input_tokens,
                    outputTokens: usage.output_tokens
                )
            }
        }
        
        return apiResponse.content.first?.text ?? "No response content"
    }
    
    private func streamClaudeAPI(
        message: String,
        context: ProjectContext?,
        conversationHistory: [ClaudeMessage]
    ) async throws -> AsyncStream<String> {
        
        guard let apiKey = apiKey else {
            throw ClaudeError.missingAPIKey
        }
        
        let systemPrompt = buildSystemPrompt(context: context)
        let messages = buildAPIMessages(
            userMessage: message,
            conversationHistory: conversationHistory
        )
        
        let requestBody = ClaudeStreamingRequest(
            model: model,
            max_tokens: maxTokens,
            system: systemPrompt,
            messages: messages,
            stream: true
        )
        
        guard let url = URL(string: "\(baseURL)/messages") else {
            throw ClaudeError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        
        return AsyncStream<String> { continuation in
            Task {
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish()
                        return
                    }
                    
                    guard httpResponse.statusCode == 200 else {
                        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                        print("API Error: \(httpResponse.statusCode) - \(errorMessage)")
                        continuation.finish()
                        return
                    }
                    
                    // Create URLSession for streaming
                    let session = URLSession(configuration: .default)
                    let (stream, _) = try await session.bytes(for: request)
                    
                    var inputTokens = 0
                    var outputTokens = 0
                    var buffer = ""
                    
                    for try await byte in stream {
                        buffer.append(Character(UnicodeScalar(byte)))
                        
                        // Process complete lines
                        if let newlineIndex = buffer.firstIndex(of: "\n") {
                            let line = String(buffer[..<newlineIndex])
                            buffer.removeSubrange(...newlineIndex)
                            
                            if line.hasPrefix("data: ") {
                                let jsonString = String(line.dropFirst(6))
                                
                                if jsonString == "[DONE]" {
                                    break
                                }
                                
                                if let jsonData = jsonString.data(using: .utf8),
                                   let streamResponse = try? JSONDecoder().decode(ClaudeStreamResponse.self, from: jsonData) {
                                    
                                    if let content = streamResponse.delta?.text {
                                        continuation.yield(content)
                                    }
                                    
                                    if let usage = streamResponse.usage {
                                        inputTokens = usage.input_tokens
                                        outputTokens = usage.output_tokens
                                        
                                        await MainActor.run {
                                            self.currentTokenUsage = TokenUsage(
                                                inputTokens: inputTokens,
                                                outputTokens: outputTokens
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    print("Streaming error: \(error)")
                    continuation.finish()
                }
            }
        }
    }
    
    // MARK: - Prompt Building
    
    private func buildSystemPrompt(context: ProjectContext?) -> String {
        var prompt = """
        You are Claude Code, an AI coding assistant that works directly in the terminal. You help developers by understanding their entire codebase and executing routine tasks through natural language commands.
        
        Key capabilities:
        - Analyze and understand code in multiple programming languages
        - Execute git workflows and handle version control
        - Debug issues and provide solutions
        - Refactor and improve code quality
        - Generate commit messages and handle file operations
        - Support @file references and command-line syntax
        - Handle slash commands like /bug for issue reporting
        
        Command patterns you understand:
        - "claude -p" for print/analysis mode
        - "claude -c" for continuing conversations
        - "@filename" for file references
        - "think" for extended reasoning
        - "/bug" for issue reporting
        
        Guidelines:
        - Be direct and actionable like a CLI tool
        - Focus on code-related tasks and workflows
        - Provide concrete solutions, not just explanations
        - Support developer workflows and productivity
        - Handle streaming responses appropriately
        """
        
        if let context = context {
            prompt += """
            
            
            Current Project Context:
            Repository: \(context.repository.name)
            Active files: \(context.files.count)
            Total tokens: \(context.totalTokens)
            
            Project files:
            \(context.relevantContent)
            """
        }
        
        return prompt
    }
    
    private func buildAPIMessages(
        userMessage: String,
        conversationHistory: [ClaudeMessage]
    ) -> [APIMessage] {
        
        var messages: [APIMessage] = []
        
        // Add conversation history
        for message in conversationHistory.suffix(8) { // Limit history to prevent context overflow
            messages.append(APIMessage(
                role: message.role.rawValue,
                content: message.content
            ))
        }
        
        // Add current user message
        messages.append(APIMessage(
            role: "user",
            content: userMessage
        ))
        
        return messages
    }
    
    private func buildRepositoryAnalysisPrompt(
        repository: Repository,
        files: [WorkspaceFile],
        gitChanges: [GitChange]
    ) -> String {
        return """
        Please analyze this repository and provide a comprehensive overview:
        
        Repository: \(repository.name)
        Total files: \(files.count)
        Code files: \(files.filter { $0.isCodeFile }.count)
        Uncommitted changes: \(gitChanges.count)
        
        Please provide:
        1. Project structure summary
        2. Main technologies and frameworks used
        3. Code quality observations
        4. Potential improvements or concerns
        5. Development workflow recommendations
        
        Focus on actionable insights that would help a developer understand and work with this codebase effectively.
        """
    }
    
    private func buildCommitMessagePrompt(diffs: [String]) -> String {
        return """
        Based on the following git diffs, generate a concise but descriptive commit message following conventional commit format:
        
        \(diffs.joined(separator: "\n\n"))
        
        Provide only the commit message, without any additional explanation.
        """
    }
    
    // MARK: - Command Processing
    
    private func processCommand(_ message: String) -> String {
        var processedMessage = message
        
        // Handle @file references
        let filePattern = #"@([a-zA-Z0-9_.-]+(?:\.[a-zA-Z0-9]+)?)"#
        let fileRegex = try? NSRegularExpression(pattern: filePattern, options: [])
        
        if let regex = fileRegex {
            let matches = regex.matches(in: message, options: [], range: NSRange(location: 0, length: message.count))
            for match in matches.reversed() {
                if let range = Range(match.range, in: message) {
                    let filename = String(message[range])
                    // In a real implementation, you'd read the file contents
                    processedMessage = processedMessage.replacingOccurrences(of: filename, with: "File reference: \(filename)")
                }
            }
        }
        
        // Handle slash commands
        if message.hasPrefix("/bug") {
            processedMessage = "Bug report: " + String(message.dropFirst(4))
        }
        
        // Handle claude commands
        if message.hasPrefix("claude -p") {
            processedMessage = "Print mode: " + String(message.dropFirst(8))
        } else if message.hasPrefix("claude -c") {
            processedMessage = "Continue conversation: " + String(message.dropFirst(8))
        }
        
        // Handle think command
        if message.hasPrefix("think") {
            processedMessage = "Extended thinking mode: " + String(message.dropFirst(5))
        }
        
        return processedMessage
    }
    
    // MARK: - Utility Methods
    
    private func loadAPIKey() -> String? {
        // Load from Keychain or UserDefaults
        return UserDefaults.standard.string(forKey: "claude_api_key")
    }
    
    private func detectLanguages(in files: [WorkspaceFile]) -> [String] {
        let extensions = Set(files.map { $0.fileExtension })
        return extensions.compactMap { ext in
            switch ext {
            case "swift": return "Swift"
            case "js", "jsx": return "JavaScript"
            case "ts", "tsx": return "TypeScript"
            case "py": return "Python"
            case "java": return "Java"
            case "kt": return "Kotlin"
            case "go": return "Go"
            case "rs": return "Rust"
            case "cpp", "cc", "cxx": return "C++"
            case "c": return "C"
            case "rb": return "Ruby"
            case "php": return "PHP"
            default: return nil
            }
        }
    }
    
    private func extractRecommendations(from response: String) -> [String] {
        // Simple extraction - in production would use more sophisticated parsing
        let lines = response.components(separatedBy: .newlines)
        return lines.filter { line in
            line.contains("recommend") || line.contains("suggest") || line.contains("consider")
        }.map { $0.trimmingCharacters(in: .whitespaces) }
    }
    
    private func extractCommitMessage(from response: String) -> String {
        // Extract just the commit message from the response
        let lines = response.components(separatedBy: .newlines)
        return lines.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? "Update files"
    }
    
    // MARK: - Conversation Persistence
    
    private func loadConversationHistory() {
        guard let data = UserDefaults.standard.data(forKey: "claude_conversation_history"),
              let messages = try? JSONDecoder().decode([ClaudeMessage].self, from: data) else {
            return
        }
        conversationHistory = messages
    }
    
    private func saveConversationHistory() {
        guard let data = try? JSONEncoder().encode(conversationHistory) else { return }
        UserDefaults.standard.set(data, forKey: "claude_conversation_history")
    }
    
    func clearConversationHistory() {
        conversationHistory.removeAll()
        saveConversationHistory()
    }
    
    func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "claude_api_key")
    }
}

// MARK: - Git MCP Server

class GitMCPServer {
    private let gitManager: GitManager
    private let fileSystemManager: FileSystemManager
    private weak var claudeService: ClaudeService?
    
    init(gitManager: GitManager, fileSystemManager: FileSystemManager, claudeService: ClaudeService) {
        self.gitManager = gitManager
        self.fileSystemManager = fileSystemManager
        self.claudeService = claudeService
    }
    
    func setupGitHooks(for repository: Repository) async throws {
        // Install Git hooks for real-time integration
        let hooksDir = repository.localPath.appendingPathComponent(".git/hooks")
        
        // Pre-commit hook
        let preCommitHook = """
        #!/bin/sh
        # Claude Code iOS Git Hook
        echo "Running Claude Code analysis..."
        # Hook implementation would go here
        """
        
        let preCommitPath = hooksDir.appendingPathComponent("pre-commit")
        try preCommitHook.write(to: preCommitPath, atomically: true, encoding: .utf8)
        
        // Make executable
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: preCommitPath.path
        )
    }
    
    func streamFileChanges() -> AsyncStream<GitChange> {
        return AsyncStream<GitChange> { continuation in
            // Implementation would stream real Git changes
            continuation.finish()
        }
    }
}

// MARK: - Supporting Types

struct ClaudeMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let repository: Repository?
    let context: ProjectContext?
}

enum MessageRole: String, Codable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
}

struct RepositoryAnalysis {
    let repository: Repository
    let summary: String
    let fileCount: Int
    let codeFileCount: Int
    let languages: [String]
    let uncommittedChanges: Int
    let recommendations: [String]
    let timestamp: Date
}

// MARK: - API Types

private struct ClaudeAPIRequest: Codable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [APIMessage]
}

private struct APIMessage: Codable {
    let role: String
    let content: String
}

private struct ClaudeAPIResponse: Codable {
    let content: [ContentBlock]
    let usage: Usage?
}

private struct ContentBlock: Codable {
    let text: String
}

private struct ClaudeStreamingRequest: Codable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [APIMessage]
    let stream: Bool
}

private struct ClaudeStreamResponse: Codable {
    let type: String
    let delta: StreamDelta?
    let usage: Usage?
}

private struct StreamDelta: Codable {
    let type: String?
    let text: String?
}

private struct Usage: Codable {
    let input_tokens: Int
    let output_tokens: Int
}

// MARK: - Error Types

enum ClaudeError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case networkError(String)
    case apiError(String)
    case invalidInput(String)
    case mcpError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Claude API key not configured"
        case .invalidURL:
            return "Invalid API URL"
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let message):
            return "API error: \(message)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .mcpError(let message):
            return "MCP error: \(message)"
        }
    }
}