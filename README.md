# Claude Code iOS 📱🤖

> An intelligent mobile coding companion that brings the power of Claude to iOS with TaskMaster intelligence and authentic CLI aesthetics.

[![iOS](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)
[![Xcode](https://img.shields.io/badge/Xcode-15.0+-blue.svg)](https://developer.apple.com/xcode/)
[![Claude](https://img.shields.io/badge/Claude-3.5%20Sonnet-green.svg)](https://claude.ai/)

## ✨ Features

### 🎯 **TaskMaster Intelligence**
- **🤖 Automatic Task Extraction**: Claude conversations automatically generate actionable tasks
- **📊 Smart Categorization**: Tasks categorized by type (feature, bug, refactor, test, documentation)
- **🎪 Priority Assignment**: Intelligent priority detection from conversation context
- **⏱️ Time Estimation**: AI-powered estimation of task completion time
- **💾 Persistent Storage**: Tasks saved across app sessions

### 🖥️ **Authentic Claude CLI Experience**
- **🎭 Funny Status Messages**: "Scheming...", "Reading your mind...", "Brewing some code magic..."
- **📈 Real-time Token Tracking**: Live token usage display (e.g., "3.1k tokens")
- **⏰ Processing Timer**: Shows elapsed time during Claude processing
- **🚦 Terminal Aesthetics**: Authentic CLI interface with traffic lights and monospace fonts
- **💬 Status Format**: `* Scheming... (129s • 3.1k tokens • esc to interrupt)`

### 🗣️ **Intelligent Conversations**
- **🧠 Persistent Memory**: Conversations saved and restored across app sessions
- **📚 Context Awareness**: Maintains conversation history for better responses
- **🔄 Streaming Responses**: Real-time response streaming for better UX
- **🎨 Syntax Highlighting**: Code blocks displayed with proper formatting

### 🛠️ **Development Tools**
- **📁 File Management**: Browse and edit project files
- **🌿 Git Integration**: Version control operations and status tracking
- **🔍 Code Analysis**: AI-powered code review and suggestions
- **🚀 Project Templates**: Quick setup for React Native, Node.js, Python projects

## 🚀 Quick Start

### Prerequisites
- iOS 16.0 or later
- Xcode 15.0 or later
- [Anthropic API key](https://console.anthropic.com/)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/claude-code-ios.git
   cd claude-code-ios/ClaudeCodeiOS
   ```

2. **Open in Xcode**
   ```bash
   open ClaudeCodeiOS.xcodeproj
   ```

3. **Build and run**
   - Select your target device or simulator
   - Press `⌘+R` to build and run

4. **Configure API Key**
   - Tap the "Settings" tab
   - Tap "Set Up" next to "API Configuration"
   - Enter your Anthropic API key
   - Tap "Save"

## 📱 Screenshots

### Claude CLI Status Bar
```
* Scheming... (45s • 2.1k tokens • esc to interrupt)
```

### TaskMaster Dashboard
```
┌─ Active Tasks ─────────────────────────────────┐
│ ○ high     Create README.md                    │
│ ◐ medium   Add GitHub OAuth integration        │
│ ● urgent   Fix token counting display          │
└───────────────────────────────── 3 tasks ─────┘
```

### Conversation Flow
```
user@local:~$ Help me implement dark mode
claude@code:~$ I'll help you implement dark mode...

✅ Tasks extracted:
• Create dark mode toggle component
• Add theme state management
• Update CSS variables for dark theme
```

## 🏗️ Architecture

### Core Components

```
ClaudeCodeiOS/
├── 🎯 Services/
│   ├── ClaudeService.swift      # AI conversation management
│   ├── TaskMasterEngine.swift   # Intelligent task extraction
│   ├── GitManager.swift         # Version control operations
│   └── FileSystemManager.swift  # File operations
├── 📱 Views/
│   ├── ClaudeStatusBarView.swift # CLI status bar
│   ├── TaskMasterView.swift     # Task management UI
│   ├── ChatView.swift           # Conversation interface
│   └── ProjectsView.swift       # File browser
└── 🧠 Models/
    ├── TaskItem.swift           # Task data model
    ├── ClaudeMessage.swift      # Conversation message
    └── Repository.swift         # Git repository model
```

### TaskMaster Engine

The TaskMaster engine automatically extracts tasks from Claude conversations:

```swift
// Automatic task detection
let claudeResponse = "We should add user authentication and create a login form..."

// Generates tasks:
// 1. Add user authentication (priority: high, category: feature, ~60min)
// 2. Create login form (priority: medium, category: feature, ~30min)
```

### Claude CLI Status Bar

Real-time status updates with authentic CLI styling:

```swift
ClaudeStatusBarView(
    isProcessing: true,
    processingStatus: "Contemplating the universe of your codebase...",
    tokenUsage: TokenUsage(inputTokens: 1500, outputTokens: 850)
)
```

## 🎨 UI/UX Design

### Terminal Aesthetics
- **🎨 Color Scheme**: Black background with green/orange accent colors
- **🔤 Typography**: SF Mono font for authentic terminal feel
- **🚦 Visual Elements**: Mac-style traffic lights, terminal prompts
- **📊 Status Indicators**: Real-time processing status and token usage

### Claude CLI Commands
```bash
claude@code:~$ analyze App.js              # Analyze code structure
claude@code:~$ debug "TypeError undefined" # Debug specific issues  
claude@code:~$ refactor UserService        # Suggest improvements
claude@code:~$ test loginFunction          # Generate unit tests
claude@code:~$ review recent-changes       # Review git diff
```

## 🔧 Configuration

### API Settings
Configure your Anthropic API key in the Settings tab:

```swift
// Secure API key storage
UserDefaults.standard.set(apiKey, forKey: "claude_api_key")
```

### Task Categories
TaskMaster automatically categorizes tasks:

- **🚀 Feature**: New functionality
- **🐛 Bug**: Error fixes and debugging  
- **♻️ Refactor**: Code improvements
- **🧪 Test**: Unit tests and validation
- **📚 Documentation**: README, comments, guides
- **⚙️ Setup**: Configuration and tooling

### Processing Messages
Funny status messages during AI processing:

```swift
let funnyMessages = [
    "Scheming...",
    "Reading your mind...", 
    "Brewing some code magic...",
    "Contemplating the universe of your codebase...",
    "Channeling the spirits of clean code...",
    "Summoning the TypeScript gods...",
    "Parsing the secrets of your project...",
    "Consulting the documentation oracle..."
]
```

## 📊 TaskMaster Features

### Intelligent Task Extraction
- **🤖 Natural Language Processing**: Extracts actionable items from conversations
- **🎯 Context-Aware Categorization**: Understands task types from conversation
- **⏰ Time Estimation**: AI-powered estimation of completion time
- **📈 Priority Detection**: Identifies urgency from conversation cues

### Task Management
- **📋 Dashboard View**: Terminal-style task list with status indicators
- **🔄 Status Tracking**: pending → in_progress → completed
- **📊 Statistics**: Completion rates, average time, daily progress
- **💾 Persistence**: Tasks saved automatically across sessions

### Integration Points
- **💬 Chat Integration**: Tasks automatically generated from Claude responses
- **🗂️ Project Context**: Tasks linked to specific repositories and files
- **📝 Conversation History**: Tasks reference original conversation context

## 🛠️ Development

### Project Structure
```
ClaudeCodeiOS/
├── 📱 ClaudeCodeiOS.xcodeproj
├── 🎯 ClaudeCodeiOS/
│   ├── Services/          # Core business logic
│   ├── Views/             # SwiftUI interface
│   ├── Models/            # Data models
│   └── Assets.xcassets/   # Images and colors
├── 📖 README.md           # This file
├── 🔒 .gitignore         # Git ignore rules
└── 📋 INTEGRATED_IMPLEMENTATION_PLAN.md
```

### Key Files

#### TaskMasterEngine.swift
The core intelligence engine that extracts and manages tasks:

```swift
@MainActor
class TaskMasterEngine: ObservableObject {
    @Published var activeTasks: [TaskItem] = []
    @Published var currentProject: TaskProject?
    @Published var taskStatistics = TaskStatistics()
    
    func generateTasks(from claudeResponse: String) -> [TaskItem]
    func getNextTask(priority: TaskItem.TaskPriority? = nil) -> TaskItem?
    func completeTask(_ task: TaskItem)
}
```

#### ClaudeStatusBarView.swift
Authentic Claude CLI status bar with real-time updates:

```swift
struct ClaudeStatusBarView: View {
    let isProcessing: Bool
    let processingStatus: String
    let tokenUsage: TokenUsage?
    
    // Real-time timer and funny message rotation
    @State private var timeElapsed: Int = 0
    @State private var funnyMessageIndex: Int = 0
}
```

### Build Instructions

1. **Requirements**
   - macOS 14.0+
   - Xcode 15.0+
   - iOS 16.0+ deployment target

2. **Dependencies**
   - SwiftUI (built-in)
   - Foundation (built-in)
   - No external dependencies required

3. **Build Commands**
   ```bash
   # Build for simulator
   xcodebuild -project ClaudeCodeiOS.xcodeproj -scheme ClaudeCodeiOS -destination 'platform=iOS Simulator,name=iPhone 15' build
   
   # Build for device
   xcodebuild -project ClaudeCodeiOS.xcodeproj -scheme ClaudeCodeiOS -destination 'platform=iOS,name=Your iPhone' build
   
   # Archive for App Store
   xcodebuild -project ClaudeCodeiOS.xcodeproj -scheme ClaudeCodeiOS -destination 'platform=iOS' archive -archivePath ./ClaudeCodeiOS.xcarchive
   ```

## 🔐 Privacy & Security

### Data Protection
- **🔒 Local Storage**: Conversations stored locally in UserDefaults
- **🛡️ API Key Security**: Securely stored, never logged or transmitted to third parties
- **🚫 No Analytics**: No user behavior tracking or analytics collection
- **📱 Offline Capable**: Core features work without network connectivity

### Privacy Disclosure
This app:
- ✅ **Does NOT** collect personal information
- ✅ **Does NOT** use recommendation algorithms
- ✅ **Does NOT** track user behavior
- ✅ **Does** encrypt API communications with Anthropic
- ✅ **Does** store conversation history locally for better UX

### ITSAppUsesNonExemptEncryption
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

## 🚀 TestFlight Deployment

### Prerequisites
- Active Apple Developer account
- App Store Connect app created
- Xcode configured with your developer team

### Deployment Steps

1. **Archive the app**
   ```bash
   # Clean and archive
   xcodebuild clean -project ClaudeCodeiOS.xcodeproj -scheme ClaudeCodeiOS
   xcodebuild archive -project ClaudeCodeiOS.xcodeproj -scheme ClaudeCodeiOS -archivePath ./ClaudeCodeiOS.xcarchive
   ```

2. **Export for App Store**
   ```bash
   xcodebuild -exportArchive -archivePath ./ClaudeCodeiOS.xcarchive -exportPath ./export -exportOptionsPlist ExportOptions.plist
   ```

3. **Upload to TestFlight**
   - Open Xcode Organizer
   - Select the archive
   - Click "Distribute App"
   - Choose "App Store Connect"
   - Upload and wait for processing

## 📚 Usage Examples

### Starting a Conversation
```
user@local:~$ I need to add authentication to my React app

claude@code:~$ I'll help you implement authentication. Here's what we need to do:

1. Set up authentication context
2. Create login/signup forms  
3. Add protected routes
4. Implement token storage

✅ 4 tasks automatically created in TaskMaster
```

### TaskMaster Workflow
```
📋 TaskMaster Dashboard

[1] Set up authentication context     ○ high     45min
[2] Create login/signup forms         ○ medium   30min  
[3] Add protected routes             ○ medium   20min
[4] Implement token storage          ○ low      15min

> next task                           # Start highest priority task
> complete [1]                        # Mark task as completed
> clear completed                     # Remove finished tasks
```

### File Operations
```
claude@code:~$ show me the structure of components/

📁 components/
├── 🔒 AuthForm.jsx
├── 📱 Navigation.jsx
├── 🎨 UserProfile.jsx
└── 🔧 utils/
    ├── auth.js
    └── storage.js

claude@code:~$ analyze AuthForm.jsx
```

## 🤝 Contributing

We welcome contributions! Here's how to get started:

### Development Setup
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes
4. Test thoroughly on device and simulator
5. Commit with descriptive messages: `git commit -m "feat: add amazing feature"`
6. Push to your fork: `git push origin feature/amazing-feature`
7. Open a Pull Request

### Code Style
- Follow Swift style guidelines
- Use descriptive variable names
- Add comments for complex logic
- Maintain SwiftUI best practices
- Test on multiple iOS versions

### Areas for Contribution
- 🌍 **Internationalization**: Multi-language support
- 🎨 **Themes**: Additional color schemes and UI variants
- 🔧 **Integrations**: GitHub, GitLab, Bitbucket connectors
- 📱 **iPad Support**: Optimized tablet interface
- 🧪 **Testing**: Unit tests and UI tests
- 📚 **Documentation**: API docs and tutorials

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **🤖 Claude by Anthropic**: The AI assistant that powers this app
- **🍎 Apple**: For SwiftUI and iOS development tools
- **👨‍💻 Claude Task Master**: Inspiration for intelligent task management
- **🖥️ Claude Code**: CLI aesthetics and user experience patterns

## 📞 Support

Having issues? We're here to help!

- 📧 **Email**: [your-email@domain.com]
- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/yourusername/claude-code-ios/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/yourusername/claude-code-ios/discussions)
- 📖 **Documentation**: [Wiki](https://github.com/yourusername/claude-code-ios/wiki)

## 🗺️ Roadmap

### v1.1.0 - Enhanced Intelligence
- [ ] 🧠 Improved task extraction accuracy
- [ ] 📊 Advanced analytics dashboard
- [ ] 🔄 Task dependencies and workflows
- [ ] 📱 Apple Watch companion app

### v1.2.0 - Collaboration
- [ ] 👥 Team project sharing
- [ ] 💬 Real-time collaboration
- [ ] 📤 Export conversations to Markdown
- [ ] 🔗 Deep linking support

### v1.3.0 - Platform Expansion
- [ ] 💻 macOS companion app
- [ ] ☁️ iCloud sync
- [ ] 🔌 Shortcuts app integration
- [ ] 📱 Widget support

---

**Made with ❤️ and Claude AI**

> Transform your mobile development workflow with intelligent task management and authentic CLI experience.

[![Download on the App Store](https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us?size=250x83)](https://apps.apple.com/app/claude-code-ios/id123456789)