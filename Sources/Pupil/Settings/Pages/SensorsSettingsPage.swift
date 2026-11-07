//
//  SensorsSettingsPage.swift
//  Pupil
//
//  Hardware tamper triggers, sleep assertion behavior, and live sensor status.
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
                SettingsLabeledOptionRow(
                    title: "Triggers",
                    subtitle: "Choose which physical events trigger the tamper countdown while armed."
                ) {
                    ForEach(HardwareTrigger.allCases) { trigger in
                        let isSelected = settings.hardwareTriggers.contains(trigger)
                        let tint: Color = isSelected
                            ? SettingsMetrics.textPrimary.opacity(0.75)
                            : SettingsMetrics.textSecondary.opacity(0.65)
                        SettingsOptionTile(
                            title: trigger.title,
                            isSelected: isSelected,
                            action: { toggleTrigger(trigger, isSelected: isSelected) },
                            previewHeight: SettingsMetrics.optionPreviewHeight,
                            previewWidth: SettingsMetrics.optionTileWidth
                        ) {
                            Image(systemName: trigger.iconName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(tint)
                        }
                    }
                }
                SettingsGroupDivider()
                SettingsRowContent(
                    title: "Prevent sleep during alarm",
                    info: "Keeps your Mac awake while the lid-close alarm is sounding."
                ) {
                    PupilToggle(isOn: $settings.holdSleepOnLidClose)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SettingsSectionTitle(text: "Hardware Status")
                SettingsGroup {
                    sensorReadoutRow(
                        title: "Power source",
                        icon: coordinator.powerMonitor.isOnACPower ? "bolt.fill" : "battery.75percent",
                        tint: coordinator.powerMonitor.isOnACPower ? PupilTheme.armedGreen : PupilTheme.warningAmber,
                        value: coordinator.powerMonitor.isOnACPower ? "Power Adapter" : "Battery"
                    )
                    SettingsGroupDivider()
                    sensorReadoutRow(
                        title: "Display lid",
                        icon: "laptopcomputer",
                        tint: PupilTheme.armedGreen,
                        value: coordinator.powerMonitor.isLidClosed ? "Closed" : "Open"
                    )
                    SettingsGroupDivider()
                    sensorReadoutRow(
                        title: "Sleep assertion",
                        icon: coordinator.powerMonitor.isSleepAssertionActive ? "bolt.shield.fill" : "moon.zzz",
                        tint: coordinator.powerMonitor.isSleepAssertionActive ? PupilTheme.accent : SettingsMetrics.textSecondary,
                        value: coordinator.powerMonitor.isSleepAssertionActive ? "Active" : "Idle"
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SettingsSectionTitle(text: "Remote Relay")
                SettingsGroup {
                    SettingsRowContent(
                        title: "WebSocket notifications",
                        info: "Forwards tamper countdowns and alarm events to a local or remote WebSocket endpoint."
                    ) {
                        PupilToggle(isOn: $settings.relayEnabled)
                    }
                    SettingsGroupDivider()
                    SettingsRowContent(title: "Endpoint") {
                        TextField("ws://127.0.0.1:8787", text: $settings.relayURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
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
                    .font(.system(size: 13))
                    .foregroundStyle(SettingsMetrics.textSecondary)
            }
        }
    }
}
