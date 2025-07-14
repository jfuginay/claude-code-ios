import SwiftUI

struct ChatView: View {
    @EnvironmentObject var claudeService: ClaudeService
    @EnvironmentObject var gitManager: GitManager
    @EnvironmentObject var fileSystemManager: FileSystemManager
    // @EnvironmentObject var taskManager: TaskManager // TODO: Add after adding TaskManager to Xcode project
    
    @State private var messageText = ""
    private var messages: [ChatMessage] {
        claudeService.conversationHistory.map { claudeMessage in
            ChatMessage(
                content: claudeMessage.content,
                type: claudeMessage.role == .user ? .user : .assistant
            )
        }
    }
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
        VStack(spacing: 0) {
            // Claude CLI Status Bar (temporarily disabled - need to add to Xcode project)
            
            ClaudeStatusBarView(
                isProcessing: isLoading,
                processingStatus: claudeService.processingStatus,
                tokenUsage: claudeService.currentTokenUsage
            )
            
            
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(messages) { message in
                            ChatMessageView(message: message)
                                .id(message.id)
                        }
                        
                        // Remove inline loading indicator as we'll show it in the status bar
                    }
                    .padding(.vertical, 12)
                }
                .onChange(of: messages.count) { _ in
                    if let lastMessage = messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Input Section
            VStack(spacing: 12) {
                // Quick Actions
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        QuickActionButton(title: "Explain Code", icon: "doc.text.magnifyingglass") {
                            messageText = "Explain how this code works"
                        }
                        
                        QuickActionButton(title: "Debug Issue", icon: "ladybug") {
                            messageText = "Help me debug this issue"
                        }
                        
                        QuickActionButton(title: "Refactor", icon: "arrow.triangle.2.circlepath") {
                            messageText = "How can I refactor this code?"
                        }
                        
                        QuickActionButton(title: "Add Tests", icon: "checkmark.circle") {
                            messageText = "Add unit tests for this code"
                        }
                        
                        QuickActionButton(title: "Optimize", icon: "speedometer") {
                            messageText = "How can I optimize this code for performance?"
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Message Input
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        TextField("Ask Claude about your code...", text: $messageText, axis: .vertical)
                            .focused($isTextFieldFocused)
                            .lineLimit(1...4)
                            .textFieldStyle(.plain)
                        
                        if !messageText.isEmpty {
                            Button(action: {
                                messageText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    
                    Button(action: sendMessage) {
                        Image(systemName: messageText.isEmpty ? "mic" : "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(messageText.isEmpty ? .secondary : .blue)
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            
            // TODO: Processing status bar - Add after adding ProcessingStatusView to Xcode project
            /*
            ProcessingStatusView(
                isProcessing: isLoading,
                statusMessage: processingStatus,
                tokenUsage: currentTokenUsage
            )
            */
        }
        .navigationTitle("claude-code@terminal")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
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
        // Don't manipulate local messages - ClaudeService will handle conversation history
        
        messageText = ""
        isTextFieldFocused = false
        
        // Check if we have an API key
        guard hasAPIKey else {
            errorMessage = "⚠️ No API key configured. Please go to Settings to set up your Anthropic API key."
            showingError = true
            return
        }
        
        isLoading = true
        streamingResponse = ""
        // TODO: Processing status tracking - Add after adding TokenUsage to Xcode project
        // processingStatus = "Initializing Claude..."
        // currentTokenUsage = nil
        
        // ClaudeService will handle adding messages to conversation history
        
        _Concurrency.Task {
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
                
                // Process streaming response (ClaudeService handles conversation updates)
                for await chunk in stream {
                    await MainActor.run {
                        streamingResponse += chunk
                        // The ClaudeService will update conversation history automatically
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
                    errorMessage = error.localizedDescription
                    showingError = true
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
            : """
            Claude Code Terminal
            
            [ERROR] API key not configured
            
            To initialize the Claude service:
            1. Navigate to Settings tab
            2. Configure Anthropic API key
            3. Return to terminal
            
            System status: OFFLINE
            """
        
        // Welcome message functionality disabled - using ClaudeService conversation history
    }
    
    private func clearChat() {
        claudeService.clearConversationHistory()
    }
    
    private func exportChat() {
        // TODO: Implement chat export functionality
    }
    
    private func openSettings() {
        // TODO: Navigate to settings
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray5))
            .cornerRadius(16)
        }
        .foregroundColor(.primary)
    }
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let type: MessageType
    let timestamp = Date()
    
    enum MessageType {
        case user
        case assistant
    }
}

struct ChatMessageView: View {
    // @EnvironmentObject var taskManager: TaskManager // TODO: Add after adding TaskManager to Xcode project
    let message: ChatMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Terminal-style prompt
            HStack(spacing: 4) {
                if message.type == .assistant {
                    Text("claude@code:~$")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                } else {
                    Text("user@local:~$")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                Text(message.timestamp, style: .time)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            // Message content with terminal styling
            VStack(alignment: .leading, spacing: 0) {
                if message.type == .assistant {
                    Text(message.content)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(message.content)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(.leading, 20) // Indent user input
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            // Terminal cursor for assistant messages
            if message.type == .assistant && !message.content.isEmpty {
                HStack {
                    // TODO: Show task indicator if this message has extracted tasks - Add after adding TaskManager to Xcode project
                    /*
                    let messageTasks = taskManager.getTasksForMessage(message.id)
                    if !messageTasks.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("\(messageTasks.count) task\(messageTasks.count == 1 ? "" : "s") extracted")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    */
                    
                    Spacer()
                    
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 8, height: 16)
                        .opacity(0.7)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
}
