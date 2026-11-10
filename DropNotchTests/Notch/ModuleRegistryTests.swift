import SwiftUI
import XCTest
@testable import DropNotch

@MainActor
final class ModuleRegistryTests: XCTestCase {
    private final class FakeModule: NotchModule {
        let id: String
        let title: LocalizedStringResource = "Fake"
        var hasCompactView = true
        var hasCompactContent = true
        var homeCard: HomeCardSize?
        let isEnabledByDefault: Bool
        let systemImage = "square"
        private(set) var starts = 0, stops = 0
        init(_ id: String, card: HomeCardSize? = nil, onByDefault: Bool = true) {
            self.id = id
            homeCard = card
            isEnabledByDefault = onByDefault
        }
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

    /// D45 Q5 dropped the tab limit: with Terminal and Clipboard on there are five tabs and the gear, and the open shape
    /// widens instead (D48).
    func testARegistryWithSixTabsInits() {
        let ids = ["home", "notes", "file-tray", "clipboard", "terminal", "extra"]
        let registry = ModuleRegistry(modules: ids.map { FakeModule($0) }, defaults: makeDefaults())
        XCTAssertEqual(registry.expandedModules.map(\.id), ids)
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
    // MARK: selectedModule (D31)

    func testSelectedModuleDefaultsToTheFirstEnabledTab() {
        let registry = ModuleRegistry(modules: [FakeModule("a"), FakeModule("b")], defaults: makeDefaults())
        XCTAssertNil(registry.selectedTabID)
        XCTAssertEqual(registry.selectedModule?.id, "a")
        registry.tabOrder = ["b", "a"]
        XCTAssertEqual(registry.selectedModule?.id, "b", "first in tab order, not in the modules array")
    }

    func testSelectedModuleFollowsTheSelectedTab() {
        let registry = ModuleRegistry(modules: [FakeModule("a"), FakeModule("b")], defaults: makeDefaults())
        registry.selectedTabID = "b"
        XCTAssertEqual(registry.selectedModule?.id, "b")
    }

    func testSelectedModuleFallsBackWhenTheTabIsOffOrUnknown() {
        let registry = ModuleRegistry(modules: [FakeModule("a"), FakeModule("b"), FakeModule("c")], defaults: makeDefaults())
        registry.selectedTabID = "a"
        registry.setEnabled("a", false)
        XCTAssertEqual(registry.selectedModule?.id, "b")
        registry.setEnabled("a", true)
        XCTAssertEqual(registry.selectedModule?.id, "a", "the selection survives the module being off")
        registry.selectedTabID = "nope"
        // Turned back on, "a" joined the end of the modules that are on (D36), so "b" is first now.
        XCTAssertEqual(registry.selectedModule?.id, "b")
    }

    func testSelectedModuleIsNilWithNoEnabledModules() {
        let registry = ModuleRegistry(modules: [FakeModule("a")], defaults: makeDefaults())
        registry.selectedTabID = "a"
        registry.setEnabled("a", false)
        XCTAssertNil(registry.selectedModule)
        XCTAssertNil(ModuleRegistry(modules: [], defaults: makeDefaults()).selectedModule)
    }

    // MARK: compactWings (D28, D36)

    func testCompactWingsNeedAnEnabledSlotModuleWithContent() {
        let a = FakeModule("a")
        let registry = ModuleRegistry(modules: [a, FakeModule("b")], defaults: makeDefaults())
        XCTAssertEqual(registry.compactRightID, "a", "the right slot defaults to the first module")
        XCTAssertEqual(registry.compactWings, [.left, .right])
        a.hasCompactContent = false
        XCTAssertEqual(registry.compactWings, [])
        a.hasCompactContent = true
        registry.setEnabled("a", false)
        XCTAssertEqual(registry.compactWings, [])
    }

    func testCompactWingsAreOnlyTheSidesWithContent() {
        let a = FakeModule("a"), b = FakeModule("b")
        let registry = ModuleRegistry(modules: [a, b], defaults: makeDefaults())
        registry.compactRightID = "b"
        a.hasCompactContent = false
        XCTAssertEqual(registry.compactWings, [.right], "right slot only")
        a.hasCompactContent = true
        b.hasCompactContent = false
        XCTAssertEqual(registry.compactWings, [.left], "left slot only")
        registry.compactLeftID = nil
        b.hasCompactContent = true
        XCTAssertEqual(registry.compactWings, [.right], "a slot set to Nothing has no wing")
    }

    func testCompactWingsAreEmptyWithEmptySlotsOrNoModules() {
        let registry = ModuleRegistry(modules: [FakeModule("a")], defaults: makeDefaults())
        registry.compactLeftID = nil
        registry.compactRightID = nil
        XCTAssertEqual(registry.compactWings, [])
        XCTAssertEqual(ModuleRegistry(modules: [], defaults: makeDefaults()).compactWings, [])
    }

    // MARK: Saved layout (D34)

    private func registry(_ ids: [String], _ defaults: UserDefaults) -> ModuleRegistry {
        ModuleRegistry(modules: ids.map { FakeModule($0) }, defaults: defaults)
    }

    func testCompactSlotsAndTabOrderSurviveANewRegistry() {
        let defaults = makeDefaults()
        let first = registry(["a", "b", "c"], defaults)
        first.compactLeftID = "b"
        first.compactRightID = "c"
        first.tabOrder = ["c", "a", "b"]
        let second = registry(["a", "b", "c"], defaults)
        XCTAssertEqual(second.compactLeftID, "b")
        XCTAssertEqual(second.compactRightID, "c")
        XCTAssertEqual(second.tabOrder, ["c", "a", "b"])
    }

    func testAnEmptySlotIsRestoredEmpty() {
        let defaults = makeDefaults()
        let first = registry(["a", "b"], defaults)
        first.compactLeftID = nil
        XCTAssertEqual(defaults.string(forKey: "layout.compactLeft"), "")
        let second = registry(["a", "b"], defaults)
        XCTAssertNil(second.compactLeftID)
        XCTAssertEqual(second.compactRightID, "a", "the unsaved slot keeps its default")
    }

    func testASavedSlotForAModuleThatIsGoneIsEmpty() {
        let defaults = makeDefaults()
        defaults.set("gone", forKey: "layout.compactLeft")
        defaults.set("gone", forKey: "layout.compactRight")
        let registry = registry(["a"], defaults)
        XCTAssertNil(registry.compactLeftID)
        XCTAssertNil(registry.compactRightID)
    }

    func testSavedTabOrderDropsUnknownIDsAndInsertsNewModulesAtTheirDefaultIndex() {
        let defaults = makeDefaults()
        defaults.set(["c", "gone", "a", "c"], forKey: "layout.tabOrder")
        XCTAssertEqual(registry(["a", "b", "c", "d"], defaults).tabOrder, ["c", "b", "a", "d"])
    }

    func testMoveTabSwapsWithItsNeighbourAndSaves() {
        let defaults = makeDefaults()
        let first = registry(["a", "b", "c"], defaults)
        first.moveTab("b", by: -1)
        XCTAssertEqual(first.tabOrder, ["b", "a", "c"])
        first.moveTab("a", by: 1)
        XCTAssertEqual(first.tabOrder, ["b", "c", "a"])
        XCTAssertEqual(registry(["a", "b", "c"], defaults).tabOrder, ["b", "c", "a"])
    }

    func testMoveTabDoesNothingAtTheEndsOrForAnUnknownID() {
        let registry = registry(["a", "b", "c"], makeDefaults())
        registry.moveTab("a", by: -1)
        registry.moveTab("c", by: 1)
        registry.moveTab("nope", by: 1)
        XCTAssertEqual(registry.tabOrder, ["a", "b", "c"])
    }

    // MARK: Modules that are off sit last (D36)

    func testInitSortsASavedOrderSoModulesThatAreOnComeFirst() {
        let defaults = makeDefaults()
        defaults.set(["c", "a", "d", "b"], forKey: "layout.tabOrder")
        defaults.set(false, forKey: "module.a.enabled")
        defaults.set(false, forKey: "module.b.enabled")
        XCTAssertEqual(registry(["a", "b", "c", "d"], defaults).tabOrder, ["c", "d", "a", "b"],
                       "each group keeps its saved order")
    }

    func testTurningOffMovesTheModuleToTheFirstSlotOfThoseThatAreOff() {
        let registry = registry(["a", "b", "c", "d"], makeDefaults())
        registry.setEnabled("d", false)
        XCTAssertEqual(registry.tabOrder, ["a", "b", "c", "d"])
        registry.setEnabled("a", false)
        XCTAssertEqual(registry.tabOrder, ["b", "c", "a", "d"])
        registry.setEnabled("a", false)
        XCTAssertEqual(registry.tabOrder, ["b", "c", "a", "d"], "turning off again changes nothing")
    }

    func testTurningOnMakesTheModuleTheLastOfThoseThatAreOn() {
        let registry = registry(["a", "b", "c", "d"], makeDefaults())
        registry.setEnabled("a", false)
        registry.setEnabled("b", false)
        XCTAssertEqual(registry.tabOrder, ["c", "d", "b", "a"])
        registry.setEnabled("a", true)
        XCTAssertEqual(registry.tabOrder, ["c", "d", "a", "b"])
        XCTAssertEqual(registry.expandedModules.map(\.id), ["c", "d", "a"])
    }

    func testMoveTabRefusesModulesThatAreOffAndTheBoundary() {
        let registry = registry(["a", "b", "c", "d"], makeDefaults())
        registry.setEnabled("c", false)
        registry.setEnabled("d", false)
        XCTAssertEqual(registry.tabOrder, ["a", "b", "d", "c"])
        registry.moveTab("d", by: -1)
        registry.moveTab("d", by: 1)
        registry.moveTab("c", by: -1)
        registry.moveTab("b", by: 1)
        XCTAssertEqual(registry.tabOrder, ["a", "b", "d", "c"], "nothing crosses between on and off")
        registry.moveTab("b", by: -1)
        XCTAssertEqual(registry.tabOrder, ["b", "a", "d", "c"])
    }

    func testOrderAfterTogglingSurvivesANewRegistry() {
        let defaults = makeDefaults()
        let first = registry(["a", "b", "c"], defaults)
        first.setEnabled("a", false)
        first.moveTab("c", by: -1)
        XCTAssertEqual(first.tabOrder, ["c", "b", "a"])
        let second = registry(["a", "b", "c"], defaults)
        XCTAssertEqual(second.tabOrder, ["c", "b", "a"])
        XCTAssertEqual(second.enabledIDs, ["b", "c"])
    }

    func testSavedSlotWithoutCompactViewIsEmpty() {
        let defaults = makeDefaults()
        defaults.set("b", forKey: "layout.compactLeft")
        let b = FakeModule("b")
        b.hasCompactView = false
        let registry = ModuleRegistry(modules: [FakeModule("a"), b], defaults: defaults)
        XCTAssertNil(registry.compactLeftID, "Settings doesn't offer a module without a compact view (code-reviewer S5)")
    }

    // MARK: Home cards (D42)

    /// Tabs a and b, cards c1 and c2, interleaved: [a, c1, b, c2].
    private func mixedRegistry(_ defaults: UserDefaults) -> ModuleRegistry {
        ModuleRegistry(modules: [FakeModule("a"), FakeModule("c1", card: .wide), FakeModule("b"),
                                 FakeModule("c2", card: .narrow)], defaults: defaults)
    }

    func testCardsAreHomeCardsInTabOrderAndNotTabs() {
        let registry = mixedRegistry(makeDefaults())
        XCTAssertEqual(registry.expandedModules.map(\.id), ["a", "b"])
        XCTAssertEqual(registry.homeCards.map(\.id), ["c1", "c2"])
        registry.tabOrder = ["c2", "a", "b", "c1"]
        XCTAssertEqual(registry.homeCards.map(\.id), ["c2", "c1"])
    }

    /// v0.2's saved order had no Calendar; it goes in at its default index, between Now Playing and Battery (D44).
    func testCalendarAddedToASavedV02OrderGoesInAtItsDefaultIndex() {
        let defaults = makeDefaults()
        defaults.set(["home", "now-playing", "battery", "notes", "file-tray", "clipboard"], forKey: "layout.tabOrder")
        let registry = ModuleRegistry(modules: [
            FakeModule("home"), FakeModule("now-playing", card: .wide), FakeModule("calendar", card: .medium),
            FakeModule("battery", card: .narrow), FakeModule("notes"), FakeModule("file-tray"), FakeModule("clipboard"),
        ], defaults: defaults)
        XCTAssertEqual(registry.tabOrder,
                       ["home", "now-playing", "calendar", "battery", "notes", "file-tray", "clipboard"])
        XCTAssertEqual(registry.homeCards.map(\.id), ["now-playing", "calendar", "battery"])
        XCTAssertEqual(registry.expandedModules.map(\.id), ["home", "notes", "file-tray", "clipboard"])
    }

    func testDisabledCardsAreNeitherTabsNorHomeCards() {
        let registry = mixedRegistry(makeDefaults())
        registry.setEnabled("c1", false)
        XCTAssertEqual(registry.expandedModules.map(\.id), ["a", "b"])
        XCTAssertEqual(registry.homeCards.map(\.id), ["c2"])
    }

    func testSelectedModuleIsNeverACard() {
        let registry = mixedRegistry(makeDefaults())
        registry.tabOrder = ["c1", "a", "b", "c2"]
        XCTAssertEqual(registry.selectedModule?.id, "a", "the first tab, not the first module")
        registry.selectedTabID = "c2"
        XCTAssertEqual(registry.selectedModule?.id, "a")
        let cardsOnly = ModuleRegistry(modules: [FakeModule("c", card: .wide)], defaults: makeDefaults())
        cardsOnly.selectedTabID = "c"
        XCTAssertNil(cardsOnly.selectedModule)
    }

    func testMoveTabOnACardSwapsWithTheNextCardSkippingTabsAndSaves() {
        let defaults = makeDefaults()
        let registry = mixedRegistry(defaults)
        registry.moveTab("c1", by: 1)
        XCTAssertEqual(registry.tabOrder, ["a", "c2", "b", "c1"])
        XCTAssertEqual(registry.homeCards.map(\.id), ["c2", "c1"])
        XCTAssertEqual(mixedRegistry(defaults).tabOrder, ["a", "c2", "b", "c1"])
        registry.moveTab("c1", by: -1)
        XCTAssertEqual(registry.tabOrder, ["a", "c1", "b", "c2"])
    }

    func testMoveTabOnATabSkipsCards() {
        let registry = mixedRegistry(makeDefaults())
        registry.moveTab("a", by: 1)
        XCTAssertEqual(registry.tabOrder, ["b", "c1", "a", "c2"])
        registry.moveTab("a", by: -1)
        XCTAssertEqual(registry.tabOrder, ["a", "c1", "b", "c2"])
    }

    func testMoveTabDoesNothingAtTheEndOfItsOwnKind() {
        let registry = mixedRegistry(makeDefaults())
        registry.moveTab("c1", by: -1)
        registry.moveTab("c2", by: 1)
        registry.moveTab("a", by: -1)
        registry.moveTab("b", by: 1)
        XCTAssertEqual(registry.tabOrder, ["a", "c1", "b", "c2"], "a card before the first tab or a tab after the last card")
    }

    func testMoveTabDoesNothingWhenTheNeighbourOfItsKindIsOff() {
        let registry = mixedRegistry(makeDefaults())
        registry.setEnabled("c2", false)
        registry.moveTab("c1", by: 1)
        registry.moveTab("c2", by: -1)
        XCTAssertEqual(registry.tabOrder, ["a", "c1", "b", "c2"])
    }

    // v0.1 had no Home; its saved order must not leave Home last.
    func testHomeIsFirstForASavedV01Order() {
        let defaults = makeDefaults()
        defaults.set(["now-playing", "notes", "file-tray", "clipboard"], forKey: "layout.tabOrder")
        // As in the app: Now Playing is a card, so four tabs plus the gear fit the top row (D35).
        let modules = [FakeModule("home"), FakeModule("now-playing", card: .wide), FakeModule("notes"),
                       FakeModule("file-tray"), FakeModule("clipboard")]
        let registry = ModuleRegistry(modules: modules, defaults: defaults)
        XCTAssertEqual(registry.tabOrder, ["home", "now-playing", "notes", "file-tray", "clipboard"])
    }

    func testUnsavedCompactSlotsDefaultToTheFirstModuleWithACompactView() {
        let home = FakeModule("home")
        home.hasCompactView = false
        let registry = ModuleRegistry(modules: [home, FakeModule("now-playing", card: .wide)], defaults: makeDefaults())
        XCTAssertEqual(registry.compactLeftID, "now-playing")
        XCTAssertEqual(registry.compactRightID, "now-playing")
        XCTAssertNil(ModuleRegistry(modules: [home], defaults: makeDefaults()).compactLeftID,
                     "no module with a compact view leaves the slot empty")
    }

    func testRealModulesDeclareTheirHomeCard() {
        XCTAssertNil(HomeModule().homeCard)
        XCTAssertEqual(NowPlayingModule(source: NoNowPlayingSource()).homeCard, .wide)
    }

    func testHomeAndNowPlayingAreOnByDefault() {
        XCTAssertTrue(HomeModule().isEnabledByDefault)
        XCTAssertTrue(NowPlayingModule(source: NoNowPlayingSource()).isEnabledByDefault)
    }

    // MARK: Default-off modules (D46)

    /// As in the app: Home, then Now Playing, Calendar and Battery cards (Battery off by default), then a tab.
    private func defaultsRegistry(_ defaults: UserDefaults, batteryOnByDefault: Bool = false)
        -> (ModuleRegistry, battery: FakeModule) {
        let battery = FakeModule("battery", card: .narrow, onByDefault: batteryOnByDefault)
        let registry = ModuleRegistry(modules: [FakeModule("home"), FakeModule("now-playing", card: .wide),
                                                FakeModule("calendar", card: .medium), battery, FakeModule("notes")],
                                      defaults: defaults)
        return (registry, battery)
    }

    func testADefaultOffModuleWithNoSavedFlagIsOffNotStartedAndLast() {
        let (registry, battery) = defaultsRegistry(makeDefaults())
        XCTAssertFalse(registry.enabledIDs.contains("battery"))
        XCTAssertEqual(registry.homeCards.map(\.id), ["now-playing", "calendar"])
        XCTAssertEqual(registry.expandedModules.map(\.id), ["home", "notes"])
        XCTAssertEqual(registry.tabOrder, ["home", "now-playing", "calendar", "notes", "battery"],
                       "below the modules that are on (D36)")
        registry.start()
        XCTAssertEqual(battery.starts, 0)
    }

    /// Init writes no flag, so a later release can change a module's default for users who never chose.
    func testInitSavesNoFlagSoTheDefaultCanChangeLater() {
        let defaults = makeDefaults()
        _ = defaultsRegistry(defaults)
        for id in ["home", "now-playing", "calendar", "battery", "notes"] {
            XCTAssertNil(defaults.object(forKey: "module.\(id).enabled"), id)
        }
        let (later, _) = defaultsRegistry(defaults, batteryOnByDefault: true)
        XCTAssertTrue(later.enabledIDs.contains("battery"))
    }

    func testASavedFlagBeatsTheDefaultEitherWay() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: "module.battery.enabled")
        defaults.set(false, forKey: "module.calendar.enabled")
        let (registry, battery) = defaultsRegistry(defaults)
        XCTAssertEqual(registry.enabledIDs, ["home", "now-playing", "battery", "notes"])
        XCTAssertEqual(registry.homeCards.map(\.id), ["now-playing", "battery"])
        registry.start()
        XCTAssertEqual(battery.starts, 1)
    }

    func testTurningADefaultOffModuleOnSavesTrueStartsItAndSurvivesANewRegistry() {
        let defaults = makeDefaults()
        let (registry, battery) = defaultsRegistry(defaults)
        registry.start()
        registry.setEnabled("battery", true)
        XCTAssertEqual(battery.starts, 1)
        XCTAssertEqual(defaults.object(forKey: "module.battery.enabled") as? Bool, true)
        XCTAssertEqual(registry.homeCards.map(\.id), ["now-playing", "calendar", "battery"])
        XCTAssertTrue(defaultsRegistry(defaults).0.enabledIDs.contains("battery"))
    }

    /// The real Terminal module (D48): off by default, so it sorts with the modules that are off and has no tab; turning
    /// it on puts it last among those on; neither the registry starting nor turning it on spawns a shell.
    func testTerminalIsOffByDefaultAndSortsWithTheOffModules() {
        // Opening a session would only fail the test: a SwiftTermSession spawns nothing until `start`.
        let terminal = TerminalModule(makeSession: { fontSize, scrollback in
            XCTFail("no shell without a deliberate open")
            return SwiftTermSession(fontSize: fontSize, scrollback: scrollback)
        }, makeShell: { LoginShell(executable: "/bin/false", argv0: "false", directory: "/", environment: []) },
           defaults: makeDefaults())
        let a = FakeModule("a"), b = FakeModule("b"), off = FakeModule("off", onByDefault: false)
        let registry = ModuleRegistry(modules: [a, terminal, off, b], defaults: makeDefaults())
        XCTAssertEqual(registry.tabOrder, ["a", "b", "terminal", "off"])
        XCTAssertEqual(registry.expandedModules.map(\.id), ["a", "b"])
        registry.start()
        registry.setEnabled("terminal", true)
        XCTAssertEqual(registry.tabOrder, ["a", "b", "terminal", "off"])
        XCTAssertEqual(registry.expandedModules.map(\.id), ["a", "b", "terminal"])
        XCTAssertEqual(terminal.state, .notStarted)
        registry.setEnabled("terminal", false)
        XCTAssertEqual(registry.expandedModules.map(\.id), ["a", "b"])
    }
}
