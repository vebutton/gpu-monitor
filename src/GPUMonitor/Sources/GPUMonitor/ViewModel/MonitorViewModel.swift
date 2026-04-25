import Foundation
import SwiftUI

@Observable
@MainActor
final class MonitorViewModel {
    // MARK: - Published state

    var timeSeries = CircularBuffer<MetricSample>(capacity: 300)  // 5 min @ 1s
    var currentGPU: GPUState = .zero
    var currentFramework: FrameworkSnapshot?
    var selectedFramework: FrameworkType?
    var isMonitoring = false
    var gpuError: String?
    var frameworkError: String?

    // MARK: - Private

    private let gpuProvider = GPUMetricsProvider()
    private var monitoringTask: Task<Void, Never>?
    private var frameworkTask: Task<Void, Never>?
    private var activeAdapter: (any FrameworkAdapter)?

    // Available adapters
    private let adapters: [FrameworkType: any FrameworkAdapter] = [
        .whisper: WhisperAdapter(),
        .ollama: OllamaAdapter()
    ]

    // MARK: - GPU Monitoring

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        gpuError = nil

        monitoringTask = Task {
            do {
                try await gpuProvider.start()
            } catch {
                gpuError = "GPU metrics unavailable: \(error.localizedDescription)"
                isMonitoring = false
                return
            }

            let stream = gpuProvider.metricsStream(interval: .seconds(1))
            for await state in stream {
                guard !Task.isCancelled else { break }
                self.currentGPU = state
                let sample = MetricSample(
                    timestamp: state.timestamp,
                    gpuUtilization: state.utilizationPercent,
                    gpuFrequencyMHz: state.frequencyMHz,
                    frameworkMetrics: self.currentFramework
                )
                self.timeSeries.append(sample)
            }
        }
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        disconnectFramework()
        isMonitoring = false
    }

    // MARK: - Framework Management

    func selectFramework(_ framework: FrameworkType?) {
        guard framework != selectedFramework else { return }
        disconnectFramework()
        selectedFramework = framework

        guard let framework, let adapter = adapters[framework] else { return }
        connectFramework(adapter)
    }

    private func connectFramework(_ adapter: any FrameworkAdapter) {
        frameworkError = nil
        activeAdapter = adapter

        frameworkTask = Task {
            do {
                try await adapter.connect()
            } catch {
                frameworkError = "Connection failed: \(error.localizedDescription)"
                return
            }

            for await snapshot in adapter.metricsStream() {
                guard !Task.isCancelled else { break }
                self.currentFramework = snapshot
            }
        }
    }

    private func disconnectFramework() {
        frameworkTask?.cancel()
        frameworkTask = nil
        if let adapter = activeAdapter {
            Task { await adapter.disconnect() }
        }
        activeAdapter = nil
        currentFramework = nil
        frameworkError = nil
    }

    // MARK: - Convenience

    var samples: [MetricSample] {
        timeSeries.toArray()
    }

    var gpuUtilizationFormatted: String {
        String(format: "%.1f%%", currentGPU.utilizationPercent)
    }

    /// Real-time factor: audio seconds processed per wall-clock second.
    /// > 1.0 means faster than real-time. Computed from the latest framework snapshot.
    var realtimeFactor: Double? {
        guard let fw = currentFramework,
              fw.processingTimeSeconds > 0 else { return nil }
        return fw.audioPositionSeconds / fw.processingTimeSeconds
    }

    var realtimeFactorFormatted: String {
        guard let rtf = realtimeFactor else { return "—" }
        return String(format: "%.1fx", rtf)
    }

    /// Processing rate smoothed over a 10-second rolling window.
    /// Avoids the zero/spike pattern from Whisper's bursty segment output.
    var processingRates: [(timestamp: Date, rate: Double)] {
        let fwSamples = samples.compactMap { sample -> (Date, FrameworkSnapshot)? in
            guard let fw = sample.frameworkMetrics else { return nil }
            return (sample.timestamp, fw)
        }
        guard fwSamples.count >= 2 else { return [] }

        let windowSeconds: TimeInterval = 10
        var rates: [(timestamp: Date, rate: Double)] = []

        for i in 1..<fwSamples.count {
            let curr = fwSamples[i]
            // Look back up to windowSeconds to find the start of the window
            var windowStart = fwSamples[i - 1]
            for j in stride(from: i - 1, through: 0, by: -1) {
                if curr.0.timeIntervalSince(fwSamples[j].0) > windowSeconds { break }
                windowStart = fwSamples[j]
            }
            let dt = curr.0.timeIntervalSince(windowStart.0)
            guard dt > 0 else { continue }
            let dSegments = Double(curr.1.segmentCount - windowStart.1.segmentCount)
            let rate = max(0, dSegments / dt)
            rates.append((timestamp: curr.0, rate: rate))
        }
        return rates
    }
}
