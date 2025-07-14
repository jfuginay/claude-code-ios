# Files to Remove from Xcode Project

## ⚠️ These files have compilation errors and should be removed from Xcode:

**In Xcode Project Navigator, select and delete these files:**
(Choose "Remove References Only" - don't delete from disk)

### CLI Files with Type Errors:
- `CLITypes.swift`
- `CLIComponents.swift` 
- `CLISettingsView.swift`
- `GitHubAuthView.swift`
- `GitHubRepositoryView.swift`
- `MinimalistHomeView.swift`

### Task Management Files (Missing TaskManager):
- `NewTaskView.swift`
- `TaskDetailView.swift`
- `TaskManagementView.swift`

### Other CLI Files:
- `MainCLIView.swift`
- `ClaudeCLIWorkspace.swift`
- `GitHubRepositoryBrowserView.swift`
- `RepositorySelectionView.swift`

## ✅ Keep These Files (They Work):
- `ContentView.swift`
- `ChatView.swift`
- `ProjectsView.swift`
- `APIKeySetupView.swift`
- `CLITerminalView.swift` (this fixes your text visibility issue)

## After Removing Files:
1. Build with ⌘ + B
2. Should compile successfully
3. You'll have a working app with the text visibility fix from CLITerminalView