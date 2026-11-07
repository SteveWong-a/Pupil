//
//  SensorsSettingsPage.swift
//  Pupil
//
//  Hardware tamper sensors (IOKit AC power, AppleClamshellState lid close, macOS lock monitor).
//

import SwiftUI

public struct SensorsSettingsPage: View {
    @Bindable var coordinator: SecurityCoordinator
    @Bindable private var settings = PupilSettings.shared

    public init(coordinator: SecurityCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SettingsMetrics.rowSpacing) {
            SettingsGroup {
                SettingsRowContent(
                    title: "Hardware Tamper Triggers",
                    subtitle: "Select which physical events escalate while armed.",
                    subtitleMaxWidth: 165
                ) {
                    HStack(spacing: 8) {
                        ForEach(HardwareTrigger.allCases) { trigger in
                            let isSelected = settings.hardwareTriggers.contains(trigger)
                            SettingsOptionTile(
                                title: trigger.title,
                                isSelected: isSelected,
                                action: { toggleTrigger(trigger, isSelected: isSelected) },
                                previewHeight: 42,
                                previewWidth: 74
                            ) {
                                Image(systemName: trigger.iconName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(isSelected ? PupilTheme.accent : SettingsMetrics.textSecondary)
                            }
                        }
                    }
                }
                SettingsGroupDivider()
                SettingsRowContent(
                    title: "Hold system sleep during lid-close alarm",
                    subtitle: "Acquires an IOKit power assertion so the siren keeps sounding before sleep.",
                    subtitleMaxWidth: SettingsMetrics.rowSubtitleMaxWidth
                ) {
                    PupilToggle(isOn: $settings.holdSleepOnLidClose)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SettingsSectionTitle(text: "Live IOKit Hardware State")
                SettingsGroup {
                    sensorReadoutRow(
                        title: "Power Source (IOPSCopyPowerSourcesInfo)",
                        icon: coordinator.powerMonitor.isOnACPower ? "bolt.fill" : "battery.75percent",
                        tint: coordinator.powerMonitor.isOnACPower ? PupilTheme.armedGreen : PupilTheme.warningAmber,
                        value: coordinator.powerMonitor.isOnACPower ? "AC Charger Connected" : "Running on Battery"
                    )
                    SettingsGroupDivider()
                    sensorReadoutRow(
                        title: "Clamshell Lid (AppleClamshellState)",
                        icon: "laptopcomputer",
                        tint: PupilTheme.armedGreen,
                        value: coordinator.powerMonitor.isLidClosed ? "Closed" : "Open"
                    )
                    SettingsGroupDivider()
                    sensorReadoutRow(
                        title: "Sleep Prevention Assertion (IOPMAssertion)",
                        icon: coordinator.powerMonitor.isSleepAssertionActive ? "lock.shield.fill" : "moon.zzz",
                        tint: coordinator.powerMonitor.isSleepAssertionActive ? PupilTheme.accent : SettingsMetrics.textSecondary,
                        value: coordinator.powerMonitor.isSleepAssertionActive ? "Active (Holding Awake)" : "Standby"
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SettingsSectionTitle(text: "Phone Alert Relay")
                SettingsGroup {
                    SettingsRowContent(
                        title: "Enable WebSocket Phone Relay",
                        subtitle: "Pushes tamper countdowns and alarm events to your paired phone."
                    ) {
                        PupilToggle(isOn: $settings.relayEnabled)
                    }
                    SettingsGroupDivider()
                    SettingsRowContent(title: "Relay endpoint") {
                        TextField("ws://127.0.0.1:8787", text: $settings.relayURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(width: 200)
                            .disabled(!settings.relayEnabled)
                    }
                }
            }
        }
    }

    private func toggleTrigger(_ trigger: HardwareTrigger, isSelected: Bool) {
        if isSelected {
            guard settings.hardwareTriggers.count > 1 else { return }
            settings.hardwareTriggers.remove(trigger)
        } else {
            settings.hardwareTriggers.insert(trigger)
        }
    }

    private func sensorReadoutRow(title: String, icon: String, tint: Color, value: String) -> some View {
        SettingsRowContent(title: title) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SettingsMetrics.textSecondary)
            }
        }
    }
}
