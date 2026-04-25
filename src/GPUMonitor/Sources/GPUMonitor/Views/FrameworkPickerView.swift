import SwiftUI

struct FrameworkPickerView: View {
    @Environment(MonitorViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Framework")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                pickerButton(label: "None", isSelected: viewModel.selectedFramework == nil) {
                    viewModel.selectFramework(nil)
                }
                ForEach(FrameworkType.allCases) { framework in
                    pickerButton(
                        label: framework.rawValue,
                        isSelected: viewModel.selectedFramework == framework
                    ) {
                        viewModel.selectFramework(framework)
                    }
                }
            }
        }
    }

    private func pickerButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.caption)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .primary : .secondary)
    }
}
