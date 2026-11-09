import Foundation
import IOKit.ps
import os

/// `BatterySource` from IOKit's public power-source API (D43): one read at the start, then one per power-source
/// change, delivered by a run-loop source on the main run loop. No timer.
@MainActor
final class PowerSourceBatterySource: BatterySource {
    /// Whether this Mac has an internal battery now. A desktop Mac doesn't register the Battery card (D43).
    static var hasInternalBattery: Bool { read() != nil }

    var updates: AsyncStream<BatteryStatus?> {
        AsyncStream { continuation in
            // The callback is a C function pointer, which can't capture anything, so the work it does travels as
            // its context pointer: a retained box, released once the source is gone.
            let box = Unmanaged.passRetained(Callback { continuation.yield(Self.read()) })
            guard let source = IOPSNotificationCreateRunLoopSource({ context in
                guard let context else { return }
                Unmanaged<Callback>.fromOpaque(context).takeUnretainedValue().run()
            }, box.toOpaque())?.takeRetainedValue() else {
                Logger.battery.error("Power source notifications unavailable")
                box.release()
                continuation.yield(Self.read())
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
    private static func read() -> BatteryStatus? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        let descriptions = list.compactMap {
            IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any]
        }
        return BatteryStatus(descriptions: descriptions)
    }

    private final class Callback {
        let run: () -> Void
        init(_ run: @escaping () -> Void) { self.run = run }
    }
}
