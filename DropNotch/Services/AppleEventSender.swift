import AppKit
import CoreServices

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
    /// Wait for the reply, and fail with errAEEventWouldRequireUserConsent instead of prompting, so only
    /// `permission(ask: true)` after a click can show the prompt (D23). The flag has no Swift case.
    private static let sendOptions = NSAppleEventDescriptor.SendOptions(
        rawValue: NSAppleEventDescriptor.SendOptions.waitForReply.rawValue | UInt(kAEDoNotPromptForUserConsent))

    func permission(for player: MediaPlayer, pid: pid_t, ask: Bool) async -> AppleEventOutcome {
        await Self.run {
            // With `ask: true` this blocks until the user answers the prompt: never on the main thread.
            dispatchPrecondition(condition: .notOnQueue(.main))
            guard Self.belongs(pid, to: player) else { return .notRunning }
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
        return await Self.run {
            guard Self.belongs(pid, to: player) else { return .notRunning }
            let appleEvent = Self.event(event.eventClass, event.eventID, pid: pid)
            if case .seek(let seconds) = command {
                // "set player position to <seconds>"; both players accept it [V: media probe] (D26).
                appleEvent.setParam(Self.property("pPos", of: NSAppleEventDescriptor.null()), forKeyword: AEKeyword(keyDirectObject))
                appleEvent.setParam(NSAppleEventDescriptor(double: seconds), forKeyword: AEKeyword(keyAEData))
            }
            return Self.send(appleEvent).outcome
        }
    }

    func readCurrent(of player: MediaPlayer, pid: pid_t) async -> NowPlayingInfo? {
        await Self.run {
            guard Self.belongs(pid, to: player) else { return nil }
            let app = NSAppleEventDescriptor.null()
            guard let reply = Self.get(Self.property("pPlS", of: app), pid: pid),
                  let state = Self.state(reply) else { return nil }
            // Between tracks Music has no current track: these reads fail (-1728) and stay nil, never zero (D26).
            let track = Self.property("pTrk", of: app)
            let title = Self.get(Self.property("pnam", of: track), pid: pid)?.stringValue
            let artist = Self.get(Self.property("pArt", of: track), pid: pid)?.stringValue
            let position = Self.number(Self.get(Self.property("pPos", of: app), pid: pid))
            let duration = Self.number(Self.get(Self.property("pDur", of: track), pid: pid))
            // Music's persistent ID is the hex its notification's PersistentID becomes; Spotify's id
            // ("spotify:ad:…" for an ad) feeds the same ad rule as notifications (D24, D26).
            let trackID = Self.get(Self.property(player == .music ? "pPIS" : "ID  ", of: track), pid: pid)?
                .stringValue.map { player == .music ? $0.uppercased() : $0 }
            var info = PlayerNotificationParser.track(
                player, state, name: title, artist: artist, trackID: trackID,
                // Spotify's duration is milliseconds, though its dictionary says seconds [V: media probe].
                duration: PlayerNotificationParser.seconds(duration, unit: player == .spotify ? 1000 : 1),
                position: PlayerNotificationParser.seconds(position, unit: 1))
            if player == .spotify, info.trackID != nil {
                info.artworkURL = Self.get(Self.property("aUrl", of: track), pid: pid)?.stringValue.flatMap(URL.init(string:))
            }
            return info
        }
    }

    func readArtwork(of player: MediaPlayer, pid: pid_t) async -> Data? {
        guard player == .music else { return nil }
        return await Self.run {
            guard Self.belongs(pid, to: player) else { return nil }
            let artwork = Self.element("cArt", index: 1, of: Self.property("pTrk", of: NSAppleEventDescriptor.null()))
            // `raw data`: the file's own bytes (JPEG on the probe), about 0.5 MB [V: media probe].
            guard let data = Self.get(Self.property("pRaw", of: artwork), pid: pid)?.data,
                  !data.isEmpty, data.count <= Self.maxArtworkBytes else { return nil }
            return data
        }
    }

    /// Music artwork above this is dropped before decoding (D26).
    static let maxArtworkBytes = 10 * 1024 * 1024

    /// A reply's number, or nil when the reply isn't numeric (Music answers `pPos` with a non-number
    /// between tracks [V: media probe]). Internal for tests.
    static func number(_ descriptor: NSAppleEventDescriptor?) -> Double? {
        guard let descriptor,
              ["doub", "sing", "long", "shor", "comp", "magn"].map(FourCharCode.init(code:)).contains(descriptor.descriptorType)
        else { return nil }
        return descriptor.doubleValue
    }

    /// Runs `work` on the Apple Event queue, never the main thread. Internal so a test can check that.
    static func run<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: work()) }
        }
    }

    /// Whether `pid` is still the player's. The Automation prompt can stay up for minutes; if the player
    /// quits meanwhile, its pid could be reused by another process.
    private static func belongs(_ pid: pid_t, to player: MediaPlayer) -> Bool {
        NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == player.bundleID
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
            let reply = try event.sendEvent(options: sendOptions, timeout: timeout)
            // An error from the player's handler comes back inside the reply, not as a thrown error [I] (D22).
            if let code = reply.paramDescriptor(forKeyword: AEKeyword(keyErrorNumber))?.int32Value, code != noErr {
                return (AppleEventOutcome(status: code), nil)
            }
            return (.ok, reply.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)))
        } catch {
            // `truncatingIfNeeded`: a plain conversion would crash on a code outside Int32.
            return (AppleEventOutcome(status: OSStatus(truncatingIfNeeded: (error as NSError).code)), nil)
        }
    }

    /// Reads one property with a "get" event; nil on any error.
    private static func get(_ specifier: NSAppleEventDescriptor, pid: pid_t) -> NSAppleEventDescriptor? {
        let event = event(AEEventClass(kAECoreSuite), AEEventID(kAEGetData), pid: pid)
        event.setParam(specifier, forKeyword: AEKeyword(keyDirectObject))
        return send(event).result
    }

    /// The object specifier for "<class> <index> of <container>", what `artwork 1 of current track`
    /// compiles to. Internal for tests.
    static func element(_ className: String, index: Int32, of container: NSAppleEventDescriptor) -> NSAppleEventDescriptor {
        let specifier = NSAppleEventDescriptor.record()
        specifier.setDescriptor(NSAppleEventDescriptor(typeCode: FourCharCode(code: className)), forKeyword: AEKeyword(keyAEDesiredClass))
        specifier.setDescriptor(NSAppleEventDescriptor(enumCode: DescType(formAbsolutePosition)), forKeyword: AEKeyword(keyAEKeyForm))
        specifier.setDescriptor(NSAppleEventDescriptor(int32: index), forKeyword: AEKeyword(keyAEKeyData))
        specifier.setDescriptor(container, forKeyword: AEKeyword(keyAEContainer))
        return specifier.coerce(toDescriptorType: DescType(typeObjectSpecifier)) ?? specifier
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
