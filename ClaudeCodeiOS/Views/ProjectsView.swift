import SwiftUI
import UniformTypeIdentifiers

struct ProjectsView: View {
    @EnvironmentObject var gitManager: GitManager
    @EnvironmentObject var fileSystemManager: FileSystemManager
    @EnvironmentObject var claudeService: ClaudeService
    
    @State private var showingDocumentPicker = false
    @State private var showingCreateProject = false
    @State private var showingCloneRepository = false
    @State private var repoURL = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if gitManager.repositories.isEmpty {
                    EmptyProjectsView {
                        showingDocumentPicker = true
                    } createAction: {
                        showingCreateProject = true
                    } cloneAction: {
                        showingCloneRepository = true
                    }
                } else {
                    List(gitManager.repositories) { repository in
                        NavigationLink(destination: ProjectDetailView(repository: repository)) {
                            RepositoryRowView(repository: repository)
                        }
                    }
                    .refreshable {
                        gitManager.loadRepositories()
                    }
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Open Folder", systemImage: "folder.badge.plus") {
                            showingDocumentPicker = true
                        }
                        
                        Button("Create New Project", systemImage: "plus.circle") {
                            showingCreateProject = true
                        }
                        
                        Button("Clone Repository", systemImage: "arrow.down.circle") {
                            showingCloneRepository = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
            }
        }
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleDocumentSelection(result)
        }
        .sheet(isPresented: $showingCreateProject) {
            CreateProjectView { project in
                Task {
                    await createNewProject(project)
                }
            }
        }
        .sheet(isPresented: $showingCloneRepository) {
            CloneRepositoryView { url in
                Task {
                    await cloneRepository(url)
                }
            }
        }
        .onAppear {
            gitManager.loadRepositories()
        }
    }
    
    private func handleDocumentSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await importExistingProject(at: url)
            }
        case .failure(let error):
            print("Error selecting document: \(error)")
        }
    }
    
    private func importExistingProject(at url: URL) async {
        isLoading = true
        defer { isLoading = false }
        
        // Check if it's a Git repository
        let gitPath = url.appendingPathComponent(".git")
        if FileManager.default.fileExists(atPath: gitPath.path) {
            // Import as Git repository
            let repository = Repository(
                name: url.lastPathComponent,
                localPath: url,
                remoteURL: nil
            )
            gitManager.repositories.append(repository)
        } else {
            // Create a new Git repository
            do {
                let _ = try await gitManager.cloneRepository(url: url.path, name: url.lastPathComponent)
            } catch {
                print("Failed to import project: \(error)")
            }
        }
    }
    
    private func createNewProject(_ project: Project) async {
        isLoading = true
        defer { isLoading = false }
        
        // Create directory structure and initialize Git repository
        let projectURL = URL(fileURLWithPath: project.path)
        
        do {
            try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
            
            // Initialize as Git repository
            let repository = Repository(
                name: project.name,
                localPath: projectURL,
                remoteURL: nil
            )
            
            gitManager.repositories.append(repository)
            
            // Create initial files based on project type
            try await createInitialFiles(for: project, at: projectURL)
            
        } catch {
            print("Failed to create project: \(error)")
        }
    }
    
    private func createInitialFiles(for project: Project, at url: URL) async throws {
        switch project.type {
        case .xcode:
            // Create basic iOS project structure
            let contentView = """
            import SwiftUI
            
            struct ContentView: View {
                var body: some View {
                    VStack {
                        Text("Hello, \(project.name)!")
                            .padding()
                    }
                }
            }
            
            #Preview {
                ContentView()
            }
            """
            
            let contentViewURL = url.appendingPathComponent("ContentView.swift")
            try contentView.write(to: contentViewURL, atomically: true, encoding: .utf8)
            
        case .folder:
            let readmeContent = "# \(project.name)\n\nA new project created with Claude Code iOS."
            let readmeURL = url.appendingPathComponent("README.md")
            try readmeContent.write(to: readmeURL, atomically: true, encoding: .utf8)
            
        case .git, .swift, .javascript, .python:
            let readmeContent = "# \(project.name)\n\nA new \(project.type.rawValue) project."
            let readmeURL = url.appendingPathComponent("README.md")
            try readmeContent.write(to: readmeURL, atomically: true, encoding: .utf8)
        }
    }
    
    private func cloneRepository(_ url: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let _ = try await gitManager.cloneRepository(url: url)
        } catch {
            print("Failed to clone repository: \(error)")
        }
    }
}

struct EmptyProjectsView: View {
    let openAction: () -> Void
    let createAction: () -> Void
    let cloneAction: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("No Projects Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Add your first project to get started with Claude Code")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button(action: openAction) {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text("Open Existing Project")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                Button(action: createAction) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Create New Project")
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                Button(action: cloneAction) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("Clone Repository")
                    }
                    .font(.headline)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
    }
}

struct RepositoryRowView: View {
    let repository: Repository
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: repository.gitStatus.icon)
                .font(.title2)
                .foregroundColor(Color(repository.gitStatus.color))
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(repository.displayName)
                    .font(.headline)
                
                Text(repository.localPath.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if repository.isGitRepository {
                        Label(repository.currentBranch, systemImage: "arrow.triangle.branch")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    
                    if repository.uncommittedChanges > 0 {
                        Label("\(repository.uncommittedChanges)", systemImage: "pencil.circle")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(repository.lastUpdated, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(repository.lastUpdated, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct Project: Identifiable, Codable {
    let id: UUID
    let name: String
    let path: String
    let type: ProjectType
    let lastModified: Date
    
    init(name: String, path: String, type: ProjectType) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.type = type
        self.lastModified = Date()
    }
    
    enum ProjectType: String, Codable, CaseIterable {
        case xcode = "xcode"
        case folder = "folder"
        case git = "git"
        case swift = "swift"
        case javascript = "javascript"
        case python = "python"
        
        var iconName: String {
            switch self {
            case .xcode: return "hammer.circle.fill"
            case .folder: return "folder.fill"
            case .git: return "arrow.triangle.branch"
            case .swift: return "swift"
            case .javascript: return "globe"
            case .python: return "snake.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .xcode: return .blue
            case .folder: return .orange
            case .git: return .green
            case .swift: return .red
            case .javascript: return .yellow
            case .python: return .purple
            }
        }
    }
}

struct CreateProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var projectName = ""
    @State private var selectedTemplate: ProjectTemplate = .empty
    @State private var projectPath = ""
    
    let onProjectCreated: (Project) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Project Details") {
                    TextField("Project Name", text: $projectName)
                    
                    TextField("Location", text: $projectPath)
                        .disabled(true)
                        .foregroundColor(.secondary)
                    
                    Button("Choose Location") {
                        // TODO: Implement location picker
                    }
                }
                
                Section("Template") {
                    ForEach(ProjectTemplate.allCases, id: \.self) { template in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.headline)
                                
                                Text(template.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedTemplate == template {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTemplate = template
                        }
                    }
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createProject()
                    }
                    .disabled(projectName.isEmpty)
                }
            }
        }
    }
    
    private func createProject() {
        let project = Project(
            name: projectName,
            path: projectPath.isEmpty ? "/tmp/\(projectName)" : projectPath,
            type: selectedTemplate.projectType
        )
        onProjectCreated(project)
        dismiss()
    }
}

enum ProjectTemplate: String, CaseIterable {
    case empty = "empty"
    case iosApp = "ios"
    case swiftPackage = "swift"
    case webApp = "web"
    
    var name: String {
        switch self {
        case .empty: return "Empty Project"
        case .iosApp: return "iOS App"
        case .swiftPackage: return "Swift Package"
        case .webApp: return "Web Application"
        }
    }
    
    var description: String {
        switch self {
        case .empty: return "Start with an empty folder"
        case .iosApp: return "SwiftUI iOS application"
        case .swiftPackage: return "Swift Package Manager project"
        case .webApp: return "HTML/CSS/JavaScript web app"
        }
    }
    
    var projectType: Project.ProjectType {
        switch self {
        case .empty: return .folder
        case .iosApp: return .xcode
        case .swiftPackage: return .swift
        case .webApp: return .javascript
        }
    }
}

struct CloneRepositoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var repoURL = ""
    @State private var repoName = ""
    @State private var isCloning = false
    
    let onRepositoryCloned: (String) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Repository Details") {
                    TextField("Repository URL", text: $repoURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    TextField("Custom Name (Optional)", text: $repoName)
                        .autocapitalization(.none)
                }
                
                Section("Quick Clone") {
                    Button("Clone claude-brain repository") {
                        repoURL = "https://github.com/jfuginay/claude-brain"
                        repoName = "claude-brain"
                    }
                    .foregroundColor(.blue)
                    
                    Button("Clone claude-code repository") {
                        repoURL = "https://github.com/jfuginay/claude-code"
                        repoName = "claude-code"
                    }
                    .foregroundColor(.blue)
                }
                
                if isCloning {
                    Section {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Cloning repository...")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Clone Repository")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clone") {
                        cloneRepository()
                    }
                    .disabled(repoURL.isEmpty || isCloning)
                }
            }
        }
    }
    
    private func cloneRepository() {
        isCloning = true
        
        onRepositoryCloned(repoURL)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            dismiss()
        }
    }
}

#Preview {
    ProjectsView()
}