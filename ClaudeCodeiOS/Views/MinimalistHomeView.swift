import SwiftUI

struct MinimalistHomeView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var claudeService: ClaudeService
    @State private var isAPIConfigured = false
    @State private var currentTime = Date()
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Terminal-style header
                TerminalHeader()
                
                // Main content area
                VStack(spacing: 24) {
                    // Status indicator
                    StatusIndicator(isConfigured: isAPIConfigured)
                    
                    // Quick actions
                    QuickActionsView(selectedTab: $selectedTab, isConfigured: isAPIConfigured)
                    
                    Spacer(minLength: 40)
                    
                    // Footer with version info
                    TerminalFooter()
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
                .padding(.bottom, 20)
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
        }
        .onAppear {
            checkAPIStatus()
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    private func checkAPIStatus() {
        if let apiKey = UserDefaults.standard.string(forKey: "claude_api_key") {
            isAPIConfigured = !apiKey.isEmpty
        } else {
            isAPIConfigured = false
        }
    }
}

struct TerminalHeader: View {
    var body: some View {
        VStack(spacing: 8) {
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
                
                Text("claude-code")
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

struct StatusIndicator: View {
    let isConfigured: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isConfigured ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                
                Text(isConfigured ? "Ready" : "Setup Required")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Text("claude-3.5-sonnet")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

struct QuickActionsView: View {
    @Binding var selectedTab: Int
    let isConfigured: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            if !isConfigured {
                CLIButton(
                    title: "configure api-key",
                    description: "Set up your Anthropic API key",
                    icon: "key",
                    isEnabled: true
                ) {
                    // Navigate to settings
                    selectedTab = 3
                }
            } else {
                VStack(spacing: 12) {
                    CLIButton(
                        title: "new chat",
                        description: "Start a conversation with Claude",
                        icon: "plus.bubble",
                        isEnabled: true
                    ) {
                        selectedTab = 2
                    }
                    
                    CLIButton(
                        title: "browse repositories",
                        description: "Connect and explore your GitHub repos",
                        icon: "folder.badge.gearshape",
                        isEnabled: true
                    ) {
                        selectedTab = 1
                    }
                }
            }
        }
    }
}

struct CLIButton: View {
    let title: String
    let description: String
    let icon: String
    let isEnabled: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(isEnabled ? .blue : .secondary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("$ \(title)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.system(.caption, design: .default))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.quaternarySystemFill))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isPressed ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .disabled(!isEnabled)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }
    }
}

struct TerminalFooter: View {
    var body: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1)
            
            HStack {
                Text("claude-code")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("v1.0.0")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    MinimalistHomeView(selectedTab: .constant(0))
        .environmentObject(ClaudeService(
            tokenizationEngine: TokenizationEngine(cacheManager: CacheManager()),
            cacheManager: CacheManager(),
            gitManager: GitManager(),
            fileSystemManager: FileSystemManager()
        ))
}