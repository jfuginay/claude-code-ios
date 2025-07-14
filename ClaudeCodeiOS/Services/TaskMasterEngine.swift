import Foundation
import SwiftUI

// MARK: - Core Models

struct TaskItem: Identifiable, Codable {
    let id = UUID()
    let title: String
    let description: String
    let priority: TaskPriority
    let category: TaskCategory
    let estimatedMinutes: Int
    let createdAt: Date
    var status: TaskStatus
    var messageId: UUID?
    
    enum TaskPriority: String, CaseIterable, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case urgent = "urgent"
        
        var color: Color {
            switch self {
            case .low: return .gray
            case .medium: return .blue
            case .high: return .orange
            case .urgent: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .low: return "minus.circle"
            case .medium: return "circle"
            case .high: return "exclamationmark.circle"
            case .urgent: return "exclamationmark.triangle"
            }
        }
    }
    
    enum TaskCategory: String, CaseIterable, Codable {
        case feature = "feature"
        case bug = "bug"
        case refactor = "refactor"
        case test = "test"
        case documentation = "documentation"
        case setup = "setup"
        
        var color: Color {
            switch self {
            case .feature: return .green
            case .bug: return .red
            case .refactor: return .purple
            case .test: return .blue
            case .documentation: return .orange
            case .setup: return .gray
            }
        }
        
        var icon: String {
            switch self {
            case .feature: return "plus.circle"
            case .bug: return "ladybug"
            case .refactor: return "arrow.2.squarepath"
            case .test: return "checkmark.circle"
            case .documentation: return "doc.text"
            case .setup: return "gear"
            }
        }
    }
    
    enum TaskStatus: String, CaseIterable, Codable {
        case pending = "pending"
        case inProgress = "in_progress"
        case completed = "completed"
        case blocked = "blocked"
        
        var color: Color {
            switch self {
            case .pending: return .gray
            case .inProgress: return .blue
            case .completed: return .green
            case .blocked: return .red
            }
        }
    }
}

struct TaskProject: Identifiable, Codable {
    let id = UUID()
    let name: String
    let path: String
    let framework: String
    let createdAt: Date
    var lastUpdated: Date
    var tasks: [TaskItem]
    
    init(name: String, path: String, framework: String = "unknown") {
        self.name = name
        self.path = path
        self.framework = framework
        self.createdAt = Date()
        self.lastUpdated = Date()
        self.tasks = []
    }
}

struct TaskStatistics: Codable {
    var totalTasks: Int = 0
    var completedTasks: Int = 0
    var averageCompletionTime: Double = 0
    var tasksCompletedToday: Int = 0
    
    var completionRate: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }
}

// MARK: - TaskMaster Engine

@MainActor
class TaskMasterEngine: ObservableObject {
    @Published var currentProject: TaskProject?
    @Published var activeTasks: [TaskItem] = []
    @Published var taskStatistics = TaskStatistics()
    @Published var isProcessing = false
    
    private let userDefaults = UserDefaults.standard
    private let tasksKey = "taskmaster_tasks"
    private let projectKey = "taskmaster_current_project"
    private let statsKey = "taskmaster_statistics"
    
    init() {
        loadPersistedData()
    }
    
    // MARK: - Core TaskMaster Methods
    
    func initializeProject(name: String, path: String, framework: String = "unknown") {
        let project = TaskProject(name: name, path: path, framework: framework)
        currentProject = project
        saveProject()
        
        // Generate initial setup tasks
        let setupTasks = generateSetupTasks(for: project)
        addTasks(setupTasks)
    }
    
    func generateTasks(from claudeResponse: String, messageId: UUID? = nil) -> [TaskItem] {
        let extractedTasks = extractTasksFromText(claudeResponse)
        
        return extractedTasks.map { taskText in
            let priority = determinePriority(from: taskText)
            let category = determineCategory(from: taskText)
            let estimatedTime = estimateTime(for: taskText)
            
            return TaskItem(
                title: extractTitle(from: taskText),
                description: taskText,
                priority: priority,
                category: category,
                estimatedMinutes: estimatedTime,
                createdAt: Date(),
                status: .pending,
                messageId: messageId
            )
        }
    }
    
    func getNextTask(priority: TaskItem.TaskPriority? = nil) -> TaskItem? {
        let availableTasks = activeTasks.filter { $0.status == .pending }
        
        if let priority = priority {
            return availableTasks.first { $0.priority == priority }
        }
        
        // Return highest priority task
        return availableTasks.sorted { task1, task2 in
            let priorities: [TaskItem.TaskPriority] = [.urgent, .high, .medium, .low]
            let index1 = priorities.firstIndex(of: task1.priority) ?? priorities.count
            let index2 = priorities.firstIndex(of: task2.priority) ?? priorities.count
            return index1 < index2
        }.first
    }
    
    func startTask(_ task: TaskItem) {
        guard let index = activeTasks.firstIndex(where: { $0.id == task.id }) else { return }
        activeTasks[index].status = .inProgress
        saveTasks()
    }
    
    func completeTask(_ task: TaskItem) {
        guard let index = activeTasks.firstIndex(where: { $0.id == task.id }) else { return }
        activeTasks[index].status = .completed
        
        // Update statistics
        taskStatistics.completedTasks += 1
        if Calendar.current.isDateInToday(Date()) {
            taskStatistics.tasksCompletedToday += 1
        }
        
        saveTasks()
        saveStatistics()
    }
    
    func addTasks(_ tasks: [TaskItem]) {
        activeTasks.append(contentsOf: tasks)
        taskStatistics.totalTasks += tasks.count
        saveTasks()
        saveStatistics()
    }
    
    // MARK: - Task Extraction Logic
    
    private func extractTasksFromText(_ text: String) -> [String] {
        var tasks: [String] = []
        
        // Look for bullet points and numbered lists
        let bulletPatterns = [
            "- ",
            "• ",
            "* ",
            "\\d+\\. "
        ]
        
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            for pattern in bulletPatterns {
                if trimmed.range(of: pattern, options: .regularExpression) != nil {
                    let taskText = trimmed.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
                    if !taskText.isEmpty && taskText.count > 10 {
                        tasks.append(taskText)
                    }
                }
            }
        }
        
        // Look for action words
        let actionWords = ["implement", "create", "add", "build", "fix", "update", "refactor", "test"]
        
        for line in lines {
            let lowercased = line.lowercased()
            if actionWords.contains(where: { lowercased.contains($0) }) && line.count > 20 {
                tasks.append(line.trimmingCharacters(in: .whitespaces))
            }
        }
        
        return Array(Set(tasks)) // Remove duplicates
    }
    
    private func determinePriority(from text: String) -> TaskItem.TaskPriority {
        let lowercased = text.lowercased()
        
        if lowercased.contains("urgent") || lowercased.contains("critical") || lowercased.contains("immediate") {
            return .urgent
        } else if lowercased.contains("important") || lowercased.contains("high") || lowercased.contains("fix") {
            return .high
        } else if lowercased.contains("medium") || lowercased.contains("should") {
            return .medium
        } else {
            return .low
        }
    }
    
    private func determineCategory(from text: String) -> TaskItem.TaskCategory {
        let lowercased = text.lowercased()
        
        if lowercased.contains("bug") || lowercased.contains("fix") || lowercased.contains("error") {
            return .bug
        } else if lowercased.contains("test") || lowercased.contains("spec") {
            return .test
        } else if lowercased.contains("refactor") || lowercased.contains("clean") || lowercased.contains("optimize") {
            return .refactor
        } else if lowercased.contains("document") || lowercased.contains("readme") || lowercased.contains("comment") {
            return .documentation
        } else if lowercased.contains("setup") || lowercased.contains("configure") || lowercased.contains("install") {
            return .setup
        } else {
            return .feature
        }
    }
    
    private func estimateTime(for text: String) -> Int {
        let wordCount = text.components(separatedBy: .whitespaces).count
        
        // Basic estimation based on complexity indicators
        var baseTime = 30 // 30 minutes default
        
        if text.lowercased().contains("simple") || text.lowercased().contains("quick") {
            baseTime = 15
        } else if text.lowercased().contains("complex") || text.lowercased().contains("difficult") {
            baseTime = 120
        }
        
        // Adjust based on word count
        if wordCount > 20 {
            baseTime += 30
        }
        
        return baseTime
    }
    
    private func extractTitle(from text: String) -> String {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
        
        // Take first sentence or up to 60 characters
        if let firstSentence = cleaned.components(separatedBy: ".").first {
            if firstSentence.count <= 60 {
                return firstSentence
            }
        }
        
        return String(cleaned.prefix(60)) + (cleaned.count > 60 ? "..." : "")
    }
    
    private func generateSetupTasks(for project: TaskProject) -> [TaskItem] {
        let setupTasks = [
            TaskItem(
                title: "Initialize project structure",
                description: "Set up basic project organization and folder structure",
                priority: .high,
                category: .setup,
                estimatedMinutes: 30,
                createdAt: Date(),
                status: .pending
            ),
            TaskItem(
                title: "Configure development environment",
                description: "Set up dependencies, build tools, and development settings",
                priority: .medium,
                category: .setup,
                estimatedMinutes: 45,
                createdAt: Date(),
                status: .pending
            )
        ]
        
        return setupTasks
    }
    
    // MARK: - Persistence
    
    private func loadPersistedData() {
        loadTasks()
        loadProject()
        loadStatistics()
    }
    
    private func loadTasks() {
        guard let data = userDefaults.data(forKey: tasksKey),
              let tasks = try? JSONDecoder().decode([TaskItem].self, from: data) else {
            return
        }
        activeTasks = tasks
    }
    
    private func saveTasks() {
        guard let data = try? JSONEncoder().encode(activeTasks) else { return }
        userDefaults.set(data, forKey: tasksKey)
    }
    
    private func loadProject() {
        guard let data = userDefaults.data(forKey: projectKey),
              let project = try? JSONDecoder().decode(TaskProject.self, from: data) else {
            return
        }
        currentProject = project
    }
    
    private func saveProject() {
        guard let project = currentProject,
              let data = try? JSONEncoder().encode(project) else { return }
        userDefaults.set(data, forKey: projectKey)
    }
    
    private func loadStatistics() {
        guard let data = userDefaults.data(forKey: statsKey),
              let stats = try? JSONDecoder().decode(TaskStatistics.self, from: data) else {
            return
        }
        taskStatistics = stats
    }
    
    private func saveStatistics() {
        guard let data = try? JSONEncoder().encode(taskStatistics) else { return }
        userDefaults.set(data, forKey: statsKey)
    }
}