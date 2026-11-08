//
//  GeneralSettingsPage.swift
//  Pupil
//
//  General settings page modeled directly after Glance's GeneralSettingsPage.
//

import AppKit
import SwiftUI

public struct GeneralSettingsPage: View {
    @Bindable var coordinator: SecurityCoordinator
    @Bindable private var settings = PupilSettings.shared

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var screens: [NSScreen] = NSScreen.screens
    @State private var showPinEditor = false
    @State private var newPinInput = ""
    @State private var pinStatusMessage: String?

    public init(coordinator: SecurityCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SettingsMetrics.rowSpacing) {
            SettingsGroup {
                SettingsRowContent(title: "Launch at login") {
                    PupilToggle(isOn: Binding(
                        get: { launchAtLogin },
                        set: { newValue in
                            try? LaunchAtLogin.setEnabled(newValue)
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    ))
                }
                SettingsGroupDivider()
                SettingsRowContent(title: "Show in menu bar") {
                    PupilToggle(isOn: $settings.showsInMenuBar)
                }
                SettingsGroupDivider()
                SettingsRowContent(
                    title: "Lock on keyboard or mouse",
                    info: "When armed, any keyboard or mouse input immediately locks the screen with a PIN / Touch ID challenge."
                ) {
                    PupilToggle(isOn: $settings.lockOnInputWhenArmed)
                }
                SettingsGroupDivider()
                SettingsRowContent(
                    title: "Blur screen on gaze",
                    info: "Instantly obscures all displays with frosted privacy glass whenever someone looks at your screen."
                ) {
                    PupilToggle(isOn: $settings.blurScreenOnGaze)
                }
                SettingsGroupDivider()
                SettingsRowContent(title: "Unlock with Touch ID") {
                    PupilToggle(isOn: $settings.allowTouchIDDisarm)
                }
                SettingsGroupDivider()
                SettingsRowContent(
                    title: "Continuous blur while armed",
                    info: "Keep the screen frosted continuously as soon as the system is armed (unblur by entering PIN or Touch ID)."
                ) {
                    PupilToggle(isOn: $settings.blurBackgroundWhenArmed)
                }
                SettingsGroupDivider()
                displayPickerRow
            }
            .onAppear {
                launchAtLogin = LaunchAtLogin.isEnabled
                screens = NSScreen.screens
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
                screens = NSScreen.screens
            }

            VStack(alignment: .leading, spacing: 8) {
                SettingsSectionTitle(text: "Behaviour")
                SettingsGroup {
                    SettingsRowContent(title: "Haptic feedback") {
                        PupilToggle(isOn: $settings.hapticFeedbackEnabled)
                    }
                    SettingsGroupDivider()
                    SettingsSteppedSliderRowContent(
                        title: "Arming delay",
                        valueLabel: "\(settings.exitDelaySeconds) seconds",
                        index: $settings.exitDelaySliderIndex,
                        stopCount: PupilSettings.exitDelayStops.count
                    )
                    SettingsGroupDivider()
                    SettingsSteppedSliderRowContent(
                        title: "Grace period",
                        valueLabel: "\(settings.gracePeriodSeconds) seconds",
                        index: $settings.gracePeriodSliderIndex,
                        stopCount: PupilSettings.gracePeriodStops.count
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SettingsSectionTitle(text: "Passcode")
                SettingsGroup {
                    SettingsRowContent(title: "Disarm PIN") {
                        PillActionButton(title: "Change…") {
                            newPinInput = ""
                            pinStatusMessage = nil
                            showPinEditor.toggle()
                        }
                        .popover(isPresented: $showPinEditor, arrowEdge: .bottom) {
                            pinEditorPopover
                        }
                    }
                    SettingsGroupDivider()
                    SettingsRowContent(title: "Preview") {
                        HStack(spacing: 8) {
                            PillActionButton(title: "Notch") {
                                coordinator.simulateGazeWarning()
                            }
                            PillActionButton(title: "Screen Shield") {
                                coordinator.previewScreenShield()
                            }
                        }
                    }
                }
                if let pinStatusMessage {
                    SettingsCaption(text: pinStatusMessage)
                }
            }
        }
    }

    private var displayPickerRow: some View {
        SettingsRowContent(
            title: "Display on",
            info: "Choose which screen shows the Pupil overlay."
        ) {
            SettingsMenuPickerPill(label: selectedDisplayLabel) {
                Button("Automatic") {
                    settings.preferredDisplayID = nil
                }
                if !screens.isEmpty {
                    Divider()
                    ForEach(screens, id: \.stableDisplayID) { screen in
                        if let id = screen.stableDisplayID {
                            Button(screen.localizedName) {
                                settings.preferredDisplayID = id
                            }
                        }
                    }
                }
            }
        }
    }

    private var selectedDisplayLabel: String {
        guard let targetID = settings.preferredDisplayID,
              let match = screens.first(where: { $0.stableDisplayID == targetID }) else {
            return "Automatic"
        }
        return match.localizedName
    }

    private var pinEditorPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Change PIN")
                .font(.system(size: 13, weight: .semibold))
            Text("Enter a 4 to 8 digit passcode.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            SecureField("New PIN", text: $newPinInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .frame(width: 180)

            HStack {
                Button("Cancel") {
                    showPinEditor = false
                }
                .controlSize(.small)

                Spacer()

                Button("Save") {
                    do {
                        try coordinator.updatePin(newPin: newPinInput)
                        pinStatusMessage = "PIN updated."
                        showPinEditor = false
                    } catch {
                        pinStatusMessage = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!KeychainManager.isValidPinFormat(newPinInput))
            }
        }
        .padding(12)
    }
}
