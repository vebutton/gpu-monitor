import SwiftUI

struct MonitorRootView: View {
    @Environment(MonitorViewModel.self) private var viewModel
    @State private var alwaysOnTop = true

    var body: some View {
        VStack(spacing: 12) {
            header
            GPUChartView()
            TokenChartView()
            CurrentStatsView()
            FrameworkPickerView()
        }
        .padding()
        .frame(width: 420, height: 520)
        .onAppear { viewModel.startMonitoring() }
        .onDisappear { viewModel.stopMonitoring() }
    }

    private var header: some View {
        HStack {
            Image(systemName: "cpu")
                .font(.title2)
            Text("GPU Monitor")
                .font(.headline)
            Spacer()

            Button {
                alwaysOnTop.toggle()
                AppDelegate.shared?.setAlwaysOnTop(alwaysOnTop)
            } label: {
                Image(systemName: alwaysOnTop ? "pin.fill" : "pin")
                    .font(.caption)
                    .foregroundStyle(alwaysOnTop ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .help(alwaysOnTop ? "Unpin from top" : "Pin on top")

            Circle()
                .fill(viewModel.isMonitoring ? .green : .gray)
                .frame(width: 8, height: 8)
        }
    }
}
