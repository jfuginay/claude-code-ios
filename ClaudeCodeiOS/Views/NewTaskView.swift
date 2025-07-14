import SwiftUI

struct NewTaskView: View {
    @EnvironmentObject var taskManager: TaskManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var priority: TaskPriority = .medium
    @State private var category: TaskCategory = .general
    @State private var estimatedTime: TimeInterval = 3600 // 1 hour default
    @State private var showingTimePicker = false
    
    var isValidTask: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Task Details") {
                    TextField("Task title", text: $title)
                    
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Properties") {
                    // Priority Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Priority")
                            .font(.headline)
                        PriorityPicker(priority: $priority)
                    }
                    .padding(.vertical, 4)
                    
                    // Category Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.headline)
                        CategoryPicker(category: $category)
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Time Estimation") {
                    HStack {
                        Text("Estimated Time")
                        Spacer()
                        Button(formatTimeInterval(estimatedTime)) {
                            showingTimePicker = true
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Section {
                    Button("Create Task") {
                        createTask()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(!isValidTask)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingTimePicker) {
                TimeEstimationPicker(estimatedTime: $estimatedTime)
            }
        }
    }
    
    private func createTask() {
        let newTask = Task(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            priority: priority,
            category: category,
            estimatedTime: estimatedTime
        )
        
        taskManager.addTask(newTask)
        dismiss()
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        
        if hours == 0 {
            return "\(minutes)m"
        } else if minutes == 0 {
            return "\(hours)h"
        } else {
            return "\(hours)h \(minutes)m"
        }
    }
}

struct TimeEstimationPicker: View {
    @Binding var estimatedTime: TimeInterval
    @Environment(\.dismiss) private var dismiss
    
    @State private var hours: Int = 1
    @State private var minutes: Int = 0
    
    let hourOptions = Array(0...8)
    let minuteOptions = [0, 15, 30, 45]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("How long do you think this task will take?")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()
                
                HStack(spacing: 20) {
                    VStack {
                        Text("Hours")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Hours", selection: $hours) {
                            ForEach(hourOptions, id: \.self) { hour in
                                Text("\(hour)")
                                    .tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 150)
                    }
                    
                    VStack {
                        Text("Minutes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Minutes", selection: $minutes) {
                            ForEach(minuteOptions, id: \.self) { minute in
                                Text("\(minute)")
                                    .tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 150)
                    }
                }
                
                // Quick preset buttons
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Presets")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        PresetButton(title: "15 min", hours: 0, minutes: 15, selectedHours: $hours, selectedMinutes: $minutes)
                        PresetButton(title: "30 min", hours: 0, minutes: 30, selectedHours: $hours, selectedMinutes: $minutes)
                        PresetButton(title: "1 hour", hours: 1, minutes: 0, selectedHours: $hours, selectedMinutes: $minutes)
                        PresetButton(title: "2 hours", hours: 2, minutes: 0, selectedHours: $hours, selectedMinutes: $minutes)
                        PresetButton(title: "Half day", hours: 4, minutes: 0, selectedHours: $hours, selectedMinutes: $minutes)
                        PresetButton(title: "Full day", hours: 8, minutes: 0, selectedHours: $hours, selectedMinutes: $minutes)
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Time Estimation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Set") {
                        estimatedTime = TimeInterval(hours * 3600 + minutes * 60)
                        dismiss()
                    }
                }
            }
            .onAppear {
                let totalMinutes = Int(estimatedTime) / 60
                hours = totalMinutes / 60
                minutes = totalMinutes % 60
                
                // Round to nearest preset minute value
                let roundedMinutes = minuteOptions.min { abs($0 - minutes) < abs($1 - minutes) } ?? 0
                minutes = roundedMinutes
            }
        }
    }
}

struct PresetButton: View {
    let title: String
    let hours: Int
    let minutes: Int
    @Binding var selectedHours: Int
    @Binding var selectedMinutes: Int
    
    var isSelected: Bool {
        selectedHours == hours && selectedMinutes == minutes
    }
    
    var body: some View {
        Button(action: {
            selectedHours = hours
            selectedMinutes = minutes
        }) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    NewTaskView()
        .environmentObject(TaskManager())
}