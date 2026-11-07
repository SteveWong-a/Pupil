//
//  GazeSettingsPage.swift
//  Pupil
//
//  Apple Vision Iris & Head-Pose gaze configuration and live telemetry card.
//

import AVFoundation
import SwiftUI

public struct GazeSettingsPage: View {
    @Bindable var coordinator: SecurityCoordinator
    @Bindable private var settings = PupilSettings.shared

    public init(coordinator: SecurityCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SettingsMetrics.rowSpacing) {
            SettingsGroup {
                SettingsRowContent(
                    title: "Enable Gaze Deterrence",
                    subtitle: "Uses Apple Vision landmarks to open the watchful eye when someone stares at your screen.",
                    subtitleMaxWidth: SettingsMetrics.rowSubtitleMaxWidth
                ) {
                    PupilToggle(isOn: Binding(
                        get: { settings.gazeDetectionEnabled },
                        set: { val in
                            settings.gazeDetectionEnabled = val
                            coordinator.syncCameraLifecycle()
                        }
                    ))
                }
                SettingsGroupDivider()
                cameraDevicePickerRow
            }

            VStack(alignment: .leading, spacing: 8) {
                SettingsSectionTitle(text: "Notch Deterrent Style")
                SettingsGroup {
                    SettingsRowContent(
                        title: "Animation style",
                        subtitle: settings.notchStyle.subtitle,
                        subtitleMaxWidth: 165
                    ) {
                        HStack(spacing: 8) {
                            ForEach(NotchDeterrentStyle.allCases) { style in
                                SettingsOptionTile(
                                    title: style.title,
                                    isSelected: settings.notchStyle == style,
                                    action: {
                                        settings.notchStyle = style
                                        coordinator.simulateGazeWarning()
                                    },
                                    previewHeight: 42,
                                    previewWidth: 74
                                ) {
                                    deterrentStylePreview(style)
                                }
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SettingsSectionTitle(text: "Cone Sensitivity & Dwell")
                SettingsGroup {
                    SettingsRowContent(
                        title: "Gaze cone sensitivity",
                        subtitle: settings.gazeSensitivity.subtitle,
                        subtitleMaxWidth: 165
                    ) {
                        HStack(spacing: 8) {
                            ForEach(GazeSensitivity.allCases) { mode in
                                SettingsOptionTile(
                                    title: mode.title,
                                    isSelected: settings.gazeSensitivity == mode,
                                    action: { settings.gazeSensitivity = mode },
                                    previewHeight: 40,
                                    previewWidth: 68
                                ) {
                                    Image(systemName: mode.iconName)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(settings.gazeSensitivity == mode ? PupilTheme.accent : SettingsMetrics.textSecondary)
                                }
                            }
                        }
                    }
                    SettingsGroupDivider()
                    SettingsSteppedSliderRowContent(
                        title: "Sustained dwell threshold",
                        valueLabel: String(format: "%.1f seconds", settings.dwellThresholdSeconds),
                        index: $settings.dwellSliderIndex,
                        stopCount: PupilSettings.dwellStops.count
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SettingsSectionTitle(text: "On-Device Apple Vision Telemetry")
                liveTelemetryCard
            }
        }
        .onDisappear {
            coordinator.setCameraPreviewRequested(false)
        }
    }

    private var cameraDevicePickerRow: some View {
        SettingsRowContent(title: "Camera input") {
            SettingsMenuPickerPill(label: selectedCameraName) {
                Button("Built-in FaceTime Camera (Default)") {
                    settings.preferredCameraID = nil
                }
                Divider()
                ForEach(coordinator.cameraManager.availableCameras) { cam in
                    Button(cam.name) {
                        settings.preferredCameraID = cam.id
                    }
                }
            }
        }
    }

    private var selectedCameraName: String {
        guard let id = settings.preferredCameraID,
              let match = coordinator.cameraManager.availableCameras.first(where: { $0.id == id }) else {
            return coordinator.cameraManager.availableCameras.first?.name ?? "Built-in Camera"
        }
        return match.name
    }

    @ViewBuilder
    private func deterrentStylePreview(_ style: NotchDeterrentStyle) -> some View {
        switch style {
        case .minimalPill:
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 5, height: 5)
                Capsule()
                    .fill(Color.black)
                    .frame(width: 24, height: 10)
                    .overlay(
                        Capsule()
                            .strokeBorder(Color(white: 0.22), lineWidth: 0.8)
                    )
            }
        case .silent:
            Image(systemName: "eye.slash")
                .font(.system(size: 14))
                .foregroundStyle(SettingsMetrics.textSecondary)
        }
    }

    private var liveTelemetryCard: some View {
        SettingsGroup {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.65))
                        .frame(width: 88, height: 64)
                    PupilEyeVectorView(
                        isOpen: coordinator.cameraManager.isRunning || coordinator.isGazeWarningActive,
                        lookOffset: coordinator.eyeLookOffset,
                        accentColor: Color.white.opacity(0.85),
                        size: 36
                    )
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(coordinator.cameraManager.isRunning ? "Vision Pipeline Active (10 FPS)" : "Camera Idle (Privacy Preserved)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(SettingsMetrics.textPrimary)
                        Spacer()
                        Text(String(format: "Score: %.0f%%", coordinator.latestGazeScore * 100))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(SettingsMetrics.textSecondary)
                    }

                    ProgressView(value: coordinator.gazeDwellProgress)
                        .tint(Color.white.opacity(0.85))

                    Text("Faces in ROI: \(coordinator.activeFaceCount) · Zero frames written to disk")
                        .font(.system(size: 10))
                        .foregroundStyle(SettingsMetrics.textTertiary)
                }
            }
            .padding(.horizontal, SettingsMetrics.rowHorizontalInset)
            .padding(.vertical, 12)

            SettingsGroupDivider()

            SettingsActionRowContent(
                title: "Live Camera Calibration",
                subtitle: "Test iris and head-pose tracking right now without arming.",
                buttonTitle: coordinator.isCameraPreviewRequested ? "Stop Calibration" : "Start Calibration"
            ) {
                if coordinator.isCameraPreviewRequested {
                    coordinator.setCameraPreviewRequested(false)
                } else {
                    Task {
                        let granted = await coordinator.cameraManager.requestCameraAccess()
                        if granted {
                            coordinator.setCameraPreviewRequested(true)
                        }
                    }
                }
            }
        }
    }
}
