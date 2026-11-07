//
//  AlarmSettingsPage.swift
//  Pupil
//
//  Native AVAudioEngine siren configuration, tamper simulation, and live security audit log.
//

import SwiftUI

public struct AlarmSettingsPage: View {
    @Bindable var coordinator: SecurityCoordinator
    @Bindable private var settings = PupilSettings.shared

    private static let frequencyPresets: [Int] = [660, 880, 1046, 1320]

    public init(coordinator: SecurityCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SettingsMetrics.rowSpacing) {
            SettingsGroup {
                SettingsRowContent(
                    title: "Siren pitch profile",
                    subtitle: "Synthesizes a dual-tone alternating square wave directly via AVAudioEngine."
                ) {
                    SettingsMenuPickerPill(label: "\(settings.sirenFrequencyHz) Hz / \(Int(Double(settings.sirenFrequencyHz) * 0.75)) Hz") {
                        ForEach(Self.frequencyPresets, id: \.self) { freq in
                            Button("\(freq) Hz Dual-Tone") {
                                settings.sirenFrequencyHz = freq
                            }
                        }
                    }
                }
                SettingsGroupDivider()
                SettingsActionRowContent(
                    title: "Test Siren Output",
                    subtitle: "Plays a 1.2-second audible chirp to verify speaker volume.",
                    buttonTitle: "Play Chirp"
                ) {
                    SirenSynthesizer.shared.playTestChirp(baseFrequencyHz: Double(settings.sirenFrequencyHz))
                }
                SettingsGroupDivider()
                SettingsActionRowContent(
                    title: "Simulate Tamper Countdown",
                    subtitle: "Arms Pupil and triggers a simulated power-unplug countdown in the notch.",
                    buttonTitle: "Simulate Tamper",
                    isDestructive: true
                ) {
                    if coordinator.state == .disarmed {
                        coordinator.startArming(immediate: true)
                    }
                    coordinator.triggerTamper(source: .manualTest, immediateAlarm: false, simulated: true)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SettingsSectionTitle(text: "Session Event Log (\(coordinator.events.count))")
                    Spacer()
                    if !coordinator.events.isEmpty {
                        Button("Clear") {
                            coordinator.clearEventLog()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PupilTheme.accent)
                        .padding(.trailing, 8)
                    }
                }

                SettingsGroup {
                    if coordinator.events.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 6) {
                                Image(systemName: "checkmark.shield")
                                    .font(.system(size: 20))
                                    .foregroundStyle(SettingsMetrics.textTertiary)
                                Text("No security events recorded in this session.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(SettingsMetrics.textSecondary)
                            }
                            .padding(.vertical, 24)
                            Spacer()
                        }
                    } else {
                        ForEach(Array(coordinator.events.prefix(12).enumerated()), id: \.element.id) { index, event in
                            if index > 0 {
                                SettingsGroupDivider()
                            }
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(dotColor(for: event.stateAtEvent))
                                    .frame(width: 7, height: 7)
                                    .padding(.top, 5)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(event.title)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(SettingsMetrics.textPrimary)
                                        if event.isSimulated {
                                            Text("SIM")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(PupilTheme.warningAmber)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(Capsule().fill(PupilTheme.warningAmber.opacity(0.16)))
                                        }
                                        Spacer()
                                        Text(event.timestamp.formatted(date: .omitted, time: .standard))
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(SettingsMetrics.textTertiary)
                                    }
                                    Text(event.detail)
                                        .font(.system(size: 11))
                                        .foregroundStyle(SettingsMetrics.textSecondary)
                                }
                            }
                            .padding(.horizontal, SettingsMetrics.rowHorizontalInset)
                            .padding(.vertical, 9)
                        }
                    }
                }
            }
        }
    }

    private func dotColor(for state: SecurityState) -> Color {
        switch state {
        case .disarmed: return .secondary
        case .arming: return PupilTheme.warningAmber
        case .armed: return PupilTheme.armedGreen
        case .tamperPending: return PupilTheme.warningAmber
        case .alarm: return PupilTheme.alarmRed
        }
    }
}
