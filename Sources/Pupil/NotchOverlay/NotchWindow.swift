//
//  NotchWindow.swift
//  Pupil
//
//  Borderless, transparent NSPanel sitting at CGShieldingWindowLevel() + 1,
//  joining all spaces and full-screen apps without stealing focus.
//

import AppKit
import CoreGraphics
import SwiftUI

public final class NotchWindow: NSPanel {
    private static let overlayWindowLevel = NSWindow.Level(
        rawValue: Int(CGShieldingWindowLevel()) + 1
    )

    public var acceptsKey = false
    public var activeNotchSize: CGSize = .zero

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        level = Self.overlayWindowLevel
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        ignoresMouseEvents = true
    }

    public override var canBecomeKey: Bool { acceptsKey }
    public override var canBecomeMain: Bool { false }
}

public final class NotchHostingView<Content: View>: NSHostingView<Content> {
    private weak var notchWindow: NotchWindow?

    public init(rootView: Content, window: NotchWindow) {
        self.notchWindow = window
        super.init(rootView: rootView)
    }

    @MainActor @preconcurrency required public init(rootView: Content) {
        super.init(rootView: rootView)
    }

    @MainActor required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        guard let window = notchWindow, !window.ignoresMouseEvents else { return nil }
        let size = window.activeNotchSize
        guard size.width > 0 && size.height > 0 else { return nil }

        // Window coordinates: (0,0) is bottom-left, (bounds.width, bounds.height) is top-right
        let bounds = self.bounds
        let notchRect = NSRect(
            x: (bounds.width - size.width) / 2,
            y: bounds.height - size.height,
            width: size.width,
            height: size.height
        )

        guard notchRect.contains(point) else {
            return nil
        }
        return super.hitTest(point)
    }
}
