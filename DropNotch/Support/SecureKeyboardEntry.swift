import Carbon

/// Secure keyboard entry while the terminal has the keys (D48, design review L1): other processes can't read
/// keystrokes, such as a password typed for sudo or ssh. macOS counts each Enable against a Disable, so this keeps
/// its own state and never calls either twice. The system turns it off if DropNotch crashes or quits.
@MainActor
final class SecureKeyboardEntry {
    private(set) var isOn = false

    func set(_ on: Bool) {
        guard on != isOn else { return }
        isOn = on
        if on { EnableSecureEventInput() } else { DisableSecureEventInput() }
    }
}
