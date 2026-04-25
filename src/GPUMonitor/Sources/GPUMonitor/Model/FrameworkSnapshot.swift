import Foundation

/// Metric payload from a framework adapter (Whisper, Ollama, etc.)
struct FrameworkSnapshot: Sendable {
    let segmentCount: Int
    let audioPositionSeconds: Double
    let processingTimeSeconds: Double
    let tokensProcessed: Int?       // Not all frameworks expose this
    let timestamp: Date
}

/// Supported local model frameworks.
enum FrameworkType: String, CaseIterable, Identifiable, Sendable {
    case whisper = "Whisper"
    case ollama = "Ollama"

    var id: String { rawValue }
}
