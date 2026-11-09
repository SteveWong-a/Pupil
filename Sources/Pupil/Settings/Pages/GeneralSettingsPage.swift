//
//  GeneralSettingsPage.swift
//  Pupil
//
//  General settings page modeled directly after Glance's GeneralSettingsPage.
//

import AppKit
import CoreImage
import SwiftUI

public struct GeneralSettingsPage: View {
    @Bindable var coordinator: SecurityCoordinator
    @Bindable private var settings = PupilSettings.shared

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var screens: [NSScreen] = NSScreen.screens
    @State private var showPinEditor = false
    @State private var showPhone2FASetup = false
    @State private var showForgotPinPopover = false
    @State private var newPinInput = ""
    @State private var totpSecret = ""
    @State private var totpVerifyCode = ""
    @State private var recoveryPinInput = ""
    @State private var recoveryCodeInput = ""
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
                SettingsSectionTitle(text: "Passcode & Recovery")
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
                                recoveryCodeInput = ""
                                pinStatusMessage = nil
                                showForgotPinPopover.toggle()
                            }
                            .popover(isPresented: $showForgotPinPopover, arrowEdge: .bottom) {
                                forgotPinPopover
                            }
                        }
                    }
                    SettingsGroupDivider()
                    SettingsRowContent(
                        title: "Phone 2FA Recovery",
                        info: "Scan with iPhone Camera, Apple Passwords, or Google Authenticator to unlock or reset your PIN if forgotten."
                    ) {
                        PillActionButton(title: "Set Up Phone 2FA…") {
                            totpSecret = KeychainManager.ensureTOTPSecret()
                            totpVerifyCode = ""
                            pinStatusMessage = nil
                            showPhone2FASetup.toggle()
                        }
                        .popover(isPresented: $showPhone2FASetup, arrowEdge: .bottom) {
                            phone2FAPopover
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

    private var phone2FAPopover: some View {
        VStack(alignment: .center, spacing: 10) {
            Text("Phone 2FA Recovery")
                .font(.system(size: 13, weight: .semibold))

            Text("Scan with iPhone Camera, Apple Passwords, or Google Authenticator.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(width: 220)

            if let qrImage = generateQRCodeImage(
                from: KeychainManager.totpProvisioningURI(secretBase32: totpSecret)
            ) {
                Image(nsImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 148, height: 148)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white)
                    )
            }

            VStack(spacing: 3) {
                Text("Manual Setup Key")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(totpSecret)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .textSelection(.enabled)
            }

            HStack(spacing: 6) {
                TextField("Test 6-digit code", text: $totpVerifyCode)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(width: 130)

                Button("Verify") {
                    if KeychainManager.verifyTOTPCode(totpVerifyCode, secretBase32: totpSecret) {
                        pinStatusMessage = "Phone 2FA verified and ready."
                        showPhone2FASetup = false
                    } else {
                        pinStatusMessage = "Invalid 6-digit code. Check your phone clock."
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            HStack {
                Button("New Key") {
                    totpSecret = KeychainManager.regenerateTOTPSecret()
                }
                .controlSize(.small)

                Spacer()

                Button("Done") {
                    showPhone2FASetup = false
                }
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 256)
    }

    private var forgotPinPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Forgot PIN / Recovery")
                .font(.system(size: 13, weight: .semibold))

            Text("Set a new 4–8 digit PIN using your Phone 2FA code or Mac login password.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 220, alignment: .leading)

            SecureField("New PIN (4–8 digits)", text: $recoveryPinInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .frame(width: 220)

            TextField("6-Digit Phone 2FA Code", text: $recoveryCodeInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 220)

            HStack(spacing: 8) {
                Button("Reset with 2FA") {
                    let ok = coordinator.disarmOrResetWithTOTP(
                        code: recoveryCodeInput,
                        newPin: recoveryPinInput
                    )
                    if ok {
                        pinStatusMessage = "PIN reset via Phone 2FA."
                        showForgotPinPopover = false
                    } else {
                        pinStatusMessage = "Invalid 2FA code or PIN format."
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!KeychainManager.isValidPinFormat(recoveryPinInput) || recoveryCodeInput.count < 6)

                Button("Use Mac Password…") {
                    let targetPin = KeychainManager.isValidPinFormat(recoveryPinInput) ? recoveryPinInput : "1234"
                    Task {
                        let ok = await coordinator.recoverPinWithDeviceOwnerAuth(newPin: targetPin)
                        if ok {
                            pinStatusMessage = "PIN reset to \(targetPin == "1234" ? "default (1234)" : "new PIN")."
                            showForgotPinPopover = false
                        } else {
                            pinStatusMessage = "Mac owner authentication failed or was cancelled."
                        }
                    }
                }
                .controlSize(.small)
            }
        }
        .padding(14)
    }

    private func generateQRCodeImage(from string: String) -> NSImage? {
        guard let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let outputImage = filter.outputImage else { return nil }
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let rep = NSCIImageRep(ciImage: transformed)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}
