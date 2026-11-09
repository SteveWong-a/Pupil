//
//  GazeSettingsPage.swift
//  Pupil
//
//  Camera & Gaze settings page modeled directly after Glance's CameraSettingsPage
//  and RecognitionSettingsPage, featuring a real on-demand AVCaptureVideoPreviewLayer.
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
                SettingsRowContent(title: "Gaze deterrence") {
                    PupilToggle(isOn: Binding(
                        get: { settings.gazeDetectionEnabled },
                        set: { val in
                            settings.gazeDetectionEnabled = val
                            if !val {
                                coordinator.setCameraPreviewRequested(false)
                                coordinator.dismissGazeWarning()
                            }
                            coordinator.syncCameraLifecycle()
                        }
                    ))
                }
                SettingsGroupDivider()
                SettingsRowContent(
                    title: "Blur screen on gaze",
                    info: "Instantly covers display content with frosted glass while someone looks at your screen, clearing when they look away."
                ) {
                    PupilToggle(isOn: $settings.blurScreenOnGaze)
                }
                SettingsGroupDivider()
                cameraDevicePickerRow
                SettingsGroupDivider()
                SettingsLabeledOptionRow(
                    title: "Style",
                    subtitle: "Choose how Pupil responds when someone looks at your screen."
                ) {
                    ForEach(NotchDeterrentStyle.allCases) { style in
                        let isSelected = settings.notchStyle == style
                        SettingsOptionTile(
                            title: style.title,
                            isSelected: isSelected,
                            action: {
                                settings.notchStyle = style
                                coordinator.simulateGazeWarning()
                            },
                            previewHeight: SettingsMetrics.optionPreviewHeight,
                            previewWidth: SettingsMetrics.optionTileWidth
                        ) {
                            deterrentStylePreview(style, isSelected: isSelected)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SettingsSectionTitle(text: "Sensitivity")
                SettingsGroup {
                    SettingsOptionSliderRowContent(
                        title: "Detection cone",
                        stepLabels: GazeSensitivity.allCases.map(\.title),
                        index: $settings.gazeSensitivityIndex,
                        stopCount: GazeSensitivity.allCases.count
                    )
                    SettingsGroupDivider()
                    SettingsSteppedSliderRowContent(
                        title: "Dwell duration",
                        valueLabel: String(format: "%.1f seconds", settings.dwellThresholdSeconds),
                        index: $settings.dwellSliderIndex,
                        stopCount: PupilSettings.dwellStops.count
                    )
                }
                SettingsCaption(text: "Higher sensitivity detects wider peripheral angles (Ultra catches side shoulder-surfing); dwell duration controls how quickly the privacy blur or deterrent triggers.")
            }

            VStack(alignment: .leading, spacing: 8) {
                SettingsSectionTitle(text: "Preview")
                liveCameraPreviewCard
                SettingsCaption(text: "Preview is only active while shown. All frames are processed in memory and never saved.")
            }
        }
        .onDisappear {
            coordinator.setCameraPreviewRequested(false)
        }
    }

    private var cameraDevicePickerRow: some View {
        SettingsRowContent(title: "Camera") {
            SettingsMenuPickerPill(label: selectedCameraName) {
                Button("Default (\(defaultCameraName))") {
                    settings.preferredCameraID = nil
                }
                if !coordinator.cameraManager.availableCameras.isEmpty {
                    Divider()
                    ForEach(coordinator.cameraManager.availableCameras) { cam in
                        Button(cam.name) {
                            settings.preferredCameraID = cam.id
                        }
                    }
                }
            }
        }
    }

    private var defaultCameraName: String {
        coordinator.cameraManager.availableCameras.first?.name ?? "Built-in Camera"
    }

    private var selectedCameraName: String {
        guard let id = settings.preferredCameraID,
              let match = coordinator.cameraManager.availableCameras.first(where: { $0.id == id }) else {
            return "Default (\(defaultCameraName))"
        }
        return match.name
    }

    @ViewBuilder
    private func deterrentStylePreview(_ style: NotchDeterrentStyle, isSelected: Bool) -> some View {
        let tint: Color = isSelected
            ? SettingsMetrics.textPrimary.opacity(0.75)
            : SettingsMetrics.textSecondary.opacity(0.65)
        switch style {
        case .minimalPill:
            Capsule()
                .fill(tint)
                .frame(width: 50, height: 14)
        case .silent:
            Image(systemName: "eye.slash")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(tint)
        }
    }

    private var liveCameraPreviewCard: some View {
        VStack(spacing: 0) {
            ZStack {
                if coordinator.isCameraPreviewRequested {
                    CameraPreviewView(session: coordinator.cameraManager.captureSessionReference)
                        .transition(.opacity)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(SettingsMetrics.textTertiary)
                        Text("Preview is off")
                            .font(.system(size: 12))
                            .foregroundStyle(SettingsMetrics.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 196)
            .background(Color.black.opacity(0.18))
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: SettingsMetrics.rowRadius,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: SettingsMetrics.rowRadius
                )
            )

            Rectangle()
                .fill(SettingsMetrics.rowBorder)
                .frame(height: SettingsMetrics.rowBorderWidth)

            HStack {
                if coordinator.isCameraPreviewRequested {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(coordinator.activeFaceCount > 0 ? PupilTheme.armedGreen : SettingsMetrics.textTertiary)
                            .frame(width: 6, height: 6)
                        Text(coordinator.activeFaceCount > 0 ? "Face detected" : "No face detected")
                            .font(.system(size: 12))
                            .foregroundStyle(SettingsMetrics.textSecondary)
                    }
                }
                Spacer()
                PillActionButton(
                    title: coordinator.isCameraPreviewRequested ? "Hide preview" : "Show preview"
                ) {
                    togglePreview()
                }
            }
            .padding(.horizontal, SettingsMetrics.rowHorizontalInset)
            .frame(height: SettingsMetrics.rowHeight)
        }
        .background(SettingsMetrics.rowColor)
        .overlay(
            RoundedRectangle(cornerRadius: SettingsMetrics.rowRadius)
                .strokeBorder(SettingsMetrics.rowBorder, lineWidth: SettingsMetrics.rowBorderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: SettingsMetrics.rowRadius))
    }

    private func togglePreview() {
        if coordinator.isCameraPreviewRequested {
            withAnimation(.easeInOut(duration: 0.18)) {
                coordinator.setCameraPreviewRequested(false)
            }
        } else {
            Task {
                let granted = await coordinator.cameraManager.requestCameraAccess()
                if granted {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        coordinator.setCameraPreviewRequested(true)
                    }
                }
            }
        }
    }
}
