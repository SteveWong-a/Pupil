//
//  AboutSettingsPage.swift
//  Pupil
//
//  About page modeled directly after Glance's AboutSettingsPage.
//

import AppKit
import SwiftUI

public struct AboutSettingsPage: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)

            VStack(spacing: 4) {
                Text(appName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(SettingsMetrics.textPrimary)

                Text("Version \(versionString)")
                    .font(.system(size: 12))
                    .foregroundStyle(SettingsMetrics.textSecondary)
            }

            SettingsGroup {
                SettingsRowContent(title: "Processing") {
                    Text("On-Device Apple Vision")
                        .font(.system(size: 13))
                        .foregroundStyle(SettingsMetrics.textSecondary)
                }
                SettingsGroupDivider()
                SettingsRowContent(title: "Passcode storage") {
                    Text("macOS Keychain (SHA-256)")
                        .font(.system(size: 13))
                        .foregroundStyle(SettingsMetrics.textSecondary)
                }
                SettingsGroupDivider()
                SettingsRowContent(title: "Camera privacy") {
                    Text("Zero frames saved to disk")
                        .font(.system(size: 13))
                        .foregroundStyle(SettingsMetrics.textSecondary)
                }
                SettingsGroupDivider()
                SettingsRowContent(title: "License") {
                    Text("MIT License")
                        .font(.system(size: 13))
                        .foregroundStyle(SettingsMetrics.textSecondary)
                }
                SettingsGroupDivider()
                SettingsRowContent(title: "Copyright") {
                    Text("© 2026 Steve Wong")
                        .font(.system(size: 13))
                        .foregroundStyle(SettingsMetrics.textSecondary)
                }
            }
            .padding(.top, 8)

            SettingsCaption(text: "Pupil is a software deterrent against opportunistic theft and shoulder-surfing. Settings UI and notch architecture adapted from Glance (jonnyoo/glance). Distributed under the MIT License.")
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Pupil"
    }

    private var versionString: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }
}
