import Foundation
import SQLite3

// MARK: - Claude Flow Engine
// Intelligent task decomposition and orchestration system

@MainActor
class ClaudeFlowEngine: ObservableObject {
    @Published var activeFlows: [Flow] = []
    @Published var flowStatus: FlowStatus = .idle
    @Published var currentMacroGoal: String?
    @Published var useEnhancedMode: Bool = false
    @Published var activeSwarmClusters: [SwarmCluster] = []
    
    private let swarmOrchestrator: ClaudeSwarmOrchestrator
    private let contextDB: SharedContextDatabase
    private let claudeService: ClaudeService
    private let enhancedEngine: EnhancedClaudeFlowEngine?
    
    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        self.contextDB = SharedContextDatabase()
        self.swarmOrchestrator = ClaudeSwarmOrchestrator(
            contextDB: contextDB,
            claudeService: claudeService
        )
        // Initialize enhanced engine for complex tasks
        self.enhancedEngine = EnhancedClaudeFlowEngine(claudeService: claudeService)
    }
    
    // MARK: - Flow Decomposition
    
    func decomposeTask(_ macroTask: String) async throws -> Flow {
        flowStatus = .analyzing
        currentMacroGoal = macroTask
        
        // Check if task complexity warrants enhanced mode
        if shouldUseEnhancedMode(for: macroTask) && enhancedEngine != nil {
            useEnhancedMode = true
            return try await decomposeWithEnhancedEngine(macroTask)
        }
        
        // Use Claude's intelligence to break down the macro task
        let decompositionPrompt = """
        You are Claude Flow - an expert task decomposition engine. Break down this complex task into micro-tasks that can be executed independently by different agents.
        
        Macro Task: \(macroTask)
        
        Rules:
        1. Each micro-task should be atomic and executable by a single agent
        2. Identify dependencies between tasks
        3. Estimate effort (1-5 scale)
        4. Assign task types (code, research, analysis, test, deploy)
        5. Return structured JSON
        
        Format:
        {
          "flow_id": "unique_id",
          "macro_goal": "goal description",
          "micro_tasks": [
            {
              "id": "task_1",
              "title": "Task title",
              "description": "Detailed description",
              "type": "code|research|analysis|test|deploy",
              "effort": 1-5,
              "dependencies": ["task_id_1", "task_id_2"],
              "estimated_duration": "5m|30m|2h",
              "prerequisites": ["what needs to be done first"],
              "deliverable": "what this task produces"
            }
          ],
          "execution_strategy": "parallel|sequential|hybrid",
          "total_estimated_time": "2h 30m"
        }
        """
        
        let response = try await claudeService.sendMessage(
            decompositionPrompt,
            in: nil,
            activeFiles: Set<WorkspaceFile>(),
            useContext: false
        )
        
        // Parse the JSON response into a Flow
        let flow = try parseFlowFromResponse(response.content)
        
        // Store in shared context database
        try await contextDB.storeFlow(flow)
        
        activeFlows.append(flow)
        flowStatus = .ready
        
        return flow
    }
    
    // MARK: - Flow Execution
    
    func executeFlow(_ flow: Flow) async throws {
        flowStatus = .executing
        
        // Update shared context with macro goal
        try await contextDB.updateMacroGoal(flow.macroGoal)
        
        // Determine execution strategy
        switch flow.executionStrategy {
        case .parallel:
            try await executeParallel(flow)
        case .sequential:
            try await executeSequential(flow)
        case .hybrid:
            try await executeHybrid(flow)
        }
        
        flowStatus = .completed
    }
    
    private func executeParallel(_ flow: Flow) async throws {
        // Find all tasks with no dependencies and execute them simultaneously
        let independentTasks = flow.microTasks.filter { $0.dependencies.isEmpty }
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for task in independentTasks {
                group.addTask {
                    try await self.swarmOrchestrator.executeTask(task, flowId: flow.id)
                }
            }
            try await group.waitForAll()
        }
        
        // Continue with dependent tasks as they become available
        try await executeDependentTasks(flow)
    }
    
    private func executeSequential(_ flow: Flow) async throws {
        for task in flow.microTasks {
            try await swarmOrchestrator.executeTask(task, flowId: flow.id)
        }
    }
    
    private func executeHybrid(_ flow: Flow) async throws {
        // Smart scheduling: parallel where possible, sequential where necessary
        var completed: Set<String> = []
        var remaining = flow.microTasks
        
        while !remaining.isEmpty {
            // Find tasks that can run (dependencies satisfied)
            let ready = remaining.filter { task in
                task.dependencies.allSatisfy { completed.contains($0) }
            }
            
            if ready.isEmpty && !remaining.isEmpty {
                throw FlowError.circularDependency
            }
            
            // Execute ready tasks in parallel
            try await withThrowingTaskGroup(of: String.self) { group in
                for task in ready {
                    group.addTask {
                        try await self.swarmOrchestrator.executeTask(task, flowId: flow.id)
                        return task.id
                    }
                }
                
                for try await completedTaskId in group {
                    completed.insert(completedTaskId)
                    remaining.removeAll { $0.id == completedTaskId }
                }
            }
        }
    }
    
    private func executeDependentTasks(_ flow: Flow) async throws {
        // Continue executing tasks as their dependencies complete
        // This is a simplified version - in production, use a proper DAG executor
        var completed: Set<String> = []
        var remaining = flow.microTasks.filter { !$0.dependencies.isEmpty }
        
        while !remaining.isEmpty {
            let ready = remaining.filter { task in
                task.dependencies.allSatisfy { completed.contains($0) }
            }
            
            for task in ready {
                try await swarmOrchestrator.executeTask(task, flowId: flow.id)
                completed.insert(task.id)
                remaining.removeAll { $0.id == task.id }
            }
        }
    }
    
    // MARK: - Enhanced Mode Methods
    
    private func shouldUseEnhancedMode(for task: String) -> Bool {
        // Use enhanced mode for complex multi-phase tasks
        let complexityIndicators = [
            "build a complete",
            "create an entire",
            "implement full",
            "develop comprehensive",
            "multiple features",
            "end-to-end",
            "production-ready",
            "enterprise",
            "scalable system"
        ]
        
        let lowercasedTask = task.lowercased()
        return complexityIndicators.contains { lowercasedTask.contains($0) }
    }
    
    private func decomposeWithEnhancedEngine(_ macroTask: String) async throws -> Flow {
        guard let engine = enhancedEngine else {
            throw FlowError.enhancedModeUnavailable
        }
        
        // Use enhanced engine for complex orchestration
        let result = try await engine.orchestrateComplexTask(macroTask)
        
        // Convert to standard Flow format
        let flow = Flow(
            id: result.swarmClusterId,
            macroGoal: result.originalTask,
            microTasks: [], // Enhanced engine manages tasks internally
            executionStrategy: .hybrid,
            totalEstimatedTime: formatDuration(result.executionTime)
        )
        
        activeFlows.append(flow)
        return flow
    }
    
    func executeWithParallelAgents(_ flow: Flow) async throws {
        guard let engine = enhancedEngine else {
            // Fallback to standard execution
            try await executeFlow(flow)
            return
        }
        
        flowStatus = .executing
        
        // Spin up multiple Claude instances for parallel execution
        let result = try await engine.orchestrateComplexTask(flow.macroGoal)
        
        // Update flow status based on result
        flowStatus = result.tasksCompleted == result.agentsUsed ? .completed : .failed
    }
    
    // MARK: - Flow Monitoring
    
    func getFlowProgress(_ flowId: String) async -> FlowProgress {
        return await contextDB.getFlowProgress(flowId)
    }
    
    func getAllActiveAgents() async -> [SwarmAgent] {
        return await swarmOrchestrator.getActiveAgents()
    }
    
    func getSwarmIntelligence(for flowId: String) async -> SwarmIntelligence {
        return await swarmOrchestrator.getSwarmIntelligence(for: flowId)
    }
    
    func getActiveSwarmClusters() -> [SwarmCluster] {
        return enhancedEngine?.activeSwarms ?? []
    }
    
    // MARK: - Private Helpers
    
    private func parseFlowFromResponse(_ response: String) throws -> Flow {
        // Extract JSON from Claude's response
        guard let jsonData = extractJSON(from: response)?.data(using: .utf8) else {
            throw FlowError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(Flow.self, from: jsonData)
    }
    
    private func extractJSON(from text: String) -> String? {
        // Find JSON block in Claude's response
        let lines = text.components(separatedBy: .newlines)
        var jsonLines: [String] = []
        var inJSON = false
        
        for line in lines {
            if line.contains("{") && !inJSON {
                inJSON = true
                jsonLines.append(line)
            } else if inJSON {
                jsonLines.append(line)
                if line.contains("}") && line.trimmingCharacters(in: .whitespaces) == "}" {
                    break
                }
            }
        }
        
        return jsonLines.isEmpty ? nil : jsonLines.joined(separator: "\n")
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Models

struct Flow: Codable, Identifiable {
    let id: String
    let macroGoal: String
    let microTasks: [MicroTask]
    let executionStrategy: ExecutionStrategy
    let totalEstimatedTime: String
    let createdAt: Date
    
    init(id: String, macroGoal: String, microTasks: [MicroTask], executionStrategy: ExecutionStrategy, totalEstimatedTime: String) {
        self.id = id
        self.macroGoal = macroGoal
        self.microTasks = microTasks
        self.executionStrategy = executionStrategy
        self.totalEstimatedTime = totalEstimatedTime
        self.createdAt = Date()
    }
}

struct MicroTask: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let type: TaskType
    let effort: Int // 1-5 scale
    let dependencies: [String]
    let estimatedDuration: String
    let prerequisites: [String]
    let deliverable: String
    var status: TaskStatus = .pending
    var assignedAgent: String?
    var result: String?
    var startedAt: Date?
    var completedAt: Date?
    var requiredOperation: Operation = .analyze
    
    enum TaskType: String, Codable, CaseIterable {
        case code = "code"
        case research = "research"
        case analysis = "analysis"
        case test = "test"
        case deploy = "deploy"
        case documentation = "documentation"
        case review = "review"
        case architect = "architect"
        case security = "security"
        case devops = "devops"
        case analyst = "analyst"
        case coder = "coder"
        case tester = "tester"
    }
    
    enum TaskStatus: String, Codable {
        case pending = "pending"
        case assigned = "assigned"
        case inProgress = "in_progress"
        case completed = "completed"
        case failed = "failed"
        case blocked = "blocked"
    }
}

enum ExecutionStrategy: String, Codable {
    case parallel = "parallel"
    case sequential = "sequential"
    case hybrid = "hybrid"
}

enum FlowStatus {
    case idle
    case analyzing
    case ready
    case executing
    case completed
    case failed
}

struct FlowProgress {
    let flowId: String
    let totalTasks: Int
    let completedTasks: Int
    let failedTasks: Int
    let activeAgents: Int
    let estimatedTimeRemaining: String
    
    var percentComplete: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks) * 100
    }
}

enum FlowError: LocalizedError {
    case invalidResponse
    case circularDependency
    case taskExecutionFailed(String)
    case agentSpawnFailed
    case databaseError
    case enhancedModeUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Claude"
        case .circularDependency:
            return "Circular dependency detected in task flow"
        case .taskExecutionFailed(let task):
            return "Task execution failed: \(task)"
        case .agentSpawnFailed:
            return "Failed to spawn swarm agent"
        case .databaseError:
            return "Database operation failed"
        case .enhancedModeUnavailable:
            return "Enhanced execution mode is not available"
        }
    }
}