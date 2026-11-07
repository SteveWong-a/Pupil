//
//  PupilApp.swift
//  Pupil
//
//  Main entry point, NSApplicationDelegate, and NSStatusItem menu bar integration,
//  modeled directly after Glance's glanceApp.swift.
//

import AppKit
import SwiftUI

@main
struct PupilApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        settingsWindow
    }

    private var settingsWindow: some Scene {
        let open = openWindow
        let delegate = appDelegate
        DispatchQueue.main.async {
            delegate.bindOpenWindowAction { open(id: "settings") }
        }
        return Window("Pupil Settings", id: "settings") {
            SettingsWindowView(coordinator: appDelegate.coordinator)
                .onAppear {
                    delegate.bindOpenWindowAction { open(id: "settings") }
                }
        }
        .defaultSize(SettingsMetrics.windowSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
        .restorationBehavior(.disabled)
    }
}

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    public let coordinator = SecurityCoordinator()
    private var notchOverlayController: NotchOverlayController?
    private var screenShieldController: ScreenShieldController?

    private var statusItem: NSStatusItem?
    private var statusHeaderItem: NSMenuItem?
    private var toggleArmItem: NSMenuItem?
    private var powerInfoItem: NSMenuItem?
    private var openSettingsWindowAction: (() -> Void)?

    public func bindOpenWindowAction(_ action: @escaping () -> Void) {
        openSettingsWindowAction = action
    }

    public func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusItemIfNeeded()

        let overlay = NotchOverlayController(coordinator: coordinator)
        self.notchOverlayController = overlay

        let shield = ScreenShieldController(coordinator: coordinator)
        self.screenShieldController = shield

        coordinator.onStateChanged = { [weak self] _ in
            self?.refreshStatusItemIconAndMenu()
            self?.notchOverlayController?.syncWithCoordinator()
            self?.screenShieldController?.syncWithCoordinator()
        }
        coordinator.onNotchUpdateNeeded = { [weak self] in
            self?.refreshStatusItemIconAndMenu()
            self?.notchOverlayController?.syncWithCoordinator()
            self?.screenShieldController?.syncWithCoordinator()
        }

        PupilSettings.shared.bindMenuBarVisibility { [weak self] visible in
            self?.setMenuBarVisibility(visible)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )

        // Reveal the Settings window immediately on launch unless launched silently
        if !CommandLine.arguments.contains("--silent") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.revealSettingsWindow()
            }
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        revealSettingsWindow()
        return true
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Prevent force-quitting via Cmd+Q while armed unless the user disarms first
        if coordinator.isMonitoring {
            if coordinator.state == .arming {
                coordinator.cancelArmingDuringExitDelay()
                return .terminateNow
            }
            revealSettingsWindow()
            screenShieldController?.syncWithCoordinator()
            NSSound.beep()
            return .terminateCancel
        }
        return .terminateNow
    }

    private func setMenuBarVisibility(_ isVisible: Bool) {
        if isVisible {
            installStatusItemIfNeeded()
        } else if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    private func installStatusItemIfNeeded() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "com.pupil.security.menubar"
        let menu = NSMenu()
        menu.delegate = self

        let header = NSMenuItem(title: "Pupil — Disarmed", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        self.statusHeaderItem = header

        let powerRow = NSMenuItem(title: "Power: Checking…", action: nil, keyEquivalent: "")
        powerRow.isEnabled = false
        menu.addItem(powerRow)
        self.powerInfoItem = powerRow

        menu.addItem(.separator())

        let armItem = NSMenuItem(title: "Arm Pupil", action: #selector(toggleArmState), keyEquivalent: "a")
        armItem.target = self
        menu.addItem(armItem)
        self.toggleArmItem = armItem

        let previewEyeItem = NSMenuItem(
            title: "Preview Notch Gaze Deterrent",
            action: #selector(triggerNotchPreview),
            keyEquivalent: "e"
        )
        previewEyeItem.target = self
        previewEyeItem.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: nil)
        menu.addItem(previewEyeItem)

        let previewShieldItem = NSMenuItem(
            title: "Preview Screen Shield Blur",
            action: #selector(triggerShieldPreview),
            keyEquivalent: "b"
        )
        previewShieldItem.target = self
        previewShieldItem.image = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: nil)
        menu.addItem(previewShieldItem)

        let simTamperItem = NSMenuItem(
            title: "Simulate Tamper Countdown",
            action: #selector(triggerSimulatedTamper),
            keyEquivalent: "t"
        )
        simTamperItem.target = self
        simTamperItem.image = NSImage(systemSymbolName: "bolt.trianglebadge.exclamationmark.fill", accessibilityDescription: nil)
        menu.addItem(simTamperItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsWindow), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: nil)
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "Quit Pupil", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)
        menu.addItem(quitItem)

        item.menu = menu
        self.statusItem = item
        refreshStatusItemIconAndMenu()
    }

    public func menuNeedsUpdate(_ menu: NSMenu) {
        refreshStatusItemIconAndMenu()
    }

    private func refreshStatusItemIconAndMenu() {
        if let button = statusItem?.button {
            let icon = MenuBarIconFactory.makeStatusIcon(
                state: coordinator.state,
                isGazeActive: coordinator.isGazeWarningActive
            )
            button.image = icon
            button.imagePosition = .imageLeft

            if coordinator.state == .arming || coordinator.state == .tamperPending {
                statusItem?.length = NSStatusItem.variableLength
                button.title = " \(coordinator.countdownSecondsRemaining)s"
            } else {
                statusItem?.length = NSStatusItem.squareLength
                button.title = ""
            }
        }

        statusHeaderItem?.title = "Pupil — \(coordinator.state.label)"
        let acStatus = coordinator.powerMonitor.isOnACPower ? "AC Charger Connected" : "On Battery"
        let gazeStatus = coordinator.settings.gazeDetectionEnabled ? "Vision Iris On" : "Vision Off"
        powerInfoItem?.title = "\(acStatus) · \(gazeStatus)"

        switch coordinator.state {
        case .disarmed:
            toggleArmItem?.title = "Arm Pupil (\(coordinator.settings.exitDelaySeconds)s delay)"
            toggleArmItem?.image = NSImage(systemSymbolName: "lock.shield.fill", accessibilityDescription: nil)
        case .arming:
            toggleArmItem?.title = "Cancel Arming (\(coordinator.countdownSecondsRemaining)s)"
            toggleArmItem?.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil)
        case .armed, .tamperPending, .alarm:
            toggleArmItem?.title = "Disarm Pupil…"
            toggleArmItem?.image = NSImage(systemSymbolName: "lock.open.fill", accessibilityDescription: nil)
        }
    }

    @objc private func toggleArmState() {
        switch coordinator.state {
        case .disarmed:
            coordinator.startArming()
        case .arming:
            coordinator.cancelArmingDuringExitDelay()
        case .armed, .tamperPending, .alarm:
            Task {
                let unlocked = await coordinator.disarmWithTouchID()
                if !unlocked {
                    revealSettingsWindow()
                }
            }
        }
    }

    @objc private func triggerNotchPreview() {
        coordinator.simulateGazeWarning()
    }

    @objc private func triggerShieldPreview() {
        coordinator.previewScreenShield()
    }

    @objc private func triggerSimulatedTamper() {
        if coordinator.state == .disarmed {
            coordinator.startArming(immediate: true)
        }
        coordinator.triggerTamper(source: .manualTest, immediateAlarm: false, simulated: true)
    }

    @objc private func openSettingsWindow() {
        revealSettingsWindow()
    }

    public func revealSettingsWindow() {
        NSApp.setActivationPolicy(.regular)
        openSettingsWindowAction?()
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow, closingWindow.canBecomeMain else { return }
        let stillOpen = NSApp.windows.contains { $0 !== closingWindow && $0.canBecomeMain && $0.isVisible }
        if !stillOpen {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
