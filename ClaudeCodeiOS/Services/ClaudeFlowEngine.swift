import Foundation
import SQLite3

// MARK: - Claude Flow Engine
// Intelligent task decomposition and orchestration system

@MainActor
class ClaudeFlowEngine: ObservableObject {
    @Published var activeFlows: [Flow] = []
    @Published var flowStatus: FlowStatus = .idle
    @Published var currentMacroGoal: String?
    
    private let swarmOrchestrator: ClaudeSwarmOrchestrator
    private let contextDB: SharedContextDatabase
    private let claudeService: ClaudeService
    
    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        self.contextDB = SharedContextDatabase()
        self.swarmOrchestrator = ClaudeSwarmOrchestrator(
            contextDB: contextDB,
            claudeService: claudeService
        )
    }
    
    // MARK: - Flow Decomposition
    
    func decomposeTask(_ macroTask: String) async throws -> Flow {
        flowStatus = .analyzing
        currentMacroGoal = macroTask
        
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
    
    enum TaskType: String, Codable, CaseIterable {
        case code = "code"
        case research = "research"
        case analysis = "analysis"
        case test = "test"
        case deploy = "deploy"
        case documentation = "documentation"
        case review = "review"
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
        }
    }
}