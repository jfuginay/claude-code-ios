import SwiftUI

struct TaskMasterView: View {
    @StateObject private var taskMaster = TaskMasterEngine()
    @EnvironmentObject var claudeService: ClaudeService
    @State private var showingTaskDetail = false
    @State private var selectedTask: TaskItem?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Terminal Header
                TerminalHeaderView()
                
                // Task Statistics
                TaskStatsView(stats: taskMaster.taskStatistics)
                
                // Active Tasks List
                TaskListView(
                    tasks: taskMaster.activeTasks,
                    onTaskTap: { task in
                        selectedTask = task
                        showingTaskDetail = true
                    },
                    onTaskComplete: { task in
                        taskMaster.completeTask(task)
                    }
                )
                
                Spacer()
                
                // Quick Actions
                TaskQuickActionsView(taskMaster: taskMaster)
            }
            .background(Color.black)
            .foregroundColor(.green)
            .navigationTitle("TaskMaster")
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingTaskDetail) {
            if let task = selectedTask {
                TaskDetailSheet(task: task, taskMaster: taskMaster)
            }
        }
        .onReceive(claudeService.$lastResponse) { response in
            if let response = response, !response.isEmpty {
                let newTasks = taskMaster.generateTasks(from: response)
                if !newTasks.isEmpty {
                    taskMaster.addTasks(newTasks)
                }
            }
        }
    }
}

struct TerminalHeaderView: View {
    var body: some View {
        HStack {
            // Terminal traffic lights
            HStack(spacing: 6) {
                Circle().fill(.red).frame(width: 12, height: 12)
                Circle().fill(.yellow).frame(width: 12, height: 12)
                Circle().fill(.green).frame(width: 12, height: 12)
            }
            
            Spacer()
            
            Text("claude-task-master")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
    }
}

struct TaskStatsView: View {
    let stats: TaskStatistics
    
    var body: some View {
        HStack(spacing: 20) {
            StatItem(
                icon: "checkmark.circle",
                value: "\(stats.completedTasks)",
                label: "completed"
            )
            
            StatItem(
                icon: "clock",
                value: "\(stats.tasksCompletedToday)",
                label: "today"
            )
            
            StatItem(
                icon: "percent",
                value: String(format: "%.0f", stats.completionRate * 100),
                label: "rate"
            )
        }
        .padding()
        .background(Color(red: 0.05, green: 0.05, blue: 0.05))
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.system(.title3, design: .monospaced, weight: .bold))
                .foregroundColor(.green)
            
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
        }
    }
}

struct TaskListView: View {
    let tasks: [TaskItem]
    let onTaskTap: (TaskItem) -> Void
    let onTaskComplete: (TaskItem) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(tasks.filter { $0.status != .completed }) { task in
                    TaskRowView(
                        task: task,
                        onTap: { onTaskTap(task) },
                        onComplete: { onTaskComplete(task) }
                    )
                }
            }
        }
    }
}

struct TaskRowView: View {
    let task: TaskItem
    let onTap: () -> Void
    let onComplete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Text(statusSymbol)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(task.status.color)
                .frame(width: 20)
            
            // Priority
            Image(systemName: task.priority.icon)
                .foregroundColor(task.priority.color)
                .frame(width: 16)
            
            // Task content
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.green)
                    .lineLimit(2)
                
                HStack {
                    Text(task.category.rawValue)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(task.category.color)
                    
                    Spacer()
                    
                    Text("\(task.estimatedMinutes)m")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Quick complete button
            if task.status == .pending || task.status == .inProgress {
                Button(action: onComplete) {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(red: 0.02, green: 0.02, blue: 0.02))
        .onTapGesture(perform: onTap)
    }
    
    private var statusSymbol: String {
        switch task.status {
        case .pending: return "○"
        case .inProgress: return "◐"
        case .completed: return "●"
        case .blocked: return "⚠"
        }
    }
}

struct TaskQuickActionsView: View {
    let taskMaster: TaskMasterEngine
    
    var body: some View {
        HStack(spacing: 16) {
            Button("next task") {
                if let nextTask = taskMaster.getNextTask() {
                    taskMaster.startTask(nextTask)
                }
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(.blue)
            
            Spacer()
            
            Button("clear completed") {
                // Filter out completed tasks
                taskMaster.activeTasks = taskMaster.activeTasks.filter { $0.status != .completed }
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(.gray)
        }
        .padding()
        .background(Color(red: 0.05, green: 0.05, blue: 0.05))
    }
}

struct TaskDetailSheet: View {
    let task: TaskItem
    let taskMaster: TaskMasterEngine
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                // Task header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: task.priority.icon)
                            .foregroundColor(task.priority.color)
                        
                        Text(task.priority.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(task.priority.color)
                        
                        Spacer()
                        
                        Text(task.category.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(task.category.color)
                    }
                    
                    Text(task.title)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                // Task description
                Text(task.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                // Task details
                VStack(alignment: .leading, spacing: 8) {
                    DetailRow(label: "Status", value: task.status.rawValue.capitalized)
                    DetailRow(label: "Estimated time", value: "\(task.estimatedMinutes) minutes")
                    DetailRow(label: "Created", value: task.createdAt.formatted(date: .abbreviated, time: .shortened))
                }
                
                Spacer()
                
                // Actions
                HStack(spacing: 16) {
                    if task.status == .pending {
                        Button("Start Task") {
                            taskMaster.startTask(task)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    if task.status == .pending || task.status == .inProgress {
                        Button("Complete") {
                            taskMaster.completeTask(task)
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.caption)
        }
    }
}

#Preview {
    TaskMasterView()
        .environmentObject(ClaudeService(
            tokenizationEngine: TokenizationEngine(cacheManager: CacheManager()),
            cacheManager: CacheManager(),
            gitManager: GitManager(),
            fileSystemManager: FileSystemManager()
        ))
}