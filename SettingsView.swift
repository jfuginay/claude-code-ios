import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var claudeService: ClaudeService
    
    @State private var apiKey: String = ""
    @State private var showingAPIKeyAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Claude API Configuration")
                        .font(.headline)
                    
                    Text("Enter your Anthropic API key to enable Claude functionality")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        SecureField("API Key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        
                        Button("Save") {
                            saveAPIKey()
                        }
                        .disabled(apiKey.isEmpty)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    
                } header: {
                    Text("API Configuration")
                }
                
                Section {
                    Button("Get API Key") {
                        if let url = URL(string: "https://console.anthropic.com") {
                            UIApplication.shared.open(url)
                        }
                    }
                    
                    Text("Visit console.anthropic.com to get your API key")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                } header: {
                    Text("Help")
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear {
            loadAPIKey()
        }
        .alert("API Key Saved", isPresented: $showingAPIKeyAlert) {
            Button("OK") { }
        } message: {
            Text("Your API key has been saved successfully.")
        }
    }
    
    private func loadAPIKey() {
        if let existingKey = UserDefaults.standard.string(forKey: "claude_api_key") {
            apiKey = existingKey
        }
    }
    
    private func saveAPIKey() {
        claudeService.setAPIKey(apiKey)
        showingAPIKeyAlert = true
    }
}

#Preview {
    SettingsView()
}