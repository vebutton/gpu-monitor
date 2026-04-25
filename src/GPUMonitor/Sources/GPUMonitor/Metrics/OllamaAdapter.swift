import Foundation

/// Polls the Ollama REST API at localhost:11434 to track token usage
/// from generation/chat requests.
actor OllamaAdapter: FrameworkAdapter {
    nonisolated let frameworkType: FrameworkType = .ollama
    private let baseURL: URL
    private var connected = false
    private var totalTokens = 0
    private var requestCount = 0

    init(baseURL: URL = URL(string: "http://localhost:11434")!) {
        self.baseURL = baseURL
    }

    func connect() async throws {
        // Verify Ollama is running by hitting the version endpoint
        let url = baseURL.appendingPathComponent("api/version")
        let (_, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw OllamaError.notRunning
        }
        connected = true
    }

    func disconnect() async {
        connected = false
        totalTokens = 0
        requestCount = 0
    }

    nonisolated func metricsStream() -> AsyncStream<FrameworkSnapshot> {
        AsyncStream { continuation in
            let task = Task {
                var lastTotalTokens = 0
                var lastRequestCount = 0

                while !Task.isCancelled {
                    guard await self.connected else { break }

                    // Poll the running models endpoint
                    if let snapshot = await self.pollMetrics(
                        lastTokens: lastTotalTokens,
                        lastRequests: lastRequestCount
                    ) {
                        lastTotalTokens = snapshot.tokensProcessed ?? 0
                        lastRequestCount = Int(snapshot.segmentCount)
                        continuation.yield(snapshot)
                    }

                    try? await Task.sleep(for: .seconds(2))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func pollMetrics(lastTokens: Int, lastRequests: Int) -> FrameworkSnapshot? {
        // Ollama's /api/ps endpoint shows currently running models
        let url = baseURL.appendingPathComponent("api/ps")
        guard let data = try? Data(contentsOf: url),
              let response = try? JSONDecoder().decode(OllamaPsResponse.self, from: data) else {
            return nil
        }

        // Count active models and their context sizes
        let activeModels = response.models ?? []
        let totalSize = activeModels.reduce(0) { $0 + ($1.sizeVram ?? 0) }

        return FrameworkSnapshot(
            segmentCount: activeModels.count,
            audioPositionSeconds: 0,
            processingTimeSeconds: 0,
            tokensProcessed: Int(totalSize / 1_000_000),  // MB of VRAM
            timestamp: .now
        )
    }
}

enum OllamaError: Error, LocalizedError {
    case notRunning

    var errorDescription: String? {
        "Ollama not running at localhost:11434"
    }
}

// Ollama /api/ps response
private struct OllamaPsResponse: Decodable {
    let models: [OllamaModel]?
}

private struct OllamaModel: Decodable {
    let name: String?
    let model: String?
    let size: Int64?
    let sizeVram: Int64?

    enum CodingKeys: String, CodingKey {
        case name, model, size
        case sizeVram = "size_vram"
    }
}
