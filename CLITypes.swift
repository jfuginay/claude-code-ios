import SwiftUI
import Foundation

// MARK: - CLI Message Types

struct CLIMessage: Identifiable {
    let id = UUID()
    let content: String
    let type: MessageType
    let prompt: String
    let timestamp = Date()
    
    enum MessageType {
        case user
        case system
        case error
        case processing
    }
}

// MARK: - CLI Mode Enums

enum CLIMode {
    case repositorySelection
    case claudeCLI
    case repositoryBrowser
}

// MARK: - Project Session Manager

class ProjectSessionManager: ObservableObject {
    private let userDefaults = UserDefaults.standard
    private let recentReposKey = "recentRepositories"
    private let maxRecentRepos = 10
    
    func saveRecentRepository(_ repository: Repository) {
        var recentRepos = getRecentRepositoryIDs()
        
        // Remove if already exists
        recentRepos.removeAll { $0 == repository.id.uuidString }
        
        // Add to front
        recentRepos.insert(repository.id.uuidString, at: 0)
        
        // Limit to max count
        if recentRepos.count > maxRecentRepos {
            recentRepos = Array(recentRepos.prefix(maxRecentRepos))
        }
        
        userDefaults.set(recentRepos, forKey: recentReposKey)
    }
    
    func loadRecentRepositories(gitManager: GitManager) {
        let recentIDs = getRecentRepositoryIDs()
        
        // Reorder repositories based on recent usage
        let recentRepos = recentIDs.compactMap { idString in
            guard let uuid = UUID(uuidString: idString) else { return nil }
            return gitManager.repositories.first { $0.id == uuid }
        }
        
        let otherRepos = gitManager.repositories.filter { repo in
            !recentIDs.contains(repo.id.uuidString)
        }
        
        gitManager.repositories = recentRepos + otherRepos
    }
    
    func getLastUsedTime(for repository: Repository) -> String {
        let recentIDs = getRecentRepositoryIDs()
        if let index = recentIDs.firstIndex(of: repository.id.uuidString) {
            switch index {
            case 0: return "just now"
            case 1: return "recently"
            case 2: return "a while ago"
            default: return "long ago"
            }
        }
        return "never"
    }
    
    private func getRecentRepositoryIDs() -> [String] {
        return userDefaults.stringArray(forKey: recentReposKey) ?? []
    }
}

// MARK: - Claude Branch Manager

class ClaudeBranchManager: ObservableObject {
    @Published var currentBranch: String = "main"
    private var repository: Repository?
    
    func setRepository(_ repository: Repository) {
        self.repository = repository
        self.currentBranch = repository.currentBranch
    }
    
    func createBranch(_ name: String) {
        currentBranch = name
        // In a real implementation, this would create the branch via Git
    }
}

// MARK: - GitHub Types

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

struct GitHubSearchResult: Codable {
    let items: [GitHubRepository]
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
        
        let url = URL(string: "\(baseURL)/user")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(GitHubUser.self, from: data)
    }
    
    func getUserRepositories() async throws -> [GitHubRepository] {
        guard let token = token else {
            throw GitHubError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/user/repos?sort=updated&per_page=50")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([GitHubRepository].self, from: data)
    }
    
    func searchRepositories(query: String) async throws -> [GitHubRepository] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "\(baseURL)/search/repositories?q=\(encodedQuery)&sort=stars&order=desc&per_page=20")!
        
        var request = URLRequest(url: url)
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let searchResult = try JSONDecoder().decode(GitHubSearchResult.self, from: data)
        return searchResult.items
    }
}

enum GitHubError: Error {
    case notAuthenticated
    case invalidResponse
    case networkError
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