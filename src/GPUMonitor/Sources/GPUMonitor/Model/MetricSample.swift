import Foundation

/// A single timestamped data point combining GPU and optional framework metrics.
struct MetricSample: Sendable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let gpuUtilization: Double      // 0.0–100.0
    let gpuFrequencyMHz: Int
    let frameworkMetrics: FrameworkSnapshot?
}
