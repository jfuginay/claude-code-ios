import Foundation
import SwiftUI

struct Task: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var description: String
    var priority: TaskPriority
    var category: TaskCategory
    var status: TaskStatus
    var subtasks: [Task]
    var messageId: UUID? // Link to the chat message that created this task
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var estimatedTime: TimeInterval?
    var actualTime: TimeInterval?
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        priority: TaskPriority = .medium,
        category: TaskCategory = .general,
        status: TaskStatus = .pending,
        subtasks: [Task] = [],
        messageId: UUID? = nil,
        estimatedTime: TimeInterval? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.priority = priority
        self.category = category
        self.status = status
        self.subtasks = subtasks
        self.messageId = messageId
        self.createdAt = Date()
        self.updatedAt = Date()
        self.completedAt = nil
        self.estimatedTime = estimatedTime
        self.actualTime = nil
    }
}

enum TaskPriority: String, CaseIterable, Codable {
    case critical = "critical"
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var color: Color {
        switch self {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .green
        }
    }
    
    var icon: String {
        switch self {
        case .critical: return "exclamationmark.3"
        case .high: return "exclamationmark.2"
        case .medium: return "exclamationmark"
        case .low: return "checkmark"
        }
    }
}

enum TaskCategory: String, CaseIterable, Codable {
    case feature = "feature"
    case bugFix = "bug-fix"
    case refactor = "refactor"
    case documentation = "documentation"
    case testing = "testing"
    case deployment = "deployment"
    case research = "research"
    case general = "general"
    
    var icon: String {
        switch self {
        case .feature: return "star.fill"
        case .bugFix: return "ladybug.fill"
        case .refactor: return "arrow.triangle.2.circlepath"
        case .documentation: return "doc.text.fill"
        case .testing: return "checkmark.shield.fill"
        case .deployment: return "icloud.and.arrow.up.fill"
        case .research: return "magnifyingglass"
        case .general: return "list.bullet"
        }
    }
    
    var color: Color {
        switch self {
        case .feature: return .blue
        case .bugFix: return .red
        case .refactor: return .purple
        case .documentation: return .gray
        case .testing: return .green
        case .deployment: return .orange
        case .research: return .cyan
        case .general: return .secondary
        }
    }
}

enum TaskStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case inProgress = "in-progress"
    case blocked = "blocked"
    case review = "review"
    case completed = "completed"
    case cancelled = "cancelled"
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .inProgress: return "arrow.right.circle"
        case .blocked: return "exclamationmark.octagon"
        case .review: return "eye"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .gray
        case .inProgress: return .blue
        case .blocked: return .red
        case .review: return .orange
        case .completed: return .green
        case .cancelled: return .secondary
        }
    }
}

// MARK: - Task Parser
struct TaskParser {
    static func extractTasks(from text: String) -> [Task] {
        var tasks: [Task] = []
        let lines = text.components(separatedBy: .newlines)
        
        // Pattern for numbered tasks (1. Task, 2. Task, etc.)
        let numberedPattern = #"^\s*(\d+)\.\s+(.+)$"#
        let numberedRegex = try? NSRegularExpression(pattern: numberedPattern)
        
        // Pattern for bullet points
        let bulletPattern = #"^\s*[-*•]\s+(.+)$"#
        let bulletRegex = try? NSRegularExpression(pattern: bulletPattern)
        
        // Pattern for checkboxes
        let checkboxPattern = #"^\s*\[[ x]\]\s+(.+)$"#
        let checkboxRegex = try? NSRegularExpression(pattern: checkboxPattern)
        
        for line in lines {
            let range = NSRange(location: 0, length: line.utf16.count)
            
            // Check numbered tasks
            if let match = numberedRegex?.firstMatch(in: line, range: range) {
                if let titleRange = Range(match.range(at: 2), in: line) {
                    let title = String(line[titleRange])
                    let task = createTask(from: title)
                    tasks.append(task)
                }
            }
            // Check bullet points
            else if let match = bulletRegex?.firstMatch(in: line, range: range) {
                if let titleRange = Range(match.range(at: 1), in: line) {
                    let title = String(line[titleRange])
                    let task = createTask(from: title)
                    tasks.append(task)
                }
            }
            // Check checkboxes
            else if let match = checkboxRegex?.firstMatch(in: line, range: range) {
                if let titleRange = Range(match.range(at: 1), in: line) {
                    let title = String(line[titleRange])
                    let task = createTask(from: title)
                    tasks.append(task)
                }
            }
        }
        
        return tasks
    }
    
    private static func createTask(from title: String) -> Task {
        let priority = detectPriority(in: title)
        let category = detectCategory(in: title)
        
        return Task(
            title: title,
            priority: priority,
            category: category
        )
    }
    
    private static func detectPriority(in text: String) -> TaskPriority {
        let lowercased = text.lowercased()
        if lowercased.contains("critical") || lowercased.contains("urgent") || lowercased.contains("asap") {
            return .critical
        } else if lowercased.contains("high priority") || lowercased.contains("important") {
            return .high
        } else if lowercased.contains("low priority") || lowercased.contains("minor") {
            return .low
        }
        return .medium
    }
    
    private static func detectCategory(in text: String) -> TaskCategory {
        let lowercased = text.lowercased()
        if lowercased.contains("feature") || lowercased.contains("implement") || lowercased.contains("add") {
            return .feature
        } else if lowercased.contains("bug") || lowercased.contains("fix") || lowercased.contains("error") {
            return .bugFix
        } else if lowercased.contains("refactor") || lowercased.contains("optimize") || lowercased.contains("improve") {
            return .refactor
        } else if lowercased.contains("document") || lowercased.contains("readme") || lowercased.contains("comment") {
            return .documentation
        } else if lowercased.contains("test") || lowercased.contains("spec") || lowercased.contains("unit") {
            return .testing
        } else if lowercased.contains("deploy") || lowercased.contains("release") || lowercased.contains("build") {
            return .deployment
        } else if lowercased.contains("research") || lowercased.contains("investigate") || lowercased.contains("analyze") {
            return .research
        }
        return .general
    }
}