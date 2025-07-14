import Foundation
import SQLite3

// MARK: - Shared Context Database
// SQLite database for agent coordination and shared context

actor SharedContextDatabase {
    private var db: OpaquePointer?
    private let dbPath: String
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        dbPath = documentsPath.appendingPathComponent("claude_swarm_context.db").path
        
        Task {
            await initializeDatabase()
        }
    }
    
    private func initializeDatabase() async {
        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            await createTables()
        } else {
            print("Error opening database")
        }
    }
    
    private func createTables() async {
        // Flows table
        let createFlowsTable = """
        CREATE TABLE IF NOT EXISTS flows (
            id TEXT PRIMARY KEY,
            macro_goal TEXT NOT NULL,
            execution_strategy TEXT NOT NULL,
            total_estimated_time TEXT NOT NULL,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        """
        
        // Micro tasks table
        let createTasksTable = """
        CREATE TABLE IF NOT EXISTS micro_tasks (
            id TEXT PRIMARY KEY,
            flow_id TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            type TEXT NOT NULL,
            effort INTEGER NOT NULL,
            dependencies TEXT NOT NULL,
            estimated_duration TEXT NOT NULL,
            prerequisites TEXT NOT NULL,
            deliverable TEXT NOT NULL,
            status TEXT NOT NULL,
            assigned_agent TEXT,
            result TEXT,
            started_at TEXT,
            completed_at TEXT,
            FOREIGN KEY (flow_id) REFERENCES flows (id)
        );
        """
        
        // Agents table
        let createAgentsTable = """
        CREATE TABLE IF NOT EXISTS swarm_agents (
            id TEXT PRIMARY KEY,
            flow_id TEXT NOT NULL,
            specialization TEXT NOT NULL,
            status TEXT NOT NULL,
            current_task_id TEXT,
            workload REAL NOT NULL,
            efficiency REAL NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (flow_id) REFERENCES flows (id),
            FOREIGN KEY (current_task_id) REFERENCES micro_tasks (id)
        );
        """
        
        // Shared context table
        let createContextTable = """
        CREATE TABLE IF NOT EXISTS shared_context (
            id TEXT PRIMARY KEY,
            flow_id TEXT NOT NULL,
            context_type TEXT NOT NULL,
            content TEXT NOT NULL,
            created_by_agent TEXT,
            created_at TEXT NOT NULL,
            FOREIGN KEY (flow_id) REFERENCES flows (id)
        );
        """
        
        // Swarm updates table
        let createUpdatesTable = """
        CREATE TABLE IF NOT EXISTS swarm_updates (
            id TEXT PRIMARY KEY,
            flow_id TEXT NOT NULL,
            agent_id TEXT NOT NULL,
            update_type TEXT NOT NULL,
            content TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            FOREIGN KEY (flow_id) REFERENCES flows (id)
        );
        """
        
        // Task results table
        let createResultsTable = """
        CREATE TABLE IF NOT EXISTS task_results (
            id TEXT PRIMARY KEY,
            task_id TEXT NOT NULL,
            agent_id TEXT NOT NULL,
            result_content TEXT NOT NULL,
            result_type TEXT NOT NULL,
            confidence_score REAL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (task_id) REFERENCES micro_tasks (id)
        );
        """
        
        let tables = [
            createFlowsTable,
            createTasksTable,
            createAgentsTable,
            createContextTable,
            createUpdatesTable,
            createResultsTable
        ]
        
        for tableSQL in tables {
            if sqlite3_exec(db, tableSQL, nil, nil, nil) != SQLITE_OK {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("Error creating table: \(errmsg)")
            }
        }
    }
    
    // MARK: - Flow Management
    
    func storeFlow(_ flow: Flow) async throws {
        let sql = """
        INSERT OR REPLACE INTO flows 
        (id, macro_goal, execution_strategy, total_estimated_time, status, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, flow.id, -1, nil)
            sqlite3_bind_text(statement, 2, flow.macroGoal, -1, nil)
            sqlite3_bind_text(statement, 3, flow.executionStrategy.rawValue, -1, nil)
            sqlite3_bind_text(statement, 4, flow.totalEstimatedTime, -1, nil)
            sqlite3_bind_text(statement, 5, "active", -1, nil)
            sqlite3_bind_text(statement, 6, ISO8601DateFormatter().string(from: flow.createdAt), -1, nil)
            sqlite3_bind_text(statement, 7, ISO8601DateFormatter().string(from: Date()), -1, nil)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                throw DatabaseError.insertFailed
            }
            
            // Store micro tasks
            for task in flow.microTasks {
                try await storeMicroTask(task, flowId: flow.id)
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    private func storeMicroTask(_ task: MicroTask, flowId: String) async throws {
        let sql = """
        INSERT OR REPLACE INTO micro_tasks 
        (id, flow_id, title, description, type, effort, dependencies, estimated_duration, 
         prerequisites, deliverable, status, assigned_agent, result, started_at, completed_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, task.id, -1, nil)
            sqlite3_bind_text(statement, 2, flowId, -1, nil)
            sqlite3_bind_text(statement, 3, task.title, -1, nil)
            sqlite3_bind_text(statement, 4, task.description, -1, nil)
            sqlite3_bind_text(statement, 5, task.type.rawValue, -1, nil)
            sqlite3_bind_int(statement, 6, Int32(task.effort))
            sqlite3_bind_text(statement, 7, task.dependencies.joined(separator: ","), -1, nil)
            sqlite3_bind_text(statement, 8, task.estimatedDuration, -1, nil)
            sqlite3_bind_text(statement, 9, task.prerequisites.joined(separator: ","), -1, nil)
            sqlite3_bind_text(statement, 10, task.deliverable, -1, nil)
            sqlite3_bind_text(statement, 11, task.status.rawValue, -1, nil)
            
            if let agent = task.assignedAgent {
                sqlite3_bind_text(statement, 12, agent, -1, nil)
            }
            
            if let result = task.result {
                sqlite3_bind_text(statement, 13, result, -1, nil)
            }
            
            if let startedAt = task.startedAt {
                sqlite3_bind_text(statement, 14, ISO8601DateFormatter().string(from: startedAt), -1, nil)
            }
            
            if let completedAt = task.completedAt {
                sqlite3_bind_text(statement, 15, ISO8601DateFormatter().string(from: completedAt), -1, nil)
            }
            
            if sqlite3_step(statement) != SQLITE_DONE {
                throw DatabaseError.insertFailed
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    // MARK: - Agent Management
    
    func storeAgent(_ agent: SwarmAgent) async throws {
        // Capture values from MainActor context
        let agentId = await agent.id
        let flowId = await agent.flowId
        let specialization = await agent.specialization
        let status = await agent.status
        let currentTaskId = await agent.currentTask?.id
        let workload = await agent.workload
        let efficiency = await agent.efficiency
        let sql = """
        INSERT OR REPLACE INTO swarm_agents 
        (id, flow_id, specialization, status, current_task_id, workload, efficiency, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, agentId, -1, nil)
            sqlite3_bind_text(statement, 2, flowId, -1, nil)
            sqlite3_bind_text(statement, 3, specialization.rawValue, -1, nil)
            sqlite3_bind_text(statement, 4, String(describing: status), -1, nil)
            
            if let taskId = currentTaskId {
                sqlite3_bind_text(statement, 5, taskId, -1, nil)
            }
            
            sqlite3_bind_double(statement, 6, workload)
            sqlite3_bind_double(statement, 7, efficiency)
            sqlite3_bind_text(statement, 8, ISO8601DateFormatter().string(from: Date()), -1, nil)
            sqlite3_bind_text(statement, 9, ISO8601DateFormatter().string(from: Date()), -1, nil)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                throw DatabaseError.insertFailed
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    func removeAgent(_ agentId: String) async throws {
        let sql = "DELETE FROM swarm_agents WHERE id = ?;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, agentId, -1, nil)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                throw DatabaseError.deleteFailed
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    func clearAllAgents() async throws {
        let sql = "DELETE FROM swarm_agents;"
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            throw DatabaseError.deleteFailed
        }
    }
    
    // MARK: - Context Management
    
    func updateMacroGoal(_ goal: String) async throws {
        // Store the macro goal as shared context
        let contextId = "macro_goal_\(UUID().uuidString)"
        try await storeSharedContext(
            id: contextId,
            flowId: "global",
            type: "macro_goal",
            content: goal,
            createdBy: "system"
        )
    }
    
    func getSharedContext(flowId: String) async -> SharedContext {
        let sql = """
        SELECT content, context_type FROM shared_context 
        WHERE flow_id = ? OR flow_id = 'global' 
        ORDER BY created_at DESC;
        """
        
        var statement: OpaquePointer?
        var contextItems: [String] = []
        var macroGoal = "No macro goal set"
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, flowId, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let content = String(cString: sqlite3_column_text(statement, 0))
                let type = String(cString: sqlite3_column_text(statement, 1))
                
                if type == "macro_goal" {
                    macroGoal = content
                } else {
                    contextItems.append(content)
                }
            }
        }
        
        sqlite3_finalize(statement)
        
        // Get completed tasks for context
        let completedTasks = await getCompletedTasks(flowId: flowId)
        let completedTaskTitles = completedTasks.map { $0.title }
        
        return SharedContext(
            macroGoal: macroGoal,
            relevantInfo: contextItems.joined(separator: "\n\n"),
            completedTasks: completedTaskTitles,
            availableResources: [], // TODO: Implement resource tracking
            constraints: [] // TODO: Implement constraint tracking
        )
    }
    
    private func storeSharedContext(id: String, flowId: String, type: String, content: String, createdBy: String) async throws {
        let sql = """
        INSERT INTO shared_context 
        (id, flow_id, context_type, content, created_by_agent, created_at)
        VALUES (?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, id, -1, nil)
            sqlite3_bind_text(statement, 2, flowId, -1, nil)
            sqlite3_bind_text(statement, 3, type, -1, nil)
            sqlite3_bind_text(statement, 4, content, -1, nil)
            sqlite3_bind_text(statement, 5, createdBy, -1, nil)
            sqlite3_bind_text(statement, 6, ISO8601DateFormatter().string(from: Date()), -1, nil)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                throw DatabaseError.insertFailed
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    // MARK: - Task Management
    
    func updateTaskStatus(_ taskId: String, _ status: MicroTask.TaskStatus, agentId: String? = nil) async throws {
        let sql = """
        UPDATE micro_tasks 
        SET status = ?, assigned_agent = ?, updated_at = ?
        WHERE id = ?;
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, status.rawValue, -1, nil)
            
            if let agentId = agentId {
                sqlite3_bind_text(statement, 2, agentId, -1, nil)
            }
            
            sqlite3_bind_text(statement, 3, ISO8601DateFormatter().string(from: Date()), -1, nil)
            sqlite3_bind_text(statement, 4, taskId, -1, nil)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                throw DatabaseError.updateFailed
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    func storeTaskResult(_ taskId: String, result: String) async throws {
        // Update the task with the result
        let updateSQL = """
        UPDATE micro_tasks 
        SET result = ?, status = 'completed', completed_at = ?
        WHERE id = ?;
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, result, -1, nil)
            sqlite3_bind_text(statement, 2, ISO8601DateFormatter().string(from: Date()), -1, nil)
            sqlite3_bind_text(statement, 3, taskId, -1, nil)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                throw DatabaseError.updateFailed
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    func getCompletedTasks(flowId: String) async -> [MicroTask] {
        return await getTasks(flowId: flowId, status: .completed)
    }
    
    func getFailedTasks(flowId: String) async -> [MicroTask] {
        return await getTasks(flowId: flowId, status: .failed)
    }
    
    private func getTasks(flowId: String, status: MicroTask.TaskStatus) async -> [MicroTask] {
        let sql = """
        SELECT id, title, description, type, effort, dependencies, estimated_duration, 
               prerequisites, deliverable, status, assigned_agent, result, started_at, completed_at
        FROM micro_tasks 
        WHERE flow_id = ? AND status = ?;
        """
        
        var statement: OpaquePointer?
        var tasks: [MicroTask] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, flowId, -1, nil)
            sqlite3_bind_text(statement, 2, status.rawValue, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let title = String(cString: sqlite3_column_text(statement, 1))
                let description = String(cString: sqlite3_column_text(statement, 2))
                let typeString = String(cString: sqlite3_column_text(statement, 3))
                let effort = Int(sqlite3_column_int(statement, 4))
                let dependenciesString = String(cString: sqlite3_column_text(statement, 5))
                let estimatedDuration = String(cString: sqlite3_column_text(statement, 6))
                let prerequisitesString = String(cString: sqlite3_column_text(statement, 7))
                let deliverable = String(cString: sqlite3_column_text(statement, 8))
                
                guard let taskType = MicroTask.TaskType(rawValue: typeString) else { continue }
                
                let dependencies = dependenciesString.isEmpty ? [] : dependenciesString.components(separatedBy: ",")
                let prerequisites = prerequisitesString.isEmpty ? [] : prerequisitesString.components(separatedBy: ",")
                
                var task = MicroTask(
                    id: id,
                    title: title,
                    description: description,
                    type: taskType,
                    effort: effort,
                    dependencies: dependencies,
                    estimatedDuration: estimatedDuration,
                    prerequisites: prerequisites,
                    deliverable: deliverable
                )
                
                task.status = status
                
                // Get optional fields
                if let agentPtr = sqlite3_column_text(statement, 10) {
                    task.assignedAgent = String(cString: agentPtr)
                }
                
                if let resultPtr = sqlite3_column_text(statement, 11) {
                    task.result = String(cString: resultPtr)
                }
                
                tasks.append(task)
            }
        }
        
        sqlite3_finalize(statement)
        return tasks
    }
    
    // MARK: - Swarm Updates
    
    func storeSwarmUpdate(_ update: SwarmUpdate) async throws {
        let sql = """
        INSERT INTO swarm_updates 
        (id, flow_id, agent_id, update_type, content, timestamp)
        VALUES (?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, update.id, -1, nil)
            sqlite3_bind_text(statement, 2, "flow_id", -1, nil) // TODO: Add flow_id to SwarmUpdate
            sqlite3_bind_text(statement, 3, update.agentId, -1, nil)
            sqlite3_bind_text(statement, 4, String(describing: update.type), -1, nil)
            sqlite3_bind_text(statement, 5, update.content, -1, nil)
            sqlite3_bind_text(statement, 6, ISO8601DateFormatter().string(from: update.timestamp), -1, nil)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                throw DatabaseError.insertFailed
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    // MARK: - Analytics
    
    func getFlowProgress(_ flowId: String) async -> FlowProgress {
        let sql = """
        SELECT 
            COUNT(*) as total_tasks,
            SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_tasks,
            SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed_tasks
        FROM micro_tasks 
        WHERE flow_id = ?;
        """
        
        var statement: OpaquePointer?
        var totalTasks = 0
        var completedTasks = 0
        var failedTasks = 0
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, flowId, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                totalTasks = Int(sqlite3_column_int(statement, 0))
                completedTasks = Int(sqlite3_column_int(statement, 1))
                failedTasks = Int(sqlite3_column_int(statement, 2))
            }
        }
        
        sqlite3_finalize(statement)
        
        // Count active agents for this flow
        let activeAgents = await getActiveAgentCount(flowId: flowId)
        
        return FlowProgress(
            flowId: flowId,
            totalTasks: totalTasks,
            completedTasks: completedTasks,
            failedTasks: failedTasks,
            activeAgents: activeAgents,
            estimatedTimeRemaining: "Calculating..." // TODO: Implement time estimation
        )
    }
    
    private func getActiveAgentCount(flowId: String) async -> Int {
        let sql = "SELECT COUNT(*) FROM swarm_agents WHERE flow_id = ? AND status != 'terminated';"
        var statement: OpaquePointer?
        var count = 0
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, flowId, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
            }
        }
        
        sqlite3_finalize(statement)
        return count
    }
    
    deinit {
        sqlite3_close(db)
    }
}

// MARK: - Database Errors

enum DatabaseError: LocalizedError {
    case connectionFailed
    case insertFailed
    case updateFailed
    case deleteFailed
    case queryFailed
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to database"
        case .insertFailed:
            return "Failed to insert data"
        case .updateFailed:
            return "Failed to update data"
        case .deleteFailed:
            return "Failed to delete data"
        case .queryFailed:
            return "Failed to query data"
        }
    }
}