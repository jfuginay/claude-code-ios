# Quick Build Fix Instructions

## The Problem
The new CLI files were added to Xcode but have compilation errors due to:
- Missing type definitions (GitHubService, ProjectSessionManager, etc.)
- Incorrect imports and references
- String interpolation syntax issues

## Quick Fix (2 minutes)

### Step 1: Remove Problematic Files from Xcode
In Xcode, **select and delete these files** (choose "Remove References Only"):

**Files to Remove:**
- `MainCLIView.swift`
- `ClaudeCLIWorkspace.swift`
- `GitHubRepositoryBrowserView.swift`
- `RepositorySelectionView.swift`
- `GitHubRepositoryView.swift`
- `MinimalistHomeView.swift`
- `CLIComponents.swift`
- Any files with `Task` in the name that reference `TaskManager`

### Step 2: Keep Working Files
**Keep these files** (they should work):
- `CLITerminalView.swift` ✅
- `ContentView.swift` ✅
- `ChatView.swift` ✅
- `ProjectsView.swift` ✅
- `APIKeySetupView.swift` ✅

### Step 3: Add the Types File
1. **Drag `CLITypes.swift`** from `/Models/` into Xcode
2. Check "Add to target: ClaudeCodeiOS"

### Step 4: Build
- Press `⌘ + B` in Xcode
- Should build successfully now ✅

## Result
You'll have:
- ✅ Working app that compiles
- ✅ Original functionality intact
- ✅ CLITerminalView ready to use (the one that fixes your text visibility issue)
- 📂 All the CLI code files saved for later

## Next Steps (Optional)
When ready to add the full CLI experience:
1. Fix type imports in the CLI files
2. Add them back to Xcode one by one
3. Test each addition

This gets you building and running immediately!