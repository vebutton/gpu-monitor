import SwiftUI

@main
struct GPUMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var viewModel = MonitorViewModel()

    var body: some Scene {
        Window("GPU Monitor", id: "gpu-monitor") {
            MonitorRootView()
                .environment(viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
    }
}
