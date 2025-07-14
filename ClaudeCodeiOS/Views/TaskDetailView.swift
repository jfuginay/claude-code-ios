import SwiftUI

struct TaskDetailView: View {
    @EnvironmentObject var taskManager: TaskManager
    @Environment(\.dismiss) private var dismiss
    @State private var editMode = false
    @State private var editedTask: Task
    
    init(task: Task) {
        _editedTask = State(initialValue: task)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Task Header
                    VStack(alignment: .leading, spacing: 8) {
                        if editMode {
                            TextField("Task title", text: $editedTask.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            Text(editedTask.title)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        HStack {
                            StatusPickerView(status: $editedTask.status, isEditing: editMode)
                            Spacer()
                            PriorityIndicator(priority: editedTask.priority)
                            CategoryIndicator(category: editedTask.category)
                        }
                    }
                    
                    Divider()
                    
                    // Task Details
                    VStack(alignment: .leading, spacing: 16) {
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                            
                            if editMode {
                                TextEditor(text: $editedTask.description)
                                    .frame(minHeight: 100)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            } else {
                                Text(editedTask.description.isEmpty ? "No description" : editedTask.description)
                                    .foregroundColor(editedTask.description.isEmpty ? .secondary : .primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        // Priority and Category (editable)
                        if editMode {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Priority")
                                    .font(.headline)
                                PriorityPicker(priority: $editedTask.priority)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Category")
                                    .font(.headline)
                                CategoryPicker(category: $editedTask.category)
                            }
                        }
                        
                        // Timestamps
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Timeline")
                                .font(.headline)
                            
                            HStack {
                                Text("Created:")
                                Spacer()
                                Text(editedTask.createdAt, style: .date)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Updated:")
                                Spacer()
                                Text(editedTask.updatedAt, style: .date)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let completedAt = editedTask.completedAt {
                                HStack {
                                    Text("Completed:")
                                    Spacer()
                                    Text(completedAt, style: .date)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        
                        // Subtasks
                        if !editedTask.subtasks.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Subtasks")
                                    .font(.headline)
                                
                                ForEach(editedTask.subtasks) { subtask in
                                    SubtaskRow(subtask: subtask)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(editMode ? "Save" : "Edit") {
                        if editMode {
                            taskManager.updateTask(editedTask)
                            dismiss()
                        } else {
                            editMode = true
                        }
                    }
                }
            }
        }
    }
}

struct StatusPickerView: View {
    @Binding var status: TaskStatus
    let isEditing: Bool
    
    var body: some View {
        if isEditing {
            Picker("Status", selection: $status) {
                ForEach(TaskStatus.allCases, id: \.self) { status in
                    HStack {
                        Image(systemName: status.icon)
                        Text(status.rawValue.capitalized)
                    }
                    .tag(status)
                }
            }
            .pickerStyle(.menu)
        } else {
            HStack(spacing: 4) {
                Image(systemName: status.icon)
                Text(status.rawValue.capitalized)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.2))
            .foregroundColor(status.color)
            .cornerRadius(6)
        }
    }
}

struct PriorityIndicator: View {
    let priority: TaskPriority
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: priority.icon)
            Text(priority.rawValue.capitalized)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(priority.color.opacity(0.2))
        .foregroundColor(priority.color)
        .cornerRadius(6)
    }
}

struct CategoryIndicator: View {
    let category: TaskCategory
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
            Text(category.rawValue.capitalized)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(category.color.opacity(0.2))
        .foregroundColor(category.color)
        .cornerRadius(6)
    }
}

struct PriorityPicker: View {
    @Binding var priority: TaskPriority
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(TaskPriority.allCases, id: \.self) { priorityOption in
                Button(action: {
                    priority = priorityOption
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: priorityOption.icon)
                        Text(priorityOption.rawValue.capitalized)
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priority == priorityOption ? priorityOption.color : Color(.systemGray5))
                    .foregroundColor(priority == priorityOption ? .white : .primary)
                    .cornerRadius(6)
                }
            }
        }
    }
}

struct CategoryPicker: View {
    @Binding var category: TaskCategory
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
            ForEach(TaskCategory.allCases, id: \.self) { categoryOption in
                Button(action: {
                    category = categoryOption
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: categoryOption.icon)
                        Text(categoryOption.rawValue.capitalized)
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(category == categoryOption ? categoryOption.color : Color(.systemGray5))
                    .foregroundColor(category == categoryOption ? .white : .primary)
                    .cornerRadius(6)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

struct SubtaskRow: View {
    let subtask: Task
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: subtask.status.icon)
                .foregroundColor(subtask.status.color)
                .font(.caption)
            
            Text(subtask.title)
                .font(.caption)
                .strikethrough(subtask.status == .completed)
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    let sampleTask = Task(
        title: "Implement dark mode",
        description: "Add dark mode support to the application with system appearance detection",
        priority: .high,
        category: .feature
    )
    
    TaskDetailView(task: sampleTask)
        .environmentObject(TaskManager())
}