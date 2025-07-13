import SwiftUI

struct ChatView: View {
    @EnvironmentObject var claudeService: ClaudeService
    @EnvironmentObject var gitManager: GitManager
    @EnvironmentObject var fileSystemManager: FileSystemManager
    
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var streamingResponse = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var hasAPIKey = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(messages) { message in
                            ChatMessageView(message: message)
                                .id(message.id)
                        }
                        
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Claude is thinking...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
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
        let userMessage = ChatMessage(content: messageToSend, type: .user)
        messages.append(userMessage)
        
        messageText = ""
        isTextFieldFocused = false
        
        // Check if we have an API key
        guard hasAPIKey else {
            let errorResponse = ChatMessage(
                content: "⚠️ No API key configured. Please go to Settings to set up your Anthropic API key.",
                type: .assistant
            )
            messages.append(errorResponse)
            return
        }
        
        isLoading = true
        streamingResponse = ""
        
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
                    }
                }
                
                await MainActor.run {
                    isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    // Replace the streaming message with error
                    if streamingIndex < messages.count {
                        messages[streamingIndex] = ChatMessage(
                            content: "❌ Error: \(error.localizedDescription)\n\nPlease check your API key in Settings.",
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
        
        let welcomeMessage = ChatMessage(
            content: welcomeContent,
            type: .assistant
        )
        messages.append(welcomeMessage)
    }
    
    private func clearChat() {
        messages.removeAll()
        addWelcomeMessage()
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