import Observation

/// Which of the lock-screen player's two states shows (D58): compact, a small player above the password prompt, or
/// expanded, the artwork across the whole screen. Every lock starts compact.
@MainActor
@Observable
final class LockScreenPresentation {
    private(set) var isExpanded = false
    /// The window resizes when this changes; set by `LockScreenPlayerWindow`.
    @ObservationIgnored var onChange: ((Bool) -> Void)?

    func expand() { set(true) }
    func collapse() { set(false) }

    private func set(_ expanded: Bool) {
        guard expanded != isExpanded else { return }
        isExpanded = expanded
        onChange?(expanded)
    }

    /// Back to compact without resizing anything: the window is hidden or about to be.
    func reset() { isExpanded = false }
}
