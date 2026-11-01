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
    /// Layout slots (D8), set in Settings › Modules and saved. Nil is an empty slot.
    var compactLeftID: String? { didSet { defaults.set(compactLeftID ?? "", forKey: Self.compactLeftKey) } }
    var compactRightID: String? { didSet { defaults.set(compactRightID ?? "", forKey: Self.compactRightKey) } }
    /// Every module id, in tab order.
    var tabOrder: [String] { didSet { defaults.set(tabOrder, forKey: Self.tabOrderKey) } }
    /// The open notch's tab (D31). Nil, or a module that is off, shows the first.
    /// shortcut: kept for the session only, upgrade if the last tab should survive a relaunch.
    var selectedTabID: String?

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
        let ids = modules.map(\.id)
        // Saved values are checked against today's modules: one may have been removed or added since.
        // Unsaved, Now Playing fills both sides: artwork left, bars right (D28). Saved as "", the slot is empty.
        // Only a module with a compact view, as Settings offers: any other id would leave its picker blank.
        func slot(_ key: String) -> String? {
            guard let saved = defaults.string(forKey: key) else { return ids.first }
            return modules.contains { $0.id == saved && $0.hasCompactView } ? saved : nil
        }
        compactLeftID = slot(Self.compactLeftKey)
        compactRightID = slot(Self.compactRightKey)
        let saved = (defaults.stringArray(forKey: Self.tabOrderKey) ?? []).filter(ids.contains)
        var seen = Set<String>()
        tabOrder = (saved + ids).filter { seen.insert($0).inserted }
    }

    /// Modules shown as tabs in the open notch, in `tabOrder`.
    var expandedModules: [any NotchModule] {
        tabOrder.compactMap { id in enabledIDs.contains(id) ? modules.first { $0.id == id } : nil }
    }

    /// The module the open notch shows: the selected tab, else the first.
    var selectedModule: (any NotchModule)? {
        let modules = expandedModules
        return modules.first { $0.id == selectedTabID } ?? modules.first
    }

    /// The module for a compact slot, if it is enabled and has something to show.
    func compactModule(for slot: CompactSlot) -> (any NotchModule)? {
        slotModule(for: slot).flatMap { $0.hasCompactContent ? $0 : nil }
    }

    /// The enabled module assigned to a compact slot, with or without content. The notch draws this while the
    /// wings are still showing, so the content fades out with the shape instead of vanishing first (D28).
    func slotModule(for slot: CompactSlot) -> (any NotchModule)? {
        let id = slot == .left ? compactLeftID : compactRightID
        return modules.first { $0.id == id && enabledIDs.contains($0.id) }
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

    /// Moves a module's tab one place earlier (-1) or later (+1); nothing at the ends.
    func moveTab(_ id: String, by offset: Int) {
        guard let index = tabOrder.firstIndex(of: id), tabOrder.indices.contains(index + offset) else { return }
        tabOrder.swapAt(index, index + offset)
    }

    private static func key(_ id: String) -> String { "module.\(id).enabled" }
    private static let compactLeftKey = "layout.compactLeft"
    private static let compactRightKey = "layout.compactRight"
    private static let tabOrderKey = "layout.tabOrder"
}
