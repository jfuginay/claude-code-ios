import SwiftUI

struct GitHubAuthView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var gitHubService: GitHubService
    
    @State private var accessToken = ""
    @State private var isAuthenticating = false
    @State private var authError: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "person.badge.key")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("GitHub Authentication")
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.medium)
                }
                .padding(.top, 40)
                
                // Instructions
                VStack(alignment: .leading, spacing: 16) {
                    Text("To connect your GitHub account:")
                        .font(.system(.headline, design: .default))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        InstructionStep(number: "1", text: "Visit github.com/settings/tokens")
                        InstructionStep(number: "2", text: "Create a personal access token")
                        InstructionStep(number: "3", text: "Select 'repo' scope for repository access")
                        InstructionStep(number: "4", text: "Copy and paste the token below")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Token input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Personal Access Token")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    SecureField("ghp_xxxxxxxxxxxxxxxxxxxx", text: $accessToken)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                
                // Error message
                if let error = authError {
                    Text(error)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                // Actions
                VStack(spacing: 12) {
                    CLIButton(
                        title: "authenticate",
                        description: "Connect to GitHub",
                        icon: "key",
                        isEnabled: !accessToken.isEmpty && !isAuthenticating
                    ) {
                        authenticateWithToken()
                    }
                    
                    Button("Open GitHub Token Settings") {
                        openTokenSettings()
                    }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.blue)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationTitle("GitHub Auth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func authenticateWithToken() {
        guard !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isAuthenticating = true
        authError = nil
        
        Task {
            await gitHubService.authenticate(with: accessToken.trimmingCharacters(in: .whitespacesAndNewlines))
            
            await MainActor.run {
                isAuthenticating = false
                
                if gitHubService.isAuthenticated {
                    dismiss()
                } else {
                    authError = "Authentication failed. Please check your token."
                }
            }
        }
    }
    
    private func openTokenSettings() {
        if let url = URL(string: "https://github.com/settings/tokens") {
            UIApplication.shared.open(url)
        }
    }
}

struct InstructionStep: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .frame(width: 16)
            
            Text(text)
                .font(.system(.caption, design: .default))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    GitHubAuthView()
        .environmentObject(GitHubService())
}