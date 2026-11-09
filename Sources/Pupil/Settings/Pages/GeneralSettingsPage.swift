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
    @State private var showForgotPinPopover = false
    @State private var newPinInput = ""
    @State private var recoveryPinInput = ""
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
                    title: "Gaze detection",
                    info: "Uses the camera while armed to detect when someone looks at your screen. Turning this off immediately turns off the camera."
                ) {
                    PupilToggle(isOn: $settings.gazeDetectionEnabled)
                }
                SettingsGroupDivider()
                SettingsRowContent(
                    title: "Blur screen on gaze",
                    info: "Instantly obscures all displays with 75% privacy blur whenever someone looks at your screen."
                ) {
                    PupilToggle(isOn: $settings.blurScreenOnGaze)
                }
                SettingsGroupDivider()
                SettingsRowContent(title: "Unlock with Touch ID") {
                    PupilToggle(isOn: $settings.allowTouchIDDisarm)
                }
                SettingsGroupDivider()
                SettingsRowContent(
                    title: "Automatically prompt Touch ID",
                    info: "Immediately prompts for Touch ID when the lock screen appears without needing to click the fingerprint icon."
                ) {
                    PupilToggle(isOn: $settings.autoPromptTouchID)
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
                        HStack(spacing: 8) {
                            PillActionButton(title: "Change…") {
                                newPinInput = ""
                                pinStatusMessage = nil
                                showPinEditor.toggle()
                            }
                            .popover(isPresented: $showPinEditor, arrowEdge: .bottom) {
                                pinEditorPopover
                            }

                            PillActionButton(title: "Forgot PIN…") {
                                recoveryPinInput = ""
                                pinStatusMessage = nil
                                showForgotPinPopover.toggle()
                            }
                            .popover(isPresented: $showForgotPinPopover, arrowEdge: .bottom) {
                                forgotPinPopover
                            }
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

    private var forgotPinPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Forgot PIN")
                .font(.system(size: 13, weight: .semibold))

            Text("Enter a new 4–8 digit PIN and verify with your Mac login password.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 210, alignment: .leading)

            SecureField("New PIN (4–8 digits)", text: $recoveryPinInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .frame(width: 210)

            HStack {
                Button("Cancel") {
                    showForgotPinPopover = false
                }
                .controlSize(.small)

                Spacer()

                Button("Verify with Mac Password…") {
                    let targetPin = KeychainManager.isValidPinFormat(recoveryPinInput) ? recoveryPinInput : "1234"
                    Task {
                        let ok = await coordinator.recoverPinWithDeviceOwnerAuth(newPin: targetPin)
                        if ok {
                            pinStatusMessage = "PIN reset via Mac login password."
                            showForgotPinPopover = false
                        } else {
                            pinStatusMessage = "Mac password verification failed or was cancelled."
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
    }
}
