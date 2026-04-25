import Foundation

/// Protocol for local model framework metric adapters.
/// Each framework (Whisper, Ollama, etc.) implements this to provide metrics.
protocol FrameworkAdapter: Sendable {
    var frameworkType: FrameworkType { get }
    func connect() async throws
    func disconnect() async
    func metricsStream() -> AsyncStream<FrameworkSnapshot>
}
