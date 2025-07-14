import Foundation

struct TokenUsage {
    let inputTokens: Int
    let outputTokens: Int
    
    var totalTokens: Int {
        inputTokens + outputTokens
    }
}