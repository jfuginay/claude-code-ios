import SwiftUI

// MARK: - Shared CLI Components

struct CLIMessageRow: View {
    let message: CLIMessage
    
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
            
            // Response content (for non-user messages)
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
        case .system: return .green
        case .error: return .red
        case .processing: return .orange
        }
    }
    
    private var contentColor: Color {
        switch message.type {
        case .system, .processing: return .white
        case .error: return .red
        case .user: return .white
        }
    }
}

struct CLIStatusBarView: View {
    @State private var currentTime = Date()
    @State private var memoryUsage = "42.1 MB"
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack {
            // Left side - system info
            HStack(spacing: 12) {
                Text("Claude Code CLI")
                    .foregroundColor(.blue)
                
                Text("•")
                    .foregroundColor(.gray)
                
                Text("v1.0.0")
                    .foregroundColor(.gray)
                
                Text("•")
                    .foregroundColor(.gray)
                
                Text("Memory: \\(memoryUsage)")
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Right side - time
            Text(currentTime, style: .time)
                .foregroundColor(.gray)
        }
        .font(.system(.caption2, design: .monospaced))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Color.black)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3)),
            alignment: .top
        )
        .onReceive(timer) { _ in
            currentTime = Date()
            // Update memory usage occasionally
            if Int.random(in: 1...10) == 1 {
                let usage = Double.random(in: 35...50)
                memoryUsage = String(format: "%.1f MB", usage)
            }
        }
    }
}

struct CLIInputView: View {
    @Binding var text: String
    var isInputFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Text("claude@code:~$")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.green)
                .fontWeight(.medium)
            
            TextField("", text: $text)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
                .focused(isInputFocused)
                .textFieldStyle(.plain)
                .onSubmit {
                    onSubmit()
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

// MARK: - Extensions for CLIMessage

extension CLIMessage {
    static func systemMessage(_ content: String, prompt: String = "claude@code:~$") -> CLIMessage {
        CLIMessage(content: content, type: .system, prompt: prompt)
    }
    
    static func userMessage(_ content: String, prompt: String = "user@local:~$") -> CLIMessage {
        CLIMessage(content: content, type: .user, prompt: prompt)
    }
    
    static func errorMessage(_ content: String, prompt: String = "claude@code:~$") -> CLIMessage {
        CLIMessage(content: content, type: .error, prompt: prompt)
    }
    
    static func processingMessage(_ content: String, prompt: String = "claude@code:~$") -> CLIMessage {
        CLIMessage(content: content, type: .processing, prompt: prompt)
    }
}

// MARK: - CLI Theme and Styling

struct CLITheme {
    static let backgroundColor = Color.black
    static let primaryTextColor = Color.white
    static let promptColors = [
        "user": Color.blue,
        "claude": Color.green,
        "system": Color.yellow,
        "error": Color.red,
        "processing": Color.orange
    ]
    static let accentColor = Color.blue
    static let successColor = Color.green
    static let warningColor = Color.yellow
    static let errorColor = Color.red
    static let secondaryTextColor = Color.gray
}

extension Font {
    static let cliBody = Font.system(.body, design: .monospaced)
    static let cliCaption = Font.system(.caption, design: .monospaced)
    static let cliHeadline = Font.system(.headline, design: .monospaced)
}

// MARK: - CLI Animations

struct TypingIndicator: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.green)
                    .frame(width: 4, height: 4)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}

struct CLICursor: View {
    @State private var isVisible = true
    
    var body: some View {
        Rectangle()
            .fill(Color.green)
            .frame(width: 8, height: 16)
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(
                Animation.easeInOut(duration: 0.8).repeatForever(),
                value: isVisible
            )
            .onAppear {
                isVisible.toggle()
            }
    }
}

// MARK: - Quick Command Helpers

struct QuickCommands {
    static let suggestions = [
        "analyze this codebase",
        "help me debug this issue",
        "refactor this function",
        "add tests for this file",
        "review my recent changes",
        "optimize performance",
        "explain this code",
        "find security issues"
    ]
    
    static func getRandomSuggestion() -> String {
        return suggestions.randomElement() ?? "help"
    }
}

// MARK: - Repository Context Helpers

extension Repository {
    var cliDisplayName: String {
        return name.isEmpty ? localPath.lastPathComponent : name
    }
    
    var statusEmoji: String {
        switch gitStatus {
        case .clean: return "✅"
        case .dirty: return "⚠️"
        default: return "❓"
        }
    }
    
    var branchDisplayName: String {
        return currentBranch.isEmpty ? "main" : currentBranch
    }
}