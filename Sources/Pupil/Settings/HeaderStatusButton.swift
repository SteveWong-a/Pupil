//
//  HeaderStatusButton.swift
//  Pupil
//
//  The Settings window header's trailing pill, modeled directly after Glance's SessionLockButton.
//  Shows live lock state with animated SF Symbol transitions and one-click Arm / Unlock popover.
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

    private var isLocked: Bool {
        coordinator.state != .disarmed
    }

    public var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 6) {
                Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
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
                    .strokeBorder(SettingsMetrics.rowBorder, lineWidth: SettingsMetrics.rowBorderWidth)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(SettingsMetrics.stateTransitionAnimation, value: coordinator.state)
        .popover(isPresented: $showDisarmPopover, arrowEdge: .bottom) {
            disarmPopoverContent
        }
    }

    private var statusLabel: String {
        switch coordinator.state {
        case .disarmed:
            return "Arm"
        case .arming:
            return "Arming (\(coordinator.countdownSecondsRemaining)s)"
        case .armed:
            return "Armed"
        case .tamperPending:
            return "Tamper (\(coordinator.countdownSecondsRemaining)s)"
        case .alarm:
            return "Alarm"
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
            Text("Unlock Pupil")
                .font(.system(size: 13, weight: .semibold))

            SecureField("Enter PIN", text: $pinInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .frame(width: 180)
                .onSubmit {
                    submitDisarmPin()
                }

            if pinError {
                Text("Incorrect PIN")
                    .font(.system(size: 11))
                    .foregroundStyle(PupilTheme.alarmRed)
            }

            HStack(spacing: 8) {
                Button("Unlock") {
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
