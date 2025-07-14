import SwiftUI

struct CLISettingsView: View {
    @EnvironmentObject var claudeService: ClaudeService
    @State private var apiKey = ""
    @State private var showingAPIKeyInput = false
    @State private var isConfigured = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Terminal header
                TerminalConfigHeader()
                
                // Configuration content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // API Configuration section
                        ConfigSection(title: "Authentication") {
                            VStack(alignment: .leading, spacing: 12) {
                                ConfigRow(
                                    command: "claude config api-key",
                                    description: isConfigured ? "API key configured" : "Set Anthropic API key",
                                    status: isConfigured ? .success : .warning,
                                    action: {
                                        showingAPIKeyInput = true
                                    }
                                )
                                
                                if isConfigured {
                                    ConfigRow(
                                        command: "claude config reset",
                                        description: "Clear API key",
                                        status: .neutral,
                                        action: {
                                            clearAPIKey()
                                        }
                                    )
                                }
                            }
                        }
                        
                        // Model Configuration
                        ConfigSection(title: "Model Settings") {
                            VStack(alignment: .leading, spacing: 12) {
                                ConfigInfoRow(
                                    label: "model",
                                    value: "claude-3.5-sonnet-20241022"
                                )
                                
                                ConfigInfoRow(
                                    label: "max_tokens",
                                    value: "4096"
                                )
                                
                                ConfigInfoRow(
                                    label: "temperature",
                                    value: "0.0"
                                )
                            }
                        }
                        
                        // App Information
                        ConfigSection(title: "Application") {
                            VStack(alignment: .leading, spacing: 12) {
                                ConfigInfoRow(
                                    label: "version",
                                    value: "1.0.0"
                                )
                                
                                ConfigInfoRow(
                                    label: "platform",
                                    value: "iOS"
                                )
                                
                                ConfigInfoRow(
                                    label: "build",
                                    value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
                                )
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationBarHidden(true)
            .background(Color(.systemBackground))
        }
        .onAppear {
            checkAPIKeyStatus()
        }
        .sheet(isPresented: $showingAPIKeyInput) {
            APIKeyConfigView()
                .environmentObject(claudeService)
        }
    }
    
    private func checkAPIKeyStatus() {
        if let storedKey = UserDefaults.standard.string(forKey: "claude_api_key") {
            isConfigured = !storedKey.isEmpty
        } else {
            isConfigured = false
        }
    }
    
    private func clearAPIKey() {
        UserDefaults.standard.removeObject(forKey: "claude_api_key")
        isConfigured = false
    }
}

struct TerminalConfigHeader: View {
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
                
                Text("claude-code --config")
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

struct ConfigSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("# \(title)")
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(.secondary)
            
            content
        }
    }
}

struct ConfigRow: View {
    let command: String
    let description: String
    let status: ConfigStatus
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: status.icon)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(status.color)
                    .frame(width: 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("$ \(command)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.system(.caption, design: .default))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.quaternarySystemFill))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

struct ConfigInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text("\(label):")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.quaternarySystemFill))
        .cornerRadius(6)
    }
}

enum ConfigStatus {
    case success
    case warning
    case error
    case neutral
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .neutral: return "gearshape"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .neutral: return .blue
        }
    }
}

struct APIKeyConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var claudeService: ClaudeService
    
    @State private var apiKey = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "key")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Configure API Key")
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.medium)
                }
                .padding(.top, 40)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Get your API key from console.anthropic.com")
                        .font(.system(.body, design: .default))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        SecureField("sk-ant-api03-...", text: $apiKey)
                            .font(.system(.body, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    CLIButton(
                        title: "save configuration",
                        description: "Store API key securely",
                        icon: "checkmark",
                        isEnabled: !apiKey.isEmpty && !isSaving
                    ) {
                        saveAPIKey()
                    }
                    
                    Button("Open Anthropic Console") {
                        if let url = URL(string: "https://console.anthropic.com") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.blue)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Load existing API key if any
            if let existingKey = UserDefaults.standard.string(forKey: "claude_api_key") {
                apiKey = existingKey
            }
        }
    }
    
    private func saveAPIKey() {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isSaving = true
        
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmedKey, forKey: "claude_api_key")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            dismiss()
        }
    }
}

#Preview {
    CLISettingsView()
        .environmentObject(ClaudeService(
            tokenizationEngine: TokenizationEngine(cacheManager: CacheManager()),
            cacheManager: CacheManager(),
            gitManager: GitManager(),
            fileSystemManager: FileSystemManager()
        ))
}