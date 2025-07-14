import SwiftUI

struct MainCLIView: View {
    @EnvironmentObject var claudeService: ClaudeService
    @EnvironmentObject var gitManager: GitManager
    @EnvironmentObject var fileSystemManager: FileSystemManager
    
    @State private var currentMode: CLIMode = .repositorySelection
    @State private var selectedRepository: Repository?
    @State private var sessionManager = ProjectSessionManager()
    @State private var inputText = ""
    @State private var messages: [CLIMessage] = []
    @FocusState private var isInputFocused: Bool
    
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal Header
            CLIHeader(currentMode: currentMode, selectedRepository: selectedRepository)
            
            // Main CLI Content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(messages) { message in
                            CLIMessageRow(message: message)
                                .id(message.id)
                        }
                        
                        // Current mode content
                        switch currentMode {
                        case .repositorySelection:
                            RepositorySelectionView(
                                onRepositorySelected: selectRepository,
                                onCloneRepository: showRepositoryBrowser
                            )
                            
                        case .claudeCLI:
                            if let repo = selectedRepository {
                                ClaudeCLIWorkspace(
                                    repository: repo,
                                    onBackToRepos: backToRepositorySelection
                                )
                            }
                            
                        case .repositoryBrowser:
                            GitHubRepositoryBrowserView(
                                onRepositoryCloned: { repo in
                                    selectRepository(repo)
                                },
                                onCancel: {
                                    currentMode = .repositorySelection
                                }
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
            
            // CLI Status Bar
            CLIStatusBarView()
            
            // CLI Input (only show in certain modes)
            if shouldShowInput {
                CLIInputView(
                    text: $inputText,
                    isInputFocused: $isInputFocused,
                    onSubmit: handleCommand
                )
            }
        }
        .background(Color.black)
        .foregroundColor(.white)
        .onAppear {
            initializeCLI()
        }
    }
    
    private var shouldShowInput: Bool {
        switch currentMode {
        case .claudeCLI:
            return true
        case .repositorySelection:
            return true
        case .repositoryBrowser:
            return false
        }
    }
    
    private func initializeCLI() {
        addMessage(CLIMessage(
            content: welcomeMessage,
            type: .system,
            prompt: "claude@code:~$"
        ))
        
        // Load recent repositories
        sessionManager.loadRecentRepositories(gitManager: gitManager)
    }
    
    private func selectRepository(_ repository: Repository) {
        selectedRepository = repository
        gitManager.currentRepository = repository
        sessionManager.saveRecentRepository(repository)
        
        addMessage(CLIMessage(
            content: "Repository selected: \\(repository.name)\\nTokenizing codebase...",
            type: .system,
            prompt: "claude@code:~$"
        ))
        
        currentMode = .claudeCLI
        
        // Start tokenization in background
        Task {
            await tokenizeRepository(repository)
        }
    }
    
    private func backToRepositorySelection() {
        selectedRepository = nil
        gitManager.currentRepository = nil
        currentMode = .repositorySelection
        
        addMessage(CLIMessage(
            content: "Returned to repository selection",
            type: .system,
            prompt: "claude@code:~$"
        ))
    }
    
    private func showRepositoryBrowser() {
        currentMode = .repositoryBrowser
    }
    
    private func handleCommand() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let command = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        addMessage(CLIMessage(
            content: command,
            type: .user,
            prompt: currentMode == .claudeCLI ? "user@\\(selectedRepository?.name ?? "local"):~$" : "user@local:~$"
        ))
        
        inputText = ""
        
        // Handle different commands based on mode
        switch currentMode {
        case .repositorySelection:
            handleRepositoryCommand(command)
        case .claudeCLI:
            handleClaudeCommand(command)
        case .repositoryBrowser:
            break
        }
    }
    
    private func handleRepositoryCommand(_ command: String) {
        if command.lowercased() == "repos" {
            showRepositoryList()
        } else if command.lowercased().starts(with: "clone ") {
            let url = String(command.dropFirst(6))
            cloneRepository(url: url)
        } else if let index = Int(command), index > 0 && index <= gitManager.repositories.count {
            selectRepository(gitManager.repositories[index - 1])
        } else {
            addMessage(CLIMessage(
                content: "Unknown command. Type 'repos' to see available repositories or 'clone <url>' to clone a new one.",
                type: .error,
                prompt: "claude@code:~$"
            ))
        }
    }
    
    private func handleClaudeCommand(_ command: String) {
        if command.lowercased() == "exit" {
            backToRepositorySelection()
            return
        }
        
        // Handle Claude AI commands
        processClaude CLICommand(command)
    }
    
    private func showRepositoryList() {
        let repoList = gitManager.repositories.enumerated().map { index, repo in
            let status = repo.uncommittedChanges > 0 ? " (dirty)" : " (clean)"
            let lastUsed = sessionManager.getLastUsedTime(for: repo)
            return "[\\(index + 1)] \\(repo.name)\\(status) - \\(lastUsed)"
        }.joined(separator: "\\n")
        
        let content = repoList.isEmpty ? 
            "No repositories found. Use 'clone <url>' to clone a repository." :
            "Available repositories:\\n\\(repoList)\\n\\nSelect repository [1-\\(gitManager.repositories.count)] or 'clone <url>':"
        
        addMessage(CLIMessage(
            content: content,
            type: .system,
            prompt: "claude@code:~$"
        ))
    }
    
    private func cloneRepository(url: String) {
        addMessage(CLIMessage(
            content: "Cloning repository from \\(url)...",
            type: .system,
            prompt: "claude@code:~$"
        ))
        
        Task {
            do {
                let repository = try await gitManager.cloneRepository(url: url)
                await MainActor.run {
                    addMessage(CLIMessage(
                        content: "✅ Repository cloned successfully: \\(repository.name)",
                        type: .system,
                        prompt: "claude@code:~$"
                    ))
                    selectRepository(repository)
                }
            } catch {
                await MainActor.run {
                    addMessage(CLIMessage(
                        content: "❌ Failed to clone repository: \\(error.localizedDescription)",
                        type: .error,
                        prompt: "claude@code:~$"
                    ))
                }
            }
        }
    }
    
    private func processClaudeCommand(_ command: String) {
        // This will be implemented with the Claude CLI workspace
        addMessage(CLIMessage(
            content: "Processing command with Claude...",
            type: .system,
            prompt: "claude@\\(selectedRepository?.name ?? "code"):~$"
        ))
    }
    
    private func tokenizeRepository(_ repository: Repository) async {
        // Simulate tokenization process
        await MainActor.run {
            addMessage(CLIMessage(
                content: "* Tokenizing codebase... (0s • 0 tokens)",
                type: .processing,
                prompt: "claude@code:~$"
            ))
        }
        
        // Simulate progress
        for i in 1...5 {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await MainActor.run {
                let tokens = i * 500
                addMessage(CLIMessage(
                    content: "* Tokenizing codebase... (\\(i)s • \\(tokens) tokens)",
                    type: .processing,
                    prompt: "claude@code:~$"
                ))
            }
        }
        
        await MainActor.run {
            addMessage(CLIMessage(
                content: "✅ Tokenization complete! Ready for Claude commands.",
                type: .system,
                prompt: "claude@\\(repository.name):~$"
            ))
        }
    }
    
    private func addMessage(_ message: CLIMessage) {
        messages.append(message)
    }
    
    private var welcomeMessage: String {
        """
        Claude Code CLI v1.0.0
        
        Welcome to the Claude Code experience!
        
        Available commands:
        • repos           - List available repositories
        • clone <url>     - Clone a new repository
        • [1-9]          - Select repository by number
        
        Start by selecting a repository to work with.
        """
    }
}


struct CLIHeader: View {
    let currentMode: CLIMode
    let selectedRepository: Repository?
    
    var body: some View {
        HStack {
            // Terminal traffic lights
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
            }
            
            Spacer()
            
            Text(headerTitle)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
            
            Spacer()
            
            if let repo = selectedRepository {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .foregroundColor(.blue)
                    Text(repo.name)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                }
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
    
    private var headerTitle: String {
        switch currentMode {
        case .repositorySelection:
            return "claude@code:~$ Repository Selection"
        case .claudeCLI:
            return "claude@\\(selectedRepository?.name ?? "code"):~$ Claude CLI"
        case .repositoryBrowser:
            return "claude@code:~$ GitHub Browser"
        }
    }
}

#Preview {
    MainCLIView()
        .environmentObject(ClaudeService(
            tokenizationEngine: TokenizationEngine(cacheManager: CacheManager()),
            cacheManager: CacheManager(),
            gitManager: GitManager(),
            fileSystemManager: FileSystemManager()
        ))
        .environmentObject(GitManager())
        .environmentObject(FileSystemManager())
}