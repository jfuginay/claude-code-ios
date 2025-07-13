import Foundation

// MARK: - Repository Models

struct Repository: Identifiable, Codable {
    let id: UUID
    let name: String
    let localPath: URL
    let remoteURL: String?
    let currentBranch: String
    let lastUpdated: Date
    let uncommittedChanges: Int
    let branches: [String]
    let gitStatus: GitRepositoryStatus
    
    init(name: String, localPath: URL, remoteURL: String? = nil, currentBranch: String = "main") {
        self.id = UUID()
        self.name = name
        self.localPath = localPath
        self.remoteURL = remoteURL
        self.currentBranch = currentBranch
        self.lastUpdated = Date()
        self.uncommittedChanges = 0
        self.branches = [currentBranch]
        self.gitStatus = .clean
    }
    
    var isGitRepository: Bool {
        return remoteURL != nil || FileManager.default.fileExists(atPath: localPath.appendingPathComponent(".git").path)
    }
    
    var displayName: String {
        return name.isEmpty ? localPath.lastPathComponent : name
    }
}

enum GitRepositoryStatus: String, Codable, CaseIterable {
    case clean = "clean"
    case dirty = "dirty"
    case merging = "merging"
    case rebasing = "rebasing"
    case cherrypicking = "cherry-picking"
    case reverting = "reverting"
    case bisecting = "bisecting"
    
    var icon: String {
        switch self {
        case .clean: return "checkmark.circle.fill"
        case .dirty: return "exclamationmark.circle.fill"
        case .merging: return "arrow.triangle.merge"
        case .rebasing: return "arrow.up.and.down.circle"
        case .cherrypicking: return "cherry"
        case .reverting: return "arrow.uturn.backward.circle"
        case .bisecting: return "magnifyingglass.circle"
        }
    }
    
    var color: String {
        switch self {
        case .clean: return "green"
        case .dirty: return "orange"
        default: return "blue"
        }
    }
}

// MARK: - File Models

struct WorkspaceFile: Identifiable, Codable, Hashable {
    let id: UUID
    let path: URL
    let relativePath: String
    let type: FileType
    let size: Int64
    let lastModified: Date
    let gitStatus: GitFileStatus
    let isDirectory: Bool
    let children: [WorkspaceFile]?
    let checksum: String?
    
    init(path: URL, relativePath: String, type: FileType, size: Int64, isDirectory: Bool, children: [WorkspaceFile]? = nil) {
        self.id = UUID()
        self.path = path
        self.relativePath = relativePath
        self.type = type
        self.size = size
        self.lastModified = Date()
        self.gitStatus = .untracked
        self.isDirectory = isDirectory
        self.children = children
        self.checksum = nil
    }
    
    var displayName: String {
        return path.lastPathComponent
    }
    
    var fileExtension: String {
        return path.pathExtension.lowercased()
    }
    
    var isCodeFile: Bool {
        let codeExtensions = ["swift", "js", "ts", "py", "java", "cpp", "c", "h", "m", "mm", "rb", "go", "rs", "php", "html", "css", "scss", "jsx", "tsx", "vue", "svelte"]
        return codeExtensions.contains(fileExtension)
    }
    
    // Custom Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(path)
        hasher.combine(relativePath)
    }
    
    static func == (lhs: WorkspaceFile, rhs: WorkspaceFile) -> Bool {
        return lhs.id == rhs.id
    }
}

enum FileType: String, Codable {
    case folder = "folder"
    case file = "file"
    case swift = "swift"
    case javascript = "javascript"
    case typescript = "typescript"
    case python = "python"
    case markdown = "markdown"
    case json = "json"
    case yaml = "yaml"
    case xml = "xml"
    case image = "image"
    case text = "text"
    case binary = "binary"
    case gitignore = "gitignore"
    case readme = "readme"
    case license = "license"
    case config = "config"
    
    init(from fileExtension: String, fileName: String = "") {
        let ext = fileExtension.lowercased()
        let name = fileName.lowercased()
        
        if name.contains("readme") {
            self = .readme
        } else if name.contains("license") {
            self = .license
        } else if name.starts(with: ".") || name.contains("config") {
            self = .config
        } else {
            switch ext {
            case "swift": self = .swift
            case "js", "jsx": self = .javascript
            case "ts", "tsx": self = .typescript
            case "py", "pyw": self = .python
            case "md", "markdown": self = .markdown
            case "json": self = .json
            case "yml", "yaml": self = .yaml
            case "xml", "plist": self = .xml
            case "png", "jpg", "jpeg", "gif", "webp", "svg": self = .image
            case "txt", "log": self = .text
            case "gitignore": self = .gitignore
            case "": self = .folder
            default: self = .file
            }
        }
    }
    
    var icon: String {
        switch self {
        case .folder: return "folder.fill"
        case .file: return "doc.text"
        case .swift: return "swift"
        case .javascript: return "logo.javascript"
        case .typescript: return "doc.badge.gearshape"
        case .python: return "snake.circle"
        case .markdown: return "doc.richtext"
        case .json: return "doc.badge.gearshape"
        case .yaml: return "doc.text.below.ecg"
        case .xml: return "doc.badge.gearshape"
        case .image: return "photo"
        case .text: return "doc.plaintext"
        case .binary: return "doc.zipper"
        case .gitignore: return "eye.slash"
        case .readme: return "book"
        case .license: return "doc.text.magnifyingglass"
        case .config: return "gear"
        }
    }
    
    var isEditable: Bool {
        switch self {
        case .folder, .image, .binary:
            return false
        default:
            return true
        }
    }
}

enum GitFileStatus: String, Codable, CaseIterable {
    case untracked = "untracked"
    case modified = "modified"
    case added = "added"
    case deleted = "deleted"
    case renamed = "renamed"
    case copied = "copied"
    case updated = "updated"
    case staged = "staged"
    case committed = "committed"
    case conflicted = "conflicted"
    case ignored = "ignored"
    
    var icon: String {
        switch self {
        case .untracked: return "questionmark.circle"
        case .modified: return "pencil.circle"
        case .added: return "plus.circle"
        case .deleted: return "minus.circle"
        case .renamed: return "arrow.right.circle"
        case .copied: return "doc.on.doc"
        case .updated: return "arrow.up.circle"
        case .staged: return "checkmark.circle"
        case .committed: return "checkmark.circle.fill"
        case .conflicted: return "exclamationmark.triangle"
        case .ignored: return "eye.slash"
        }
    }
    
    var color: String {
        switch self {
        case .untracked: return "gray"
        case .modified: return "orange"
        case .added: return "green"
        case .deleted: return "red"
        case .renamed, .copied: return "blue"
        case .updated, .staged: return "blue"
        case .committed: return "green"
        case .conflicted: return "red"
        case .ignored: return "gray"
        }
    }
}

// MARK: - Git Change Models

struct GitChange: Identifiable, Codable {
    let id: UUID
    let file: WorkspaceFile
    let changeType: GitFileStatus
    let diff: String?
    let timestamp: Date
    let commit: String?
    
    init(file: WorkspaceFile, changeType: GitFileStatus, diff: String? = nil, commit: String? = nil) {
        self.id = UUID()
        self.file = file
        self.changeType = changeType
        self.diff = diff
        self.timestamp = Date()
        self.commit = commit
    }
}

struct GitCommit: Identifiable, Codable {
    let id: UUID
    let hash: String
    let message: String
    let author: String
    let email: String
    let timestamp: Date
    let changes: [GitChange]
    
    init(hash: String, message: String, author: String, email: String, changes: [GitChange] = []) {
        self.id = UUID()
        self.hash = hash
        self.message = message
        self.author = author
        self.email = email
        self.timestamp = Date()
        self.changes = changes
    }
    
    var shortHash: String {
        return String(hash.prefix(8))
    }
}

struct GitBranch: Identifiable, Codable {
    let id: UUID
    let name: String
    let isActive: Bool
    let lastCommit: GitCommit?
    let aheadBy: Int
    let behindBy: Int
    
    init(name: String, isActive: Bool = false, lastCommit: GitCommit? = nil, aheadBy: Int = 0, behindBy: Int = 0) {
        self.id = UUID()
        self.name = name
        self.isActive = isActive
        self.lastCommit = lastCommit
        self.aheadBy = aheadBy
        self.behindBy = behindBy
    }
}