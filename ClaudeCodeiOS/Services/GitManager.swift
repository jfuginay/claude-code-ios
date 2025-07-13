import Foundation
import Combine

@MainActor
class GitManager: ObservableObject {
    @Published var repositories: [Repository] = []
    @Published var currentRepository: Repository?
    @Published var currentBranch: String?
    @Published var isLoading = false
    @Published var error: GitError?
    
    private let fileManager = FileManager.default
    private let workspaceURL: URL
    
    init() {
        // Create workspace directory in Documents
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.workspaceURL = documentsURL.appendingPathComponent("ClaudeCode")
        
        createWorkspaceDirectories()
        loadRepositories()
    }
    
    // MARK: - Repository Management
    
    func loadRepositories() {
        do {
            let repositoriesURL = workspaceURL.appendingPathComponent("repositories")
            let contents = try fileManager.contentsOfDirectory(at: repositoriesURL, includingPropertiesForKeys: [.isDirectoryKey])
            
            repositories = contents.compactMap { url -> Repository? in
                guard url.hasDirectoryPath else { return nil }
                
                let name = url.lastPathComponent
                let gitURL = url.appendingPathComponent(".git")
                let isGitRepo = fileManager.fileExists(atPath: gitURL.path)
                
                if isGitRepo {
                    return Repository(
                        name: name,
                        localPath: url,
                        remoteURL: getRemoteURL(for: url),
                        currentBranch: getCurrentBranch(for: url) ?? "main"
                    )
                }
                return nil
            }
        } catch {
            self.error = .fileSystemError(error.localizedDescription)
        }
    }
    
    func cloneRepository(url: String, name: String? = nil) async throws -> Repository {
        isLoading = true
        defer { isLoading = false }
        
        let repoName = name ?? extractRepoName(from: url)
        let localPath = workspaceURL.appendingPathComponent("repositories").appendingPathComponent(repoName)
        
        // Ensure directory doesn't exist
        if fileManager.fileExists(atPath: localPath.path) {
            throw GitError.repositoryAlreadyExists
        }
        
        try await executeGitCommand(["clone", url, localPath.path])
        
        let repository = Repository(
            name: repoName,
            localPath: localPath,
            remoteURL: url,
            currentBranch: getCurrentBranch(for: localPath) ?? "main"
        )
        
        repositories.append(repository)
        return repository
    }
    
    func deleteRepository(_ repository: Repository) throws {
        try fileManager.removeItem(at: repository.localPath)
        repositories.removeAll { $0.id == repository.id }
        
        if currentRepository?.id == repository.id {
            currentRepository = nil
        }
    }
    
    // MARK: - Branch Operations
    
    func getBranches(for repository: Repository) async throws -> [GitBranch] {
        let output = try await executeGitCommand(["branch", "-a"], in: repository.localPath)
        return parseBranches(from: output)
    }
    
    func createBranch(name: String, in repository: Repository) async throws {
        try await executeGitCommand(["checkout", "-b", name], in: repository.localPath)
        await refreshRepository(repository)
    }
    
    func switchBranch(to branch: String, in repository: Repository) async throws {
        try await executeGitCommand(["checkout", branch], in: repository.localPath)
        await refreshRepository(repository)
    }
    
    func deleteBranch(name: String, in repository: Repository) async throws {
        try await executeGitCommand(["branch", "-d", name], in: repository.localPath)
        await refreshRepository(repository)
    }
    
    // MARK: - File Operations
    
    func getFileStatus(for repository: Repository) async throws -> [GitChange] {
        let output = try await executeGitCommand(["status", "--porcelain"], in: repository.localPath)
        return parseFileStatus(from: output, repository: repository)
    }
    
    func getFileDiff(for file: WorkspaceFile, in repository: Repository) async throws -> String {
        let relativePath = file.relativePath
        return try await executeGitCommand(["diff", relativePath], in: repository.localPath)
    }
    
    func stageFile(_ file: WorkspaceFile, in repository: Repository) async throws {
        try await executeGitCommand(["add", file.relativePath], in: repository.localPath)
    }
    
    func unstageFile(_ file: WorkspaceFile, in repository: Repository) async throws {
        try await executeGitCommand(["reset", "HEAD", file.relativePath], in: repository.localPath)
    }
    
    func stageAllFiles(in repository: Repository) async throws {
        try await executeGitCommand(["add", "."], in: repository.localPath)
    }
    
    // MARK: - Commit Operations
    
    func commitChanges(message: String, in repository: Repository) async throws -> GitCommit {
        let commitHash = try await executeGitCommand(
            ["commit", "-m", message], 
            in: repository.localPath
        )
        
        let commit = GitCommit(
            hash: extractCommitHash(from: commitHash),
            message: message,
            author: try await getGitUserName(),
            email: try await getGitUserEmail()
        )
        
        await refreshRepository(repository)
        return commit
    }
    
    func getCommitHistory(for repository: Repository, limit: Int = 100) async throws -> [GitCommit] {
        let output = try await executeGitCommand([
            "log", 
            "--oneline", 
            "--format=%H|%s|%an|%ae|%at",
            "-n", "\(limit)"
        ], in: repository.localPath)
        
        return parseCommitHistory(from: output)
    }
    
    // MARK: - Remote Operations
    
    func pullChanges(from repository: Repository) async throws {
        try await executeGitCommand(["pull"], in: repository.localPath)
        await refreshRepository(repository)
    }
    
    func pushChanges(from repository: Repository) async throws {
        try await executeGitCommand(["push"], in: repository.localPath)
        await refreshRepository(repository)
    }
    
    func fetchChanges(from repository: Repository) async throws {
        try await executeGitCommand(["fetch"], in: repository.localPath)
        await refreshRepository(repository)
    }
    
    // MARK: - Utility Functions
    
    private func createWorkspaceDirectories() {
        let directories = [
            "repositories",
            "cache/tokenized",
            "cache/embeddings", 
            "cache/contexts",
            "config"
        ]
        
        for dir in directories {
            let url = workspaceURL.appendingPathComponent(dir)
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    private func refreshRepository(_ repository: Repository) async {
        // Update repository state
        if let index = repositories.firstIndex(where: { $0.id == repository.id }) {
            var updatedRepo = repository
            // Update with latest Git state
            repositories[index] = updatedRepo
        }
        
        if currentRepository?.id == repository.id {
            currentRepository = repositories.first { $0.id == repository.id }
        }
    }
    
    private func executeGitCommand(_ args: [String], in directory: URL? = nil) async throws -> String {
        // TODO: Implement using libgit2 or SwiftGit2 for real Git operations in iOS
        // iOS apps cannot execute external processes due to sandboxing restrictions
        
        guard let command = args.first else {
            throw GitError.gitCommandFailed("No command provided")
        }
        
        // Mock responses for different Git commands to enable app functionality
        switch command {
        case "status":
            return "On branch main\nnothing to commit, working tree clean"
        case "branch":
            return "* main"
        case "log":
            return "commit abc123 (HEAD -> main)\nAuthor: User <user@example.com>\nDate: \(Date())\n\n    Initial commit"
        case "diff":
            return "" // No changes
        case "clone":
            // Mock successful clone
            return "Cloning into '\(args.last ?? "repository")'..."
        case "add":
            return "Files added to staging area"
        case "commit":
            return "1 file changed, 1 insertion(+)"
        case "push":
            return "Everything up-to-date"
        case "pull":
            return "Already up to date."
        default:
            return "Command executed successfully"
        }
    }
    
    // MARK: - Parsing Functions
    
    private func extractRepoName(from url: String) -> String {
        let components = url.split(separator: "/")
        let name = components.last?.replacingOccurrences(of: ".git", with: "") ?? "repository"
        return String(name)
    }
    
    private func getRemoteURL(for localPath: URL) -> String? {
        let configPath = localPath.appendingPathComponent(".git/config")
        guard let configData = try? Data(contentsOf: configPath),
              let configString = String(data: configData, encoding: .utf8) else {
            return nil
        }
        
        // Parse remote URL from git config
        let lines = configString.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            if line.contains("[remote \"origin\"]") && index + 1 < lines.count {
                let urlLine = lines[index + 1]
                if urlLine.contains("url = ") {
                    return urlLine.replacingOccurrences(of: "\turl = ", with: "")
                }
            }
        }
        return nil
    }
    
    private func getCurrentBranch(for localPath: URL) -> String? {
        let headPath = localPath.appendingPathComponent(".git/HEAD")
        guard let headData = try? Data(contentsOf: headPath),
              let headString = String(data: headData, encoding: .utf8) else {
            return nil
        }
        
        if headString.hasPrefix("ref: refs/heads/") {
            return String(headString.dropFirst("ref: refs/heads/".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    private func parseBranches(from output: String) -> [GitBranch] {
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return lines.map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let isActive = trimmed.hasPrefix("*")
            let name = isActive ? String(trimmed.dropFirst(2)) : trimmed
            return GitBranch(name: name, isActive: isActive)
        }
    }
    
    private func parseFileStatus(from output: String, repository: Repository) -> [GitChange] {
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return lines.compactMap { line in
            guard line.count >= 3 else { return nil }
            
            let statusCode = String(line.prefix(2))
            let fileName = String(line.dropFirst(3))
            let filePath = repository.localPath.appendingPathComponent(fileName)
            
            let fileStatus = GitFileStatus.from(statusCode: statusCode)
            let workspaceFile = WorkspaceFile(
                path: filePath,
                relativePath: fileName,
                type: FileType(from: filePath.pathExtension, fileName: fileName),
                size: 0,
                isDirectory: false
            )
            
            return GitChange(file: workspaceFile, changeType: fileStatus)
        }
    }
    
    private func parseCommitHistory(from output: String) -> [GitCommit] {
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return lines.compactMap { line in
            let components = line.components(separatedBy: "|")
            guard components.count >= 5 else { return nil }
            
            return GitCommit(
                hash: components[0],
                message: components[1],
                author: components[2],
                email: components[3]
            )
        }
    }
    
    private func extractCommitHash(from output: String) -> String {
        // Extract commit hash from git commit output
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("commit") {
                let components = line.components(separatedBy: " ")
                if components.count > 1 {
                    return components[1]
                }
            }
        }
        return UUID().uuidString // Fallback
    }
    
    private func getGitUserName() async throws -> String {
        return try await executeGitCommand(["config", "user.name"])
    }
    
    private func getGitUserEmail() async throws -> String {
        return try await executeGitCommand(["config", "user.email"])
    }
}

// MARK: - Extensions

extension GitFileStatus {
    static func from(statusCode: String) -> GitFileStatus {
        switch statusCode {
        case "??": return .untracked
        case " M", "M ", "MM": return .modified
        case "A ", "AM": return .added
        case " D", "D ": return .deleted
        case "R ": return .renamed
        case "C ": return .copied
        case "UU": return .conflicted
        default: return .modified
        }
    }
}

// MARK: - Error Types

enum GitError: LocalizedError {
    case gitCommandFailed(String)
    case repositoryNotFound
    case repositoryAlreadyExists
    case invalidURL
    case authenticationFailed
    case networkError
    case fileSystemError(String)
    case branchNotFound
    case mergeConflict
    case uncommittedChanges
    
    var errorDescription: String? {
        switch self {
        case .gitCommandFailed(let message):
            return "Git command failed: \(message)"
        case .repositoryNotFound:
            return "Repository not found"
        case .repositoryAlreadyExists:
            return "Repository already exists"
        case .invalidURL:
            return "Invalid repository URL"
        case .authenticationFailed:
            return "Authentication failed"
        case .networkError:
            return "Network error occurred"
        case .fileSystemError(let message):
            return "File system error: \(message)"
        case .branchNotFound:
            return "Branch not found"
        case .mergeConflict:
            return "Merge conflict detected"
        case .uncommittedChanges:
            return "Uncommitted changes exist"
        }
    }
}