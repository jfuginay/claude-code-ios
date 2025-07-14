import SwiftUI

struct ClaudeStatusBarView: View {
    let isProcessing: Bool
    let processingStatus: String
    let tokenUsage: TokenUsage?
    
    @State private var timeElapsed: Int = 0
    @State private var timer: Timer?
    
    var body: some View {
        HStack(spacing: 8) {
            // Status text with authentic Claude CLI styling
            if isProcessing {
                // Processing state - matches Claude CLI behavior
                Text("*")
                    .foregroundColor(.orange)
                    .font(.system(.body, design: .monospaced, weight: .bold))
                
                Text(processingStatus.isEmpty ? "Processing..." : processingStatus)
                    .foregroundColor(.primary)
                    .font(.system(.body, design: .monospaced))
                
                Text("(\(timeElapsed)s)")
                    .foregroundColor(.secondary)
                    .font(.system(.body, design: .monospaced))
                
                if let usage = tokenUsage {
                    Text("•")
                        .foregroundColor(.secondary)
                        .font(.system(.body, design: .monospaced))
                    
                    Text("\(formatTokens(usage.inputTokens)) → \(formatTokens(usage.outputTokens))")
                        .foregroundColor(.secondary)
                        .font(.system(.body, design: .monospaced))
                }
                
                Text("• esc to interrupt)")
                    .foregroundColor(.secondary)
                    .font(.system(.body, design: .monospaced))
            } else {
                // Ready state
                Text("claude@code:~$")
                    .foregroundColor(.green)
                    .font(.system(.body, design: .monospaced, weight: .bold))
                
                Text("Ready")
                    .foregroundColor(.secondary)
                    .font(.system(.body, design: .monospaced))
                
                if let usage = tokenUsage {
                    Text("• \(formatTokens(usage.totalTokens)) tokens")
                        .foregroundColor(.secondary)
                        .font(.system(.body, design: .monospaced))
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1),
            alignment: .top
        )
        .onAppear {
            if isProcessing {
                startTimer()
            }
        }
        .onChange(of: isProcessing, perform: { processing in
            if processing {
                startTimer()
            } else {
                stopTimer()
            }
        })
        .onDisappear {
            stopTimer()
        }
    }
    
    private func formatTokens(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        } else {
            return "\(count)"
        }
    }
    
    private func startTimer() {
        stopTimer() // Stop any existing timer
        timeElapsed = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.timeElapsed += 1
            }
        }
        
        // Ensure timer runs on main run loop
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        timeElapsed = 0
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