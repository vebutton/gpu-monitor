import SwiftUI
import Charts

struct GPUChartView: View {
    @Environment(MonitorViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("GPU Utilization")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Chart(viewModel.samples) { sample in
                AreaMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("GPU %", sample.gpuUtilization)
                )
                .foregroundStyle(gpuGradient)
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("GPU %", sample.gpuUtilization)
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text("\(v)%")
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
            .frame(height: 160)

            if let error = viewModel.gpuError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var gpuGradient: LinearGradient {
        LinearGradient(
            colors: [.blue.opacity(0.3), .blue.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
