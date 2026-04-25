import Foundation
import CIOReport

/// Reads GPU utilization, power, and frequency from IOReport on Apple Silicon.
/// Uses GPUPH (P-state residency) from "GPU Stats" and GPU Energy from "Energy Model".
actor GPUMetricsProvider {
    private var subscription: IOReportSubscriptionRef?
    private var channels: CFMutableDictionary?
    private var previousSample: CFDictionary?
    private var gpuphIndex: Int?
    private var energyIndex: Int?
    private var previousEnergy: Int64 = 0
    private var previousEnergyTime: Date = .now

    // M4 GPU approximate P-state frequencies (MHz), 16 states: OFF + P1–P15
    // These are estimates — Apple doesn't publish exact values
    private static let pStateFreqMHz = [
        0,    // OFF
        396, 528, 660, 792, 924, 1056, 1122, 1188,
        1254, 1320, 1386, 1452, 1500, 1540, 1578
    ]

    func start() throws {
        // Subscribe to both GPU Stats (utilization) and Energy Model (power)
        guard let gpuChannels = IOReportCopyChannelsInGroup("GPU Stats" as CFString, nil, 0, 0, 0) else {
            throw GPUMetricsError.channelDiscoveryFailed
        }
        let mutable = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, gpuChannels)!

        if let energyChannels = IOReportCopyChannelsInGroup("Energy Model" as CFString, nil, 0, 0, 0) {
            IOReportMergeChannels(mutable, energyChannels, nil)
        }

        self.channels = mutable

        var subbedChannels: Unmanaged<CFMutableDictionary>?
        let sub = IOReportCreateSubscription(nil, mutable, &subbedChannels, 0, nil)
        guard let sub else { throw GPUMetricsError.subscriptionFailed }
        self.subscription = sub
        self.previousSample = IOReportCreateSamples(sub, mutable, nil)
        self.previousEnergyTime = .now

        // Find channel indices
        if let sample = self.previousSample,
           let arr = (sample as NSDictionary)["IOReportChannels"] as? [NSDictionary] {
            for (idx, channel) in arr.enumerated() {
                let cfChannel = channel as CFDictionary
                let name = IOReportChannelGetChannelName(cfChannel) as String? ?? ""
                if name == "GPUPH" && IOReportChannelGetFormat(cfChannel) == 2 {
                    self.gpuphIndex = idx
                }
                if name == "GPU Energy" && IOReportChannelGetFormat(cfChannel) == 1 {
                    self.energyIndex = idx
                    self.previousEnergy = IOReportSimpleGetIntegerValue(cfChannel, 0)
                }
            }
        }

        guard gpuphIndex != nil else { throw GPUMetricsError.channelNotFound }
    }

    func sample() -> GPUState {
        guard let subscription, let channels else { return .zero }
        guard let currentSample = IOReportCreateSamples(subscription, channels, nil) else { return .zero }
        defer { self.previousSample = currentSample }
        guard let prev = previousSample,
              let delta = IOReportCreateSamplesDelta(prev, currentSample, nil) else { return .zero }

        let (utilization, freqMHz) = extractUtilizationAndFreq(from: delta)
        let powerMW = extractPower(from: currentSample)

        return GPUState(
            utilizationPercent: utilization,
            frequencyMHz: freqMHz,
            powerMilliwatts: powerMW,
            timestamp: .now
        )
    }

    private func extractUtilizationAndFreq(from delta: CFDictionary) -> (Double, Int) {
        guard let gpuphIndex,
              let arr = (delta as NSDictionary)["IOReportChannels"] as? [NSDictionary],
              gpuphIndex < arr.count else { return (0, 0) }

        let cfChannel = arr[gpuphIndex] as CFDictionary
        let stateCount = IOReportStateGetCount(cfChannel)
        guard stateCount > 0 else { return (0, 0) }

        var totalResidency: Double = 0
        var offResidency: Double = 0
        var peakActiveState = 0
        var peakResidency: Double = 0

        for s in 0..<stateCount {
            let residency = Double(IOReportStateGetResidency(cfChannel, Int32(s)))
            totalResidency += residency
            if s == 0 {
                offResidency += residency
            } else if residency > peakResidency {
                peakResidency = residency
                peakActiveState = Int(s)
            }
        }

        let activeResidency = totalResidency - offResidency
        let utilization = totalResidency > 0 ? (activeResidency / totalResidency * 100.0) : 0

        // Map peak active P-state to frequency
        let freqIdx = min(peakActiveState, Self.pStateFreqMHz.count - 1)
        let freqMHz = Self.pStateFreqMHz[freqIdx]

        return (min(100, max(0, utilization)), freqMHz)
    }

    private func extractPower(from currentSample: CFDictionary) -> Double {
        guard let energyIndex,
              let arr = (currentSample as NSDictionary)["IOReportChannels"] as? [NSDictionary],
              energyIndex < arr.count else { return 0 }

        let cfChannel = arr[energyIndex] as CFDictionary
        let currentEnergy = IOReportSimpleGetIntegerValue(cfChannel, 0)
        let now = Date.now
        let dt = now.timeIntervalSince(previousEnergyTime)

        guard dt > 0, previousEnergy > 0 else {
            previousEnergy = currentEnergy
            previousEnergyTime = now
            return 0
        }

        // Energy is in nanojoules; convert delta to milliwatts
        let deltaEnergy = Double(currentEnergy - previousEnergy)
        let powerMW = (deltaEnergy / dt) / 1_000_000.0  // nJ/s → mW

        previousEnergy = currentEnergy
        previousEnergyTime = now

        return max(0, powerMW)
    }

    nonisolated func metricsStream(interval: Duration = .seconds(1)) -> AsyncStream<GPUState> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    let state = await self.sample()
                    continuation.yield(state)
                    try? await Task.sleep(for: interval)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

enum GPUMetricsError: Error, LocalizedError {
    case channelDiscoveryFailed
    case subscriptionFailed
    case channelNotFound

    var errorDescription: String? {
        switch self {
        case .channelDiscoveryFailed: "Could not discover GPU Stats channels"
        case .subscriptionFailed: "Could not create IOReport subscription"
        case .channelNotFound: "GPUPH performance state channel not found"
        }
    }
}
