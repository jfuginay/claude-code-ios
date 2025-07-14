import SwiftUI

struct GitHubRepositoryView: View {
    @EnvironmentObject var gitHubService: GitHubService
    @EnvironmentObject var gitManager: GitManager
    @EnvironmentObject var claudeService: ClaudeService
    
    @State private var searchText = ""
    @State private var showingAuthSheet = false
    @State private var selectedRepository: GitHubRepository?
    @State private var showingCloneOptions = false
    
    var filteredRepositories: [GitHubRepository] {
        if searchText.isEmpty {
            return gitHubService.repositories
        } else {
            return gitHubService.repositories.filter { repo in
                repo.name.localizedCaseInsensitiveContains(searchText) ||
                repo.fullName.localizedCaseInsensitiveContains(searchText) ||
                (repo.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if gitHubService.isAuthenticated {
                    authenticatedView
                } else {
                    unauthenticatedView
                }
            }
            .navigationTitle("repositories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if gitHubService.isAuthenticated {
                        Button("Sign Out") {
                            gitHubService.signOut()
                        }
                        .font(.system(.caption, design: .monospaced))
                    }
                }
            }
        }
        .sheet(isPresented: $showingAuthSheet) {
            GitHubAuthView()
                .environmentObject(gitHubService)
        }
        .sheet(item: $selectedRepository) { repository in
            RepositoryActionSheet(repository: repository) {
                selectedRepository = nil
            }
            .environmentObject(gitHubService)
            .environmentObject(gitManager)
            .environmentObject(claudeService)
        }
    }
    
    private var authenticatedView: some View {
        VStack(spacing: 0) {
            // User info header
            if let user = gitHubService.currentUser {
                UserHeader(user: user)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                
                Divider()
            }
            
            // Search bar
            SearchBar(searchText: $searchText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            
            // Repository list
            if gitHubService.isLoading {
                LoadingView()
            } else if filteredRepositories.isEmpty {
                EmptyRepositoriesView(hasSearch: !searchText.isEmpty)
            } else {
                repositoryList
            }
        }
        .refreshable {
            await gitHubService.loadRepositories()
        }
    }
    
    private var unauthenticatedView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "person.badge.key")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    Text("Connect to GitHub")
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.medium)
                    
                    Text("Sign in to browse and clone your repositories")
                        .font(.system(.body, design: .default))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            CLIButton(
                title: "gh auth login",
                description: "Authenticate with GitHub",
                icon: "key",
                isEnabled: true
            ) {
                showingAuthSheet = true
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    private var repositoryList: some View {
        List(filteredRepositories, id: \.id) { repository in
            RepositoryRow(repository: repository) {
                selectedRepository = repository
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
    }
}

struct UserHeader: View {
    let user: GitHubUser
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: user.avatarURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color(.systemGray4))
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text("@\(user.login)")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                
                if let name = user.name {
                    Text(name)
                        .font(.system(.caption, design: .default))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text("\(user.publicRepos) repos")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}

struct SearchBar: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(.body, design: .monospaced))
            
            TextField("filter repositories...", text: $searchText)
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct RepositoryRow: View {
    let repository: GitHubRepository
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(repository.name)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if repository.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                    
                    Text(relativeDateString(from: repository.updatedDate))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.tertiary)
                }
                
                if let description = repository.description {
                    Text(description)
                        .font(.system(.caption, design: .default))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 16) {
                    if let language = repository.language {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(repository.languageColor)
                                .frame(width: 8, height: 8)
                            Text(language)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if repository.stargazersCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "star")
                                .font(.caption2)
                            Text("\(repository.stargazersCount)")
                                .font(.system(.caption2, design: .monospaced))
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    if repository.forksCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "tuningfork")
                                .font(.caption2)
                            Text("\(repository.forksCount)")
                                .font(.system(.caption2, design: .monospaced))
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(0.8)
            
            Text("Loading repositories...")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyRepositoriesView: View {
    let hasSearch: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasSearch ? "magnifyingglass" : "folder")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(hasSearch ? "No matching repositories" : "No repositories found")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RepositoryActionSheet: View {
    let repository: GitHubRepository
    let onDismiss: () -> Void
    
    @EnvironmentObject var gitHubService: GitHubService
    @EnvironmentObject var gitManager: GitManager
    @EnvironmentObject var claudeService: ClaudeService
    
    @State private var isCloning = false
    @State private var cloneError: String?
    @State private var showingChat = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Repository header
                VStack(spacing: 12) {
                    Text(repository.name)
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                    
                    if let description = repository.description {
                        Text(description)
                            .font(.system(.body, design: .default))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    HStack(spacing: 16) {
                        if let language = repository.language {
                            Label(language, systemImage: "chevron.left.forwardslash.chevron.right")
                                .font(.system(.caption, design: .monospaced))
                        }
                        
                        Label("\(repository.stargazersCount)", systemImage: "star")
                            .font(.system(.caption, design: .monospaced))
                        
                        Label("\(repository.forksCount)", systemImage: "tuningfork")
                            .font(.system(.caption, design: .monospaced))
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Actions
                VStack(spacing: 12) {
                    CLIButton(
                        title: "git clone",
                        description: "Clone repository locally",
                        icon: "arrow.down.to.line",
                        isEnabled: !isCloning
                    ) {
                        cloneRepository()
                    }
                    
                    CLIButton(
                        title: "start chat",
                        description: "Discuss this repository with Claude",
                        icon: "bubble.left.and.text.bubble.right",
                        isEnabled: true
                    ) {
                        startChatWithRepository()
                    }
                    
                    CLIButton(
                        title: "open in browser",
                        description: "View on GitHub",
                        icon: "safari",
                        isEnabled: true
                    ) {
                        openInBrowser()
                    }
                }
                
                if let error = cloneError {
                    Text(error)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.red)
                        .padding(.top, 8)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationTitle("Repository")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private func cloneRepository() {
        isCloning = true
        cloneError = nil
        
        Task {
            do {
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let localPath = documentsPath.appendingPathComponent(repository.name)
                
                try await gitHubService.cloneRepository(repository, to: localPath, gitManager: gitManager)
                
                await MainActor.run {
                    isCloning = false
                    onDismiss()
                }
            } catch {
                await MainActor.run {
                    isCloning = false
                    cloneError = error.localizedDescription
                }
            }
        }
    }
    
    private func startChatWithRepository() {
        // TODO: Navigate to chat with repository context
        onDismiss()
    }
    
    private func openInBrowser() {
        if let url = URL(string: repository.htmlURL) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    GitHubRepositoryView()
        .environmentObject(GitHubService())
        .environmentObject(GitManager())
        .environmentObject(ClaudeService(
            tokenizationEngine: TokenizationEngine(cacheManager: CacheManager()),
            cacheManager: CacheManager(),
            gitManager: GitManager(),
            fileSystemManager: FileSystemManager()
        ))
}