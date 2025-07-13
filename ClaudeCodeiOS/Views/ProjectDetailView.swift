import SwiftUI

struct ProjectDetailView: View {
    let repository: Repository
    @EnvironmentObject var gitManager: GitManager
    @EnvironmentObject var fileSystemManager: FileSystemManager
    @EnvironmentObject var claudeService: ClaudeService
    
    @State private var selectedTab = 0
    @State private var files: [WorkspaceFile] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Repository Header
            RepositoryHeaderView(repository: repository)
            
            // Tab Picker
            Picker("View", selection: $selectedTab) {
                Text("Files").tag(0)
                Text("Chat").tag(1)
                Text("Git").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Tab Content
            TabView(selection: $selectedTab) {
                // Files Tab
                FileBrowserView(files: files, isLoading: isLoading)
                    .tag(0)
                
                // Chat Tab
                ChatView()
                    .tag(1)
                
                // Git Tab
                GitStatusView(repository: repository)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle(repository.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Menu {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    loadFiles()
                }
                
                Button("Search Files", systemImage: "magnifyingglass") {
                    searchFiles()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .onAppear {
            loadFiles()
        }
    }
    
    private func loadFiles() {
        isLoading = true
        
        Task {
            let repositoryFiles = await fileSystemManager.scanRepository(repository)
            await MainActor.run {
                files = repositoryFiles
                isLoading = false
            }
        }
    }
    
    private func searchFiles() {
        // Simple search implementation - could be enhanced with fuzzy search
        // For now, this refreshes the file list
        loadFiles()
    }
}

struct RepositoryHeaderView: View {
    let repository: Repository
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: repository.gitStatus.icon)
                .font(.title)
                .foregroundColor(Color(repository.gitStatus.color))
                .frame(width: 40, height: 40)
                .background(Color(repository.gitStatus.color).opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(repository.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(repository.localPath.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Branch")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(repository.currentBranch)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

struct FileBrowserView: View {
    let files: [WorkspaceFile]
    let isLoading: Bool
    @State private var expandedFolders: Set<UUID> = []
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading files...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if files.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No files found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(files, id: \.id) { file in
                        FileRowView(
                            file: file,
                            level: 0,
                            expandedFolders: $expandedFolders
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

struct FileRowView: View {
    let file: WorkspaceFile
    let level: Int
    @Binding var expandedFolders: Set<UUID>
    @State private var showingFileViewer = false
    
    private var isExpanded: Bool {
        expandedFolders.contains(file.id)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // Indentation
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: CGFloat(level * 20))
                
                // Expand/Collapse button for folders
                if file.isDirectory {
                    Button(action: {
                        toggleExpansion()
                    }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 16)
                } else {
                    Spacer()
                        .frame(width: 16)
                }
                
                // File icon
                Image(systemName: file.type.icon)
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(width: 20)
                
                // File name
                Text(file.displayName)
                    .font(.body)
                    .lineLimit(1)
                
                Spacer()
                
                // File size (for files only)
                if !file.isDirectory {
                    Text(formatFileSize(Int(file.size)))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture {
                if file.isDirectory {
                    toggleExpansion()
                } else {
                    openFile(file)
                }
            }
            
            // Children (if expanded)
            if file.isDirectory && isExpanded, let children = file.children {
                ForEach(children, id: \.id) { child in
                    FileRowView(
                        file: child,
                        level: level + 1,
                        expandedFolders: $expandedFolders
                    )
                }
            }
        }
        .sheet(isPresented: $showingFileViewer) {
            FileViewerView(file: file)
        }
    }
    
    private func openFile(_ file: WorkspaceFile) {
        showingFileViewer = true
    }
    
    private func toggleExpansion() {
        if isExpanded {
            expandedFolders.remove(file.id)
        } else {
            expandedFolders.insert(file.id)
        }
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct GitStatusView: View {
    let repository: Repository
    @EnvironmentObject var gitManager: GitManager
    @State private var gitChanges: [GitChange] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading Git status...")
            } else {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: repository.gitStatus.icon)
                            .foregroundColor(Color(repository.gitStatus.color))
                        Text("Repository Status: \(repository.gitStatus.rawValue.capitalized)")
                            .font(.headline)
                    }
                    
                    if gitChanges.isEmpty {
                        Text("No changes")
                            .foregroundColor(.secondary)
                    } else {
                        List(gitChanges) { change in
                            HStack {
                                Image(systemName: change.changeType.icon)
                                    .foregroundColor(Color(change.changeType.color))
                                Text(change.file.relativePath)
                                Spacer()
                                Text(change.changeType.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            loadGitStatus()
        }
    }
    
    private func loadGitStatus() {
        Task {
            do {
                let changes = try await gitManager.getFileStatus(for: repository)
                await MainActor.run {
                    gitChanges = changes
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

struct FileViewerView: View {
    let file: WorkspaceFile
    @State private var content = ""
    @State private var isLoading = true
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading file...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if let error = error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        
                        Text("Error loading file")
                            .font(.headline)
                        
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(content)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                    }
                }
            }
            .navigationTitle(file.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Copy Content", systemImage: "doc.on.clipboard") {
                            UIPasteboard.general.string = content
                        }
                        
                        Button("Analyze with Claude", systemImage: "brain.head.profile") {
                            // TODO: Send to Claude for analysis
                        }
                        
                        Button("File Info", systemImage: "info.circle") {
                            // TODO: Show file info
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            loadFileContent()
        }
    }
    
    private func loadFileContent() {
        Task {
            do {
                let data = try Data(contentsOf: file.path)
                let fileContent = String(data: data, encoding: .utf8) ?? "Unable to decode file content"
                
                await MainActor.run {
                    self.content = fileContent
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
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
    
    NavigationStack {
        ProjectDetailView(repository: Repository(name: "MyApp", localPath: URL(fileURLWithPath: "/tmp/MyApp")))
            .environmentObject(gitManager)
            .environmentObject(fileSystemManager)
            .environmentObject(claudeService)
    }
}