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
        XCTAssertEqual(registry.compactModule(for: .right)?.id, "a")
        a.hasCompactContent = false
        XCTAssertNil(registry.compactModule(for: .left))
        // The slot's module stays drawable while the wings retract (D28).
        XCTAssertEqual(registry.slotModule(for: .left)?.id, "a")
        a.hasCompactContent = true
        registry.setEnabled("a", false)
        XCTAssertNil(registry.compactModule(for: .left))
        XCTAssertNil(registry.slotModule(for: .left))
    }

    func testInitStartsAndStopsNothing() {
        let a = FakeModule("a"), b = FakeModule("b")
        _ = ModuleRegistry(modules: [a, b], defaults: makeDefaults())
        XCTAssertEqual([a.starts, a.stops, b.starts, b.stops], [0, 0, 0, 0])
    }

    func testStartStartsEveryEnabledModuleOnce() {
        let a = FakeModule("a"), b = FakeModule("b")
        let registry = ModuleRegistry(modules: [a, b], defaults: makeDefaults())
        registry.start()
        XCTAssertEqual([a.starts, b.starts], [1, 1])
    }

    func testEnablingAnEnabledModuleIsANoOp() {
        let a = FakeModule("a")
        let defaults = makeDefaults()
        let registry = ModuleRegistry(modules: [a], defaults: defaults)
        registry.start()
        registry.setEnabled("a", true)
        XCTAssertEqual([a.starts, a.stops], [1, 0])
        XCTAssertNil(defaults.object(forKey: "module.a.enabled"))
    }

    func testStopBeforeStartStopsNothing() {
        let a = FakeModule("a")
        ModuleRegistry(modules: [a], defaults: makeDefaults()).stop()
        XCTAssertEqual(a.stops, 0)
    }

    // Disabling already stopped it, so stop() must not stop it a second time.
    func testStopSkipsModuleDisabledWhileRunning() {
        let a = FakeModule("a"), b = FakeModule("b")
        let registry = ModuleRegistry(modules: [a, b], defaults: makeDefaults())
        registry.start()
        registry.setEnabled("a", false)
        registry.stop()
        XCTAssertEqual([a.stops, b.stops], [1, 1])
    }

    func testToggleSavesFlagAndBothValuesSurviveANewRegistry() {
        let defaults = makeDefaults()
        let first = ModuleRegistry(modules: [FakeModule("a"), FakeModule("b")], defaults: defaults)
        first.setEnabled("a", false)
        first.setEnabled("b", false)
        first.setEnabled("b", true)
        XCTAssertEqual(defaults.object(forKey: "module.a.enabled") as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: "module.b.enabled") as? Bool, true)
        let second = ModuleRegistry(modules: [FakeModule("a"), FakeModule("b")], defaults: defaults)
        XCTAssertEqual(second.enabledIDs, ["b"])
    }

    func testCompactModuleIsNilForAnUnknownID() {
        let registry = ModuleRegistry(modules: [FakeModule("a")], defaults: makeDefaults())
        registry.compactLeftID = "nope"
        registry.compactRightID = "nope"
        XCTAssertNil(registry.compactModule(for: .left))
        XCTAssertNil(registry.compactModule(for: .right))
    }

    func testExpandedModulesIgnoreUnknownTabOrderIDs() {
        let registry = ModuleRegistry(modules: [FakeModule("a")], defaults: makeDefaults())
        registry.tabOrder = ["nope", "a"]
        XCTAssertEqual(registry.expandedModules.map(\.id), ["a"])
    }
    // MARK: hasCompactContent (D28)

    func testHasCompactContentNeedsAnEnabledSlotModuleWithContent() {
        let a = FakeModule("a")
        let registry = ModuleRegistry(modules: [a, FakeModule("b")], defaults: makeDefaults())
        XCTAssertEqual(registry.compactRightID, "a", "the right slot defaults to the first module")
        XCTAssertTrue(registry.hasCompactContent)
        a.hasCompactContent = false
        XCTAssertFalse(registry.hasCompactContent)
        a.hasCompactContent = true
        registry.setEnabled("a", false)
        XCTAssertFalse(registry.hasCompactContent)
    }

    func testHasCompactContentWhenEitherSlotHasContent() {
        let a = FakeModule("a"), b = FakeModule("b")
        let registry = ModuleRegistry(modules: [a, b], defaults: makeDefaults())
        registry.compactRightID = "b"
        a.hasCompactContent = false
        XCTAssertTrue(registry.hasCompactContent, "right slot only")
        a.hasCompactContent = true
        b.hasCompactContent = false
        XCTAssertTrue(registry.hasCompactContent, "left slot only")
        a.hasCompactContent = false
        XCTAssertFalse(registry.hasCompactContent)
    }

    func testHasCompactContentIsFalseWithEmptySlotsOrNoModules() {
        let registry = ModuleRegistry(modules: [FakeModule("a")], defaults: makeDefaults())
        registry.compactLeftID = nil
        registry.compactRightID = nil
        XCTAssertFalse(registry.hasCompactContent)
        XCTAssertFalse(ModuleRegistry(modules: [], defaults: makeDefaults()).hasCompactContent)
    }
}
