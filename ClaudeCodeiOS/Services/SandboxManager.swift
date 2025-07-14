import Foundation
import Combine

// MARK: - Sandbox Manager
// Provides isolated execution environments for swarm agents

@MainActor
class SandboxManager: ObservableObject {
    @Published var activeSandboxes: [Sandbox] = []
    private let fileManager = FileManager.default
    private let sandboxRoot: URL
    
    init() {
        // Create sandbox root directory
        let tempDir = fileManager.temporaryDirectory
        self.sandboxRoot = tempDir.appendingPathComponent("claude_sandboxes")
        
        try? fileManager.createDirectory(
            at: sandboxRoot,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    // MARK: - Sandbox Creation
    
    func createSandbox(for agentType: MicroTask.TaskType, restrictions: SandboxRestrictions) async throws -> Sandbox {
        let sandboxId = "sandbox_\(agentType.rawValue)_\(UUID().uuidString.prefix(8))"
        let sandboxPath = sandboxRoot.appendingPathComponent(sandboxId)
        
        // Create sandbox directory structure
        try fileManager.createDirectory(
            at: sandboxPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Create subdirectories
        let subdirs = ["workspace", "logs", "temp", "output"]
        for subdir in subdirs {
            try fileManager.createDirectory(
                at: sandboxPath.appendingPathComponent(subdir),
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        
        // Create sandbox configuration
        let sandbox = Sandbox(
            id: sandboxId,
            path: sandboxPath,
            restrictions: restrictions,
            createdAt: Date(),
            agentType: agentType
        )
        
        // Write restrictions manifest
        try await writeRestrictionsManifest(for: sandbox)
        
        activeSandboxes.append(sandbox)
        return sandbox
    }
    
    // MARK: - Sandbox Cleanup
    
    func cleanupSandbox(_ sandbox: Sandbox) async throws {
        // Remove from active list
        activeSandboxes.removeAll { $0.id == sandbox.id }
        
        // Archive sandbox contents for audit
        try await archiveSandbox(sandbox)
        
        // Clean up filesystem
        try fileManager.removeItem(at: sandbox.path)
    }
    
    func cleanupAllSandboxes() async throws {
        for sandbox in activeSandboxes {
            try await cleanupSandbox(sandbox)
        }
    }
    
    // MARK: - Sandbox Operations
    
    func validateOperation(_ operation: Operation, in sandbox: Sandbox) throws {
        guard sandbox.restrictions.allowedOperations.contains(operation) else {
            throw SandboxError.operationDenied(operation, sandbox.id)
        }
        
        if sandbox.restrictions.deniedOperations.contains(operation) {
            throw SandboxError.operationExplicitlyDenied(operation, sandbox.id)
        }
    }
    
    func executeCommand(_ command: String, in sandbox: Sandbox) async throws -> String {
        // Validate command safety
        try validateCommand(command, restrictions: sandbox.restrictions)
        
        // Execute in sandbox context
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = sandbox.path.appendingPathComponent("workspace")
        
        // Set up environment
        var environment = ProcessInfo.processInfo.environment
        environment["SANDBOX_ID"] = sandbox.id
        environment["SANDBOX_PATH"] = sandbox.path.path
        environment["SANDBOX_MODE"] = "restricted"
        process.environment = environment
        
        // Capture output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Execute with timeout
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 30_000_000_000) // 30 second timeout
            process.terminate()
        }
        
        try process.run()
        process.waitUntilExit()
        timeoutTask.cancel()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        
        if process.terminationStatus != 0 {
            throw SandboxError.commandFailed(command, error)
        }
        
        // Log command execution
        try await logExecution(command: command, output: output, in: sandbox)
        
        return output
    }
    
    // MARK: - Safety Validation
    
    private func validateCommand(_ command: String, restrictions: SandboxRestrictions) throws {
        // Check against denied commands
        let deniedPatterns = [
            "rm -rf /",
            "sudo",
            "chmod 777",
            "curl.*\\|.*bash",
            "wget.*\\|.*sh",
            "> /dev/",
            "dd if=",
            "mkfs",
            "fdisk"
        ]
        
        for pattern in deniedPatterns {
            if command.range(of: pattern, options: .regularExpression) != nil {
                throw SandboxError.dangerousCommand(command)
            }
        }
        
        // Check allowed commands if specified
        if let allowedCommands = restrictions.allowedCommands {
            let commandBase = command.components(separatedBy: " ").first ?? ""
            if !allowedCommands.contains(where: { command.hasPrefix($0) }) {
                throw SandboxError.commandNotAllowed(command)
            }
        }
    }
    
    // MARK: - File System Operations
    
    func readFile(at path: String, in sandbox: Sandbox) async throws -> String {
        try validateOperation(.read, in: sandbox)
        
        let fullPath = resolvePath(path, in: sandbox)
        guard isPathWithinSandbox(fullPath, sandbox: sandbox) else {
            throw SandboxError.pathOutsideSandbox(path)
        }
        
        return try String(contentsOf: fullPath, encoding: .utf8)
    }
    
    func writeFile(_ content: String, to path: String, in sandbox: Sandbox) async throws {
        try validateOperation(.write, in: sandbox)
        
        let fullPath = resolvePath(path, in: sandbox)
        guard isPathWithinSandbox(fullPath, sandbox: sandbox) else {
            throw SandboxError.pathOutsideSandbox(path)
        }
        
        // Ensure directory exists
        let directory = fullPath.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        try content.write(to: fullPath, atomically: true, encoding: .utf8)
        
        // Log file operation
        try await logFileOperation(operation: .write, path: path, in: sandbox)
    }
    
    // MARK: - Helper Methods
    
    private func writeRestrictionsManifest(for sandbox: Sandbox) async throws {
        let manifest = """
        Sandbox ID: \(sandbox.id)
        Agent Type: \(sandbox.agentType.rawValue)
        Created: \(ISO8601DateFormatter().string(from: sandbox.createdAt))
        
        Restrictions:
        - Allowed Operations: \(sandbox.restrictions.allowedOperations.map { $0.rawValue }.joined(separator: ", "))
        - Denied Operations: \(sandbox.restrictions.deniedOperations.map { $0.rawValue }.joined(separator: ", "))
        - Working Directory: \(sandbox.restrictions.workingDirectory)
        - Network Access: \(sandbox.restrictions.networkAccess ? "Yes" : "No")
        - File System Access: \(sandbox.restrictions.fileSystemAccess.rawValue)
        
        Memory Limit: \(sandbox.memoryLimit / 1024 / 1024) MB
        CPU Limit: \(sandbox.cpuLimit)%
        """
        
        let manifestPath = sandbox.path.appendingPathComponent("SANDBOX_MANIFEST.txt")
        try manifest.write(to: manifestPath, atomically: true, encoding: .utf8)
    }
    
    private func archiveSandbox(_ sandbox: Sandbox) async throws {
        let archivePath = sandboxRoot.appendingPathComponent("archives")
        try fileManager.createDirectory(
            at: archivePath,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        let archiveName = "\(sandbox.id)_\(Date().timeIntervalSince1970).tar.gz"
        let archiveURL = archivePath.appendingPathComponent(archiveName)
        
        // Create compressed archive
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        task.arguments = ["-czf", archiveURL.path, "-C", sandbox.path.deletingLastPathComponent().path, sandbox.path.lastPathComponent]
        try task.run()
        task.waitUntilExit()
    }
    
    private func resolvePath(_ path: String, in sandbox: Sandbox) -> URL {
        if path.hasPrefix("/") {
            // Absolute path - make it relative to sandbox
            let relativePath = String(path.dropFirst())
            return sandbox.path.appendingPathComponent("workspace").appendingPathComponent(relativePath)
        } else {
            // Relative path
            return sandbox.path.appendingPathComponent("workspace").appendingPathComponent(path)
        }
    }
    
    private func isPathWithinSandbox(_ url: URL, sandbox: Sandbox) -> Bool {
        let sandboxPath = sandbox.path.standardized.path
        let targetPath = url.standardized.path
        return targetPath.hasPrefix(sandboxPath)
    }
    
    private func logExecution(command: String, output: String, in sandbox: Sandbox) async throws {
        let logEntry = """
        [\(ISO8601DateFormatter().string(from: Date()))]
        Command: \(command)
        Output Length: \(output.count) characters
        Status: Success
        ---
        """
        
        let logPath = sandbox.path.appendingPathComponent("logs/execution.log")
        if let data = logEntry.data(using: .utf8) {
            if fileManager.fileExists(atPath: logPath.path) {
                let handle = try FileHandle(forWritingTo: logPath)
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                try data.write(to: logPath)
            }
        }
    }
    
    private func logFileOperation(operation: Operation, path: String, in sandbox: Sandbox) async throws {
        let logEntry = """
        [\(ISO8601DateFormatter().string(from: Date()))]
        Operation: \(operation.rawValue)
        Path: \(path)
        ---
        """
        
        let logPath = sandbox.path.appendingPathComponent("logs/files.log")
        if let data = logEntry.data(using: .utf8) {
            if fileManager.fileExists(atPath: logPath.path) {
                let handle = try FileHandle(forWritingTo: logPath)
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                try data.write(to: logPath)
            }
        }
    }
}

// MARK: - Sandbox Model

struct Sandbox {
    let id: String
    let path: URL
    let restrictions: SandboxRestrictions
    let createdAt: Date
    let agentType: MicroTask.TaskType
    
    // Resource limits
    let memoryLimit: Int = 512 * 1024 * 1024  // 512MB
    let cpuLimit: Int = 50  // 50% CPU
    let diskQuota: Int = 1024 * 1024 * 1024  // 1GB
}

struct SandboxRestrictions {
    let allowedOperations: Set<Operation>
    let deniedOperations: Set<Operation>
    let workingDirectory: String
    let networkAccess: Bool
    let fileSystemAccess: FileSystemAccessLevel
    let allowedCommands: [String]?
    
    enum FileSystemAccessLevel: String {
        case none = "none"
        case readonly = "readonly"
        case sandboxed = "sandboxed"
        case full = "full"
    }
}

enum Operation: String {
    case read = "read"
    case write = "write"
    case execute = "execute"
    case delete = "delete"
    case analyze = "analyze"
}

// MARK: - Sandboxed Agent

@MainActor
class SandboxedAgent: ObservableObject {
    let id: String
    let type: MicroTask.TaskType
    let sandbox: Sandbox
    let clusterId: String
    let personality: String
    
    @Published var status: AgentStatus = .idle
    @Published var resourceUsage = ResourceUsage()
    @Published var completedTasks: [TaskResult] = []
    
    private let claudeService: ClaudeService
    private let sandboxManager = SandboxManager()
    
    init(id: String, type: MicroTask.TaskType, sandbox: Sandbox, clusterId: String, claudeService: ClaudeService, personality: String) {
        self.id = id
        self.type = type
        self.sandbox = sandbox
        self.clusterId = clusterId
        self.claudeService = claudeService
        self.personality = personality
    }
    
    func initialize() async throws {
        status = .initializing
        
        // Write agent configuration
        let config = """
        Agent ID: \(id)
        Type: \(type.rawValue)
        Cluster: \(clusterId)
        Initialized: \(ISO8601DateFormatter().string(from: Date()))
        """
        
        try await sandboxManager.writeFile(
            config,
            to: "agent_config.txt",
            in: sandbox
        )
        
        status = .ready
    }
    
    func execute(task: MicroTask) async throws -> TaskResult {
        status = .working
        let startTime = Date()
        
        // Build sandboxed prompt
        let prompt = buildSandboxedPrompt(for: task)
        
        do {
            // Execute task with Claude
            let response = try await claudeService.sendMessage(
                prompt,
                in: nil,
                activeFiles: Set<WorkspaceFile>(),
                useContext: false
            )
            
            // Process response in sandbox
            let processedResult = try await processInSandbox(
                response: response.content,
                task: task
            )
            
            let result = TaskResult(
                taskId: task.id,
                agentId: id,
                content: processedResult,
                status: .success,
                duration: Date().timeIntervalSince(startTime)
            )
            
            completedTasks.append(result)
            status = .ready
            
            return result
            
        } catch {
            let result = TaskResult(
                taskId: task.id,
                agentId: id,
                content: "Error: \(error.localizedDescription)",
                status: .failed,
                duration: Date().timeIntervalSince(startTime)
            )
            
            completedTasks.append(result)
            status = .failed
            
            return result
        }
    }
    
    private func buildSandboxedPrompt(for task: MicroTask) -> String {
        return """
        \(personality)
        
        SANDBOX CONTEXT:
        - You are operating in a restricted sandbox environment
        - Sandbox ID: \(sandbox.id)
        - Allowed operations: \(sandbox.restrictions.allowedOperations.map { $0.rawValue }.joined(separator: ", "))
        - Working directory: \(sandbox.restrictions.workingDirectory)
        
        TASK:
        \(task.title)
        
        Description: \(task.description)
        Deliverable: \(task.deliverable)
        
        IMPORTANT:
        - Only perform operations within your allowed permissions
        - All file operations must be within the sandbox
        - Return structured output that can be verified
        - Include any commands or code in clearly marked blocks
        """
    }
    
    private func processInSandbox(response: String, task: MicroTask) async throws -> String {
        // Extract and execute any commands in sandbox
        let commands = extractCommands(from: response)
        var results: [String] = []
        
        for command in commands {
            do {
                let output = try await sandboxManager.executeCommand(command, in: sandbox)
                results.append("Command: \(command)\nOutput: \(output)")
            } catch {
                results.append("Command: \(command)\nError: \(error.localizedDescription)")
            }
        }
        
        // Save any generated files
        let files = extractFiles(from: response)
        for (filename, content) in files {
            try await sandboxManager.writeFile(content, to: filename, in: sandbox)
        }
        
        // Update resource usage
        await updateResourceUsage()
        
        // Return processed result
        if results.isEmpty {
            return response
        } else {
            return """
            \(response)
            
            Execution Results:
            \(results.joined(separator: "\n\n"))
            """
        }
    }
    
    private func extractCommands(from text: String) -> [String] {
        // Extract bash commands from code blocks
        var commands: [String] = []
        let pattern = "```(?:bash|sh|shell)\\n(.*?)\\n```"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators)
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    commands.append(String(text[range]))
                }
            }
        } catch {
            print("Regex error: \(error)")
        }
        
        return commands
    }
    
    private func extractFiles(from text: String) -> [(filename: String, content: String)] {
        // Extract file content from code blocks
        var files: [(String, String)] = []
        
        // Pattern for file blocks like ```filename:example.py
        let pattern = "```(?:file:)?([\\w.-]+)\\n(.*?)\\n```"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators)
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            
            for match in matches {
                if let filenameRange = Range(match.range(at: 1), in: text),
                   let contentRange = Range(match.range(at: 2), in: text) {
                    let filename = String(text[filenameRange])
                    let content = String(text[contentRange])
                    
                    // Skip bash commands
                    if !["bash", "sh", "shell"].contains(filename) {
                        files.append((filename, content))
                    }
                }
            }
        } catch {
            print("Regex error: \(error)")
        }
        
        return files
    }
    
    private func updateResourceUsage() async {
        // Simulate resource usage tracking
        resourceUsage.memoryUsage = Int.random(in: 100_000_000...300_000_000)  // 100-300MB
        resourceUsage.cpuUsage = Double.random(in: 10...40)  // 10-40%
        resourceUsage.diskUsage = Int.random(in: 10_000_000...100_000_000)  // 10-100MB
    }
}

// MARK: - Supporting Types

struct ResourceUsage {
    var memoryUsage: Int = 0  // bytes
    var cpuUsage: Double = 0  // percentage
    var diskUsage: Int = 0  // bytes
}

struct TaskResult {
    let taskId: String
    let agentId: String
    var content: String
    let status: ResultStatus
    let duration: TimeInterval
    
    enum ResultStatus {
        case success
        case failed
        case partial
    }
}

// MARK: - Sandboxed File System Manager

class SandboxedFileSystemManager: FileSystemManager {
    let sandbox: Sandbox
    
    init(sandbox: Sandbox) {
        self.sandbox = sandbox
        super.init()
    }
    
    override func contentsOfDirectory(at url: URL) throws -> [URL] {
        // Restrict to sandbox
        guard url.path.hasPrefix(sandbox.path.path) else {
            throw SandboxError.pathOutsideSandbox(url.path)
        }
        return try super.contentsOfDirectory(at: url)
    }
    
    override func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {
        // Restrict to sandbox
        guard url.path.hasPrefix(sandbox.path.path) else {
            throw SandboxError.pathOutsideSandbox(url.path)
        }
        try super.createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories)
    }
}

// MARK: - Sandbox Errors

enum SandboxError: LocalizedError {
    case operationDenied(Operation, String)
    case operationExplicitlyDenied(Operation, String)
    case pathOutsideSandbox(String)
    case dangerousCommand(String)
    case commandNotAllowed(String)
    case commandFailed(String, String)
    case resourceLimitExceeded(String)
    
    var errorDescription: String? {
        switch self {
        case .operationDenied(let op, let sandbox):
            return "Operation '\(op.rawValue)' is not allowed in sandbox \(sandbox)"
        case .operationExplicitlyDenied(let op, let sandbox):
            return "Operation '\(op.rawValue)' is explicitly denied in sandbox \(sandbox)"
        case .pathOutsideSandbox(let path):
            return "Path '\(path)' is outside the sandbox"
        case .dangerousCommand(let cmd):
            return "Command '\(cmd)' is considered dangerous and blocked"
        case .commandNotAllowed(let cmd):
            return "Command '\(cmd)' is not in the allowed commands list"
        case .commandFailed(let cmd, let error):
            return "Command '\(cmd)' failed: \(error)"
        case .resourceLimitExceeded(let msg):
            return "Resource limit exceeded: \(msg)"
        }
    }
}

// MARK: - Swarm Errors Extension

extension SwarmError {
    static func operationNotAllowed(_ message: String) -> SwarmError {
        return SwarmError.taskExecutionFailed(message)
    }
    
    static func resourceLimitExceeded(_ message: String) -> SwarmError {
        return SwarmError.taskExecutionFailed(message)
    }
    
    static func dangerousOperation(_ message: String) -> SwarmError {
        return SwarmError.taskExecutionFailed(message)
    }
}