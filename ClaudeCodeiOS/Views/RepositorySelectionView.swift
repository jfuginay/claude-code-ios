import SwiftUI

struct RepositorySelectionView: View {
    @EnvironmentObject var gitManager: GitManager
    let onRepositorySelected: (Repository) -> Void
    let onCloneRepository: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if gitManager.repositories.isEmpty {
                EmptyRepositoryState(onCloneRepository: onCloneRepository)
            } else {
                RepositoryList(
                    repositories: gitManager.repositories,
                    onRepositorySelected: onRepositorySelected,
                    onCloneRepository: onCloneRepository
                )
            }
        }
        .padding(.vertical, 8)
    }
}

struct EmptyRepositoryState: View {
    let onCloneRepository: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No repositories found.")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.yellow)
            
            Text("Get started:")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
            
            Button(action: onCloneRepository) {
                HStack {
                    Text("🔗")
                    Text("Browse GitHub repositories")
                }
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            
            Text("Or type: clone <repository-url>")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
        }
    }
}

struct RepositoryList: View {
    let repositories: [Repository]
    let onRepositorySelected: (Repository) -> Void
    let onCloneRepository: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Available repositories:")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.green)
            
            ForEach(Array(repositories.enumerated()), id: \\.element.id) { index, repository in
                RepositoryRow(
                    index: index + 1,
                    repository: repository,
                    onSelected: { onRepositorySelected(repository) }
                )
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            Button(action: onCloneRepository) {
                HStack {
                    Text("[+]")
                        .foregroundColor(.green)
                    Text("Clone new repository")
                        .foregroundColor(.blue)
                }
                .font(.system(.body, design: .monospaced))
            }
            .buttonStyle(.plain)
            
            Text("\\nSelect repository [1-\\(repositories.count)] or type command:")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
        }
    }
}

struct RepositoryRow: View {
    let index: Int
    let repository: Repository
    let onSelected: () -> Void
    @State private var lastUsed: String = ""
    
    var body: some View {
        Button(action: onSelected) {
            HStack {
                // Index number
                Text("[\\(index)]")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.cyan)
                    .frame(width: 40, alignment: .leading)
                
                // Repository name
                Text(repository.name)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .fontWeight(.medium)
                
                Spacer()
                
                // Status indicators
                HStack(spacing: 8) {
                    // Git status
                    HStack(spacing: 2) {
                        Image(systemName: statusIcon)
                            .font(.caption)
                            .foregroundColor(statusColor)
                        Text(statusText)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(statusColor)
                    }
                    
                    // Last used
                    Text(lastUsed)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            // Add hover effect for macOS
        }
        .onAppear {
            updateLastUsed()
        }
    }
    
    private var statusIcon: String {
        switch repository.gitStatus {
        case .clean:
            return "checkmark.circle.fill"
        case .dirty:
            return "exclamationmark.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch repository.gitStatus {
        case .clean:
            return .green
        case .dirty:
            return .orange
        default:
            return .yellow
        }
    }
    
    private var statusText: String {
        switch repository.gitStatus {
        case .clean:
            return "clean"
        case .dirty:
            return "\\(repository.uncommittedChanges) changes"
        default:
            return "unknown"
        }
    }
    
    private func updateLastUsed() {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        lastUsed = formatter.localizedString(for: repository.lastUpdated, relativeTo: Date())
    }
}


#Preview {
    RepositorySelectionView(
        onRepositorySelected: { _ in },
        onCloneRepository: { }
    )
    .environmentObject(GitManager())
    .background(Color.black)
}