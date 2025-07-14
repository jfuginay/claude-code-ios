import SwiftUI

struct CLITerminalView: View {
    @EnvironmentObject var claudeService: ClaudeService
    @EnvironmentObject var gitManager: GitManager
    @EnvironmentObject var fileSystemManager: FileSystemManager
    
    @State private var inputText = ""
    @State private var messages: [TerminalMessage] = []
    @State private var isProcessing = false
    @State private var streamingResponse = ""
    @State private var hasAPIKey = false
    @State private var currentTokens = 0
    @State private var totalTime = 0
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(messages) { message in
                            TerminalMessageRow(message: message)
                                .id(message.id)
                        }
                        
                        if isProcessing {
                            TerminalLoadingRow()
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
            
            // Status bar (like Claude CLI)
            CLIStatusBar(
                isProcessing: isProcessing,
                tokenCount: currentTokens,
                timeElapsed: totalTime
            )
            
            // Input area
            CLIInputArea(
                text: $inputText,
                isInputFocused: $isInputFocused,
                isProcessing: isProcessing,
                onSubmit: sendMessage
            )
        }
        .background(Color.black)
        .onAppear {
            checkAPIKeyStatus()
            initializeTerminal()
        }
    }
    
    private func checkAPIKeyStatus() {
        if let apiKey = UserDefaults.standard.string(forKey: "claude_api_key") {
            hasAPIKey = !apiKey.isEmpty
        } else {
            hasAPIKey = false
        }
    }
    
    private func initializeTerminal() {
        if messages.isEmpty {
            let welcomeMessage = TerminalMessage(
                content: hasAPIKey ? noAPIKeyText : welcomeText,
                type: .system,
                prompt: "claude@code:~$"
            )
            messages.append(welcomeMessage)
        }
    }
    
    private var welcomeText: String {
        """
        Claude Code Terminal
        
        [ERROR] API key not configured
        
        To initialize the Claude service:
        1. Navigate to Settings tab
        2. Configure Anthropic API key
        3. Return to terminal
        
        System status: OFFLINE
        """
    }
    
    private var noAPIKeyText: String {
        """
        Claude Code v1.0.0 initialized
        
        Available commands:
        • analyze <file>     - Analyze code structure and patterns
        • debug <issue>      - Debug problems and errors  
        • refactor <code>    - Suggest code improvements
        • test <function>    - Generate unit tests
        • review <changes>   - Review code changes
        • help              - Show available commands
        
        Ready for your input...
        """
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let messageText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add user message
        let userMessage = TerminalMessage(
            content: messageText,
            type: .user,
            prompt: "user@local:~$"
        )
        messages.append(userMessage)
        
        inputText = ""
        isInputFocused = false
        
        // Check API key
        guard hasAPIKey else {
            let errorMessage = TerminalMessage(
                content: "Error: No API key configured. Run 'claude config' to set up authentication.",
                type: .error,
                prompt: "claude@code:~$"
            )
            messages.append(errorMessage)
            return
        }
        
        isProcessing = true
        streamingResponse = ""
        currentTokens = 0
        totalTime = 0
        
        // Add placeholder for streaming response
        let streamingMessage = TerminalMessage(
            content: "",
            type: .assistant,
            prompt: "claude@code:~$"
        )
        messages.append(streamingMessage)
        let streamingIndex = messages.count - 1
        
        Task {
            let startTime = Date()
            
            do {
                let currentRepo = gitManager.currentRepository
                let activeFiles = Set<WorkspaceFile>()
                
                let stream = claudeService.streamMessage(
                    messageText,
                    in: currentRepo,
                    activeFiles: activeFiles
                )
                
                for await chunk in stream {
                    await MainActor.run {
                        streamingResponse += chunk
                        currentTokens += chunk.count // Rough estimation
                        totalTime = Int(Date().timeIntervalSince(startTime))
                        
                        if streamingIndex < messages.count {
                            messages[streamingIndex] = TerminalMessage(
                                content: streamingResponse,
                                type: .assistant,
                                prompt: "claude@code:~$"
                            )
                        }
                    }
                }
                
                await MainActor.run {
                    isProcessing = false
                }
                
            } catch {
                await MainActor.run {
                    isProcessing = false
                    if streamingIndex < messages.count {
                        messages[streamingIndex] = TerminalMessage(
                            content: "Error: \(error.localizedDescription)",
                            type: .error,
                            prompt: "claude@code:~$"
                        )
                    }
                }
            }
        }
    }
}

struct TerminalMessage: Identifiable {
    let id = UUID()
    let content: String
    let type: MessageType
    let prompt: String
    let timestamp = Date()
    
    enum MessageType {
        case user
        case assistant
        case system
        case error
    }
}

struct TerminalMessageRow: View {
    let message: TerminalMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Prompt line
            HStack {
                Text(message.prompt)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(promptColor)
                    .fontWeight(.medium)
                
                if message.type == .user {
                    Text(message.content)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text(message.timestamp, style: .time)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.gray)
            }
            
            // Response content (for assistant/system/error messages)
            if message.type != .user && !message.content.isEmpty {
                Text(message.content)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(contentColor)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 8)
            }
        }
        .padding(.vertical, 2)
    }
    
    private var promptColor: Color {
        switch message.type {
        case .user: return .blue
        case .assistant: return .green
        case .system: return .yellow
        case .error: return .red
        }
    }
    
    private var contentColor: Color {
        switch message.type {
        case .assistant, .system: return .white
        case .error: return .red
        case .user: return .white
        }
    }
}

struct TerminalLoadingRow: View {
    @State private var dotCount = 0
    
    var body: some View {
        HStack {
            Text("claude@code:~$")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.green)
                .fontWeight(.medium)
            
            Text(String(repeating: ".", count: dotCount))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.green)
            
            Spacer()
        }
        .padding(.vertical, 2)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                dotCount = (dotCount + 1) % 4
            }
        }
    }
}

struct CLIStatusBar: View {
    let isProcessing: Bool
    let tokenCount: Int
    let timeElapsed: Int
    
    var body: some View {
        HStack {
            if isProcessing {
                HStack(spacing: 8) {
                    Text("* Scheming...")
                        .foregroundColor(.orange)
                    
                    Text("(\(timeElapsed)s")
                        .foregroundColor(.gray)
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    Text("\(String(format: "%.1f", Double(tokenCount) / 1000))k tokens")
                        .foregroundColor(.gray)
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    Text("esc to interrupt)")
                        .foregroundColor(.gray)
                }
            } else {
                Text("Ready")
                    .foregroundColor(.green)
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

struct CLIInputArea: View {
    @Binding var text: String
    var isInputFocused: FocusState<Bool>.Binding
    let isProcessing: Bool
    let onSubmit: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Text("user@local:~$")
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
    CLITerminalView()
        .environmentObject(ClaudeService(
            tokenizationEngine: TokenizationEngine(cacheManager: CacheManager()),
            cacheManager: CacheManager(),
            gitManager: GitManager(),
            fileSystemManager: FileSystemManager()
        ))
        .environmentObject(GitManager())
        .environmentObject(FileSystemManager())
}