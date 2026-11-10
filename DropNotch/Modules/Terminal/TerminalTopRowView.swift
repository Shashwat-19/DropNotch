import SwiftUI

/// Left of the camera housing while Terminal is selected (D48, mock-up Layout A): the shell's name and End Session.
/// The size is in the button's tooltip; the strip is only 132 pt at 536 pt.
struct TerminalTopRowView: View {
    let module: TerminalModule

    var body: some View {
        HStack(spacing: NotchStyle.spacing) {
            switch module.state {
            case .notStarted:
                EmptyView()
            case .running:
                Text(verbatim: module.shellName)
                Button(action: module.endSession) {
                    Text("End Session")
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                // Tab belongs to the shell.
                .focusable(false)
                .help(module.columns > 0 ? Text("End Session (\(module.columns) × \(module.rows))") : Text("End Session"))
            case .ended:
                Text("\(module.shellName) · ended")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}
