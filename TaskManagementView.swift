import SwiftUI

struct TaskManagementView: View {
    @EnvironmentObject var taskManager: TaskManager
    @State private var selectedFilter: TaskFilter = .all
    @State private var showingNewTaskSheet = false
    @State private var searchText = ""
    
    var filteredTasks: [Task] {
        let filtered = switch selectedFilter {
        case .all: taskManager.tasks
        case .pending: taskManager.getTasksByStatus(.pending)
        case .inProgress: taskManager.getTasksByStatus(.inProgress)
        case .completed: taskManager.getTasksByStatus(.completed)
        case .blocked: taskManager.getTasksByStatus(.blocked)
        }
        
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { task in
                task.title.localizedCaseInsensitiveContains(searchText) ||
                task.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Task Statistics
                TaskStatisticsView(statistics: taskManager.taskStatistics)
                    .padding()
                
                // Filters
                TaskFilterView(selectedFilter: $selectedFilter)
                    .padding(.horizontal)
                
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search tasks...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
                
                // Task List
                if filteredTasks.isEmpty {
                    EmptyTasksView(filter: selectedFilter)
                } else {
                    List {
                        ForEach(filteredTasks) { task in
                            TaskRowView(task: task)
                                .environmentObject(taskManager)
                        }
                        .onDelete(perform: deleteTasks)
                    }
                    .listStyle(.plain)
                }
                
                Spacer()
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingNewTaskSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewTaskSheet) {
                NewTaskView()
                    .environmentObject(taskManager)
            }
        }
    }
    
    private func deleteTasks(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                taskManager.deleteTask(filteredTasks[index])
            }
        }
    }
}

struct TaskStatisticsView: View {
    let statistics: TaskStatistics
    
    var body: some View {
        HStack(spacing: 16) {
            StatisticCard(
                title: "Total",
                value: "\(statistics.total)",
                color: .blue
            )
            
            StatisticCard(
                title: "Completed",
                value: "\(statistics.completed)",
                color: .green
            )
            
            StatisticCard(
                title: "Progress",
                value: String(format: "%.0f%%", statistics.completionRate * 100),
                color: .orange
            )
        }
    }
}

struct StatisticCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct TaskFilterView: View {
    @Binding var selectedFilter: TaskFilter
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TaskFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.displayName,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct TaskRowView: View {
    @EnvironmentObject var taskManager: TaskManager
    let task: Task
    @State private var showingDetail = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Button(action: {
                if task.status == .completed {
                    var updatedTask = task
                    updatedTask.status = .pending
                    taskManager.updateTask(updatedTask)
                } else {
                    taskManager.markTaskCompleted(task)
                }
            }) {
                Image(systemName: task.status.icon)
                    .foregroundColor(task.status.color)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .strikethrough(task.status == .completed)
                        .foregroundColor(task.status == .completed ? .secondary : .primary)
                    
                    Spacer()
                    
                    // Priority indicator
                    Image(systemName: task.priority.icon)
                        .foregroundColor(task.priority.color)
                        .font(.caption)
                }
                
                HStack {
                    // Category
                    HStack(spacing: 4) {
                        Image(systemName: task.category.icon)
                        Text(task.category.rawValue)
                    }
                    .font(.caption)
                    .foregroundColor(task.category.color)
                    
                    Spacer()
                    
                    // Creation date
                    Text(task.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if !task.description.isEmpty {
                    Text(task.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            TaskDetailView(task: task)
                .environmentObject(taskManager)
        }
    }
}

struct EmptyTasksView: View {
    let filter: TaskFilter
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(emptyMessage)
                .font(.title3)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(40)
    }
    
    private var emptyMessage: String {
        switch filter {
        case .all: return "No tasks yet\nStart by adding a new task"
        case .pending: return "No pending tasks\nYou're all caught up!"
        case .inProgress: return "No tasks in progress\nSelect a task to start working"
        case .completed: return "No completed tasks yet\nComplete some tasks to see them here"
        case .blocked: return "No blocked tasks\nGreat! Nothing is blocking your progress"
        }
    }
}

enum TaskFilter: CaseIterable {
    case all, pending, inProgress, completed, blocked
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .blocked: return "Blocked"
        }
    }
}

#Preview {
    TaskManagementView()
        .environmentObject(TaskManager())
}