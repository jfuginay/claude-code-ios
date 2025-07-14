import SwiftUI

struct GitHubRepositoryBrowserView: View {
    @State private var searchText = ""
    @State private var repositories: [GitHubRepository] = []
    @State private var isLoading = false
    @State private var currentUser: GitHubUser?
    @State private var organizations: [GitHubOrganization] = []
    @State private var selectedFilter: RepositoryFilter = .all
    
    let onRepositoryCloned: (Repository) -> Void
    let onCancel: () -> Void
    
    @EnvironmentObject var gitManager: GitManager
    @State private var gitHubService = GitHubService()
    
    enum RepositoryFilter: String, CaseIterable {
        case all = "All"
        case owned = "Owned"
        case member = "Member"
        case starred = "Starred"
        case recent = "Recent"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            GitHubBrowserHeader(
                currentUser: currentUser,
                onCancel: onCancel
            )
            
            // Search and filters
            GitHubSearchBar(
                searchText: $searchText,
                selectedFilter: $selectedFilter,
                onSearch: performSearch
            )
            
            // Repository list
            if isLoading {
                LoadingRepositoriesView()
            } else if repositories.isEmpty {
                EmptyRepositoriesView(hasSearched: !searchText.isEmpty)
            } else {
                RepositoryListView(
                    repositories: repositories,
                    onRepositorySelected: cloneRepository
                )
            }
        }
        .background(Color.black)
        .onAppear {
            loadGitHubData()
        }
    }
    
    private func loadGitHubData() {
        Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                // Check if authenticated
                if let token = UserDefaults.standard.string(forKey: "github_token"), !token.isEmpty {
                    try await gitHubService.authenticate(with: token)
                    await loadUserRepositories()
                } else {
                    // Show public repositories or prompt for authentication
                    await loadPublicRepositories()
                }
            } catch {
                print("GitHub authentication failed: \\(error)")
                await loadPublicRepositories()
            }
        }
    }
    
    @MainActor
    private func loadUserRepositories() async {
        do {
            currentUser = try await gitHubService.getCurrentUser()
            repositories = try await gitHubService.getUserRepositories()
        } catch {
            print("Failed to load user repositories: \\(error)")
        }
    }
    
    @MainActor
    private func loadPublicRepositories() async {
        // Load some popular public repositories as examples
        repositories = [
            GitHubRepository(
                name: "react",
                fullName: "facebook/react",
                description: "The library for web and native user interfaces",
                url: "https://github.com/facebook/react",
                cloneURL: "https://github.com/facebook/react.git",
                language: "JavaScript",
                stars: 228000,
                isPrivate: false,
                updatedAt: Date()
            ),
            GitHubRepository(
                name: "vue",
                fullName: "vuejs/vue",
                description: "Vue.js is a progressive, incrementally-adoptable JavaScript framework",
                url: "https://github.com/vuejs/vue",
                cloneURL: "https://github.com/vuejs/vue.git",
                language: "TypeScript",
                stars: 207000,
                isPrivate: false,
                updatedAt: Date()
            )
        ]
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                repositories = try await gitHubService.searchRepositories(query: searchText)
            } catch {
                print("Search failed: \\(error)")
            }
        }
    }
    
    private func cloneRepository(_ repository: GitHubRepository) {
        Task {
            do {
                let localRepo = try await gitManager.cloneRepository(url: repository.cloneURL, name: repository.name)
                await MainActor.run {
                    onRepositoryCloned(localRepo)
                }
            } catch {
                print("Failed to clone repository: \\(error)")
            }
        }
    }
}

struct GitHubBrowserHeader: View {
    let currentUser: GitHubUser?
    let onCancel: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onCancel) {
                HStack {
                    Text("←")
                    Text("Back")
                }
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("GitHub Repository Browser")
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(.white)
            
            Spacer()
            
            if let user = currentUser {
                HStack(spacing: 4) {
                    Image(systemName: "person.circle")
                        .foregroundColor(.green)
                    Text(user.login)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                }
            } else {
                Text("Public")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
}

struct GitHubSearchBar: View {
    @Binding var searchText: String
    @Binding var selectedFilter: GitHubRepositoryBrowserView.RepositoryFilter
    let onSearch: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Search input
            HStack {
                Text("Search:")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                
                TextField("repository name or username/repo", text: $searchText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        onSearch()
                    }
                
                Button("Search", action: onSearch)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.blue)
                    .buttonStyle(.plain)
            }
            
            // Filter buttons
            HStack {
                Text("Filter:")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
                
                ForEach(GitHubRepositoryBrowserView.RepositoryFilter.allCases, id: \\.self) { filter in
                    Button(filter.rawValue) {
                        selectedFilter = filter
                    }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(selectedFilter == filter ? .green : .blue)
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
}

struct LoadingRepositoriesView: View {
    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
                .tint(.white)
            
            Text("Loading repositories...")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyRepositoriesView: View {
    let hasSearched: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text(hasSearched ? "No repositories found" : "Start by searching for repositories")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.yellow)
            
            if !hasSearched {
                Text("Try searching for 'react', 'vue', or 'your-username/repo-name'")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct RepositoryListView: View {
    let repositories: [GitHubRepository]
    let onRepositorySelected: (GitHubRepository) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(repositories, id: \\.id) { repository in
                    GitHubRepositoryRow(
                        repository: repository,
                        onSelected: { onRepositorySelected(repository) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

struct GitHubRepositoryRow: View {
    let repository: GitHubRepository
    let onSelected: () -> Void
    
    var body: some View {
        Button(action: onSelected) {
            VStack(alignment: .leading, spacing: 4) {
                // Repository name and privacy
                HStack {
                    Text(repository.fullName)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                    
                    if repository.isPrivate {
                        Text("PRIVATE")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.red)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(3)
                    }
                    
                    Spacer()
                    
                    // Stars
                    HStack(spacing: 2) {
                        Image(systemName: "star")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text("\\(repository.stars)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
                
                // Description
                if let description = repository.description {
                    Text(description)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                // Language and updated date
                HStack {
                    if let language = repository.language {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(languageColor(language))
                                .frame(width: 8, height: 8)
                            Text(language)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    Text("Updated \\(repository.updatedAt, style: .relative)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    private func languageColor(_ language: String) -> Color {
        switch language.lowercased() {
        case "swift": return .orange
        case "javascript": return .yellow
        case "typescript": return .blue
        case "python": return .green
        case "java": return .red
        case "go": return .cyan
        case "rust": return .orange
        default: return .gray
        }
    }
}

// MARK: - GitHub Models

struct GitHubUser: Codable {
    let id: Int
    let login: String
    let name: String?
    let email: String?
    let avatarURL: String?
    
    enum CodingKeys: String, CodingKey {
        case id, login, name, email
        case avatarURL = "avatar_url"
    }
}

struct GitHubRepository: Codable, Identifiable {
    let id = UUID()
    let name: String
    let fullName: String
    let description: String?
    let url: String
    let cloneURL: String
    let language: String?
    let stars: Int
    let isPrivate: Bool
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case description
        case url = "html_url"
        case cloneURL = "clone_url"
        case language
        case stars = "stargazers_count"
        case isPrivate = "private"
        case updatedAt = "updated_at"
    }
}

struct GitHubOrganization: Codable {
    let id: Int
    let login: String
    let name: String?
    let description: String?
}

// MARK: - GitHub Service

class GitHubService: ObservableObject {
    private var token: String?
    private let baseURL = "https://api.github.com"
    
    func authenticate(with token: String) async throws {
        self.token = token
        // Verify token by making a test request
        _ = try await getCurrentUser()
    }
    
    func getCurrentUser() async throws -> GitHubUser {
        guard let token = token else {
            throw GitHubError.notAuthenticated
        }
        
        let url = URL(string: "\\(baseURL)/user")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \\(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(GitHubUser.self, from: data)
    }
    
    func getUserRepositories() async throws -> [GitHubRepository] {
        guard let token = token else {
            throw GitHubError.notAuthenticated
        }
        
        let url = URL(string: "\\(baseURL)/user/repos?sort=updated&per_page=50")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \\(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([GitHubRepository].self, from: data)
    }
    
    func searchRepositories(query: String) async throws -> [GitHubRepository] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "\\(baseURL)/search/repositories?q=\\(encodedQuery)&sort=stars&order=desc&per_page=20")!
        
        var request = URLRequest(url: url)
        if let token = token {
            request.setValue("Bearer \\(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let searchResult = try JSONDecoder().decode(GitHubSearchResult.self, from: data)
        return searchResult.items
    }
}

struct GitHubSearchResult: Codable {
    let items: [GitHubRepository]
}

enum GitHubError: Error {
    case notAuthenticated
    case invalidResponse
    case networkError
}

#Preview {
    GitHubRepositoryBrowserView(
        onRepositoryCloned: { _ in },
        onCancel: { }
    )
    .environmentObject(GitManager())
}