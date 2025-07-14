import Foundation
import Network

// MARK: - Claude Swarm Orchestrator
// Manages multiple Claude agent instances with shared context

@MainActor
class ClaudeSwarmOrchestrator: ObservableObject {
    @Published var activeAgents: [SwarmAgent] = []
    @Published var swarmStatus: SwarmStatus = .idle
    @Published var agentCapacity: Int = 3 // Max concurrent agents
    
    private let contextDB: SharedContextDatabase
    private let claudeService: ClaudeService
    private let agentQueue = DispatchQueue(label: "swarm.agent.queue", qos: .userInitiated)
    
    init(contextDB: SharedContextDatabase, claudeService: ClaudeService) {
        self.contextDB = contextDB
        self.claudeService = claudeService
    }
    
    // MARK: - Agent Management
    
    func spawnAgent(for task: MicroTask, flowId: String) async throws -> SwarmAgent {
        guard activeAgents.count < agentCapacity else {
            throw SwarmError.agentCapacityExceeded
        }
        
        let agentId = "agent_\(UUID().uuidString.prefix(8))"
        
        // Get shared context for this flow
        let sharedContext = await contextDB.getSharedContext(flowId: flowId)
        
        // Create specialized agent based on task type
        let agent = SwarmAgent(
            id: agentId,
            specialization: task.type,
            assignedTask: task,
            flowId: flowId,
            sharedContext: sharedContext,
            claudeService: claudeService
        )
        
        activeAgents.append(agent)
        
        // Store agent in context database
        try await contextDB.storeAgent(agent)
        
        // Update task status
        try await contextDB.updateTaskStatus(task.id, .assigned, agentId: agentId)
        
        return agent
    }
    
    func executeTask(_ task: MicroTask, flowId: String) async throws {
        let agent = try await spawnAgent(for: task, flowId: flowId)
        
        try await agent.executeTask()
        
        // Update shared context with results
        if let result = agent.currentTask?.result {
            try await contextDB.storeTaskResult(task.id, result: result)
        }
        
        // Remove agent after completion
        activeAgents.removeAll { $0.id == agent.id }
        try await contextDB.removeAgent(agent.id)
    }
    
    func getActiveAgents() async -> [SwarmAgent] {
        return activeAgents
    }
    
    func terminateAgent(_ agentId: String) async {
        if let index = activeAgents.firstIndex(where: { $0.id == agentId }) {
            let agent = activeAgents[index]
            await agent.terminate()
            activeAgents.remove(at: index)
            try? await contextDB.removeAgent(agentId)
        }
    }
    
    func terminateAllAgents() async {
        for agent in activeAgents {
            await agent.terminate()
        }
        activeAgents.removeAll()
        try? await contextDB.clearAllAgents()
    }
    
    // MARK: - Swarm Coordination
    
    func broadcastUpdate(_ update: SwarmUpdate) async {
        try? await contextDB.storeSwarmUpdate(update)
        
        // Notify all agents of the update
        for agent in activeAgents {
            await agent.receiveSwarmUpdate(update)
        }
    }
    
    func getSwarmIntelligence(for flowId: String) async -> SwarmIntelligence {
        let agents = activeAgents.filter { $0.flowId == flowId }
        let completedTasks = await contextDB.getCompletedTasks(flowId: flowId)
        let failedTasks = await contextDB.getFailedTasks(flowId: flowId)
        
        return SwarmIntelligence(
            activeAgentCount: agents.count,
            completedTasksCount: completedTasks.count,
            failedTasksCount: failedTasks.count,
            averageTaskDuration: calculateAverageTaskDuration(completedTasks),
            swarmEfficiency: calculateSwarmEfficiency(agents),
            recommendedActions: generateRecommendations(agents, completedTasks, failedTasks)
        )
    }
    
    // MARK: - Performance Analytics
    
    private func calculateAverageTaskDuration(_ tasks: [MicroTask]) -> TimeInterval {
        let completedTasks = tasks.compactMap { task -> TimeInterval? in
            guard let start = task.startedAt, let end = task.completedAt else { return nil }
            return end.timeIntervalSince(start)
        }
        
        guard !completedTasks.isEmpty else { return 0 }
        return completedTasks.reduce(0, +) / Double(completedTasks.count)
    }
    
    private func calculateSwarmEfficiency(_ agents: [SwarmAgent]) -> Double {
        guard !agents.isEmpty else { return 0 }
        
        let totalEfficiency = agents.reduce(0.0) { sum, agent in
            return sum + agent.efficiency
        }
        
        return totalEfficiency / Double(agents.count)
    }
    
    private func generateRecommendations(_ agents: [SwarmAgent], _ completed: [MicroTask], _ failed: [MicroTask]) -> [String] {
        var recommendations: [String] = []
        
        // Check for overloaded agents
        let overloadedAgents = agents.filter { $0.workload > 0.8 }
        if !overloadedAgents.isEmpty {
            recommendations.append("Consider spawning additional agents - \(overloadedAgents.count) agents are overloaded")
        }
        
        // Check for failed tasks
        if !failed.isEmpty {
            recommendations.append("Review and retry \(failed.count) failed tasks")
        }
        
        // Check for idle capacity
        if agents.count < agentCapacity && !completed.isEmpty {
            recommendations.append("Swarm has available capacity - consider parallel task execution")
        }
        
        return recommendations
    }
}

// MARK: - Swarm Agent

@MainActor
class SwarmAgent: ObservableObject, Identifiable {
    let id: String
    let specialization: MicroTask.TaskType
    let flowId: String
    
    @Published var status: AgentStatus = .idle
    @Published var currentTask: MicroTask?
    @Published var workload: Double = 0.0
    @Published var efficiency: Double = 1.0
    
    private let sharedContext: SharedContext
    private let claudeService: ClaudeService
    private var agentPersonality: String
    
    init(id: String, specialization: MicroTask.TaskType, assignedTask: MicroTask, flowId: String, sharedContext: SharedContext, claudeService: ClaudeService) {
        self.id = id
        self.specialization = specialization
        self.currentTask = assignedTask
        self.flowId = flowId
        self.sharedContext = sharedContext
        self.claudeService = claudeService
        self.agentPersonality = Self.createPersonality(for: specialization)
    }
    
    func executeTask() async throws {
        guard let task = currentTask else { return }
        
        status = .working
        currentTask?.status = .inProgress
        currentTask?.startedAt = Date()
        
        let agentPrompt = buildAgentPrompt(for: task)
        
        do {
            let response = try await claudeService.sendMessage(
                agentPrompt,
                in: nil,
                activeFiles: Set<WorkspaceFile>(),
                useContext: false
            )
            
            currentTask?.result = response.content
            currentTask?.status = .completed
            currentTask?.completedAt = Date()
            status = .completed
            
            // Update efficiency based on completion time vs estimate
            updateEfficiency()
            
        } catch {
            currentTask?.status = .failed
            currentTask?.result = "Error: \(error.localizedDescription)"
            status = .failed
            throw SwarmError.taskExecutionFailed(error.localizedDescription)
        }
    }
    
    func receiveSwarmUpdate(_ update: SwarmUpdate) async {
        // Process updates from other agents
        // This allows agents to adapt their approach based on swarm intelligence
        
        switch update.type {
        case .taskCompleted:
            // Another agent completed a task - update our approach if needed
            break
        case .contextUpdate:
            // Shared context was updated - refresh our understanding
            break
        case .strategyChange:
            // Swarm strategy changed - adapt our execution
            break
        case .agentMessage:
            // Message from another agent - process for coordination
            break
        }
    }
    
    func terminate() async {
        status = .terminated
        currentTask?.status = .blocked
    }
    
    // MARK: - Private Methods
    
    private static func createPersonality(for specialization: MicroTask.TaskType) -> String {
        switch specialization {
        case .code:
            return "You are a focused coding specialist. You write clean, efficient code and follow best practices. You think systematically about implementation details."
        case .research:
            return "You are a thorough research specialist. You gather comprehensive information, analyze sources critically, and synthesize insights effectively."
        case .analysis:
            return "You are an analytical specialist. You break down complex problems, identify patterns, and provide data-driven insights."
        case .test:
            return "You are a testing specialist. You think about edge cases, create comprehensive test scenarios, and ensure quality."
        case .deploy:
            return "You are a deployment specialist. You focus on reliability, monitoring, and smooth production rollouts."
        case .documentation:
            return "You are a documentation specialist. You create clear, comprehensive documentation that helps users understand and use the system."
        case .review:
            return "You are a review specialist. You provide constructive feedback, identify improvements, and ensure quality standards."
        }
    }
    
    private func buildAgentPrompt(for task: MicroTask) -> String {
        return """
        \(agentPersonality)
        
        SWARM CONTEXT:
        - You are Agent \(id) in a swarm working toward: \(sharedContext.macroGoal)
        - Flow ID: \(flowId)
        - Your specialization: \(specialization.rawValue)
        
        SHARED CONTEXT:
        \(sharedContext.relevantInfo)
        
        TASK ASSIGNMENT:
        Task: \(task.title)
        Description: \(task.description)
        Deliverable: \(task.deliverable)
        Prerequisites: \(task.prerequisites.joined(separator: ", "))
        
        COORDINATION RULES:
        1. Your output will be shared with other agents
        2. Focus only on YOUR specific task
        3. Provide clear, actionable deliverables
        4. If you need information from other agents, state it clearly
        5. Consider the macro goal in your approach
        
        Execute this task with expertise and precision. Provide your result in a structured format that other agents can easily understand and build upon.
        """
    }
    
    private func updateEfficiency() {
        guard let task = currentTask,
              let started = task.startedAt,
              let completed = task.completedAt else { return }
        
        let actualDuration = completed.timeIntervalSince(started)
        let estimatedDuration = parseEstimatedDuration(task.estimatedDuration)
        
        if estimatedDuration > 0 {
            efficiency = min(1.0, estimatedDuration / actualDuration)
        }
    }
    
    private func parseEstimatedDuration(_ duration: String) -> TimeInterval {
        // Parse duration strings like "5m", "2h", "30m"
        let components = duration.lowercased()
        if components.hasSuffix("m") {
            return Double(components.dropLast()) ?? 0 * 60
        } else if components.hasSuffix("h") {
            return Double(components.dropLast()) ?? 0 * 3600
        }
        return 0
    }
}

// MARK: - Supporting Models

enum SwarmStatus {
    case idle
    case spawning
    case active
    case scaling
    case terminating
}

enum AgentStatus {
    case idle
    case assigned
    case working
    case completed
    case failed
    case terminated
}

struct SwarmUpdate {
    let id: String
    let type: UpdateType
    let content: String
    let agentId: String
    let timestamp: Date
    
    enum UpdateType {
        case taskCompleted
        case contextUpdate
        case strategyChange
        case agentMessage
    }
}

struct SwarmIntelligence {
    let activeAgentCount: Int
    let completedTasksCount: Int
    let failedTasksCount: Int
    let averageTaskDuration: TimeInterval
    let swarmEfficiency: Double
    let recommendedActions: [String]
}

struct SharedContext {
    let macroGoal: String
    let relevantInfo: String
    let completedTasks: [String]
    let availableResources: [String]
    let constraints: [String]
}

enum SwarmError: LocalizedError {
    case agentCapacityExceeded
    case agentSpawnFailed
    case taskExecutionFailed(String)
    case invalidAgentConfiguration
    
    var errorDescription: String? {
        switch self {
        case .agentCapacityExceeded:
            return "Maximum agent capacity exceeded"
        case .agentSpawnFailed:
            return "Failed to spawn new agent"
        case .taskExecutionFailed(let error):
            return "Task execution failed: \(error)"
        case .invalidAgentConfiguration:
            return "Invalid agent configuration"
        }
    }
}