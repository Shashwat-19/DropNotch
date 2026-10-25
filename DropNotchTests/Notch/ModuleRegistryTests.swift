import SwiftUI
import XCTest
@testable import DropNotch

@MainActor
final class ModuleRegistryTests: XCTestCase {
    private final class FakeModule: NotchModule {
        let id: String
        let title: LocalizedStringResource = "Fake"
        var hasCompactContent = true
        private(set) var starts = 0, stops = 0
        init(_ id: String) { self.id = id }
        func compactView(slot: CompactSlot) -> AnyView { AnyView(EmptyView()) }
        func expandedView() -> AnyView { AnyView(EmptyView()) }
        func settingsView() -> AnyView { AnyView(EmptyView()) }
        func start() { starts += 1 }
        func stop() { stops += 1 }
    }

    private var suites: [String] = []

    /// A throwaway defaults domain, so tests never touch the real preferences.
    private func makeDefaults() -> UserDefaults {
        let name = "ModuleRegistryTests.\(UUID())"
        suites.append(name)
        return UserDefaults(suiteName: name)!
    }

    override func tearDown() {
        suites.forEach { UserDefaults(suiteName: $0)?.removePersistentDomain(forName: $0) }
        suites = []
        super.tearDown()
    }

    func testStartAndStopRunOnlyEnabledModulesAndOnlyOnce() {
        let a = FakeModule("a"), b = FakeModule("b")
        let defaults = makeDefaults()
        defaults.set(false, forKey: "module.b.enabled")
        let registry = ModuleRegistry(modules: [a, b], defaults: defaults)
        registry.start()
        registry.start()
        XCTAssertEqual([a.starts, b.starts], [1, 0])
        registry.stop()
        registry.stop()
        XCTAssertEqual([a.stops, b.stops], [1, 0])
    }

    func testDisablingStopsAndEnablingStartsARunningModule() {
        let a = FakeModule("a")
        let registry = ModuleRegistry(modules: [a], defaults: makeDefaults())
        registry.start()
        registry.setEnabled("a", false)
        registry.setEnabled("a", false)
        XCTAssertEqual([a.starts, a.stops], [1, 1])
        registry.setEnabled("a", true)
        XCTAssertEqual([a.starts, a.stops], [2, 1])
    }

    // A disabled module must run nothing: no observers, no prompts (ARCHITECTURE.md §1).
    func testChangingTheFlagWhileStoppedRunsNothing() {
        let a = FakeModule("a")
        let registry = ModuleRegistry(modules: [a], defaults: makeDefaults())
        registry.setEnabled("a", false)
        registry.setEnabled("a", true)
        XCTAssertEqual([a.starts, a.stops], [0, 0])
        registry.start()
        XCTAssertEqual(a.starts, 1)
    }

    func testEnabledFlagIsSavedAndUnknownIDIsIgnored() {
        let defaults = makeDefaults()
        let first = ModuleRegistry(modules: [FakeModule("a")], defaults: defaults)
        first.setEnabled("a", false)
        first.setEnabled("nope", false)
        let second = ModuleRegistry(modules: [FakeModule("a")], defaults: defaults)
        XCTAssertEqual(second.enabledIDs, [])
        XCTAssertNil(defaults.object(forKey: "module.nope.enabled"))
    }

    func testExpandedModulesFollowTabOrderAndSkipDisabled() {
        let registry = ModuleRegistry(modules: [FakeModule("a"), FakeModule("b"), FakeModule("c")], defaults: makeDefaults())
        registry.tabOrder = ["c", "a", "b"]
        registry.setEnabled("a", false)
        XCTAssertEqual(registry.expandedModules.map(\.id), ["c", "b"])
    }

    func testCompactSlotNeedsAnEnabledModuleWithContent() {
        let a = FakeModule("a")
        let registry = ModuleRegistry(modules: [a], defaults: makeDefaults())
        XCTAssertEqual(registry.compactModule(for: .left)?.id, "a")
        XCTAssertNil(registry.compactModule(for: .right))
        a.hasCompactContent = false
        XCTAssertNil(registry.compactModule(for: .left))
        a.hasCompactContent = true
        registry.setEnabled("a", false)
        XCTAssertNil(registry.compactModule(for: .left))
    }
}
