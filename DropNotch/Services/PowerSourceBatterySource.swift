import Foundation
import IOKit.ps
import os

/// `BatterySource` from IOKit's public power-source API (D43): one read at the start, then one per power-source
/// change, delivered by a run-loop source on the main run loop. No timer.
@MainActor
final class PowerSourceBatterySource: BatterySource {
    /// Whether this Mac lists an internal battery. A desktop Mac doesn't register the Battery card (D43). Only the
    /// type is checked, so a laptop whose first reading is incomplete still gets the card and its empty state.
    static var hasInternalBattery: Bool {
        descriptions().contains { $0[kIOPSTypeKey] as? String == kIOPSInternalBatteryType }
    }

    /// Each access subscribes: it adds a run-loop source until the stream is cancelled or dropped, so iterate it once.
    /// Only the newest status matters, so older ones aren't buffered.
    var updates: AsyncStream<BatteryStatus?> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            // The callback is a C function pointer, which can't capture anything, so the work it does travels as
            // its context pointer: a retained box, released once the source is gone.
            let box = Unmanaged.passRetained(Callback { continuation.yield(Self.read()) })
            guard let source = IOPSNotificationCreateRunLoopSource({ context in
                guard let context else { return }
                // The source is on the main run loop, so this is the main thread; checked rather than assumed.
                MainActor.assumeIsolated { Unmanaged<Callback>.fromOpaque(context).takeUnretainedValue().run() }
            }, box.toOpaque())?.takeRetainedValue() else {
                Logger.battery.error("Power source notifications unavailable")
                box.release()
                // No updates would follow, so show no reading rather than one that silently goes stale.
                continuation.yield(nil)
                continuation.finish()
                return
            }
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            continuation.yield(Self.read())
            // Termination can arrive on any thread; removing and releasing on the main queue orders it after any
            // callback already running there, so the box is never released under one.
            continuation.onTermination = { _ in
                DispatchQueue.main.async {
                    CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
                    box.release()
                }
            }
        }
    }

    /// shortcut: reads on the main thread; IOKit answers from powerd in well under a millisecond [I: not measured].
    /// Move off the main thread if performance-optimizer measures it.
    private static func read() -> BatteryStatus? { BatteryStatus(descriptions: descriptions()) }

    private static func descriptions() -> [[String: Any]] {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return [] }
        return list.compactMap { IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any] }
    }

    @MainActor
    private final class Callback {
        let run: () -> Void
        init(_ run: @escaping () -> Void) { self.run = run }
    }
}
