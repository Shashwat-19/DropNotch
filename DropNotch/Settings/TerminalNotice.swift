import EventKit
import SwiftUI

/// The one-time confirmation before the Terminal tab is first turned on (D48; text by Shash): what commands there can
/// use. Settings › Terminal shows the same text all the time.
enum TerminalNotice {
    static let shownKey = "terminal.permissionsNoticeShown"

    /// Turning Terminal on from Settings asks first, once.
    static func needsConfirmation(_ defaults: UserDefaults = .standard) -> Bool { !defaults.bool(forKey: shownKey) }

    /// The Calendars line follows the real setting; folders and other apps can't be checked without a prompt.
    static var calendarsAllowed: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }

    static let title: LocalizedStringKey = "Terminal uses DropNotch's permissions"

    static func message(calendarsAllowed: Bool) -> Text {
        let calendars = calendarsAllowed ? Text("Calendars: full access, which can add, change and delete events")
                                         : Text("Calendars: not allowed")
        return Text("""
            Commands you run in the Terminal tab, and your shell's setup files, can use everything DropNotch is allowed to use, without asking again:
            • \(calendars)
            • Desktop, Documents and Downloads, where you allowed them for the tray
            • Controlling Music, Spotify and any other app you allowed

            Anything you allow from the terminal later is added to this. Jobs you start with nohup or disown keep running after you end the session or quit DropNotch. You can review all of these in System Settings › Privacy & Security.

            To stop this, turn Terminal off in Settings › Modules and end any jobs you left running.
            """)
    }
}

extension View {
    /// The confirmation: Cancel leaves Terminal off; Turn On Terminal turns it on and never asks again.
    func terminalNotice(isPresented: Binding<Bool>, turnOn: @escaping () -> Void) -> some View {
        alert(Text(TerminalNotice.title), isPresented: isPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Turn On Terminal") {
                UserDefaults.standard.set(true, forKey: TerminalNotice.shownKey)
                turnOn()
            }
        } message: {
            TerminalNotice.message(calendarsAllowed: TerminalNotice.calendarsAllowed)
        }
    }
}
