import Foundation

/// Whether the screen is locked (D55). `@MainActor`: its only consumer is `LockScreenPlayer`.
@MainActor
protocol LockStateSource {
    /// True on lock, false on unlock; not polled. Iterate it once.
    var changes: AsyncStream<Bool> { get }
}

/// `LockStateSource` from the system's lock and unlock distributed notifications (D55). Undocumented names, but long
/// standing; both arrived on macOS 27.2.1 [V: probe, 2026-11-13]. Unlike Atoll (research §8) there is no poll while
/// locked: a missed unlock leaves the player up until the next lock or unlock, which the device checks look for.
@MainActor
final class DistributedLockStateSource: LockStateSource {
    static let locked = Notification.Name("com.apple.screenIsLocked")
    static let unlocked = Notification.Name("com.apple.screenIsUnlocked")

    private let center: DistributedNotificationCenter

    /// `center` is for tests.
    init(center: DistributedNotificationCenter = .default()) {
        self.center = center
    }

    var changes: AsyncStream<Bool> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let observers = [(Self.locked, true), (Self.unlocked, false)].map { name, isLocked in
                center.addObserver(forName: name, object: nil, queue: .main) { _ in continuation.yield(isLocked) }
            }
            continuation.onTermination = { [center] _ in
                observers.forEach { center.removeObserver($0) }
            }
        }
    }
}
