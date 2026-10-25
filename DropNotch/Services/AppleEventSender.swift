import CoreServices
import Foundation

/// The real `AppleEventSending`: raw Apple Events built with `NSAppleEventDescriptor` (D22).
///
/// Swift/AppKit notes:
/// - Events go to the pid of the running app, never its bundle ID, so a player that just quit gets an
///   error instead of being relaunched.
/// - Everything runs on one serial queue: clicks stay in order, and the Automation prompt (which blocks
///   its caller until the user answers) or a hung player never blocks the main thread.
struct AppleEventSender: AppleEventSending {
    private static let queue = DispatchQueue(label: "com.shashwat.DropNotch.apple-events", qos: .userInitiated)
    /// A local reply takes milliseconds; give up on a hung player instead of queueing clicks behind it.
    private static let timeout: TimeInterval = 2

    func permission(for player: MediaPlayer, pid: pid_t, ask: Bool) async -> AppleEventOutcome {
        await Self.run {
            let target = NSAppleEventDescriptor(processIdentifier: pid)
            // Consent is per target app, so one of its events stands for all of them [I] (D23).
            let event = player.event(for: .playPause)
            let status = withExtendedLifetime(target) {
                AEDeterminePermissionToAutomateTarget(target.aeDesc, event.eventClass, event.eventID, ask)
            }
            return AppleEventOutcome(status: status)
        }
    }

    func send(_ command: PlaybackCommand, to player: MediaPlayer, pid: pid_t) async -> AppleEventOutcome {
        let event = player.event(for: command)
        return await Self.run { Self.send(Self.event(event.eventClass, event.eventID, pid: pid)).outcome }
    }

    func readCurrent(of player: MediaPlayer, pid: pid_t) async -> NowPlayingInfo? {
        await Self.run {
            let app = NSAppleEventDescriptor.null()
            guard let reply = Self.get(Self.property("pPlS", of: app), pid: pid),
                  let state = Self.state(reply) else { return nil }
            // A stopped player may have no current track; those reads then fail and stay nil.
            let track = Self.property("pTrk", of: app)
            let title = Self.get(Self.property("pnam", of: track), pid: pid)?.stringValue
            let artist = Self.get(Self.property("pArt", of: track), pid: pid)?.stringValue
            return NowPlayingInfo(player: player, state: state,
                                  title: PlayerNotificationParser.text(title),
                                  artist: PlayerNotificationParser.text(artist))
        }
    }

    private static func run<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: work()) }
        }
    }

    private static func event(_ eventClass: AEEventClass, _ eventID: AEEventID, pid: pid_t) -> NSAppleEventDescriptor {
        NSAppleEventDescriptor(eventClass: eventClass, eventID: eventID,
                               targetDescriptor: NSAppleEventDescriptor(processIdentifier: pid),
                               returnID: AEReturnID(kAutoGenerateReturnID),
                               transactionID: AETransactionID(kAnyTransactionID))
    }

    /// Sends one event and waits for the reply. On success, also returns the reply's result.
    private static func send(_ event: NSAppleEventDescriptor) -> (outcome: AppleEventOutcome, result: NSAppleEventDescriptor?) {
        do {
            let reply = try event.sendEvent(options: .waitForReply, timeout: timeout)
            // An error from the player's handler comes back inside the reply, not as a thrown error [I] (D22).
            if let code = reply.paramDescriptor(forKeyword: AEKeyword(keyErrorNumber))?.int32Value, code != noErr {
                return (AppleEventOutcome(status: code), nil)
            }
            return (.ok, reply.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)))
        } catch {
            return (AppleEventOutcome(status: OSStatus((error as NSError).code)), nil)
        }
    }

    /// Reads one property with a "get" event; nil on any error.
    private static func get(_ specifier: NSAppleEventDescriptor, pid: pid_t) -> NSAppleEventDescriptor? {
        let event = event(AEEventClass(kAECoreSuite), AEEventID(kAEGetData), pid: pid)
        event.setParam(specifier, forKeyword: AEKeyword(keyDirectObject))
        return send(event).result
    }

    /// The object specifier for "<property> of <container>", which is what AppleScript's
    /// `name of current track` compiles to. A null container means the application itself.
    private static func property(_ code: String, of container: NSAppleEventDescriptor) -> NSAppleEventDescriptor {
        let specifier = NSAppleEventDescriptor.record()
        specifier.setDescriptor(NSAppleEventDescriptor(typeCode: DescType(cProperty)), forKeyword: AEKeyword(keyAEDesiredClass))
        specifier.setDescriptor(NSAppleEventDescriptor(enumCode: DescType(formPropertyID)), forKeyword: AEKeyword(keyAEKeyForm))
        specifier.setDescriptor(NSAppleEventDescriptor(typeCode: FourCharCode(code: code)), forKeyword: AEKeyword(keyAEKeyData))
        specifier.setDescriptor(container, forKeyword: AEKeyword(keyAEContainer))
        return specifier.coerce(toDescriptorType: DescType(typeObjectSpecifier)) ?? specifier
    }

    /// `pPlS` values from the scripting dictionaries (docs/research/now-playing-probe-2026-10-25.md).
    private static func state(_ descriptor: NSAppleEventDescriptor) -> NowPlayingInfo.State? {
        switch descriptor.enumCodeValue {
        case FourCharCode(code: "kPSP"): .playing
        case FourCharCode(code: "kPSp"): .paused
        case FourCharCode(code: "kPSS"): .stopped
        default: nil
        }
    }
}
