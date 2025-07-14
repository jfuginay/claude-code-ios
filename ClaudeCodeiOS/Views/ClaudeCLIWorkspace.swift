import SwiftUI

struct ClaudeCLIWorkspace: View {
    let repository: Repository
    let onBackToRepos: () -> Void
    
    @EnvironmentObject var claudeService: ClaudeService
    @EnvironmentObject var gitManager: GitManager
    @EnvironmentObject var fileSystemManager: FileSystemManager
    
    @State private var inputText = ""
    @State private var messages: [CLIMessage] = []
    @State private var isProcessing = false
    @State private var currentTokens = 0
    @State private var totalTime = 0
    @State private var streamingResponse = ""
    @State private var currentStatusMessage = "Ready"
    @State private var hasAPIKey = false
    @State private var branchManager = ClaudeBranchManager()
    
    @FocusState private var isInputFocused: Bool
    
    private let funnyStatusMessages = [
        "Scheming...",
        "Reading your mind...",
        "Brewing some code magic...",
        "Contemplating the universe of your codebase...",
        "Channeling the spirits of clean code...",
        "Deciphering the ancient scrolls of documentation...",
        "Summoning the wisdom of Stack Overflow...",
        "Consulting the rubber duck...",
        "Applying the sacred rituals of refactoring...",
        "Translating coffee into code...",
        "Debugging the simulation we call reality...",
        "Optimizing for maximum confusion reduction...",
        "Implementing the theory of computational magic..."
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Workspace header
            ClaudeWorkspaceHeader(
                repository: repository,
                currentBranch: branchManager.currentBranch,
                onBackToRepos: onBackToRepos
            )
            
            // Messages area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(messages) { message in
                            CLIMessageRow(message: message)
                                .id(message.id)
                        }
                        
                        if isProcessing {
                            ClaudeProcessingIndicator(
                                statusMessage: currentStatusMessage,
                                tokens: currentTokens,
                                timeElapsed: totalTime
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(Color.black)
                .onChange(of: messages.count) { _ in
                    if let lastMessage = messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Claude CLI Status Bar
            ClaudeStatusBar(
                isProcessing: isProcessing,
                statusMessage: currentStatusMessage,
                tokenCount: currentTokens,
                timeElapsed: totalTime,
                repository: repository
            )
            
            // Input area
            ClaudeCLIInput(
                text: $inputText,
                isInputFocused: $isInputFocused,
                isProcessing: isProcessing,
                repository: repository,
                onSubmit: handleCommand
            )
        }
        .background(Color.black)
        .onAppear {
            initializeWorkspace()
        }
    }
    
    private func initializeWorkspace() {
        checkAPIKeyStatus()
        
        addMessage(CLIMessage(
            content: generateWelcomeMessage(),
            type: .system,
            prompt: "claude@\\(repository.name):~$"
        ))
        
        // Initialize branch manager
        branchManager.setRepository(repository)
        
        // Start tokenization process
        if hasAPIKey {
            startTokenization()
        }
    }
    
    private func checkAPIKeyStatus() {
        if let apiKey = UserDefaults.standard.string(forKey: "claude_api_key") {
            hasAPIKey = !apiKey.isEmpty
        } else {
            hasAPIKey = false
        }
    }
    
    private func generateWelcomeMessage() -> String {
        let commands = [
            "analyze           - Analyze code structure and patterns",
            "debug <issue>     - Debug problems and errors",
            "refactor <code>   - Suggest code improvements", 
            "test <function>   - Generate unit tests",
            "review           - Review recent changes",
            "commit <message> - Create a commit with Claude's help",
            "branch <name>    - Create new feature branch",
            "status           - Show repository and tokenization status",
            "files            - List project files",
            "help             - Show available commands",
            "exit             - Return to repository selection"
        ]
        
        return """
        🚀 Claude CLI initialized for \(repository.name)
        
        Repository: \(repository.name)
        Branch: \(branchManager.currentBranch)
        Status: \(hasAPIKey ? "Ready" : "API key required")
        
        Available commands:
        \(commands.map { "• \($0)" }.joined(separator: "\n"))
        
        Ready for your coding adventure! 🎯
        """
    }
    
    private func startTokenization() {
        isProcessing = true
        currentStatusMessage = funnyStatusMessages.randomElement() ?? "Tokenizing..."
        currentTokens = 0
        totalTime = 0
        
        addMessage(CLIMessage(
            content: "🔍 Starting codebase tokenization...",
            type: .system,
            prompt: "claude@\\(repository.name):~$"
        ))
        
        Task {
            await simulateTokenization()
        }
    }
    
    private func simulateTokenization() async {
        let startTime = Date()
        
        // Simulate tokenization progress
        for i in 1...8 {
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
            
            await MainActor.run {
                currentTokens = i * 300 + Int.random(in: 0...100)
                totalTime = Int(Date().timeIntervalSince(startTime))
                currentStatusMessage = funnyStatusMessages.randomElement() ?? "Tokenizing..."
            }
        }
        
        await MainActor.run {
            isProcessing = false
            currentStatusMessage = "Ready"
            
            addMessage(CLIMessage(
                content: "✅ Tokenization complete! (\\(currentTokens) tokens processed)\\nRepository is ready for Claude commands.",
                type: .system,
                prompt: "claude@\\(repository.name):~$"
            ))
        }
    }
    
    private func handleCommand() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let command = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        addMessage(CLIMessage(
            content: command,
            type: .user,
            prompt: "user@\\(repository.name):~$"
        ))
        
        inputText = ""
        isInputFocused = false
        
        processCommand(command)
    }
    
    private func processCommand(_ command: String) {
        let parts = command.components(separatedBy: " ")
        let cmd = parts[0].lowercased()
        
        switch cmd {
        case "exit":
            onBackToRepos()
            
        case "help":
            showHelp()
            
        case "status":
            showStatus()
            
        case "files":
            listFiles()
            
        case "branch":
            if parts.count > 1 {
                let branchName = parts[1]
                createBranch(branchName)
            } else {
                showCurrentBranch()
            }
            
        case "analyze", "debug", "refactor", "test", "review", "commit":
            processClaudeCommand(command)
            
        default:
            // Default to Claude AI processing
            processClaudeCommand(command)
        }
    }
    
    private func showHelp() {
        addMessage(CLIMessage(
            content: generateWelcomeMessage(),
            type: .system,
            prompt: "claude@\\(repository.name):~$"
        ))
    }
    
    private func showStatus() {
        let status = \"""
        📊 Repository Status:
        • Name: \\(repository.name)
        • Branch: \\(branchManager.currentBranch)
        • Uncommitted changes: \\(repository.uncommittedChanges)
        • Tokenization: \\(hasAPIKey ? "Complete (\\(currentTokens) tokens)" : "Pending API key")
        • Claude API: \\(hasAPIKey ? "Connected" : "Not configured")
        
        💾 Memory Usage:
        • Tokenized files: \\(currentTokens) tokens
        • Cache size: ~\\(currentTokens * 4) bytes
        \"""
        
        addMessage(CLIMessage(
            content: status,
            type: .system,
            prompt: "claude@\\(repository.name):~$"
        ))
    }
    
    private func listFiles() {
        // Simulate file listing
        let files = [
            "README.md",
            "package.json",
            "src/index.js",
            "src/components/App.js",
            "src/utils/helpers.js",
            "tests/app.test.js"
        ]
        
        let content = "📁 Project files:\\n" + files.map { "  \\($0)" }.joined(separator: "\\n")
        
        addMessage(CLIMessage(
            content: content,
            type: .system,
            prompt: "claude@\\(repository.name):~$"
        ))
    }
    
    private func createBranch(_ name: String) {
        let branchName = "claude/\\(name)-\\(Int(Date().timeIntervalSince1970))"
        branchManager.createBranch(branchName)
        
        addMessage(CLIMessage(
            content: "🌿 Created and switched to branch: \\(branchName)",
            type: .system,
            prompt: "claude@\\(repository.name):~$"
        ))
    }
    
    private func showCurrentBranch() {
        addMessage(CLIMessage(
            content: "🌿 Current branch: \\(branchManager.currentBranch)",
            type: .system,
            prompt: "claude@\\(repository.name):~$"
        ))
    }
    
    private func processClaudeCommand(_ command: String) {
        guard hasAPIKey else {
            addMessage(CLIMessage(
                content: "❌ API key not configured. Please go to Settings to set up your Anthropic API key.",
                type: .error,
                prompt: "claude@\\(repository.name):~$"
            ))
            return
        }
        
        isProcessing = true
        streamingResponse = ""
        currentTokens = 0
        totalTime = 0
        currentStatusMessage = funnyStatusMessages.randomElement() ?? "Processing..."
        
        // Add placeholder message for streaming response
        let streamingMessage = CLIMessage(
            content: "",
            type: .system,
            prompt: "claude@\\(repository.name):~$"
        )
        messages.append(streamingMessage)
        let streamingIndex = messages.count - 1
        
        Task {
            let startTime = Date()
            
            do {
                let activeFiles = Set<WorkspaceFile>()
                let stream = claudeService.streamMessage(
                    command,
                    in: repository,
                    activeFiles: activeFiles
                )
                
                for await chunk in stream {
                    await MainActor.run {
                        streamingResponse += chunk
                        currentTokens += chunk.count // Rough estimation
                        totalTime = Int(Date().timeIntervalSince(startTime))
                        
                        // Update status message occasionally
                        if Int.random(in: 1...10) == 1 {
                            currentStatusMessage = funnyStatusMessages.randomElement() ?? "Processing..."
                        }
                        
                        if streamingIndex < messages.count {
                            messages[streamingIndex] = CLIMessage(
                                content: streamingResponse,
                                type: .system,
                                prompt: "claude@\\(repository.name):~$"
                            )
                        }
                    }
                }
                
                await MainActor.run {
                    isProcessing = false
                    currentStatusMessage = "Ready"
                }
                
            } catch {
                await MainActor.run {
                    isProcessing = false
                    currentStatusMessage = "Error"
                    if streamingIndex < messages.count {
                        messages[streamingIndex] = CLIMessage(
                            content: "❌ Error: \\(error.localizedDescription)",
                            type: .error,
                            prompt: "claude@\\(repository.name):~$"
                        )
                    }
                }
            }
        }
    }
    
    private func addMessage(_ message: CLIMessage) {
        messages.append(message)
    }
}

struct ClaudeWorkspaceHeader: View {
    let repository: Repository
    let currentBranch: String
    let onBackToRepos: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onBackToRepos) {
                HStack {
                    Text("←")
                    Text("repos")
                }
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            VStack {
                Text("claude@\\(repository.name):~$")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                
                Text("\\(currentBranch)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .foregroundColor(.blue)
                Text(repository.name)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
}

struct ClaudeProcessingIndicator: View {
    let statusMessage: String
    let tokens: Int
    let timeElapsed: Int
    
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack {
            Text("claude@processing:~$")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.green)
                .fontWeight(.medium)
            
            Text("* \\(statusMessage)")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.orange)
            
            Text("(\\(timeElapsed)s • \\(String(format: "%.1f", Double(tokens) / 1000))k tokens)")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.gray)
            
            Spacer()
            
            // Animated processing indicator
            HStack(spacing: 2) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 4, height: 4)
                        .opacity(0.3)
                        .scaleEffect(animationOffset == CGFloat(i) ? 1.5 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(i) * 0.2),
                            value: animationOffset
                        )
                }
            }
        }
        .padding(.vertical, 2)
        .onAppear {
            animationOffset = 2
        }
    }
}

struct ClaudeStatusBar: View {
    let isProcessing: Bool
    let statusMessage: String
    let tokenCount: Int
    let timeElapsed: Int
    let repository: Repository
    
    var body: some View {
        HStack {
            if isProcessing {
                HStack(spacing: 8) {
                    Text("* \\(statusMessage)")
                        .foregroundColor(.orange)
                    
                    Text("(\\(timeElapsed)s • \\(String(format: "%.1f", Double(tokenCount) / 1000))k tokens • esc to interrupt)")
                        .foregroundColor(.gray)
                }
            } else {
                HStack(spacing: 12) {
                    Text("Ready")
                        .foregroundColor(.green)
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    Text("\\(String(format: "%.1f", Double(tokenCount) / 1000))k tokens")
                        .foregroundColor(.gray)
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    Text(repository.name)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
        }
        .font(.system(.caption, design: .monospaced))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3)),
            alignment: .top
        )
    }
}

struct ClaudeCLIInput: View {
    @Binding var text: String
    var isInputFocused: FocusState<Bool>.Binding
    let isProcessing: Bool
    let repository: Repository
    let onSubmit: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Text("user@\\(repository.name):~$")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.blue)
                .fontWeight(.medium)
            
            TextField("", text: $text)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
                .focused(isInputFocused)
                .textFieldStyle(.plain)
                .onSubmit {
                    onSubmit()
                }
                .disabled(isProcessing)
            
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3)),
            alignment: .top
        )
    }
}


#Preview {
    ClaudeCLIWorkspace(
        repository: Repository(
            name: "test-repo",
            localPath: URL(string: "/tmp/test")!,
            remoteURL: "https://github.com/user/test.git"
        ),
        onBackToRepos: { }
    )
    .environmentObject(ClaudeService(
        tokenizationEngine: TokenizationEngine(cacheManager: CacheManager()),
        cacheManager: CacheManager(),
        gitManager: GitManager(),
        fileSystemManager: FileSystemManager()
    ))
    .environmentObject(GitManager())
    .environmentObject(FileSystemManager())
}