import SwiftUI

extension View {
    /// A button that Tab and the arrow keys reach, and Space or Return presses (D30). `.edit`, not `.activate`:
    /// activate-focus on macOS only works with the system's keyboard navigation setting on.
    func keyboardControl<ID: Hashable>(_ id: ID, focus: FocusState<ID?>.Binding, action: @escaping () -> Void) -> some View {
        focusable(interactions: .edit)
            .focused(focus, equals: id)
            // Key-down only: holding Space mustn't press the control again on every repeat.
            .onKeyPress(keys: [.space, .return], phases: .down) { _ in
                action()
                return .handled
            }
    }
}
