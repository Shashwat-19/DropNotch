import Foundation
import Observation
import os

/// Owns the modules, their enabled flags and the fixed layout slots (ARCHITECTURE.md §3, D8, D21).
/// `@Observable` so the notch view redraws when a flag changes.
@MainActor
@Observable
final class ModuleRegistry {
    let modules: [any NotchModule]
    private(set) var enabledIDs: Set<String>
    /// Layout slots (D8). Defaults only.
    /// shortcut: not persisted or editable, upgrade when Phase 3 Settings adds the pickers.
    var compactLeftID: String?
    var compactRightID: String?
    var tabOrder: [String]

    @ObservationIgnored private let defaults: UserDefaults
    /// Modules are started only while the registry runs, so `setEnabled` before `start()`
    /// (or after `stop()`) changes the flag but runs nothing.
    @ObservationIgnored private var isRunning = false

    init(modules: [any NotchModule], defaults: UserDefaults = .standard) {
        precondition(Set(modules.map(\.id)).count == modules.count, "Module ids must be unique")
        self.modules = modules
        self.defaults = defaults
        // A module with no saved flag is on.
        enabledIDs = Set(modules.map(\.id).filter { defaults.object(forKey: Self.key($0)) as? Bool ?? true })
        // Now Playing fills both sides: artwork left, bars right (D28).
        compactLeftID = modules.first?.id
        compactRightID = modules.first?.id
        tabOrder = modules.map(\.id)
    }

    /// Modules shown as tabs in the open notch, in `tabOrder`.
    var expandedModules: [any NotchModule] {
        tabOrder.compactMap { id in enabledIDs.contains(id) ? modules.first { $0.id == id } : nil }
    }

    /// The module for a compact slot, if it is enabled and has something to show.
    func compactModule(for slot: CompactSlot) -> (any NotchModule)? {
        let id = slot == .left ? compactLeftID : compactRightID
        return modules.first { $0.id == id && enabledIDs.contains($0.id) && $0.hasCompactContent }
    }

    /// Whether either compact slot has something to show, which widens the closed notch (D28).
    var hasCompactContent: Bool { compactModule(for: .left) != nil || compactModule(for: .right) != nil }

    /// Starts every enabled module.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        modules.filter { enabledIDs.contains($0.id) }.forEach { $0.start() }
    }

    /// Stops every enabled module (app quit).
    func stop() {
        guard isRunning else { return }
        isRunning = false
        modules.filter { enabledIDs.contains($0.id) }.forEach { $0.stop() }
    }

    func setEnabled(_ id: String, _ enabled: Bool) {
        guard let module = modules.first(where: { $0.id == id }),
              enabledIDs.contains(id) != enabled else { return }
        if enabled { enabledIDs.insert(id) } else { enabledIDs.remove(id) }
        defaults.set(enabled, forKey: Self.key(id))
        Logger.notch.debug("Module \(id, privacy: .public) enabled: \(enabled)")
        guard isRunning else { return }
        if enabled { module.start() } else { module.stop() }
    }

    private static func key(_ id: String) -> String { "module.\(id).enabled" }
}
