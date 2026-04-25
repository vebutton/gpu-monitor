import SwiftUI
import Charts

struct TokenChartView: View {
    @Environment(MonitorViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Processing Rate")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let fw = viewModel.selectedFramework {
                    Text(fw.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
                if let rtf = viewModel.realtimeFactor {
                    Text(String(format: "%.1fx realtime", rtf))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.orange)
                }
            }

            if viewModel.selectedFramework == nil {
                noFrameworkView
            } else if viewModel.frameworkError != nil {
                errorView
            } else if viewModel.currentFramework == nil {
                waitingView
            } else {
                chartView
            }
        }
    }

    private var chartView: some View {
        let rates = viewModel.processingRates
        return Chart(rates, id: \.timestamp) { point in
            AreaMark(
                x: .value("Time", point.timestamp),
                y: .value("seg/s", point.rate)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [.orange.opacity(0.3), .orange.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.monotone)

            LineMark(
                x: .value("Time", point.timestamp),
                y: .value("seg/s", point.rate)
            )
            .foregroundStyle(.orange)
            .interpolationMethod(.monotone)
            .lineStyle(StrokeStyle(lineWidth: 1.5))
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.1f", v))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.minute().second())
            }
        }
        .frame(height: 120)
    }

    private var noFrameworkView: some View {
        Text("Select a framework below to monitor")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(height: 120)
            .frame(maxWidth: .infinity)
    }

    private var waitingView: some View {
        VStack(spacing: 4) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Waiting for data...")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }

    private var errorView: some View {
        Text(viewModel.frameworkError ?? "Unknown error")
            .font(.caption)
            .foregroundStyle(.red)
            .frame(height: 120)
            .frame(maxWidth: .infinity)
    }
}
