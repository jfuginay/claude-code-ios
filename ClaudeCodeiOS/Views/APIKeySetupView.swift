import SwiftUI

struct APIKeySetupView: View {
    @EnvironmentObject var claudeService: ClaudeService
    @Environment(\.dismiss) private var dismiss
    
    @State private var apiKey: String = ""
    @State private var isValidating = false
    @State private var validationState: ValidationState = .none
    @State private var showingHelpSheet = false
    @State private var hasAttemptedValidation = false
    
    private var isValidFormat: Bool {
        apiKey.hasPrefix("sk-ant-api") && apiKey.count > 20
    }
    
    private var canSave: Bool {
        isValidFormat && (validationState == .valid || !hasAttemptedValidation)
    }
    
    enum ValidationState {
        case none
        case validating
        case valid
        case invalid
        
        var message: String {
            switch self {
            case .none: return ""
            case .validating: return "Checking API key..."
            case .valid: return "✓ API key is working correctly"
            case .invalid: return "⚠ API key appears to be invalid or expired"
            }
        }
        
        var color: Color {
            switch self {
            case .none: return .clear
            case .validating: return .blue
            case .valid: return .green
            case .invalid: return .orange
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 16) {
                        Image(systemName: "key.radiowaves.forward")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        VStack(spacing: 8) {
                            Text("Connect to Claude")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Enter your Anthropic API key to start using Claude's AI capabilities")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 20)
                    
                    // API Key Input Section
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("API Key")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Button(action: { showingHelpSheet = true }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "questionmark.circle.fill")
                                        Text("Help")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                }
                            }
                            
                            Text("Your API key should start with 'sk-ant-api'")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(spacing: 12) {
                            SecureField("sk-ant-api03-...", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(.body, design: .monospaced))
                                .onChange(of: apiKey) { _ in
                                    if hasAttemptedValidation {
                                        validationState = .none
                                        hasAttemptedValidation = false
                                    }
                                }
                            
                            // Format Validation Indicator
                            if !apiKey.isEmpty {
                                HStack {
                                    Image(systemName: isValidFormat ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundColor(isValidFormat ? .green : .orange)
                                    
                                    Text(isValidFormat ? "Format looks correct" : "API key format doesn't look right")
                                        .font(.caption)
                                        .foregroundColor(isValidFormat ? .green : .orange)
                                    
                                    Spacer()
                                }
                            }
                            
                            // API Validation Status
                            if validationState != .none {
                                HStack {
                                    if validationState == .validating {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: validationState == .valid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                            .foregroundColor(validationState.color)
                                    }
                                    
                                    Text(validationState.message)
                                        .font(.caption)
                                        .foregroundColor(validationState.color)
                                    
                                    Spacer()
                                }
                            }
                        }
                        
                        // Action Buttons
                        HStack(spacing: 12) {
                            Button("Test Connection") {
                                testAPIKey()
                            }
                            .disabled(!isValidFormat || isValidating)
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            
                            Button("Save & Continue") {
                                saveAPIKey()
                            }
                            .disabled(!canSave || isValidating)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Help Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            Text("Don't have an API key yet?")
                                .font(.headline)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. Visit console.anthropic.com")
                            Text("2. Sign up or log in to your account")
                            Text("3. Navigate to 'API Keys' in the sidebar")
                            Text("4. Click 'Create Key' and copy it here")
                        }
                        .font(.body)
                        .foregroundColor(.secondary)
                        
                        Button("Open Anthropic Console") {
                            if let url = URL(string: "https://console.anthropic.com") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("API Setup")
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
            loadExistingAPIKey()
        }
        .sheet(isPresented: $showingHelpSheet) {
            APIKeyHelpView()
        }
    }
    
    private func loadExistingAPIKey() {
        if let existingKey = UserDefaults.standard.string(forKey: "claude_api_key"), !existingKey.isEmpty {
            apiKey = existingKey
            validationState = .valid
        }
    }
    
    private func testAPIKey() {
        guard isValidFormat else { return }
        
        hasAttemptedValidation = true
        validationState = .validating
        
        Task {
            do {
                // Set the API key temporarily for testing
                claudeService.setAPIKey(apiKey)
                
                // Try a minimal test request
                let _ = try await claudeService.sendMessage("Hello", useContext: false)
                
                await MainActor.run {
                    validationState = .valid
                }
            } catch {
                await MainActor.run {
                    validationState = .invalid
                }
            }
        }
    }
    
    private func saveAPIKey() {
        claudeService.setAPIKey(apiKey)
        
        // Show success feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        dismiss()
    }
}

struct APIKeyHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What is an API Key?")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("An API key is like a password that allows this app to securely connect to Claude's AI service. It's unique to your Anthropic account and enables the app to send your questions to Claude and receive intelligent responses.")
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Step-by-Step Guide")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 16) {
                            StepView(
                                number: "1",
                                title: "Visit Anthropic Console",
                                description: "Go to console.anthropic.com in your web browser",
                                systemImage: "safari"
                            )
                            
                            StepView(
                                number: "2",
                                title: "Create Account or Sign In",
                                description: "You'll need an Anthropic account to access the API",
                                systemImage: "person.circle"
                            )
                            
                            StepView(
                                number: "3",
                                title: "Find API Keys Section",
                                description: "Look for 'API Keys' in the left sidebar or main menu",
                                systemImage: "key"
                            )
                            
                            StepView(
                                number: "4",
                                title: "Create New Key",
                                description: "Click 'Create Key' and give it a name like 'iOS App'",
                                systemImage: "plus.circle"
                            )
                            
                            StepView(
                                number: "5",
                                title: "Copy the Key",
                                description: "Copy the entire key (starts with 'sk-ant-api') and paste it in this app",
                                systemImage: "doc.on.clipboard"
                            )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Security & Privacy")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 12) {
                            SecurityFeatureView(
                                icon: "lock.shield",
                                title: "Stored Securely",
                                description: "Your API key is encrypted and stored only on your device"
                            )
                            
                            SecurityFeatureView(
                                icon: "eye.slash",
                                title: "Never Shared",
                                description: "We never share your API key with anyone except Anthropic"
                            )
                            
                            SecurityFeatureView(
                                icon: "dollarsign.circle",
                                title: "You Control Costs",
                                description: "Usage charges apply to your Anthropic account based on your usage"
                            )
                        }
                    }
                    
                    Button("Open Anthropic Console") {
                        if let url = URL(string: "https://console.anthropic.com") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("Getting Your API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StepView: View {
    let number: String
    let title: String
    let description: String
    let systemImage: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(.blue)
                    .frame(width: 32, height: 32)
                
                Text(number)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: systemImage)
                        .foregroundColor(.blue)
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

struct SecurityFeatureView: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.green)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

#Preview {
    APIKeySetupView()
        .environmentObject(ClaudeService(
            tokenizationEngine: TokenizationEngine(cacheManager: CacheManager()),
            cacheManager: CacheManager(),
            gitManager: GitManager(),
            fileSystemManager: FileSystemManager()
        ))
}