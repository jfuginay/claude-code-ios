import Foundation
import Combine

// MARK: - Enhanced Claude Flow Engine with Queen-Led Architecture
// Inspired by claude-flow and claude-swarm patterns

@MainActor
class EnhancedClaudeFlowEngine: ObservableObject {
    // MARK: - Queen AI Properties
    @Published var queenStatus: QueenStatus = .idle
    @Published var activeSwarms: [SwarmCluster] = []
    @Published var globalMemory: GlobalMemory
    
    private let claudeService: ClaudeService
    private let swarmOrchestrator: ClaudeSwarmOrchestrator
    private let contextDB: SharedContextDatabase
    private let sandboxManager: SandboxManager
    
    // Agent pools for different specializations
    private var agentPools: [MicroTask.TaskType: [SwarmAgent]] = [:]
    private let maxAgentsPerType = 3
    
    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        self.contextDB = SharedContextDatabase()
        self.swarmOrchestrator = ClaudeSwarmOrchestrator(
            contextDB: contextDB,
            claudeService: claudeService
        )
        self.sandboxManager = SandboxManager()
        self.globalMemory = GlobalMemory()
        
        setupAgentPools()
    }
    
    // MARK: - Queen AI Orchestration
    
    func orchestrateComplexTask(_ macroTask: String) async throws -> OrchestrationResult {
        queenStatus = .analyzing
        
        // Step 1: Queen AI analyzes and creates master plan
        let masterPlan = try await createMasterPlan(for: macroTask)
        
        // Step 2: Determine optimal swarm configuration
        let swarmConfig = determineSwarmConfiguration(for: masterPlan)
        
        // Step 3: Spin up required agent clusters
        let swarmCluster = try await spawnSwarmCluster(config: swarmConfig, plan: masterPlan)
        activeSwarms.append(swarmCluster)
        
        // Step 4: Execute with safety controls
        queenStatus = .orchestrating
        let result = try await executeWithSafety(swarmCluster: swarmCluster)
        
        // Step 5: Consolidate results
        queenStatus = .consolidating
        let finalResult = try await consolidateResults(from: swarmCluster, originalTask: macroTask)
        
        queenStatus = .completed
        return finalResult
    }
    
    // MARK: - Master Planning (Queen AI)
    
    private func createMasterPlan(for macroTask: String) async throws -> MasterPlan {
        let planningPrompt = """
        You are the Queen AI orchestrator. Analyze this complex task and create a master execution plan.
        
        TASK: \(macroTask)
        
        Create a detailed plan that includes:
        1. Task decomposition into specialized sub-tasks
        2. Required agent types and their roles
        3. Execution order and dependencies
        4. Safety considerations and constraints
        5. Success criteria
        
        Format your response as a structured plan with clear sections.
        """
        
        let response = try await claudeService.sendMessage(
            planningPrompt,
            in: nil,
            activeFiles: Set<WorkspaceFile>(),
            useContext: false
        )
        
        return parseMasterPlan(from: response.content)
    }
    
    // MARK: - Swarm Configuration
    
    private func determineSwarmConfiguration(for plan: MasterPlan) -> SwarmConfiguration {
        var requiredAgents: [AgentRequirement] = []
        
        // Analyze task complexity and determine agent needs
        for phase in plan.phases {
            switch phase.complexity {
            case .high:
                // High complexity needs multiple specialized agents
                requiredAgents.append(contentsOf: [
                    AgentRequirement(type: .architect, count: 1, priority: .critical),
                    AgentRequirement(type: .coder, count: 2, priority: .high),
                    AgentRequirement(type: .analyst, count: 1, priority: .medium)
                ])
            case .medium:
                requiredAgents.append(contentsOf: [
                    AgentRequirement(type: .coder, count: 1, priority: .high),
                    AgentRequirement(type: .tester, count: 1, priority: .medium)
                ])
            case .low:
                requiredAgents.append(
                    AgentRequirement(type: phase.primaryType, count: 1, priority: .medium)
                )
            }
        }
        
        return SwarmConfiguration(
            mode: plan.phases.count > 5 ? .hiveMode : .swarmMode,
            requiredAgents: requiredAgents,
            coordinationStrategy: .queenLed,
            safetyLevel: .strict
        )
    }
    
    // MARK: - Agent Spawning with Sandboxing
    
    private func spawnSwarmCluster(config: SwarmConfiguration, plan: MasterPlan) async throws -> SwarmCluster {
        let clusterId = UUID().uuidString
        var agents: [SandboxedAgent] = []
        
        for requirement in config.requiredAgents {
            for _ in 0..<requirement.count {
                let sandbox = try await sandboxManager.createSandbox(
                    for: requirement.type,
                    restrictions: determineRestrictions(for: requirement.type)
                )
                
                let agent = try await spawnSandboxedAgent(
                    type: requirement.type,
                    in: sandbox,
                    clusterId: clusterId
                )
                
                agents.append(agent)
            }
        }
        
        return SwarmCluster(
            id: clusterId,
            agents: agents,
            masterPlan: plan,
            configuration: config,
            startTime: Date()
        )
    }
    
    private func spawnSandboxedAgent(type: MicroTask.TaskType, in sandbox: Sandbox, clusterId: String) async throws -> SandboxedAgent {
        // Create specialized agent with sandbox restrictions
        let agentId = "agent_\(type.rawValue)_\(UUID().uuidString.prefix(8))"
        
        let agent = SandboxedAgent(
            id: agentId,
            type: type,
            sandbox: sandbox,
            clusterId: clusterId,
            claudeService: createRestrictedClaudeService(for: sandbox),
            personality: createEnhancedPersonality(for: type)
        )
        
        // Initialize agent in sandbox
        try await agent.initialize()
        
        return agent
    }
    
    // MARK: - Safety Controls
    
    private func determineRestrictions(for agentType: MicroTask.TaskType) -> SandboxRestrictions {
        switch agentType {
        case .deploy:
            // Deploy agents get the most restrictions
            return SandboxRestrictions(
                allowedOperations: [.read, .analyze],
                deniedOperations: [.write, .delete, .execute],
                workingDirectory: "/tmp/sandbox/deploy",
                networkAccess: false,
                fileSystemAccess: .readonly
            )
        case .code:
            // Code agents can write but only in sandbox
            return SandboxRestrictions(
                allowedOperations: [.read, .write, .analyze],
                deniedOperations: [.delete, .execute],
                workingDirectory: "/tmp/sandbox/code",
                networkAccess: false,
                fileSystemAccess: .sandboxed
            )
        case .test:
            // Test agents can execute but only test commands
            return SandboxRestrictions(
                allowedOperations: [.read, .analyze, .execute],
                deniedOperations: [.write, .delete],
                workingDirectory: "/tmp/sandbox/test",
                networkAccess: false,
                fileSystemAccess: .readonly,
                allowedCommands: ["npm test", "jest", "pytest", "go test"]
            )
        default:
            // Default restrictions for other agent types
            return SandboxRestrictions(
                allowedOperations: [.read, .analyze],
                deniedOperations: [.write, .delete, .execute],
                workingDirectory: "/tmp/sandbox/\(agentType.rawValue)",
                networkAccess: false,
                fileSystemAccess: .readonly
            )
        }
    }
    
    // MARK: - Parallel Execution with Safety
    
    private func executeWithSafety(swarmCluster: SwarmCluster) async throws -> SwarmExecutionResult {
        var results: [String: TaskResult] = [:]
        let executionQueue = DispatchQueue(label: "swarm.execution", attributes: .concurrent)
        let resultLock = NSLock()
        
        // Create execution groups based on dependencies
        let executionGroups = createExecutionGroups(from: swarmCluster.masterPlan)
        
        for group in executionGroups {
            // Execute tasks in parallel within each group
            try await withThrowingTaskGroup(of: (String, TaskResult).self) { taskGroup in
                for task in group.tasks {
                    let agent = swarmCluster.agents.first { $0.type == task.type }
                    guard let agent = agent else { continue }
                    
                    taskGroup.addTask {
                        // Pre-execution safety check
                        try await self.performSafetyCheck(for: task, agent: agent)
                        
                        // Execute in sandbox
                        let result = try await agent.execute(task: task)
                        
                        // Post-execution validation
                        try await self.validateResult(result, for: task)
                        
                        return (task.id, result)
                    }
                }
                
                // Collect results
                for try await (taskId, result) in taskGroup {
                    resultLock.lock()
                    results[taskId] = result
                    resultLock.unlock()
                    
                    // Update global memory
                    await updateGlobalMemory(with: result)
                }
            }
        }
        
        return SwarmExecutionResult(
            clusterId: swarmCluster.id,
            results: results,
            duration: Date().timeIntervalSince(swarmCluster.startTime)
        )
    }
    
    // MARK: - Safety Checks
    
    private func performSafetyCheck(for task: MicroTask, agent: SandboxedAgent) async throws {
        // Validate task is within agent's allowed operations
        guard agent.sandbox.restrictions.allowedOperations.contains(task.requiredOperation) else {
            throw SwarmError.operationNotAllowed(
                "Agent \(agent.id) cannot perform \(task.requiredOperation) for task \(task.id)"
            )
        }
        
        // Check resource limits
        if await agent.resourceUsage.memoryUsage > agent.sandbox.memoryLimit {
            throw SwarmError.resourceLimitExceeded("Memory limit exceeded for agent \(agent.id)")
        }
        
        // Validate no dangerous patterns in task
        let dangerousPatterns = ["rm -rf", "sudo", "chmod 777", "curl | bash"]
        for pattern in dangerousPatterns {
            if task.description.contains(pattern) || task.deliverable.contains(pattern) {
                throw SwarmError.dangerousOperation("Dangerous pattern detected: \(pattern)")
            }
        }
    }
    
    private func validateResult(_ result: TaskResult, for task: MicroTask) async throws {
        // Ensure result doesn't contain sensitive information
        let sensitivePatterns = ["password", "api_key", "secret", "token"]
        let lowercasedContent = result.content.lowercased()
        
        for pattern in sensitivePatterns {
            if lowercasedContent.contains(pattern) {
                // Redact sensitive information
                result.content = redactSensitiveInfo(from: result.content)
            }
        }
        
        // Validate result meets task requirements
        if result.status == .failed {
            // Log failure for analysis
            await logFailure(task: task, result: result)
        }
    }
    
    // MARK: - Result Consolidation
    
    private func consolidateResults(from swarmCluster: SwarmCluster, originalTask: String) async throws -> OrchestrationResult {
        // Gather all results
        let allResults = swarmCluster.agents.compactMap { $0.completedTasks }
            .flatMap { $0 }
        
        // Queen AI consolidates and synthesizes
        let consolidationPrompt = """
        You are the Queen AI. Consolidate these results from your swarm agents into a cohesive response.
        
        ORIGINAL TASK: \(originalTask)
        
        AGENT RESULTS:
        \(formatAgentResults(allResults))
        
        Provide a comprehensive summary that:
        1. Addresses the original task completely
        2. Highlights key achievements
        3. Notes any issues or limitations
        4. Provides actionable next steps
        """
        
        let finalResponse = try await claudeService.sendMessage(
            consolidationPrompt,
            in: nil,
            activeFiles: Set<WorkspaceFile>(),
            useContext: false
        )
        
        // Clean up sandboxes
        for agent in swarmCluster.agents {
            try await sandboxManager.cleanupSandbox(agent.sandbox)
        }
        
        return OrchestrationResult(
            originalTask: originalTask,
            swarmClusterId: swarmCluster.id,
            consolidatedResponse: finalResponse.content,
            executionTime: Date().timeIntervalSince(swarmCluster.startTime),
            agentsUsed: swarmCluster.agents.count,
            tasksCompleted: allResults.count
        )
    }
    
    // MARK: - Helper Methods
    
    private func setupAgentPools() {
        // Pre-initialize agent pools for faster spawning
        for taskType in MicroTask.TaskType.allCases {
            agentPools[taskType] = []
        }
    }
    
    private func createRestrictedClaudeService(for sandbox: Sandbox) -> ClaudeService {
        // Create a restricted Claude service that respects sandbox boundaries
        let restrictedService = ClaudeService(
            tokenizationEngine: claudeService.tokenizationEngine,
            cacheManager: claudeService.cacheManager,
            gitManager: claudeService.gitManager,
            fileSystemManager: SandboxedFileSystemManager(sandbox: sandbox)
        )
        
        return restrictedService
    }
    
    private func createEnhancedPersonality(for type: MicroTask.TaskType) -> String {
        let basePersonality = SwarmAgent.createPersonality(for: type)
        
        return """
        \(basePersonality)
        
        SWARM PROTOCOL:
        - You are part of a coordinated swarm led by the Queen AI
        - Focus only on your specialized task
        - Report results in structured format
        - Flag any safety concerns immediately
        - Operate within your sandbox restrictions
        - Collaborate through shared memory, not direct communication
        """
    }
    
    private func updateGlobalMemory(with result: TaskResult) async {
        await globalMemory.addEntry(
            type: .taskResult,
            content: result.content,
            metadata: [
                "taskId": result.taskId,
                "agentId": result.agentId,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        )
    }
    
    private func parseMasterPlan(from content: String) -> MasterPlan {
        // Parse the Queen AI's response into a structured plan
        // This is a simplified version - in production, use proper parsing
        
        return MasterPlan(
            id: UUID().uuidString,
            phases: [
                ExecutionPhase(
                    id: "phase1",
                    name: "Analysis",
                    tasks: [],
                    complexity: .medium,
                    primaryType: .analysis
                )
            ],
            dependencies: [],
            estimatedDuration: "30m",
            successCriteria: ["All tasks completed", "No errors reported"]
        )
    }
    
    private func createExecutionGroups(from plan: MasterPlan) -> [ExecutionGroup] {
        // Group tasks by dependencies for parallel execution
        // This is simplified - real implementation would analyze dependency graph
        
        return plan.phases.map { phase in
            ExecutionGroup(
                id: phase.id,
                tasks: phase.tasks,
                canRunInParallel: true
            )
        }
    }
    
    private func formatAgentResults(_ results: [TaskResult]) -> String {
        return results.map { result in
            """
            Agent: \(result.agentId)
            Task: \(result.taskId)
            Status: \(result.status)
            Output: \(result.content)
            ---
            """
        }.joined(separator: "\n")
    }
    
    private func redactSensitiveInfo(from content: String) -> String {
        // Simple redaction - in production use proper regex
        var redacted = content
        let patterns = [
            "password": "[REDACTED_PASSWORD]",
            "api_key": "[REDACTED_API_KEY]",
            "secret": "[REDACTED_SECRET]",
            "token": "[REDACTED_TOKEN]"
        ]
        
        for (pattern, replacement) in patterns {
            redacted = redacted.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .caseInsensitive
            )
        }
        
        return redacted
    }
    
    private func logFailure(task: MicroTask, result: TaskResult) async {
        await globalMemory.addEntry(
            type: .failure,
            content: "Task \(task.id) failed: \(result.content)",
            metadata: [
                "taskId": task.id,
                "agentId": result.agentId,
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "taskType": task.type.rawValue
            ]
        )
    }
}

// MARK: - Supporting Types

enum QueenStatus {
    case idle
    case analyzing
    case orchestrating
    case consolidating
    case completed
    case failed
}

struct MasterPlan {
    let id: String
    let phases: [ExecutionPhase]
    let dependencies: [TaskDependency]
    let estimatedDuration: String
    let successCriteria: [String]
}

struct ExecutionPhase {
    let id: String
    let name: String
    var tasks: [MicroTask]
    let complexity: Complexity
    let primaryType: MicroTask.TaskType
    
    enum Complexity {
        case low, medium, high
    }
}

struct SwarmConfiguration {
    let mode: SwarmMode
    let requiredAgents: [AgentRequirement]
    let coordinationStrategy: CoordinationStrategy
    let safetyLevel: SafetyLevel
    
    enum SwarmMode {
        case swarmMode  // For standard tasks
        case hiveMode   // For complex multi-phase tasks
    }
    
    enum CoordinationStrategy {
        case queenLed
        case distributed
        case hierarchical
    }
    
    enum SafetyLevel {
        case permissive
        case standard
        case strict
    }
}

struct AgentRequirement {
    let type: MicroTask.TaskType
    let count: Int
    let priority: Priority
    
    enum Priority {
        case low, medium, high, critical
    }
}

struct SwarmCluster {
    let id: String
    var agents: [SandboxedAgent]
    let masterPlan: MasterPlan
    let configuration: SwarmConfiguration
    let startTime: Date
}

struct TaskDependency {
    let taskId: String
    let dependsOn: [String]
}

struct ExecutionGroup {
    let id: String
    let tasks: [MicroTask]
    let canRunInParallel: Bool
}

struct OrchestrationResult {
    let originalTask: String
    let swarmClusterId: String
    let consolidatedResponse: String
    let executionTime: TimeInterval
    let agentsUsed: Int
    let tasksCompleted: Int
}

struct SwarmExecutionResult {
    let clusterId: String
    let results: [String: TaskResult]
    let duration: TimeInterval
}

// MARK: - Global Memory System

actor GlobalMemory {
    private var entries: [MemoryEntry] = []
    private let maxEntries = 1000
    
    func addEntry(type: EntryType, content: String, metadata: [String: String]) {
        let entry = MemoryEntry(
            id: UUID().uuidString,
            type: type,
            content: content,
            metadata: metadata,
            timestamp: Date()
        )
        
        entries.append(entry)
        
        // Maintain memory limit
        if entries.count > maxEntries {
            entries.removeFirst()
        }
    }
    
    func getEntries(of type: EntryType? = nil, limit: Int = 100) -> [MemoryEntry] {
        let filtered = type == nil ? entries : entries.filter { $0.type == type }
        return Array(filtered.suffix(limit))
    }
    
    func search(query: String) -> [MemoryEntry] {
        return entries.filter { entry in
            entry.content.lowercased().contains(query.lowercased())
        }
    }
    
    struct MemoryEntry {
        let id: String
        let type: EntryType
        let content: String
        let metadata: [String: String]
        let timestamp: Date
    }
    
    enum EntryType {
        case taskResult
        case failure
        case insight
        case warning
        case decision
    }
}

// MARK: - Task Type Helpers

extension MicroTask.TaskType {
    var primaryType: MicroTask.TaskType {
        switch self {
        case .architect, .code, .coder:
            return .code
        case .analyst, .analysis:
            return .analysis
        case .tester, .test:
            return .test
        case .security, .devops, .deploy:
            return .deploy
        default:
            return self
        }
    }
}