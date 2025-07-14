import Foundation
import SwiftUI

@MainActor
class TaskManager: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var currentTask: Task?
    @Published var isProcessingTasks = false
    
    private let storageKey = "claude_tasks"
    private let fileManager = FileManager.default
    private var tasksFileURL: URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("tasks.json")
    }
    
    init() {
        loadTasks()
    }
    
    // MARK: - Task Management
    
    func addTask(_ task: Task) {
        tasks.append(task)
        saveTasks()
    }
    
    func addTasks(_ newTasks: [Task]) {
        tasks.append(contentsOf: newTasks)
        saveTasks()
    }
    
    func updateTask(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            var updatedTask = task
            updatedTask.updatedAt = Date()
            tasks[index] = updatedTask
            saveTasks()
        }
    }
    
    func deleteTask(_ task: Task) {
        tasks.removeAll { $0.id == task.id }
        saveTasks()
    }
    
    func markTaskCompleted(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].status = .completed
            tasks[index].completedAt = Date()
            tasks[index].updatedAt = Date()
            saveTasks()
        }
    }
    
    func setCurrentTask(_ task: Task?) {
        currentTask = task
        if let task = task {
            updateTask(Task(
                id: task.id,
                title: task.title,
                description: task.description,
                priority: task.priority,
                category: task.category,
                status: .inProgress,
                subtasks: task.subtasks,
                messageId: task.messageId,
                estimatedTime: task.estimatedTime
            ))
        }
    }
    
    // MARK: - Task Extraction
    
    func extractTasksFromMessage(_ message: String, messageId: UUID? = nil) -> [Task] {
        let extractedTasks = TaskParser.extractTasks(from: message)
        
        // Link tasks to the message that created them
        return extractedTasks.map { task in
            var linkedTask = task
            linkedTask.messageId = messageId
            return linkedTask
        }
    }
    
    // MARK: - Task Queries
    
    func getTasksByStatus(_ status: TaskStatus) -> [Task] {
        tasks.filter { $0.status == status }
    }
    
    func getTasksByPriority(_ priority: TaskPriority) -> [Task] {
        tasks.filter { $0.priority == priority }
    }
    
    func getTasksByCategory(_ category: TaskCategory) -> [Task] {
        tasks.filter { $0.category == category }
    }
    
    func getPendingTasks() -> [Task] {
        tasks.filter { $0.status == .pending || $0.status == .inProgress }
            .sorted { task1, task2 in
                // Sort by priority first, then by creation date
                if task1.priority != task2.priority {
                    return priorityValue(task1.priority) > priorityValue(task2.priority)
                }
                return task1.createdAt < task2.createdAt
            }
    }
    
    func getNextTask() -> Task? {
        getPendingTasks().first { $0.status == .pending }
    }
    
    func getTasksForMessage(_ messageId: UUID) -> [Task] {
        tasks.filter { $0.messageId == messageId }
    }
    
    private func priorityValue(_ priority: TaskPriority) -> Int {
        switch priority {
        case .critical: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
    
    // MARK: - Task Statistics
    
    var taskStatistics: TaskStatistics {
        TaskStatistics(
            total: tasks.count,
            completed: tasks.filter { $0.status == .completed }.count,
            pending: tasks.filter { $0.status == .pending }.count,
            inProgress: tasks.filter { $0.status == .inProgress }.count,
            blocked: tasks.filter { $0.status == .blocked }.count
        )
    }
    
    // MARK: - Persistence
    
    private func saveTasks() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(tasks)
            try data.write(to: tasksFileURL)
        } catch {
            print("Failed to save tasks: \(error)")
        }
    }
    
    private func loadTasks() {
        guard fileManager.fileExists(atPath: tasksFileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: tasksFileURL)
            let decoder = JSONDecoder()
            tasks = try decoder.decode([Task].self, from: data)
        } catch {
            print("Failed to load tasks: \(error)")
        }
    }
    
    // MARK: - Task Generation from PRD
    
    func generateTasksFromPRD(_ prd: String) async -> [Task] {
        // This would integrate with Claude to generate tasks from a PRD
        // For now, return extracted tasks
        return extractTasksFromMessage(prd)
    }
}

// MARK: - Supporting Types

struct TaskStatistics {
    let total: Int
    let completed: Int
    let pending: Int
    let inProgress: Int
    let blocked: Int
    
    var completionRate: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}