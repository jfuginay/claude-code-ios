import Foundation
import SwiftUI

@MainActor
class GitHubService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: GitHubUser?
    @Published var repositories: [GitHubRepository] = []
    @Published var isLoading = false
    @Published var error: GitHubError?
    
    private let baseURL = "https://api.github.com"
    private let tokenKey = "github_access_token"
    
    var accessToken: String? {
        get { UserDefaults.standard.string(forKey: tokenKey) }
        set { 
            UserDefaults.standard.set(newValue, forKey: tokenKey)
            isAuthenticated = newValue != nil
        }
    }
    
    init() {
        isAuthenticated = accessToken != nil
        if isAuthenticated {
            Task {
                await loadCurrentUser()
            }
        }
    }
    
    // MARK: - Authentication
    
    func authenticate(with token: String) async {
        accessToken = token
        await loadCurrentUser()
    }
    
    func signOut() {
        accessToken = nil
        currentUser = nil
        repositories = []
        isAuthenticated = false
    }
    
    // MARK: - User Management
    
    func loadCurrentUser() async {
        guard let token = accessToken else { return }
        
        isLoading = true
        error = nil
        
        do {
            let request = createRequest(endpoint: "/user", token: token)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                throw GitHubError.apiError("Failed to load user: \(httpResponse.statusCode)")
            }
            
            let user = try JSONDecoder().decode(GitHubUser.self, from: data)
            currentUser = user
            
            // Load repositories after getting user
            await loadRepositories()
            
        } catch {
            self.error = GitHubError.networkError(error.localizedDescription)
            isAuthenticated = false
            accessToken = nil
        }
        
        isLoading = false
    }
    
    // MARK: - Repository Management
    
    func loadRepositories() async {
        guard let token = accessToken else { return }
        
        isLoading = true
        error = nil
        
        do {
            let request = createRequest(endpoint: "/user/repos?sort=updated&per_page=100", token: token)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                throw GitHubError.apiError("Failed to load repositories: \(httpResponse.statusCode)")
            }
            
            let repos = try JSONDecoder().decode([GitHubRepository].self, from: data)
            repositories = repos.sorted { $0.updatedAt > $1.updatedAt }
            
        } catch {
            self.error = GitHubError.networkError(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func searchRepositories(query: String) async -> [GitHubRepository] {
        guard let token = accessToken, !query.isEmpty else { return [] }
        
        do {
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let request = createRequest(endpoint: "/search/repositories?q=\(encodedQuery)&sort=updated", token: token)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                return []
            }
            
            let searchResult = try JSONDecoder().decode(GitHubSearchResult.self, from: data)
            return searchResult.items
            
        } catch {
            return []
        }
    }
    
    // MARK: - Repository Operations
    
    func cloneRepository(_ repository: GitHubRepository, to localPath: URL, gitManager: GitManager) async throws {
        guard let cloneURL = repository.cloneURL else {
            throw GitHubError.invalidRepository("Repository has no clone URL")
        }
        
        try await gitManager.cloneRepository(from: cloneURL, to: localPath, name: repository.name)
    }
    
    // MARK: - Helper Methods
    
    private func createRequest(endpoint: String, token: String) -> URLRequest {
        let url = URL(string: baseURL + endpoint)!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("claude-code-ios/1.0", forHTTPHeaderField: "User-Agent")
        return request
    }
}

// MARK: - Models

struct GitHubUser: Codable, Identifiable {
    let id: Int
    let login: String
    let name: String?
    let email: String?
    let avatarURL: String
    let publicRepos: Int
    let privateRepos: Int?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, login, name, email
        case avatarURL = "avatar_url"
        case publicRepos = "public_repos"
        case privateRepos = "total_private_repos"
        case createdAt = "created_at"
    }
}

struct GitHubRepository: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let htmlURL: String
    let cloneURL: String?
    let sshURL: String?
    let isPrivate: Bool
    let isFork: Bool
    let language: String?
    let stargazersCount: Int
    let forksCount: Int
    let size: Int
    let defaultBranch: String
    let createdAt: String
    let updatedAt: String
    let pushedAt: String?
    let owner: GitHubUser
    
    var updatedDate: Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: updatedAt) ?? Date()
    }
    
    var languageColor: Color {
        switch language?.lowercased() {
        case "swift": return .orange
        case "javascript", "typescript": return .yellow
        case "python": return .blue
        case "java": return .red
        case "go": return .cyan
        case "rust": return .brown
        case "c++", "cpp": return .purple
        case "c": return .gray
        case "html": return .orange
        case "css": return .blue
        case "ruby": return .red
        case "php": return .purple
        case "kotlin": return .orange
        case "dart": return .blue
        default: return .secondary
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, language, size, owner
        case fullName = "full_name"
        case htmlURL = "html_url"
        case cloneURL = "clone_url"
        case sshURL = "ssh_url"
        case isPrivate = "private"
        case isFork = "fork"
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case defaultBranch = "default_branch"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case pushedAt = "pushed_at"
    }
}

struct GitHubSearchResult: Codable {
    let totalCount: Int
    let incompleteResults: Bool
    let items: [GitHubRepository]
    
    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case incompleteResults = "incomplete_results"
        case items
    }
}

// MARK: - Error Types

enum GitHubError: LocalizedError {
    case networkError(String)
    case apiError(String)
    case authenticationError
    case invalidRepository(String)
    case cloneError(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let message):
            return "GitHub API error: \(message)"
        case .authenticationError:
            return "GitHub authentication failed"
        case .invalidRepository(let message):
            return "Invalid repository: \(message)"
        case .cloneError(let message):
            return "Clone error: \(message)"
        }
    }
}