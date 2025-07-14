import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showingAPISetup = false
    
    // Real service instances
    @StateObject private var cacheManager = CacheManager()
    @StateObject private var gitManager = GitManager()
    @StateObject private var fileSystemManager = FileSystemManager()
    @StateObject private var tokenizationEngine: TokenizationEngine
    @StateObject private var claudeService: ClaudeService
    // @StateObject private var taskManager = TaskManager() // TODO: Add after adding TaskManager to Xcode project
    // @StateObject private var gitHubService = GitHubService() // TODO: Add after adding GitHubService to Xcode project
    
    init() {
        let cacheManager = CacheManager()
        let gitManager = GitManager()
        let fileSystemManager = FileSystemManager()
        let tokenizationEngine = TokenizationEngine(cacheManager: cacheManager)
        let claudeService = ClaudeService(
            tokenizationEngine: tokenizationEngine,
            cacheManager: cacheManager,
            gitManager: gitManager,
            fileSystemManager: fileSystemManager
        )
        
        self._cacheManager = StateObject(wrappedValue: cacheManager)
        self._gitManager = StateObject(wrappedValue: gitManager)
        self._fileSystemManager = StateObject(wrappedValue: fileSystemManager)
        self._tokenizationEngine = StateObject(wrappedValue: tokenizationEngine)
        self._claudeService = StateObject(wrappedValue: claudeService)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Claude Code Terminal - exact replica of Claude Code for macOS
            ChatView()
                .environmentObject(claudeService)
                .environmentObject(gitManager)
                .environmentObject(fileSystemManager)
                .tabItem {
                    Image(systemName: "terminal.fill")
                    Text("claude")
                }
                .tag(0)
            
            // Projects Tab  
            ProjectsView()
                .environmentObject(gitManager)
                .environmentObject(fileSystemManager)
                .environmentObject(claudeService)
                .tabItem {
                    Image(systemName: "folder.badge.gearshape")
                    Text("repos")
                }
                .tag(1)
            
            // Claude Desktop Chat - for ideation and PRD creation
            NavigationView {
                ChatView()
                    .navigationTitle("Claude Chat")
                    .navigationBarTitleDisplayMode(.large)
            }
            .environmentObject(claudeService)
            .environmentObject(gitManager)
            .environmentObject(fileSystemManager)
            .tabItem {
                Image(systemName: "bubble.left.and.text.bubble.right")
                Text("chat")
            }
            .tag(2)
            
            // Claude Flow & Swarm - Multi-agent task orchestration
            ClaudeFlowSwarmView(claudeService: claudeService)
                .environmentObject(claudeService)
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("flow")
                }
                .tag(3)
            
            // TaskMaster Tab (temporarily disabled - need to add to Xcode project)
            TaskMasterView()
                .environmentObject(claudeService)
                .tabItem {
                    Image(systemName: "checklist")
                    Text("tasks")
                }
                .tag(4)
            
            
            // Settings Tab
            SettingsTabView(showingAPISetup: $showingAPISetup)
                .environmentObject(claudeService)
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("config")
                }
                .tag(5)
        }
        .accentColor(.blue)
        .sheet(isPresented: $showingAPISetup) {
            APIKeySetupView()
                .environmentObject(claudeService)
        }
    }
}

struct HomeView: View {
    @Binding var selectedTab: Int
    @Binding var showingAPISetup: Bool
    @EnvironmentObject var claudeService: ClaudeService
    // @EnvironmentObject var taskManager: TaskManager // TODO: Add after adding TaskManager to Xcode project
    @State private var isConfigured = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "terminal")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Claude Code")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("AI-powered coding assistant for iOS")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Feature Cards
                VStack(spacing: 16) {
                    FeatureCard(
                        icon: "bubble.left.and.text.bubble.right",
                        title: "Interactive Chat",
                        description: "Get coding help through natural conversation"
                    )
                    
                    FeatureCard(
                        icon: "folder",
                        title: "File Management",
                        description: "Browse and edit your project files"
                    )
                    
                    FeatureCard(
                        icon: "hammer",
                        title: "Code Tools",
                        description: "Run code, analyze structure, and debug issues"
                    )
                    
                    FeatureCard(
                        icon: "arrow.triangle.branch",
                        title: "Git Integration",
                        description: "Manage version control and commits"
                    )
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Quick Start
                VStack(spacing: 12) {
                    Text("Quick Start")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        QuickStartButton(
                            icon: "plus.bubble",
                            title: "Start New Conversation",
                            description: "Ask Claude about your code"
                        ) {
                            selectedTab = 2
                        }
                        
                        QuickStartButton(
                            icon: "folder.badge.plus",
                            title: "Open Project",
                            description: "Browse your project files"
                        ) {
                            selectedTab = 1
                        }
                        
                        QuickStartButton(
                            icon: "doc.text.magnifyingglass",
                            title: "Analyze Code",
                            description: "Get insights about your codebase"
                        ) {
                            // Open code analysis
                        }
                        
                        // TODO: Task management quick actions - Add after adding TaskManager to Xcode project
                        /*
                        QuickStartButton(
                            icon: "checklist",
                            title: "View Tasks",
                            description: "Manage your project tasks"
                        ) {
                            selectedTab = 3
                        }
                        
                        if let nextTask = taskManager.getNextTask() {
                            QuickTaskButton(
                                task: nextTask,
                                onStart: {
                                    taskManager.setCurrentTask(nextTask)
                                    selectedTab = 3
                                }
                            )
                        }
                        */
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Claude Code")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                checkAPIKeyStatus()
            }
            .onChange(of: showingAPISetup) { _ in
                if !showingAPISetup {
                    // Refresh status when returning from setup
                    checkAPIKeyStatus()
                }
            }
        }
    }
    
    private func checkAPIKeyStatus() {
        if let apiKey = UserDefaults.standard.string(forKey: "claude_api_key") {
            isConfigured = !apiKey.isEmpty
        } else {
            isConfigured = false
        }
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct QuickStartButton: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct SettingsTabView: View {
    @Binding var showingAPISetup: Bool
    @EnvironmentObject var claudeService: ClaudeService
    @State private var isConfigured = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Claude API") {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            HStack {
                                Text("API Configuration")
                                    .font(.headline)
                                
                                if isConfigured {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                            }
                            
                            Text(isConfigured ? "Claude is ready to use" : "Connect your Anthropic API key")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(isConfigured ? "Reconfigure" : "Set Up") {
                            showingAPISetup = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                
                Section("App Settings") {
                    SettingsRow(icon: "moon", title: "Dark Mode", subtitle: "System")
                    SettingsRow(icon: "textformat", title: "Font Size", subtitle: "Medium")
                }
                
                Section("About") {
                    SettingsRow(icon: "info.circle", title: "Version", subtitle: "1.0.0")
                    SettingsRow(icon: "doc.text", title: "Privacy Policy")
                    SettingsRow(icon: "questionmark.circle", title: "Help & Support")
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear {
            checkAPIKeyStatus()
        }
    }
    
    private func checkAPIKeyStatus() {
        if let apiKey = UserDefaults.standard.string(forKey: "claude_api_key") {
            isConfigured = !apiKey.isEmpty
        } else {
            isConfigured = false
        }
    }
}

// TODO: QuickTaskButton - Add after adding TaskManager to Xcode project
/*
struct QuickTaskButton: View {
    let task: Task
    let onStart: () -> Void
    
    var body: some View {
        Button(action: onStart) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Next Task")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Image(systemName: task.priority.icon)
                        .foregroundColor(task.priority.color)
                        .font(.caption)
                }
                
                Text(task.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: task.category.icon)
                        Text(task.category.rawValue.capitalized)
                    }
                    .font(.caption)
                    .foregroundColor(task.category.color)
                    
                    Spacer()
                    
                    Text("Start Task")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}
*/

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let isDestructive: Bool
    let action: (() -> Void)?
    
    init(icon: String, title: String, subtitle: String? = nil, isDestructive: Bool = false, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Button(action: action ?? {}) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(isDestructive ? .red : .blue)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(isDestructive ? .red : .primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .disabled(action == nil)
    }
}

#Preview {
    ContentView()
}
