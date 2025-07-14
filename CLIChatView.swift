import SwiftUI

struct CLIChatView: View {
    @EnvironmentObject var claudeService: ClaudeService
    @EnvironmentObject var gitManager: GitManager
    @EnvironmentObject var fileSystemManager: FileSystemManager
    // @EnvironmentObject var taskManager: TaskManager // TODO: Add after adding TaskManager to Xcode project
    
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var streamingResponse = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var hasAPIKey = false
    @FocusState private var isTextFieldFocused: Bool
    
    // TODO: Processing status tracking - Add after adding TokenUsage to Xcode project
    // @State private var processingStatus = "Ready"
    // @State private var currentTokenUsage: TokenUsage?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Terminal header
                TerminalChatHeader()
                
                // Messages area
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(messages) { message in
                                CLIMessageView(message: message)
                                    .id(message.id)
                            }
                            
                            if isLoading {
                                CLILoadingView()
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .background(Color(.systemBackground))
                    .onChange(of: messages.count) { _ in
                        if let lastMessage = messages.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Command input
                CLIInputView(
                    messageText: $messageText,
                    isTextFieldFocused: $isTextFieldFocused,
                    isLoading: isLoading,
                    onSend: sendMessage
                )
            }
            .navigationBarHidden(true)
            .background(Color(.systemBackground))
        }
        .onAppear {
            checkAPIKeyStatus()
            if messages.isEmpty {
                addWelcomeMessage()
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let messageToSend = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        let userMessage = ChatMessage(content: messageToSend, type: .user)
        messages.append(userMessage)
        
        messageText = ""
        isTextFieldFocused = false
        
        // Check if we have an API key
        guard hasAPIKey else {
            let errorResponse = ChatMessage(
                content: "Error: No API key configured. Run 'claude config' to set up authentication.",
                type: .assistant
            )
            messages.append(errorResponse)
            return
        }
        
        isLoading = true
        streamingResponse = ""
        // TODO: Processing status tracking - Add after adding TokenUsage to Xcode project
        // processingStatus = "Initializing Claude..."
        // currentTokenUsage = nil
        
        // Add placeholder message for streaming response
        let streamingMessage = ChatMessage(content: "", type: .assistant)
        messages.append(streamingMessage)
        let streamingIndex = messages.count - 1
        
        Task {
            do {
                // Get current repository context if available
                let currentRepo = gitManager.currentRepository
                let activeFiles = Set<WorkspaceFile>()
                
                // Use streaming for better UX
                let stream = claudeService.streamMessage(
                    messageToSend,
                    in: currentRepo,
                    activeFiles: activeFiles
                )
                
                for await chunk in stream {
                    await MainActor.run {
                        streamingResponse += chunk
                        if streamingIndex < messages.count {
                            messages[streamingIndex] = ChatMessage(
                                content: streamingResponse,
                                type: .assistant
                            )
                        }
                        // TODO: Update status and token usage from service - Add after adding TokenUsage to Xcode project
                        // processingStatus = claudeService.processingStatus
                        // currentTokenUsage = claudeService.currentTokenUsage
                    }
                }
                
                await MainActor.run {
                    isLoading = false
                    // TODO: Processing status tracking - Add after adding TokenUsage to Xcode project
                    // processingStatus = claudeService.processingStatus
                    // currentTokenUsage = claudeService.currentTokenUsage
                    
                    // TODO: Extract tasks from the completed response - Add after adding TaskManager to Xcode project
                    /*
                    if !streamingResponse.isEmpty {
                        let extractedTasks = taskManager.extractTasksFromMessage(streamingResponse, messageId: messages.last?.id)
                        if !extractedTasks.isEmpty {
                            taskManager.addTasks(extractedTasks)
                        }
                    }
                    */
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    // Replace the streaming message with error
                    if streamingIndex < messages.count {
                        messages[streamingIndex] = ChatMessage(
                            content: "Error: \(error.localizedDescription)",
                            type: .assistant
                        )
                    }
                }
            }
        }
    }
    
    private func checkAPIKeyStatus() {
        if let apiKey = UserDefaults.standard.string(forKey: "claude_api_key") {
            hasAPIKey = !apiKey.isEmpty
        } else {
            hasAPIKey = false
        }
    }
    
    private func addWelcomeMessage() {
        let welcomeContent = hasAPIKey 
            ? """
            claude-code v1.0.0 (claude-3.5-sonnet-20241022)
            
            Type your message to start a conversation.
            Available commands:
              analyze <file>     Analyze code structure
              debug <issue>      Debug problems
              refactor <code>    Suggest improvements
              test <function>    Generate tests
              review <changes>   Review code
              help              Show commands
            
            Ready.
            """
            : """
            claude-code v1.0.0
            
            Error: API key not configured
            
            To authenticate:
              1. Get an API key from console.anthropic.com
              2. Go to config tab
              3. Enter your API key
            
            Status: Offline
            """
        
        let welcomeMessage = ChatMessage(
            content: welcomeContent,
            type: .assistant
        )
        messages.append(welcomeMessage)
    }
}

struct TerminalChatHeader: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
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
                
                Text("claude-code@terminal")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1)
        }
    }
}

struct CLIMessageView: View {
    // @EnvironmentObject var taskManager: TaskManager // TODO: Add after adding TaskManager to Xcode project
    let message: ChatMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Prompt line
            HStack(spacing: 8) {
                Text(promptText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(promptColor)
                    .fontWeight(.medium)
                
                if message.type == .user {
                    Text(message.content)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                }
                
                Spacer()
            }
            
            // Assistant response content
            if message.type == .assistant && !message.content.isEmpty {
                Text(message.content)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 8)
                
                // TODO: Show task indicator if this message has extracted tasks - Add after adding TaskManager to Xcode project
                /*
                let messageTasks = taskManager.getTasksForMessage(message.id)
                if !messageTasks.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("→ \(messageTasks.count) task\(messageTasks.count == 1 ? "" : "s") extracted")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                    .padding(.leading, 8)
                    .padding(.top, 4)
                }
                */
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    private var promptText: String {
        switch message.type {
        case .user:
            return "user@local:~$"
        case .assistant:
            return "claude@sonnet:~$"
        }
    }
    
    private var promptColor: Color {
        switch message.type {
        case .user:
            return .blue
        case .assistant:
            return .green
        }
    }
}

struct CLILoadingView: View {
    @State private var animationPhase = 0.0
    
    var body: some View {
        HStack(spacing: 8) {
            Text("claude@sonnet:~$")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.green)
                .fontWeight(.medium)
            
            HStack(spacing: 2) {
                ForEach(0..<3) { index in
                    Text(".")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.green)
                        .opacity(animationPhase == Double(index) ? 1.0 : 0.3)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: animationPhase
                        )
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onAppear {
            animationPhase = 2.0
        }
    }
}

struct CLIInputView: View {
    @Binding var messageText: String
    var isTextFieldFocused: FocusState<Bool>.Binding
    let isLoading: Bool
    let onSend: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1)
            
            HStack(spacing: 8) {
                Text("user@local:~$")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
                
                TextField("", text: $messageText)
                    .font(.system(.body, design: .monospaced))
                    .focused(isTextFieldFocused)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        onSend()
                    }
                    .disabled(isLoading)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if !messageText.isEmpty {
                    Button(action: onSend) {
                        Image(systemName: "return")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
}

#Preview {
    CLIChatView()
        .environmentObject(ClaudeService(
            tokenizationEngine: TokenizationEngine(cacheManager: CacheManager()),
            cacheManager: CacheManager(),
            gitManager: GitManager(),
            fileSystemManager: FileSystemManager()
        ))
        .environmentObject(GitManager())
        .environmentObject(FileSystemManager())
}