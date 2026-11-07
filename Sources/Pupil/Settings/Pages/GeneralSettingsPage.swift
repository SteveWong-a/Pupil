//
//  GeneralSettingsPage.swift
//  Pupil
//
//  General settings page modeled after Glance's GeneralSettingsPage.
//

import AppKit
import SwiftUI

public struct GeneralSettingsPage: View {
    @Bindable var coordinator: SecurityCoordinator
    @Bindable private var settings = PupilSettings.shared

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
                SettingsRowContent(
                    title: "Show in menu bar",
                    info: "Displays the Pupil eye status icon in your macOS menu bar."
                ) {
                    PupilToggle(isOn: $settings.showsInMenuBar)
                }
                SettingsGroupDivider()
                SettingsRowContent(
                    title: "Allow Touch ID to disarm",
                    subtitle: "Use the Touch ID sensor alongside your Keychain PIN."
                ) {
                    PupilToggle(isOn: $settings.allowTouchIDDisarm)
                }
                SettingsGroupDivider()
                SettingsRowContent(title: "Trackpad haptic feedback") {
                    PupilToggle(isOn: $settings.hapticFeedbackEnabled)
                }
                SettingsGroupDivider()
                displayPickerRow
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
                screens = NSScreen.screens
            }

            VStack(alignment: .leading, spacing: 8) {
                SettingsSectionTitle(text: "Timing & Delays")
                SettingsGroup {
                    SettingsSteppedSliderRowContent(
                        title: "Arming exit delay",
                        valueLabel: "\(settings.exitDelaySeconds) seconds",
                        index: $settings.exitDelaySliderIndex,
                        stopCount: PupilSettings.exitDelayStops.count
                    )
                    SettingsGroupDivider()
                    SettingsSteppedSliderRowContent(
                        title: "Tamper grace countdown",
                        valueLabel: "\(settings.gracePeriodSeconds) seconds",
                        index: $settings.gracePeriodSliderIndex,
                        stopCount: PupilSettings.gracePeriodStops.count
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SettingsSectionTitle(text: "Authentication & Keychain")
                SettingsGroup {
                    SettingsActionRowContent(
                        title: "Disarm PIN",
                        subtitle: "Stored as a salted SHA-256 digest in macOS Keychain.",
                        buttonTitle: "Change PIN…"
                    ) {
                        newPinInput = ""
                        pinStatusMessage = nil
                        showPinEditor.toggle()
                    }
                    .popover(isPresented: $showPinEditor, arrowEdge: .bottom) {
                        pinEditorPopover
                    }
                }
                if let pinStatusMessage {
                    SettingsCaption(text: pinStatusMessage)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SettingsSectionTitle(text: "Quick Verification")
                SettingsGroup {
                    SettingsActionRowContent(
                        title: "Preview Notch Gaze Deterrent",
                        subtitle: "Expands the MacBook notch with the tracking Pupil eye for 4.5 seconds.",
                        buttonTitle: "Preview in Notch"
                    ) {
                        coordinator.simulateGazeWarning()
                    }
                }
            }
        }
    }

    private var displayPickerRow: some View {
        SettingsRowContent(title: "Display overlay on") {
            SettingsMenuPickerPill(label: selectedDisplayLabel) {
                Button("Automatic (Notch Preferred)") {
                    settings.preferredDisplayID = nil
                }
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

    private var selectedDisplayLabel: String {
        guard let targetID = settings.preferredDisplayID,
              let match = screens.first(where: { $0.stableDisplayID == targetID }) else {
            return "Automatic"
        }
        return match.localizedName
    }

    private var pinEditorPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Set New Disarm PIN")
                .font(.system(size: 13, weight: .semibold))
            Text("Enter 4 to 8 numeric digits.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            SecureField("New PIN (4–8 digits)", text: $newPinInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, design: .monospaced))
                .frame(width: 180)

            HStack {
                Button("Cancel") {
                    showPinEditor = false
                }
                .controlSize(.small)

                Spacer()

                Button("Save PIN") {
                    do {
                        try coordinator.updatePin(newPin: newPinInput)
                        pinStatusMessage = "PIN updated in macOS Keychain."
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
