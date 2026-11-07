//
//  AlarmSettingsPage.swift
//  Pupil
//
//  Siren tone configuration, test actions, and session activity log.
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
                SettingsRowContent(title: "Siren tone") {
                    SettingsMenuPickerPill(label: "\(settings.sirenFrequencyHz) Hz") {
                        ForEach(Self.frequencyPresets, id: \.self) { freq in
                            Button("\(freq) Hz") {
                                settings.sirenFrequencyHz = freq
                            }
                        }
                    }
                }
                SettingsGroupDivider()
                SettingsRowContent(title: "Test speaker") {
                    PillActionButton(title: "Play sound") {
                        SirenSynthesizer.shared.playTestChirp(baseFrequencyHz: Double(settings.sirenFrequencyHz))
                    }
                }
                SettingsGroupDivider()
                SettingsRowContent(
                    title: "Simulate tamper",
                    subtitle: "Starts a test countdown in the notch."
                ) {
                    HoldToConfirmButton(title: "Hold to test", holdDuration: 1.0) {
                        if coordinator.state == .disarmed {
                            coordinator.startArming(immediate: true)
                        }
                        coordinator.triggerTamper(source: .manualTest, immediateAlarm: false, simulated: true)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SettingsSectionTitle(text: "Activity")
                    Spacer()
                    if !coordinator.events.isEmpty {
                        Button("Clear") {
                            coordinator.clearEventLog()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PupilTheme.accent)
                        .padding(.trailing, 8)
                        .padding(.top, SettingsMetrics.sectionTitleVerticalPadding)
                    }
                }

                SettingsGroup {
                    if coordinator.events.isEmpty {
                        HStack {
                            Spacer()
                            Text("No recent activity")
                                .font(.system(size: 13))
                                .foregroundStyle(SettingsMetrics.textTertiary)
                                .padding(.vertical, 22)
                            Spacer()
                        }
                    } else {
                        ForEach(Array(coordinator.events.prefix(10).enumerated()), id: \.element.id) { index, event in
                            if index > 0 {
                                SettingsGroupDivider()
                            }
                            HStack(alignment: .center, spacing: 10) {
                                Circle()
                                    .fill(dotColor(for: event.stateAtEvent))
                                    .frame(width: 6, height: 6)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(SettingsMetrics.textPrimary)
                                    Text(event.detail)
                                        .font(.system(size: 11))
                                        .foregroundStyle(SettingsMetrics.textTertiary)
                                }

                                Spacer()

                                Text(event.timestamp.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 12))
                                    .foregroundStyle(SettingsMetrics.textTertiary)
                            }
                            .padding(.horizontal, SettingsMetrics.rowHorizontalInset)
                            .padding(.vertical, 10)
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
