//
//  NotchOverlayController.swift
//  Pupil
//
//  Owns and positions the borderless NotchWindow on the active NSScreen.
//

import AppKit
import SwiftUI

@MainActor
public final class NotchOverlayController {
    private var panel: NotchWindow?
    private weak var coordinator: SecurityCoordinator?

    public init(coordinator: SecurityCoordinator) {
        self.coordinator = coordinator
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.repositionWindow()
            }
        }
    }

    public func syncWithCoordinator() {
        guard let coordinator else { return }
        let shouldShow = coordinator.state != .disarmed
        if shouldShow {
            ensureWindowInstalled()
            repositionWindow()
            panel?.orderFrontRegardless()
        } else {
            panel?.ignoresMouseEvents = true
            panel?.activeNotchSize = .zero
            panel?.orderOut(nil)
            panel?.contentView = nil
            panel = nil
        }
    }

    private func ensureWindowInstalled() {
        guard panel == nil, let coordinator else { return }
        let geometry = NotchGeometry.forPreferredScreen()
        let winSize = NotchGeometry.windowSize(for: geometry.style)
        let window = NotchWindow(contentRect: NSRect(origin: .zero, size: winSize))

        let rootView = NotchOverlayView(
            coordinator: coordinator,
            geometry: geometry,
            onRequestInteractive: { [weak window] interactive, size in
                guard let window else { return }
                window.acceptsKey = interactive
                window.ignoresMouseEvents = !interactive
                window.activeNotchSize = size
                if interactive {
                    window.makeKey()
                }
            }
        )
        window.contentView = NotchHostingView(rootView: rootView, window: window)
        self.panel = window
    }

    public func repositionWindow() {
        guard let coordinator, coordinator.state != .disarmed else {
            panel?.ignoresMouseEvents = true
            panel?.activeNotchSize = .zero
            panel?.orderOut(nil)
            panel?.contentView = nil
            panel = nil
            return
        }
        guard let panel, let screen = NotchGeometry.preferredScreen() else { return }
        let geometry = NotchGeometry.forScreen(screen)
        let winSize = NotchGeometry.windowSize(for: geometry.style)
        let screenFrame = screen.frame
        let originX = screenFrame.midX - (winSize.width / 2)
        let originY = screenFrame.maxY - winSize.height
        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
    }
}
