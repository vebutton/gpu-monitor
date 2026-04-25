import Foundation

/// Snapshot of GPU state at a point in time.
struct GPUState: Sendable {
    let utilizationPercent: Double  // 0.0–100.0
    let frequencyMHz: Int           // Estimated from active P-state
    let powerMilliwatts: Double     // Derived from Energy Model delta
    let timestamp: Date

    static let zero = GPUState(utilizationPercent: 0, frequencyMHz: 0, powerMilliwatts: 0, timestamp: .now)
}
