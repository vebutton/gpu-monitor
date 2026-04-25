import SwiftUI

struct CurrentStatsView: View {
    @Environment(MonitorViewModel.self) private var viewModel

    var body: some View {
        HStack(spacing: 12) {
            statCard(
                title: "GPU",
                value: viewModel.gpuUtilizationFormatted,
                color: gpuColor
            )
            statCard(
                title: "Freq",
                value: freqFormatted,
                color: .blue
            )
            statCard(
                title: "Power",
                value: powerFormatted,
                color: .purple
            )
            if let fw = viewModel.currentFramework {
                statCard(
                    title: "Segments",
                    value: "\(fw.segmentCount)",
                    color: .orange
                )
            }
        }
    }

    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.monospacedDigit().bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private var gpuColor: Color {
        let util = viewModel.currentGPU.utilizationPercent
        if util > 85 { return .red }
        if util > 60 { return .orange }
        return .green
    }

    private var freqFormatted: String {
        let mhz = viewModel.currentGPU.frequencyMHz
        if mhz == 0 { return "Idle" }
        if mhz >= 1000 { return String(format: "%.1f GHz", Double(mhz) / 1000) }
        return "\(mhz) MHz"
    }

    private var powerFormatted: String {
        let mw = viewModel.currentGPU.powerMilliwatts
        if mw == 0 { return "—" }
        if mw >= 1000 { return String(format: "%.1f W", mw / 1000) }
        return String(format: "%.0f mW", mw)
    }
}
