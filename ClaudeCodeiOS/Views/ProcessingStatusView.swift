import SwiftUI

struct ProcessingStatusView: View {
    let isProcessing: Bool
    let statusMessage: String
    let tokenUsage: TokenUsage?
    
    @State private var animationPhase = 0.0
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Processing indicator
                if isProcessing {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.green)
                                .frame(width: 4, height: 4)
                                .scaleEffect(animationPhase == Double(index) ? 1.3 : 0.8)
                                .animation(
                                    Animation.easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                    value: animationPhase
                                )
                        }
                    }
                    .onAppear {
                        animationPhase = 2.0
                    }
                }
                
                // Status message
                Text(statusMessage)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                // Token usage
                if let usage = tokenUsage {
                    HStack(spacing: 8) {
                        TokenUsageIndicator(
                            label: "in",
                            value: usage.inputTokens,
                            color: .blue
                        )
                        
                        TokenUsageIndicator(
                            label: "out",
                            value: usage.outputTokens,
                            color: .green
                        )
                        
                        TokenUsageIndicator(
                            label: "total",
                            value: usage.totalTokens,
                            color: .orange
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
        }
    }
}

struct TokenUsageIndicator: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
            
            Text(formatTokenCount(value))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(color)
                .fontWeight(.medium)
        }
    }
    
    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}


#Preview {
    VStack {
        Spacer()
        
        ProcessingStatusView(
            isProcessing: true,
            statusMessage: "Reading file: /Users/dev/project/main.swift",
            tokenUsage: TokenUsage(inputTokens: 2453, outputTokens: 1827)
        )
    }
}