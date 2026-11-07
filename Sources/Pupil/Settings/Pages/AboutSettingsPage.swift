//
//  AboutSettingsPage.swift
//  Pupil
//
//  About & Privacy page modeled after Glance's AboutSettingsPage.
//

import SwiftUI

public struct AboutSettingsPage: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: SettingsMetrics.rowSpacing) {
            SettingsGroup {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.85))
                            .frame(width: 54, height: 54)
                        PupilEyeVectorView(isOpen: true, accentColor: PupilTheme.accent, size: 28)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text("Pupil")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(SettingsMetrics.textPrimary)
                            Text("v1.0.0")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(SettingsMetrics.textSecondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(SettingsMetrics.pickerPillFill))
                        }
                        Text("Native macOS menu bar & notch security sentinel for solo study sessions.")
                            .font(.system(size: 12))
                            .foregroundStyle(SettingsMetrics.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, SettingsMetrics.rowHorizontalInset)
                .padding(.vertical, 14)
            }

            VStack(alignment: .leading, spacing: 8) {
                SettingsSectionTitle(text: "Four Response Levels")
                SettingsGroup {
                    levelRow(
                        number: "1",
                        title: "Armed Deterrence",
                        detail: "Menu bar closed eye glyph; hardware power & lid sensors armed."
                    )
                    SettingsGroupDivider()
                    levelRow(
                        number: "2",
                        title: "Gaze Warning",
                        detail: "Sustained gaze inside camera ROI expands the MacBook notch with a tracking eye."
                    )
                    SettingsGroupDivider()
                    levelRow(
                        number: "3",
                        title: "Tamper Countdown",
                        detail: "AC charger unplug or screen lock initiates an immediate grace countdown."
                    )
                    SettingsGroupDivider()
                    levelRow(
                        number: "4",
                        title: "PIN-Latched Siren",
                        detail: "Lid closure or expired countdown latches the AVAudioEngine siren until PIN/Touch ID disarm."
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SettingsSectionTitle(text: "On-Device Privacy & Security")
                SettingsGroup {
                    SettingsRowContent(
                        title: "100% On-Device Vision Pipeline",
                        subtitle: "Camera frames are processed in memory via Apple Vision and immediately discarded. Zero images or videos are ever saved to disk or sent over the network."
                    ) {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(PupilTheme.armedGreen)
                    }
                    SettingsGroupDivider()
                    SettingsRowContent(
                        title: "Keychain & Biometric Protection",
                        subtitle: "Disarm PINs are salted and SHA-256 hashed in the macOS Keychain alongside LocalAuthentication Touch ID."
                    ) {
                        Image(systemName: "key.fill")
                            .foregroundStyle(PupilTheme.accent)
                    }
                }
            }
        }
    }

    private func levelRow(number: String, title: String, detail: String) -> some View {
        SettingsRowContent(title: "\(number). \(title)", subtitle: detail) {
            EmptyView()
        }
    }
}
