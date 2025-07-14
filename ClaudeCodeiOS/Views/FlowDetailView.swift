import SwiftUI

struct FlowDetailView: View {
    let flow: Flow
    let flowEngine: ClaudeFlowEngine
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var flowProgress: FlowProgress?
    @State private var swarmIntelligence: SwarmIntelligence?
    @State private var refreshTimer: Timer?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Flow header with progress
                FlowProgressHeader(
                    flow: flow,
                    progress: flowProgress
                )
                
                // Tab selector
                Picker("View", selection: $selectedTab) {
                    Text("Tasks").tag(0)
                    Text("Swarm").tag(1)
                    Text("Analytics").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    TasksView(flow: flow)
                        .tag(0)
                    
                    SwarmView(
                        flowEngine: flowEngine,
                        flowId: flow.id,
                        swarmIntelligence: swarmIntelligence
                    )
                    .tag(1)
                    
                    AnalyticsView(
                        flow: flow,
                        progress: flowProgress,
                        swarmIntelligence: swarmIntelligence
                    )
                    .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle(flow.macroGoal)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Execute") {
                        executeFlow()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .onAppear {
            startRefreshTimer()
            refreshData()
        }
        .onDisappear {
            stopRefreshTimer()
        }
    }
    
    private func executeFlow() {
        Task {
            do {
                try await flowEngine.executeFlow(flow)
            } catch {
                // TODO: Handle error
            }
        }
    }
    
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            refreshData()
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func refreshData() {
        Task {
            let progress = await flowEngine.getFlowProgress(flow.id)
            let intelligence = await flowEngine.getSwarmIntelligence(for: flow.id)
            
            await MainActor.run {
                self.flowProgress = progress
                self.swarmIntelligence = intelligence
            }
        }
    }
}

// MARK: - Flow Progress Header

struct FlowProgressHeader: View {
    let flow: Flow
    let progress: FlowProgress?
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress overview
            HStack(spacing: 20) {
                ProgressMetric(
                    title: "Tasks",
                    value: "\(progress?.completedTasks ?? 0)/\(progress?.totalTasks ?? flow.microTasks.count)",
                    color: .blue
                )
                
                ProgressMetric(
                    title: "Agents",
                    value: "\(progress?.activeAgents ?? 0)",
                    color: .green
                )
                
                ProgressMetric(
                    title: "Failed",
                    value: "\(progress?.failedTasks ?? 0)",
                    color: .red
                )
            }
            
            // Progress bar
            if let progress = progress {
                VStack(spacing: 8) {
                    HStack {
                        Text("Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(progress.percentComplete))%")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    ProgressView(value: progress.percentComplete, total: 100)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

struct ProgressMetric: View {
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
    }
}

// MARK: - Tasks View

struct TasksView: View {
    let flow: Flow
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(flow.microTasks) { task in
                    TaskCard(task: task)
                }
            }
            .padding()
        }
    }
}

struct TaskCard: View {
    let task: MicroTask
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(task.type.rawValue.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(typeColor.opacity(0.2))
                        .foregroundColor(typeColor)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                TaskStatusBadge(status: task.status)
            }
            
            // Description
            Text(task.description)
                .font(.body)
                .foregroundColor(.secondary)
            
            // Metadata
            VStack(alignment: .leading, spacing: 8) {
                MetadataRow(icon: "clock", text: task.estimatedDuration)
                MetadataRow(icon: "star", text: "Effort: \(task.effort)/5")
                
                if !task.dependencies.isEmpty {
                    MetadataRow(icon: "link", text: "Depends on: \(task.dependencies.joined(separator: ", "))")
                }
                
                if let agent = task.assignedAgent {
                    MetadataRow(icon: "person", text: "Agent: \(agent)")
                }
            }
            
            // Result (if completed)
            if let result = task.result, !result.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Result:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(result)
                        .font(.caption)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var typeColor: Color {
        switch task.type {
        case .code: return .blue
        case .research: return .purple
        case .analysis: return .orange
        case .test: return .green
        case .deploy: return .red
        case .documentation: return .gray
        case .review: return .yellow
        }
    }
}

struct TaskStatusBadge: View {
    let status: MicroTask.TaskStatus
    
    var body: some View {
        Text(statusText)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(6)
    }
    
    private var statusText: String {
        switch status {
        case .pending: return "Pending"
        case .assigned: return "Assigned"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .blocked: return "Blocked"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .pending: return .gray
        case .assigned: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        case .failed: return .red
        case .blocked: return .yellow
        }
    }
}

struct MetadataRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 12)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Swarm View

struct SwarmView: View {
    let flowEngine: ClaudeFlowEngine
    let flowId: String
    let swarmIntelligence: SwarmIntelligence?
    @State private var activeAgents: [SwarmAgent] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Swarm intelligence summary
                if let intelligence = swarmIntelligence {
                    SwarmIntelligenceCard(intelligence: intelligence)
                }
                
                // Active agents
                if !activeAgents.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Active Agents")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(activeAgents) { agent in
                            AgentCard(agent: agent)
                        }
                    }
                } else {
                    EmptySwarmState()
                }
            }
            .padding()
        }
        .onAppear {
            refreshAgents()
        }
    }
    
    private func refreshAgents() {
        Task {
            let agents = await flowEngine.getAllActiveAgents()
            await MainActor.run {
                self.activeAgents = agents.filter { $0.flowId == flowId }
            }
        }
    }
}

struct SwarmIntelligenceCard: View {
    let intelligence: SwarmIntelligence
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Swarm Intelligence")
                .font(.headline)
            
            HStack(spacing: 20) {
                IntelligenceMetric(
                    icon: "brain.head.profile",
                    title: "Efficiency",
                    value: "\(Int(intelligence.swarmEfficiency * 100))%",
                    color: .purple
                )
                
                IntelligenceMetric(
                    icon: "timer",
                    title: "Avg Duration",
                    value: formatDuration(intelligence.averageTaskDuration),
                    color: .blue
                )
            }
            
            // Recommendations
            if !intelligence.recommendedActions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommendations:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(intelligence.recommendedActions, id: \.self) { recommendation in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            
                            Text(recommendation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        } else {
            return "\(Int(seconds / 3600))h"
        }
    }
}

struct IntelligenceMetric: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct AgentCard: View {
    let agent: SwarmAgent
    
    var body: some View {
        HStack(spacing: 12) {
            // Agent avatar
            Circle()
                .fill(agentColor)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(agent.specialization.rawValue.prefix(1).uppercased())
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Agent \(agent.id.suffix(4))")
                    .font(.headline)
                
                Text(agent.specialization.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let task = agent.currentTask {
                    Text(task.title)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                AgentStatusBadge(status: agent.status)
                
                Text("Efficiency: \(Int(agent.efficiency * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
    
    private var agentColor: Color {
        switch agent.specialization {
        case .code: return .blue
        case .research: return .purple
        case .analysis: return .orange
        case .test: return .green
        case .deploy: return .red
        case .documentation: return .gray
        case .review: return .yellow
        }
    }
}

struct AgentStatusBadge: View {
    let status: AgentStatus
    
    var body: some View {
        Text(statusText)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(4)
    }
    
    private var statusText: String {
        switch status {
        case .idle: return "Idle"
        case .assigned: return "Assigned"
        case .working: return "Working"
        case .completed: return "Done"
        case .failed: return "Failed"
        case .terminated: return "Terminated"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .idle: return .gray
        case .assigned: return .blue
        case .working: return .orange
        case .completed: return .green
        case .failed: return .red
        case .terminated: return .black
        }
    }
}

struct EmptySwarmState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Active Agents")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Execute the flow to see agents working on tasks")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Analytics View

struct AnalyticsView: View {
    let flow: Flow
    let progress: FlowProgress?
    let swarmIntelligence: SwarmIntelligence?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Flow analytics
                FlowAnalyticsCard(flow: flow, progress: progress)
                
                // Performance metrics
                if let intelligence = swarmIntelligence {
                    PerformanceMetricsCard(intelligence: intelligence)
                }
                
                // Task breakdown
                TaskBreakdownCard(tasks: flow.microTasks)
            }
            .padding()
        }
    }
}

struct FlowAnalyticsCard: View {
    let flow: Flow
    let progress: FlowProgress?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Flow Analytics")
                .font(.headline)
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                GridRow {
                    AnalyticItem(title: "Total Tasks", value: "\(flow.microTasks.count)")
                    AnalyticItem(title: "Completed", value: "\(progress?.completedTasks ?? 0)")
                }
                
                GridRow {
                    AnalyticItem(title: "Failed", value: "\(progress?.failedTasks ?? 0)")
                    AnalyticItem(title: "Strategy", value: flow.executionStrategy.rawValue.capitalized)
                }
                
                GridRow {
                    AnalyticItem(title: "Estimated Time", value: flow.totalEstimatedTime)
                    AnalyticItem(title: "Remaining", value: progress?.estimatedTimeRemaining ?? "Unknown")
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
}

struct AnalyticItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }
}

struct PerformanceMetricsCard: View {
    let intelligence: SwarmIntelligence
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Metrics")
                .font(.headline)
            
            HStack(spacing: 20) {
                MetricGauge(
                    title: "Swarm Efficiency",
                    value: intelligence.swarmEfficiency,
                    color: .green
                )
                
                MetricGauge(
                    title: "Success Rate",
                    value: calculateSuccessRate(),
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
    
    private func calculateSuccessRate() -> Double {
        let total = intelligence.completedTasksCount + intelligence.failedTasksCount
        guard total > 0 else { return 0 }
        return Double(intelligence.completedTasksCount) / Double(total)
    }
}

struct MetricGauge: View {
    let title: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 8)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: value)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(value * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct TaskBreakdownCard: View {
    let tasks: [MicroTask]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Task Breakdown")
                .font(.headline)
            
            let taskTypeGroups = Dictionary(grouping: tasks, by: { $0.type })
            
            VStack(spacing: 8) {
                ForEach(MicroTask.TaskType.allCases, id: \.self) { type in
                    if let typeTasks = taskTypeGroups[type] {
                        TaskTypeRow(
                            type: type,
                            count: typeTasks.count,
                            totalCount: tasks.count
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
}

struct TaskTypeRow: View {
    let type: MicroTask.TaskType
    let count: Int
    let totalCount: Int
    
    var body: some View {
        HStack {
            Text(type.rawValue.capitalized)
                .font(.body)
            
            Spacer()
            
            Text("\(count)")
                .font(.body)
                .fontWeight(.medium)
            
            Rectangle()
                .fill(typeColor.opacity(0.3))
                .frame(width: 60 * (Double(count) / Double(totalCount)), height: 8)
                .cornerRadius(4)
        }
    }
    
    private var typeColor: Color {
        switch type {
        case .code: return .blue
        case .research: return .purple
        case .analysis: return .orange
        case .test: return .green
        case .deploy: return .red
        case .documentation: return .gray
        case .review: return .yellow
        }
    }
}

#Preview {
    FlowDetailView(
        flow: Flow(
            id: "test-flow",
            macroGoal: "Build a complete REST API with authentication",
            microTasks: [],
            executionStrategy: .hybrid,
            totalEstimatedTime: "4h 30m"
        ),
        flowEngine: ClaudeFlowEngine(claudeService: ClaudeService(
            tokenizationEngine: TokenizationEngine(cacheManager: CacheManager()),
            cacheManager: CacheManager(),
            gitManager: GitManager(),
            fileSystemManager: FileSystemManager()
        ))
    )
}