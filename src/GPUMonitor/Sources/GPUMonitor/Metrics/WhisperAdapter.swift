import Foundation

/// Connects to the whisper_bridge.py script via Unix domain socket
/// to receive real-time transcription progress metrics.
actor WhisperAdapter: FrameworkAdapter {
    nonisolated let frameworkType: FrameworkType = .whisper
    private let socketPath: String
    private var client: SocketClient?
    private var connected = false

    init(socketPath: String = "/tmp/gpu-monitor-whisper.sock") {
        self.socketPath = socketPath
    }

    func connect() async throws {
        let client = SocketClient(socketPath: socketPath)
        try await client.connect()
        self.client = client
        self.connected = true
    }

    func disconnect() async {
        if let client {
            await client.disconnect()
        }
        self.client = nil
        self.connected = false
    }

    nonisolated func metricsStream() -> AsyncStream<FrameworkSnapshot> {
        AsyncStream { continuation in
            let task = Task {
                guard let client = await self.client else {
                    continuation.finish()
                    return
                }

                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase

                for await line in client.lines() {
                    guard !Task.isCancelled else { break }
                    guard let data = line.data(using: .utf8) else { continue }

                    do {
                        let msg = try decoder.decode(WhisperMessage.self, from: data)
                        let snapshot = FrameworkSnapshot(
                            segmentCount: msg.segmentCount,
                            audioPositionSeconds: msg.positionSeconds,
                            processingTimeSeconds: msg.processingTimeSeconds,
                            tokensProcessed: msg.tokensProcessed,
                            timestamp: .now
                        )
                        continuation.yield(snapshot)
                    } catch {
                        // Skip malformed messages
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// JSON message format from whisper_bridge.py
private struct WhisperMessage: Decodable {
    let type: String
    let segmentCount: Int
    let positionSeconds: Double
    let processingTimeSeconds: Double
    let tokensProcessed: Int?
}
