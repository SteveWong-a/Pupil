//
//  HeaderStatusButton.swift
//  Pupil
//
//  The Settings window header's trailing pill, modeled directly after Glance's SessionLockButton.
//  Shows live security state with animated SF Symbol transitions and one-click Arm / Disarm popover.
//

import SwiftUI

public struct HeaderStatusButton: View {
    @Bindable var coordinator: SecurityCoordinator

    @State private var showDisarmPopover = false
    @State private var pinInput = ""
    @State private var pinError = false

    public init(coordinator: SecurityCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 7) {
                Circle()
                    .fill(statusDotColor)
                    .frame(width: 7, height: 7)

                Image(systemName: coordinator.menuBarSymbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))

                Text(statusLabel)
                    .font(SettingsMetrics.headerButtonFont)
                    .contentTransition(.opacity)
            }
            .foregroundStyle(SettingsMetrics.textPrimary)
            .padding(.horizontal, 12)
            .frame(height: SettingsMetrics.headerButtonHeight)
            .background(Capsule().fill(SettingsMetrics.rowColor))
            .overlay(
                Capsule()
                    .strokeBorder(borderColor, lineWidth: SettingsMetrics.rowBorderWidth)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(SettingsMetrics.stateTransitionAnimation, value: coordinator.state)
        .popover(isPresented: $showDisarmPopover, arrowEdge: .bottom) {
            disarmPopoverContent
        }
    }

    private var statusDotColor: Color {
        switch coordinator.state {
        case .disarmed: return Color.secondary.opacity(0.5)
        case .arming: return PupilTheme.warningAmber
        case .armed: return coordinator.isGazeWarningActive ? Color.cyan : PupilTheme.armedGreen
        case .tamperPending: return PupilTheme.warningAmber
        case .alarm: return PupilTheme.alarmRed
        }
    }

    private var borderColor: Color {
        switch coordinator.state {
        case .alarm: return PupilTheme.alarmRed.opacity(0.65)
        case .tamperPending: return PupilTheme.warningAmber.opacity(0.55)
        case .armed: return PupilTheme.armedGreen.opacity(0.35)
        default: return SettingsMetrics.rowBorder
        }
    }

    private var statusLabel: String {
        switch coordinator.state {
        case .disarmed:
            return "Disarmed — Click to Arm"
        case .arming:
            return "Arming (\(coordinator.countdownSecondsRemaining)s)…"
        case .armed:
            return coordinator.isGazeWarningActive ? "Gaze Warning" : "Armed & Monitoring"
        case .tamperPending:
            return "Tamper (\(coordinator.countdownSecondsRemaining)s)"
        case .alarm:
            return "ALARM LATCHED"
        }
    }

    private func handleTap() {
        switch coordinator.state {
        case .disarmed:
            coordinator.startArming()
        case .arming:
            coordinator.cancelArmingDuringExitDelay()
        case .armed, .tamperPending, .alarm:
            pinInput = ""
            pinError = false
            showDisarmPopover = true
        }
    }

    private var disarmPopoverContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(PupilTheme.accent)
                Text("Disarm Pupil")
                    .font(.system(size: 13, weight: .semibold))
            }

            SecureField("Enter 4–8 digit PIN", text: $pinInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, design: .monospaced))
                .frame(width: 190)
                .onSubmit {
                    submitDisarmPin()
                }

            if pinError {
                Text("Incorrect PIN. Default is 1234.")
                    .font(.system(size: 11))
                    .foregroundStyle(PupilTheme.alarmRed)
            }

            HStack(spacing: 8) {
                Button("Disarm") {
                    submitDisarmPin()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                if coordinator.settings.allowTouchIDDisarm {
                    Button {
                        Task {
                            let ok = await coordinator.disarmWithTouchID()
                            if ok {
                                showDisarmPopover = false
                            }
                        }
                    } label: {
                        Label("Touch ID", systemImage: "touchid")
                    }
                    .controlSize(.small)
                }
            }
        }
        .padding(12)
    }

    private func submitDisarmPin() {
        if coordinator.disarmWithPin(pinInput) {
            pinError = false
            pinInput = ""
            showDisarmPopover = false
        } else {
            pinError = true
            pinInput = ""
        }
    }
}
