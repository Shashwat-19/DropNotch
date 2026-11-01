import SwiftUI

/// The black shape that extends the hardware notch (or draws a pill without one).
/// It is pinned to the top centre of the panel and sized for the displayed phase.
struct NotchRootView: View {
    let state: NotchState
    let registry: ModuleRegistry

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        // The panel's frame, not the shape's: the shape fills the 1 pt strip above the screen too, so its top
        // edge is off-screen in every state and during every animation (D29).
        let phase = state.displayedPhase, wings = state.displayedWings
        let frame = state.geometry?.panelFrame(for: phase, wings: wings) ?? .zero
        // Placed from the canvas's leading edge rather than centred: a shape with one wing isn't centred (D36), and
        // whole-point edges keep it on whole pixels, which centring an odd width difference wouldn't (code-reviewer S1).
        let offset = frame.minX - (state.geometry?.panelFrame(for: .open).minX ?? frame.minX)
        let shape = NotchShape(shoulder: NotchGeometry.shoulder(for: phase, wings: wings),
                               bottomRadius: phase == .open ? 18 : 10)
        shape
            .fill(.black)
            .frame(width: frame.width, height: frame.height)
            .overlay(alignment: .top) {
                if phase != .open, !wings.isEmpty, let geometry = state.geometry {
                    compactSlots(geometry, wings: wings)
                        .padding(.top, NotchGeometry.topOverhang)
                        .transition(.opacity)
                }
            }
            // Clipped, so the wings' content never shows outside the shape while it widens or narrows (D28).
            .clipShape(shape)
            // The selected tab's module (D31). Fades in on open and vanishes at once on close, so the text
            // never pokes out of the shrinking shape (D19).
            .overlay {
                if state.displayedPhase == .open {
                    VStack(spacing: 0) {
                        // The tabs sit in the strip right of the camera housing; the module starts below it. The row
                        // shows with every module off too, so Settings stays reachable (code-reviewer W1, D35).
                        topRow.frame(height: state.geometry?.closedFrame.height ?? 0)
                        if let module = registry.selectedModule {
                            // Every module gets the same margins (D37). The id makes a tab switch cross-fade.
                            module.expandedView()
                                .padding(.horizontal, NotchStyle.sidePadding)
                                .padding(.bottom, NotchStyle.bottomPadding)
                                .frame(maxHeight: .infinity)
                                // One group named after the module, empty states included, so VoiceOver announces
                                // where the content belongs (L4).
                                .accessibilityElement(children: .contain)
                                .accessibilityLabel(Text(module.title))
                                .id(module.id)
                                .transition(.opacity)
                        }
                    }
                    // Keeps the row at the top when no module fills the space below it.
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, NotchGeometry.topOverhang)
                    // The content sits in the body, between the shoulders.
                    .padding(.horizontal, NotchGeometry.openShoulder)
                    // The shape is always black, so its content uses dark colours in light mode too (L5).
                    .environment(\.colorScheme, .dark)
                    .environment(\.notchHasKeyboardFocus, state.hasKeyboardFocus)
                    // A click in a hover-opened note takes keyboard focus (D31).
                    .environment(\.requestNotchKeyboardFocus, NotchFocusRequest { state.send(.focusRequested) })
                    // Clipboard copy-back closes a keyboard-opened notch so ⌘V reaches the front app.
                    .environment(\.dismissNotch, NotchFocusRequest { state.send(.dismissed) })
                    .transition(.asymmetric(insertion: .opacity, removal: .identity))
                }
            }
            .offset(x: offset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // The panel overlaps the camera housing; without this SwiftUI would push
            // the content below the screen's safe area.
            .ignoresSafeArea()
            // Fallback only: `NotchPanel.sendEvent` catches Escape before SwiftUI sees it (D31).
            .onExitCommand { state.send(.dismissed) }
    }

    /// Right of the camera housing (D35): one icon per module once there is more than one (D31), then Settings.
    /// The leading padding keeps every button clear of the housing; the geometry makes the strip wide enough.
    private var topRow: some View {
        let modules = registry.expandedModules
        return HStack(spacing: NotchGeometry.topRowSpacing) {
            Spacer(minLength: 0)
            if modules.count > 1 {
                ForEach(Array(modules.enumerated()), id: \.element.id) { index, module in
                    tab(module, index: index)
                }
            }
            settingsButton
        }
        .padding(.leading, (state.geometry?.openTopRowLeading ?? 0) + NotchGeometry.topRowInset)
        .padding(.trailing, NotchGeometry.topRowInset)
    }

    /// Opens Settings in front, the same way as the menu-bar item (D14), which can hide behind the notch on a crowded
    /// menu bar. Activating DropNotch takes key focus from the panel, which closes a keyboard-opened notch (D30).
    private var settingsButton: some View {
        Button {
            NSApp.activate()
            openSettings()
        } label: {
            Label("Settings", systemImage: "gearshape")
                .labelStyle(.iconOnly)
                .frame(width: NotchGeometry.topRowItemSize.width, height: NotchGeometry.topRowItemSize.height)
                .foregroundStyle(.secondary)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        // ⌘, while the panel is key, like the tabs' ⌘1… Not a Tab stop either.
        .keyboardShortcut(",")
        .focusable(false)
        // On macOS this is the tooltip and also VoiceOver's hint: "Settings, button, Open Settings".
        .help("Open Settings (⌘,)")
    }

    private func tab(_ module: any NotchModule, index: Int) -> some View {
        let selected = module.id == registry.selectedModule?.id
        // The shared spring, which here only cross-fades, so it stays on under Reduce Motion (L8).
        return Button { withAnimation(NotchStyle.spring) { registry.selectedTabID = module.id } } label: {
            Label { Text(module.title) } icon: { Image(systemName: module.systemImage) }
                .labelStyle(.iconOnly)
                .frame(width: NotchGeometry.topRowItemSize.width, height: NotchGeometry.topRowItemSize.height)
                // A filled capsule as well as brighter, so the selection doesn't rest on colour alone (L6).
                .background(NotchSelection(shape: Capsule(), isSelected: selected))
                .foregroundStyle(selected ? .primary : .secondary)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        // ⌘1, ⌘2… while the panel is key. Not a Tab stop: Tab belongs to the module's own controls.
        .keyboardShortcut(index < 9 ? KeyboardShortcut(KeyEquivalent(Character("\(index + 1)"))) : nil)
        .focusable(false)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .help(index < 9 ? Text("\(Text(module.title)) (⌘\(index + 1))") : Text(module.title))
    }

    /// The compact wings beside the notch (D8, D28), on the sides that have content (D36), at the closed height so
    /// peek doesn't move them.
    private func compactSlots(_ geometry: NotchGeometry, wings: Set<CompactSlot>) -> some View {
        HStack(spacing: 0) {
            if wings.contains(.left) { compactSlot(.left, geometry) }
            Spacer(minLength: 0)
            if wings.contains(.right) { compactSlot(.right, geometry) }
        }
        .frame(width: geometry.frame(for: .closed, wings: wings).width, height: geometry.closedFrame.height)
        .environment(\.colorScheme, .dark)
    }

    private func compactSlot(_ slot: CompactSlot, _ geometry: NotchGeometry) -> some View {
        registry.slotModule(for: slot)?.compactView(slot: slot)
            // Even padding on all sides of a square wing.
            .padding(geometry.wingWidth * 0.2)
            .frame(width: geometry.wingWidth, height: geometry.closedFrame.height)
    }
}

extension EnvironmentValues {
    /// Whether the hotkey holds the notch open with keyboard focus (D30), for modules' open content.
    @Entry var notchHasKeyboardFocus = false
    /// Takes keyboard focus for a hover-opened notch (D31). Modules don't see `NotchState`.
    @Entry var requestNotchKeyboardFocus = NotchFocusRequest {}
    /// Closes a keyboard-opened notch and hands focus back; does nothing to a hover-opened one.
    @Entry var dismissNotch = NotchFocusRequest {}
}

/// A struct rather than a bare closure, so SwiftUI can compare it and skip redrawing the views that read it.
/// Every instance sends the same event to the one `NotchState`, so any two are equal.
struct NotchFocusRequest: Equatable {
    let action: @MainActor () -> Void
    @MainActor func callAsFunction() { action() }
    static func == (lhs: Self, rhs: Self) -> Bool { true }
}
