import AppKit
import os

/// Puts a window where the lock screen shows it (D55). No public API can (D3, RISKS.md §1.3), so the one
/// implementation uses private window-server calls; behind this protocol so a macOS that drops them turns the feature
/// off instead of crashing (CLAUDE.md).
@MainActor
protocol LockScreenSpace {
    /// Whether this macOS has everything the route needs. Checked before offering the setting.
    var isAvailable: Bool { get }
    /// Moves the window into the space shown above the lock screen. False if it couldn't.
    func attach(windowNumber: Int) -> Bool
}

/// `LockScreenSpace` through SkyLight, the private framework behind the window server (D55). Symbols are looked up at
/// run time with `dlsym`, never linked, so a missing one leaves `isAvailable` false. Clean-room: written from the
/// probe of 2026-11-13, not from Atoll or the SkyLightWindow package (CLAUDE.md, D55).
@MainActor
final class SkyLightLockScreenSpace: LockScreenSpace {
    /// The space level the probe drew at above the lock screen's shield [V: probe, 2026-11-13, macOS 27.2.1].
    static let level: Int32 = 400

    private typealias MainConnection = @convention(c) () -> Int32
    private typealias SpaceCreate = @convention(c) (Int32, Int32, UnsafeRawPointer?) -> UInt64
    private typealias SpaceSetLevel = @convention(c) (Int32, UInt64, Int32) -> Int32
    // Their return values were not meaningful in the probe, so they're treated as returning nothing.
    private typealias ShowSpaces = @convention(c) (Int32, CFArray) -> Void
    private typealias AddWindows = @convention(c) (Int32, UInt64, CFArray, Int32) -> Void

    private struct Calls {
        let main: MainConnection
        let create: SpaceCreate
        let setLevel: SpaceSetLevel
        let show: ShowSpaces
        let add: AddWindows
    }

    private let calls: Calls?
    /// Made on the first attach and kept for the app's life; one space holds DropNotch's lock-screen window.
    private var space: UInt64?

    init() {
        calls = Self.load()
        if calls == nil { Logger.lockScreen.error("Lock-screen space unavailable: SkyLight symbols missing") }
    }

    var isAvailable: Bool { calls != nil }

    func attach(windowNumber: Int) -> Bool {
        guard let calls, windowNumber > 0 else { return false }
        let connection = calls.main()
        if space == nil {
            let created = calls.create(connection, 1, nil)
            guard created != 0 else {
                Logger.lockScreen.error("Lock-screen space not created")
                return false
            }
            _ = calls.setLevel(connection, created, Self.level)
            calls.show(connection, [NSNumber(value: created)] as CFArray)
            space = created
        }
        guard let space else { return false }
        // 7: move the window into this space and out of every other one, as in the probe.
        calls.add(connection, space, [NSNumber(value: windowNumber)] as CFArray, 7)
        return true
    }

    private static func load() -> Calls? {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY) else {
            return nil
        }
        func symbol<T>(_ name: String, _ type: T.Type) -> T? {
            dlsym(handle, name).map { unsafeBitCast($0, to: type) }
        }
        guard let main = symbol("SLSMainConnectionID", MainConnection.self),
              let create = symbol("SLSSpaceCreate", SpaceCreate.self),
              let setLevel = symbol("SLSSpaceSetAbsoluteLevel", SpaceSetLevel.self),
              let show = symbol("SLSShowSpaces", ShowSpaces.self),
              let add = symbol("SLSSpaceAddWindowsAndRemoveFromSpaces", AddWindows.self) else { return nil }
        return Calls(main: main, create: create, setLevel: setLevel, show: show, add: add)
    }
}
