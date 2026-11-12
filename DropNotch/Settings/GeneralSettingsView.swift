import KeyboardShortcuts
import os
import ServiceManagement
import SwiftUI

/// Launch at login, the notch size, rounded screen corners, alerts, the hotkey and the notch's display (D30, D34, D49, D52).
struct GeneralSettingsView: View {
    let notchState: NotchState
    let screenCorners: ScreenCornersController
    /// Nil on a Mac without a battery: no charging alert to offer (D43).
    let chargingAlert: ChargingAlert?
    let headphoneAlert: HeadphoneAlert

    /// Read from the system, never saved by DropNotch: the user can change it in System Settings › Login Items.
    /// Waiting for approval shows as on, so the toggle can withdraw it (security-auditor L4).
    @State private var loginStatus = SMAppService.mainApp.status
    @State private var loginError = false
    @AppStorage(NotchDisplay.key) private var display = NotchDisplay.builtIn
    @AppStorage(ScreenCorners.key) private var roundCorners = false
    @AppStorage(ChargingAlert.key) private var chargingAlertOn = true
    @AppStorage(Haptics.key) private var hapticsOn = true
    @AppStorage(HeadphoneAlert.key) private var headphoneAlertOn = false
    @AppStorage(NotchAppearance.key) private var appearance = NotchAppearance.black

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(get: { loginStatus == .enabled || loginStatus == .requiresApproval },
                                                      set: setLaunchAtLogin))
                if loginStatus == .requiresApproval {
                    // Registered, but macOS waits for the user to allow it in Login Items.
                    LabeledContent("Allow DropNotch in System Settings › General › Login Items.") {
                        Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
                    }
                }
                if loginError {
                    Text("Couldn't change the login item. Try again, or add DropNotch in System Settings › General › Login Items.")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Picker("Notch size", selection: Binding(get: { notchState.notchSize },
                                                         set: { notchState.setNotchSize($0) })) {
                    Text("Standard").tag(NotchSize.standard)
                    Text("Large").tag(NotchSize.large)
                }
            } footer: {
                Text("Large is taller and wider, with larger text and controls on every tab. The terminal keeps its own font size.").foregroundStyle(.secondary)
            }
            if NotchAppearance.isGlassAvailable {
                Section {
                    Picker("Look", selection: $appearance) {
                        Text("Black").tag(NotchAppearance.black)
                        Text("Liquid Glass").tag(NotchAppearance.liquidGlass)
                    }
                } footer: {
                    Text("Liquid Glass applies to the open notch; closed, it stays black to match the camera. With Reduce Transparency on, it's black.")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Toggle("Round the bottom corners of the screen", isOn: $roundCorners)
                    .onChange(of: roundCorners) { screenCorners.refresh() }
            } footer: {
                Text("Matches the rounded top corners of the built-in display. Clicks in the corners still reach what's underneath.")
                    .foregroundStyle(.secondary)
            }
            Section {
                if let chargingAlert {
                    Toggle("Show an alert when the Mac starts charging", isOn: $chargingAlertOn)
                        .onChange(of: chargingAlertOn) { chargingAlert.refresh() }
                }
                Toggle("Show headphone battery when they connect", isOn: $headphoneAlertOn)
                    .onChange(of: headphoneAlertOn) { headphoneAlert.refresh() }
                Toggle("Haptic feedback", isOn: $hapticsOn)
            } footer: {
                Text("Headphone battery asks for Bluetooth access the first time; DropNotch only reads AirPods and other headphones' levels. A light tap on the trackpad comes with each alert, felt only with a finger on the trackpad.")
                    .foregroundStyle(.secondary)
            }
            Section {
                KeyboardShortcuts.Recorder("Open and close the notch", name: .toggleNotch)
                Picker("Show the notch on", selection: $display) {
                    Text("Built-in display").tag(NotchDisplay.builtIn)
                    Text("Main display").tag(NotchDisplay.main)
                }
                .onChange(of: display) { notchState.screensChanged() }
            } footer: {
                Text("Built-in display falls back to the main display when the built-in one is closed or has no notch.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { loginStatus = SMAppService.mainApp.status }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = false
        } catch {
            loginError = true
            Logger.settings.error("Login item change failed: \((error as NSError).domain, privacy: .public) \((error as NSError).code)")
        }
        loginStatus = SMAppService.mainApp.status
    }
}
