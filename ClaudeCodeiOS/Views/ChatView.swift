import SwiftUI

// MARK: - Keyboard Avoidance Extension
extension View {
    func keyboardAvoiding() -> some View {
        self.modifier(KeyboardAvoidingModifier())
    }
}

struct KeyboardAvoidingModifier: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                    let keyboardRectangle = keyboardFrame.cgRectValue
                    keyboardHeight = keyboardRectangle.height
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardHeight = 0
            }
            .animation(.easeInOut(duration: 0.3), value: keyboardHeight)
    }
}

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
        ZStack(alignment: .bottom) {
            // Main terminal content area
            VStack(spacing: 0) {
                // Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(messages) { message in
                                ChatMessageView(message: message)
                                    .id(message.id)
                            }
                            
                            // Spacer to push content up when status bar is shown
                            if isLoading {
                                Color.clear
                                    .frame(height: 60)
                                    .id("bottom-spacer")
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .background(Color(.systemBackground))
                    .onChange(of: messages.count) { _ in
                        withAnimation(.easeOut(duration: 0.3)) {
                            if isLoading {
                                proxy.scrollTo("bottom-spacer", anchor: .bottom)
                            } else if let lastMessage = messages.last {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Input Section (only shown when not processing)
                if !isLoading {
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
                        VStack(spacing: 8) {
                            // Full-width input field
                            HStack(spacing: 8) {
                                TextField("Type your message or use @file.swift to reference files...", text: $messageText, axis: .vertical)
                                    .focused($isTextFieldFocused)
                                    .lineLimit(1...4)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                
                                if !messageText.isEmpty {
                                    Button(action: {
                                        messageText = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Button(action: sendMessage) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(messageText.isEmpty ? .secondary : .blue)
                                }
                                .disabled(messageText.isEmpty)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            
                            // Quick command buttons
                            HStack(spacing: 8) {
                                CommandButton(title: "claude -c", subtitle: "Continue") {
                                    messageText = "Continue our previous conversation"
                                }
                                
                                CommandButton(title: "claude -p", subtitle: "Print mode") {
                                    messageText = "Analyze this codebase and print summary"
                                }
                                
                                CommandButton(title: "/bug", subtitle: "Report issue") {
                                    messageText = "/bug "
                                }
                                
                                CommandButton(title: "think", subtitle: "Extended thinking") {
                                    messageText = "think about this problem step by step"
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                }
            }
            
            // Status bar at bottom (overlays when processing)
            if isLoading {
                ClaudeStatusBarView(
                    isProcessing: isLoading,
                    processingStatus: claudeService.processingStatus,
                    tokenUsage: claudeService.currentTokenUsage
                )
                .transition(.move(edge: .bottom))
            }
        }
        .navigationTitle("claude-code@terminal")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .keyboardAvoiding()
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            isTextFieldFocused = false
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
        
        // ClaudeService will handle adding messages to conversation history
        _Concurrency.Task {
            do {
                // Get current repository context if available
                let currentRepo = gitManager.currentRepository
                let activeFiles = Set<WorkspaceFile>()
                
                // Add user message to conversation history immediately
                let userMessage = ClaudeMessage(
                    id: UUID(),
                    role: .user,
                    content: messageToSend,
                    timestamp: Date(),
                    repository: currentRepo,
                    context: nil
                )
                
                await MainActor.run {
                    claudeService.conversationHistory.append(userMessage)
                }
                
                // Use streaming for better UX
                let stream = claudeService.streamMessage(
                    messageToSend,
                    in: currentRepo,
                    activeFiles: activeFiles
                )
                
                var fullResponse = ""
                
                // Process streaming response (ClaudeService handles conversation updates)
                for await chunk in stream {
                    await MainActor.run {
                        streamingResponse += chunk
                        fullResponse += chunk
                    }
                }
                
                await MainActor.run {
                    // Add assistant response to conversation history
                    let assistantMessage = ClaudeMessage(
                        id: UUID(),
                        role: .assistant,
                        content: fullResponse,
                        timestamp: Date(),
                        repository: currentRepo,
                        context: nil
                    )
                    
                    claudeService.conversationHistory.append(assistantMessage)
                    isLoading = false
                    
                    // TODO: Extract tasks from the completed response - Add after adding TaskManager to Xcode project
                    /*
                    if !fullResponse.isEmpty {
                        let extractedTasks = taskManager.extractTasksFromMessage(fullResponse, messageId: messages.last?.id)
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

struct CommandButton: View {
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                
                Text(subtitle)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
            .cornerRadius(6)
        }
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
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
