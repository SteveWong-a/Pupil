//
//  ScreenShieldController.swift
//  Pupil
//
//  Manages the multi-display full-screen privacy blur shield windows.
//  Blurs all displays while armed and prevents unblurring until disarmed with Keychain PIN or Touch ID.
//

import AppKit
import SwiftUI

@MainActor
public final class ScreenShieldController {
    private weak var coordinator: SecurityCoordinator?
    private var shieldWindows: [ScreenShieldWindow] = []
    private var isVisible = false

    public init(coordinator: SecurityCoordinator) {
        self.coordinator = coordinator

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reconfigureForCurrentScreens()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .screenShieldFocusPrimary,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.activatePrimary()
            }
        }
    }

    public func syncWithCoordinator() {
        guard let coordinator else { return }
        let isArmedOrEscalated = (coordinator.state == .armed || coordinator.state == .tamperPending || coordinator.state == .alarm)
        let isArmedBlur = isArmedOrEscalated && coordinator.settings.blurBackgroundWhenArmed
        let isGazePrivacyBlur = (coordinator.state == .armed && coordinator.isGazeWarningActive && coordinator.settings.blurScreenOnGaze)
        let shouldShow = coordinator.isShieldPreviewActive || isArmedBlur || isGazePrivacyBlur

        if shouldShow {
            showShield()
        } else {
            hideShield()
        }
    }

    private func showShield() {
        guard let coordinator else { return }

        // If screens count changed or no windows yet, build windows
        if shieldWindows.count != NSScreen.screens.count {
            destroyWindows()
            for (index, screen) in NSScreen.screens.enumerated() {
                let window = makeShieldWindow(for: screen, isPrimary: index == 0, coordinator: coordinator)
                shieldWindows.append(window)
            }
        } else {
            // Reposition existing windows to screen frames
            for (index, screen) in NSScreen.screens.enumerated() {
                guard shieldWindows.indices.contains(index) else { continue }
                shieldWindows[index].setFrame(screen.frame, display: true)
            }
        }

        guard !isVisible else {
            activatePrimary()
            return
        }
        isVisible = true

        for window in shieldWindows {
            window.alphaValue = 0.0
            window.orderFrontRegardless()
        }

        // Animate smooth fade-in
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for window in shieldWindows {
                window.animator().alphaValue = 1.0
            }
        }

        // Make the primary screen's shield key and activate the application for immediate keyboard PIN input
        activatePrimary()
    }

    private func hideShield() {
        guard isVisible else { return }
        isVisible = false

        let windowsToHide = shieldWindows
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for window in windowsToHide {
                window.animator().alphaValue = 0.0
            }
        }, completionHandler: {
            for window in windowsToHide {
                window.orderOut(nil)
            }
        })
    }

    private func reconfigureForCurrentScreens() {
        guard isVisible, let coordinator else { return }
        destroyWindows()
        for (index, screen) in NSScreen.screens.enumerated() {
            let window = makeShieldWindow(for: screen, isPrimary: index == 0, coordinator: coordinator)
            window.alphaValue = 1.0
            window.orderFrontRegardless()
            shieldWindows.append(window)
        }
        activatePrimary()
    }

    private func activatePrimary() {
        NSApp.activate(ignoringOtherApps: true)
        if let primary = shieldWindows.first {
            primary.makeKeyAndOrderFront(nil)
        }
    }

    private func makeShieldWindow(for screen: NSScreen, isPrimary: Bool, coordinator: SecurityCoordinator) -> ScreenShieldWindow {
        let window = ScreenShieldWindow(contentRect: screen.frame)
        window.setFrame(screen.frame, display: true)

        let rootView = ScreenShieldView(coordinator: coordinator, isPrimary: isPrimary)
        window.contentView = NSHostingView(rootView: rootView)
        return window
    }

    private func destroyWindows() {
        for window in shieldWindows {
            window.orderOut(nil)
        }
        shieldWindows.removeAll()
    }
}

