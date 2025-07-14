import SwiftUI

struct ClaudeFlowSwarmView: View {
    @EnvironmentObject var claudeService: ClaudeService
    @StateObject private var flowEngine: ClaudeFlowEngine
    @State private var macroTaskInput = ""
    @State private var showingFlowCreation = false
    @State private var isCreatingFlow = false
    @State private var selectedFlow: Flow?
    @State private var showingEnhancedOptions = false
    @State private var enhancedModeEnabled = false
    @FocusState private var isInputFocused: Bool
    
    init(claudeService: ClaudeService) {
        self._flowEngine = StateObject(wrappedValue: ClaudeFlowEngine(claudeService: claudeService))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with flow status
                FlowStatusHeader(
                    status: flowEngine.flowStatus,
                    macroGoal: flowEngine.currentMacroGoal,
                    enhancedMode: enhancedModeEnabled
                )
                
                if flowEngine.activeFlows.isEmpty {
                    // Empty state - Flow creation
                    EmptyFlowState(
                        macroTaskInput: $macroTaskInput,
                        isInputFocused: $isInputFocused,
                        isCreatingFlow: isCreatingFlow,
                        onCreateFlow: createFlow
                    )
                } else {
                    // Active flows list
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(flowEngine.activeFlows) { flow in
                                FlowCard(
                                    flow: flow,
                                    onTap: { selectedFlow = flow },
                                    onExecute: { executeFlow(flow) }
                                )
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
                
                // Quick actions
                if !flowEngine.activeFlows.isEmpty {
                    QuickActionsBar(
                        onNewFlow: { showingFlowCreation = true },
                        onViewSwarm: { selectedFlow = flowEngine.activeFlows.first }
                    )
                }
            }
            .navigationTitle("Claude Flow & Swarm")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingFlowCreation = true }) {
                            Label("New Flow", systemImage: "plus.circle")
                        }
                        .disabled(isCreatingFlow)
                        
                        Divider()
                        
                        Toggle(isOn: $enhancedModeEnabled) {
                            Label("Enhanced Mode", systemImage: "bolt.fill")
                        }
                        
                        Button(action: { showingEnhancedOptions = true }) {
                            Label("Swarm Settings", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingFlowCreation) {
            FlowCreationSheet(
                macroTaskInput: $macroTaskInput,
                isCreatingFlow: $isCreatingFlow,
                onCreateFlow: createFlow
            )
        }
        .sheet(item: $selectedFlow) { flow in
            FlowDetailView(flow: flow, flowEngine: flowEngine)
        }
    }
    
    private func createFlow() {
        guard !macroTaskInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isCreatingFlow = true
        let originalTask = macroTaskInput
        
        // Set enhanced mode on flow engine
        flowEngine.useEnhancedMode = enhancedModeEnabled
        
        Task {
            do {
                let flow = try await flowEngine.decomposeTask(macroTaskInput)
                
                // Send the decomposed flow to Claude for actual execution
                let flowSummary = buildFlowSummary(flow)
                let executePrompt = """
                I've decomposed the task "\(originalTask)" into the following micro-tasks. Please execute these tasks step by step:

                \(flowSummary)

                Please proceed to execute each task and provide the actual results, not just the plan.
                """
                
                // Send to Claude chat for execution
                _ = try await claudeService.sendMessage(executePrompt)
                
                await MainActor.run {
                    macroTaskInput = ""
                    isCreatingFlow = false
                    showingFlowCreation = false
                    selectedFlow = flow
                }
            } catch {
                await MainActor.run {
                    isCreatingFlow = false
                    // TODO: Show error alert
                }
            }
        }
    }
    
    private func buildFlowSummary(_ flow: Flow) -> String {
        var summary = "## Flow: \(flow.macroGoal)\n\n"
        
        for (index, task) in flow.microTasks.enumerated() {
            summary += "\(index + 1). **\(task.title)** (\(task.type.rawValue))\n"
            summary += "   - \(task.description)\n"
            summary += "   - Effort: \(task.effort)/5\n"
            summary += "   - Duration: \(task.estimatedDuration)\n\n"
        }
        
        return summary
    }
    
    private func executeFlow(_ flow: Flow) {
        Task {
            do {
                if enhancedModeEnabled {
                    // Use parallel agent execution for enhanced mode
                    try await flowEngine.executeWithParallelAgents(flow)
                } else {
                    try await flowEngine.executeFlow(flow)
                }
            } catch {
                // TODO: Handle execution error
                print("Flow execution error: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct FlowStatusHeader: View {
    let status: FlowStatus
    let macroGoal: String?
    let enhancedMode: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                StatusIndicator(status: status)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(statusText)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if enhancedMode {
                            Label("Enhanced", systemImage: "bolt.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    if let goal = macroGoal {
                        Text(goal)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            if status == .executing {
                ProgressView()
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding(.horizontal)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var statusText: String {
        switch status {
        case .idle: return "Ready to Create Flow"
        case .analyzing: return "Analyzing Task..."
        case .ready: return "Flow Ready"
        case .executing: return "Executing Flow"
        case .completed: return "Flow Completed"
        case .failed: return "Flow Failed"
        }
    }
}

struct StatusIndicator: View {
    let status: FlowStatus
    
    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(statusColor.opacity(0.3), lineWidth: 4)
                    .scaleEffect(status == .executing ? 1.5 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: status == .executing)
            )
    }
    
    private var statusColor: Color {
        switch status {
        case .idle: return .gray
        case .analyzing: return .blue
        case .ready: return .green
        case .executing: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }
}

struct EmptyFlowState: View {
    @Binding var macroTaskInput: String
    @FocusState.Binding var isInputFocused: Bool
    let isCreatingFlow: Bool
    let onCreateFlow: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Claude Flow illustration
            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Claude Flow & Swarm")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Break down complex tasks into micro-tasks and execute them with multiple AI agents working in coordination")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            // Input area
            VStack(spacing: 16) {
                Text("What complex task would you like to accomplish?")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("Describe your macro task...", text: $macroTaskInput, axis: .vertical)
                    .focused($isInputFocused)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 24)
                
                Button(action: onCreateFlow) {
                    HStack {
                        if isCreatingFlow {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text(isCreatingFlow ? "Creating Flow..." : "Create Flow")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(macroTaskInput.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(macroTaskInput.isEmpty || isCreatingFlow)
                .padding(.horizontal, 24)
            }
            
            // Example tasks
            VStack(spacing: 12) {
                Text("Example tasks:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    ExampleTaskButton(
                        text: "Build a complete REST API with authentication",
                        onTap: { macroTaskInput = "Build a complete REST API with user authentication, CRUD operations, database integration, and comprehensive testing" }
                    )
                    
                    ExampleTaskButton(
                        text: "Create a mobile app prototype",
                        onTap: { macroTaskInput = "Create a mobile app prototype with user interface design, core functionality implementation, user testing, and deployment preparation" }
                    )
                    
                    ExampleTaskButton(
                        text: "Research and implement ML pipeline",
                        onTap: { macroTaskInput = "Research machine learning approaches, implement a data processing pipeline, train models, evaluate performance, and deploy to production" }
                    )
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .padding(.top, 40)
    }
}

struct ExampleTaskButton: View {
    let text: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(text)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "arrow.up.left")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct FlowCard: View {
    let flow: Flow
    let onTap: () -> Void
    let onExecute: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(flow.macroGoal)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text("\(flow.microTasks.count) micro-tasks • \(flow.totalEstimatedTime)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onExecute) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                        Text("Execute")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            
            // Task breakdown preview
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(flow.microTasks.prefix(5)) { task in
                        MicroTaskChip(microTask: task)
                    }
                    
                    if flow.microTasks.count > 5 {
                        Text("+\(flow.microTasks.count - 5) more")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .cornerRadius(6)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .onTapGesture(perform: onTap)
    }
}

struct MicroTaskChip: View {
    let microTask: MicroTask
    
    var body: some View {
        VStack(spacing: 2) {
            Text(microTask.type.rawValue.capitalized)
                .font(.caption2)
                .fontWeight(.medium)
            
            Text("\(microTask.effort)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(typeColor.opacity(0.2))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(typeColor.opacity(0.5), lineWidth: 1)
        )
    }
    
    private var typeColor: Color {
        switch microTask.type {
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

struct QuickActionsBar: View {
    let onNewFlow: () -> Void
    let onViewSwarm: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: onNewFlow) {
                HStack {
                    Image(systemName: "plus")
                    Text("New Flow")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            Button(action: onViewSwarm) {
                HStack {
                    Image(systemName: "eye")
                    Text("View Swarm")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

struct FlowCreationSheet: View {
    @Binding var macroTaskInput: String
    @Binding var isCreatingFlow: Bool
    let onCreateFlow: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Describe the complex task you want to accomplish. Claude Flow will break it down into micro-tasks and coordinate multiple agents to execute them.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                TextField("Enter your macro task...", text: $macroTaskInput, axis: .vertical)
                    .lineLimit(5...10)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                Button(action: {
                    onCreateFlow()
                    dismiss()
                }) {
                    HStack {
                        if isCreatingFlow {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text(isCreatingFlow ? "Creating Flow..." : "Create Flow")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(macroTaskInput.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(macroTaskInput.isEmpty || isCreatingFlow)
                .padding()
                
                Spacer()
            }
            .navigationTitle("Create New Flow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ClaudeFlowSwarmView(claudeService: ClaudeService(
        tokenizationEngine: TokenizationEngine(cacheManager: CacheManager()),
        cacheManager: CacheManager(),
        gitManager: GitManager(),
        fileSystemManager: FileSystemManager()
    ))
}