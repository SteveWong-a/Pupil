//
//  LockMonitor.swift
//  Pupil
//
//  Detects macOS screen lock/unlock and display wake events using DistributedNotificationCenter
//  and NSWorkspace, modeled directly after Glance's LockMonitor.
//

import AppKit
import CoreGraphics
import Foundation
import Observation

public enum LockEventKind: Sendable, Equatable {
    case screenLocked
    case screenUnlocked
    case willSleep
    case wake
}

@MainActor
@Observable
public final class LockMonitor {
    public private(set) var isScreenLocked: Bool = false
    public private(set) var isSleeping: Bool = false
    public private(set) var lastEvent: LockEventKind?
    public private(set) var eventCount: Int = 0

    public var onLockEvent: ((LockEventKind) -> Void)?

    private var distributedObservers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []

    public init() {
        startMonitoring()
    }

    private func startMonitoring() {
        let distributed = DistributedNotificationCenter.default()
        distributedObservers.append(
            distributed.addObserver(
                forName: Notification.Name("com.apple.screenIsLocked"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.isScreenLocked = true
                    self?.record(.screenLocked)
                }
            }
        )
        distributedObservers.append(
            distributed.addObserver(
                forName: Notification.Name("com.apple.screenIsUnlocked"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.isScreenLocked = false
                    self?.record(.screenUnlocked)
                }
            }
        )

        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            workspace.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.isSleeping = true
                    self?.record(.willSleep)
                }
            }
        )
        workspaceObservers.append(
            workspace.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.isSleeping = false
                    self?.record(.wake)
                }
            }
        )
        workspaceObservers.append(
            workspace.addObserver(
                forName: NSWorkspace.screensDidWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.isSleeping = false
                    self?.record(.wake)
                }
            }
        )
    }

    private func record(_ kind: LockEventKind) {
        lastEvent = kind
        eventCount += 1
        onLockEvent?(kind)
    }
}
