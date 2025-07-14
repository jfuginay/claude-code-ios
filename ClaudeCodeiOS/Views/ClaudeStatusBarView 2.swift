import SwiftUI

struct ClaudeStatusBarView: View {
    let isProcessing: Bool
    let processingStatus: String
    let tokenUsage: TokenUsage?
    
    @State private var timeElapsed: Int = 0
    @State private var timer: Timer?
    @State private var funnyMessageIndex: Int = 0
    
    private let funnyMessages = [
        "Scheming...",
        "Reading your mind...",
        "Brewing some code magic...", 
        "Contemplating the universe of your codebase...",
        "Channeling the spirits of clean code...",
        "Summoning the TypeScript gods...",
        "Parsing the secrets of your project...",
        "Consulting the documentation oracle...",
        "Weaving threads of logic...",
        "Debugging the matrix..."
    ]
    
    var body: some View {
        HStack {
            // Terminal-style traffic lights
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(.yellow)
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(.green)
                    .frame(width: 12, height: 12)
            }
            .padding(.leading, 8)
            
            Spacer()
            
            // Status text with Claude CLI styling
            HStack(spacing: 8) {
                if isProcessing {
                    Text("*")
                        .foregroundColor(.orange)
                        .font(.system(.body, design: .monospaced, weight: .bold))
                    
                    Text(currentFunnyMessage)
                        .foregroundColor(.white)
                        .font(.system(.body, design: .monospaced))
                    
                    Text("(\(timeElapsed)s")
                        .foregroundColor(.gray)
                        .font(.system(.body, design: .monospaced))
                    
                    if let usage = tokenUsage {
                        Text("• \(formatTokens(usage.totalTokens)) tokens")
                            .foregroundColor(.gray)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    Text("• esc to interrupt)")
                        .foregroundColor(.gray)
                        .font(.system(.body, design: .monospaced))
                } else {
                    Text("claude@code:~$")
                        .foregroundColor(.green)
                        .font(.system(.body, design: .monospaced, weight: .bold))
                    
                    Text("Ready")
                        .foregroundColor(.gray)
                        .font(.system(.body, design: .monospaced))
                    
                    if let usage = tokenUsage {
                        Text("• \(formatTokens(usage.totalTokens)) tokens")
                            .foregroundColor(.gray)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .background(Color.black)
        .onChange(of: isProcessing) { processing in
            if processing {
                startTimer()
                startFunnyMessageRotation()
            } else {
                stopTimer()
            }
        }
    }
    
    private var currentFunnyMessage: String {
        funnyMessages[funnyMessageIndex % funnyMessages.count]
    }
    
    private func formatTokens(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        } else {
            return "\(count)"
        }
    }
    
    private func startTimer() {
        timeElapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            timeElapsed += 1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        timeElapsed = 0
    }
    
    private func startFunnyMessageRotation() {
        funnyMessageIndex = Int.random(in: 0..<funnyMessages.count)
        
        // Rotate funny messages every 3 seconds while processing
        _Concurrency.Task {
            while isProcessing {
                try? await _Concurrency.Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                if isProcessing {
                    funnyMessageIndex = (funnyMessageIndex + 1) % funnyMessages.count
                }
            }
        }
    }
}

#Preview {
    VStack {
        ClaudeStatusBarView(
            isProcessing: true,
            processingStatus: "Thinking...",
            tokenUsage: TokenUsage(inputTokens: 1500, outputTokens: 850)
        )
        
        ClaudeStatusBarView(
            isProcessing: false,
            processingStatus: "Ready",
            tokenUsage: TokenUsage(inputTokens: 1500, outputTokens: 850)
        )
    }
}