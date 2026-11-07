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
    }

    public func syncWithCoordinator() {
        guard let coordinator else { return }
        let isArmedOrEscalated = (coordinator.state == .armed || coordinator.state == .tamperPending || coordinator.state == .alarm)
        let shouldShow = coordinator.isShieldPreviewActive || (isArmedOrEscalated && coordinator.settings.blurBackgroundWhenArmed)

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
            for screen in NSScreen.screens {
                let window = makeShieldWindow(for: screen, coordinator: coordinator)
                shieldWindows.append(window)
            }
        } else {
            // Reposition existing windows to screen frames
            for (index, screen) in NSScreen.screens.enumerated() {
                guard shieldWindows.indices.contains(index) else { continue }
                shieldWindows[index].setFrame(screen.frame, display: true)
            }
        }

        guard !isVisible else { return }
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

        // Make the primary screen's shield key for immediate keyboard PIN input
        if let primary = shieldWindows.first {
            primary.makeKey()
        }
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
        for screen in NSScreen.screens {
            let window = makeShieldWindow(for: screen, coordinator: coordinator)
            window.alphaValue = 1.0
            window.orderFrontRegardless()
            shieldWindows.append(window)
        }
        if let primary = shieldWindows.first {
            primary.makeKey()
        }
    }

    private func makeShieldWindow(for screen: NSScreen, coordinator: SecurityCoordinator) -> ScreenShieldWindow {
        let window = ScreenShieldWindow(contentRect: screen.frame)
        window.setFrame(screen.frame, display: true)

        let rootView = ScreenShieldView(coordinator: coordinator)
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

