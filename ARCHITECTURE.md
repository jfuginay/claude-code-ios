# Claude Code iOS - Real Git Integration Architecture

## Overview

This architecture enables real-time project work with Claude through Git integration, local storage caching, and intelligent tokenization for optimal Claude context management.

## Core Components

### 1. Git Integration Layer

#### Git Operations Manager
- **Repository Cloning**: Clone repositories from GitHub, GitLab, Bitbucket
- **Branch Management**: Create, switch, merge, delete branches
- **Commit Operations**: Stage, commit, push, pull changes
- **Status Tracking**: Real-time file change detection
- **Conflict Resolution**: Handle merge conflicts with Claude assistance

#### Git MCP Server Integration
- **MCP Protocol**: Direct integration with Git MCP server for Claude communication
- **Real-time Hooks**: Git hooks that trigger Claude context updates
- **Change Streaming**: Stream file changes to Claude in real-time
- **Branch Context**: Maintain separate Claude contexts per branch

### 2. File System & Storage Architecture

#### Local Project Storage
```
~/Documents/ClaudeCode/
├── repositories/           # Cloned Git repositories
│   ├── {repo-name}/       # Individual repository folders
│   └── .workspace/        # Workspace metadata
├── cache/                 # Claude context cache
│   ├── tokenized/         # Pre-tokenized file contents
│   ├── embeddings/        # File embeddings for similarity search
│   └── contexts/          # Saved Claude conversation contexts
└── config/               # User settings and API keys
    ├── git-credentials    # Encrypted Git credentials
    └── claude-config      # Claude API configuration
```

#### iOS Document Picker Integration
- **Repository Import**: Import existing local repositories
- **Export Capabilities**: Export projects to other apps
- **iCloud Sync**: Optional iCloud Drive integration for cross-device access

### 3. Tokenization & Context Management

#### Intelligent File Tokenization
- **Selective Tokenization**: Only tokenize files relevant to current task
- **Language-Aware Parsing**: Use Tree-sitter for syntax-aware tokenization
- **Incremental Updates**: Update only changed portions of files
- **Memory Management**: Intelligent cache eviction based on usage patterns

#### Context Optimization
```swift
struct ProjectContext {
    let activeFiles: Set<FileReference>
    let recentChanges: [GitChange]
    let relevantDependencies: [String]
    let conversationHistory: [Message]
    let tokenBudget: Int
}
```

#### Cache Strategy
- **Hot Cache**: Currently editing files (in RAM)
- **Warm Cache**: Recently accessed files (local storage)
- **Cold Cache**: Entire repository metadata (compressed storage)

### 4. Real-time Git Hooks System

#### Pre-commit Hooks
- **Code Analysis**: Run Claude analysis before commits
- **Lint Integration**: Automatic code formatting and linting
- **Test Execution**: Run relevant tests and get Claude feedback

#### Post-commit Hooks
- **Context Update**: Update Claude context with new changes
- **Documentation**: Auto-generate commit message improvements
- **Change Summary**: Create human-readable change summaries

#### Branch Hooks
- **Context Switching**: Switch Claude context when changing branches
- **Merge Assistance**: Claude-assisted conflict resolution
- **Feature Analysis**: Analyze feature branch differences

## Implementation Plan

### Phase 1: Core Git Operations

#### GitManager Service
```swift
class GitManager: ObservableObject {
    @Published var repositories: [Repository] = []
    @Published var currentRepository: Repository?
    @Published var currentBranch: String?
    
    func cloneRepository(url: String, path: String) async throws
    func createBranch(name: String) async throws
    func commitChanges(message: String, files: [String]) async throws
    func pushChanges() async throws
    func pullChanges() async throws
}
```

#### Repository Model
```swift
struct Repository: Identifiable, Codable {
    let id: UUID
    let name: String
    let localPath: URL
    let remoteURL: String
    let currentBranch: String
    let lastUpdated: Date
    let uncommittedChanges: Int
    let branches: [String]
}
```

### Phase 2: File System Integration

#### FileSystemManager
```swift
class FileSystemManager: ObservableObject {
    @Published var workspaceFiles: [WorkspaceFile] = []
    
    func scanRepository(_ repo: Repository) async -> [WorkspaceFile]
    func watchFileChanges(in repo: Repository) -> AsyncStream<FileChange>
    func readFile(at path: URL) async throws -> String
    func writeFile(content: String, to path: URL) async throws
}
```

#### WorkspaceFile Model
```swift
struct WorkspaceFile: Identifiable, Codable {
    let id: UUID
    let path: URL
    let relativePath: String
    let type: FileType
    let size: Int64
    let lastModified: Date
    let gitStatus: GitFileStatus
    let isDirectory: Bool
    let children: [WorkspaceFile]?
}

enum GitFileStatus {
    case untracked, modified, staged, committed, conflicted
}
```

### Phase 3: Claude Integration with MCP

#### ClaudeService with Git MCP
```swift
class ClaudeService: ObservableObject {
    private let mcpServer: GitMCPServer
    
    func sendMessage(_ message: String, context: ProjectContext) async throws -> String
    func streamResponse(_ message: String, context: ProjectContext) -> AsyncStream<String>
    func updateContext(with changes: [GitChange]) async
    func analyzeRepository(_ repo: Repository) async -> RepositoryAnalysis
}
```

#### Git MCP Server Integration
```swift
class GitMCPServer {
    func setupGitHooks(for repository: Repository) async throws
    func streamFileChanges() -> AsyncStream<GitChange>
    func getRelevantFiles(for query: String) async -> [FileReference]
    func updateClaudeContext(with changes: [GitChange]) async
}
```

### Phase 4: Tokenization & Caching

#### TokenizationEngine
```swift
class TokenizationEngine {
    func tokenizeFile(_ file: WorkspaceFile) async -> TokenizedFile
    func updateTokenizedFile(_ file: WorkspaceFile, changes: [TextChange]) async
    func getRelevantTokens(for query: String, in repo: Repository) async -> [Token]
    func estimateTokenCount(for files: [WorkspaceFile]) -> Int
}

struct TokenizedFile {
    let fileId: UUID
    let tokens: [Token]
    let embeddings: [Float]
    let lastUpdated: Date
    let checksum: String
}
```

#### CacheManager
```swift
class CacheManager {
    func cacheTokenizedFile(_ file: TokenizedFile) async
    func getCachedFile(id: UUID) async -> TokenizedFile?
    func evictOldCache(olderThan date: Date) async
    func getCacheSize() -> Int64
    func optimizeCache() async
}
```

## Git Workflow Integration

### 1. Repository Setup
```swift
// Clone repository
let repo = try await gitManager.cloneRepository(
    url: "https://github.com/user/project.git",
    path: localProjectsPath
)

// Setup Git hooks for Claude integration
try await mcpServer.setupGitHooks(for: repo)

// Initial repository analysis
let analysis = try await claudeService.analyzeRepository(repo)
```

### 2. File Change Detection
```swift
// Watch for file changes
for await change in fileSystemManager.watchFileChanges(in: repository) {
    // Update tokenization for changed files
    let tokenizedFile = await tokenizationEngine.updateTokenizedFile(
        change.file, 
        changes: change.textChanges
    )
    
    // Update Claude context
    await claudeService.updateContext(with: [change])
    
    // Cache updated tokenization
    await cacheManager.cacheTokenizedFile(tokenizedFile)
}
```

### 3. Claude Conversation with Context
```swift
// Build project context for Claude
let context = ProjectContext(
    activeFiles: Set(currentlyOpenFiles),
    recentChanges: gitManager.getRecentChanges(limit: 10),
    relevantDependencies: await fileSystemManager.getDependencies(),
    conversationHistory: chatHistory,
    tokenBudget: 100000
)

// Send message to Claude with full context
let response = try await claudeService.sendMessage(
    "Help me refactor this authentication function",
    context: context
)
```

### 4. Real-time Git Operations
```swift
// Commit changes with Claude assistance
let stagedFiles = gitManager.getStagedFiles()
let commitMessage = try await claudeService.generateCommitMessage(
    for: stagedFiles
)

try await gitManager.commitChanges(
    message: commitMessage,
    files: stagedFiles.map(\.path)
)

// Push changes and update context
try await gitManager.pushChanges()
await claudeService.updateContext(with: gitManager.getLastCommit())
```

## Performance Optimizations

### 1. Lazy Loading
- Load file contents only when needed
- Progressive repository scanning
- On-demand tokenization

### 2. Intelligent Caching
- LRU cache for frequently accessed files
- Background cache warming for likely-to-be-accessed files
- Compressed storage for cold cache

### 3. Context Optimization
- Relevance scoring for files in context
- Dynamic token budget allocation
- Conversation context pruning

### 4. Memory Management
- Automatic cache eviction under memory pressure
- Background processing for non-critical operations
- Efficient data structures for large repositories

## Security Considerations

### 1. Git Credentials
- Secure Keychain storage for Git credentials
- OAuth integration for GitHub/GitLab
- SSH key management

### 2. Claude API Security
- Encrypted API key storage
- Request signing and validation
- Rate limiting and abuse prevention

### 3. Local Data Protection
- File-level encryption for sensitive repositories
- Secure cache storage
- Privacy-focused logging

## User Experience Features

### 1. Repository Management
- One-tap repository cloning
- Visual Git status indicators
- Branch switching with context preservation

### 2. Intelligent Assistance
- Context-aware code suggestions
- Real-time error detection and fixes
- Automated code review comments

### 3. Collaboration Features
- Share Claude conversations with team
- Export analysis reports
- Integration with existing Git workflows

This architecture provides a robust foundation for real-time Git integration with Claude, enabling seamless project work while maintaining performance and security.