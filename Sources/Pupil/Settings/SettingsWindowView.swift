//
//  SettingsWindowView.swift
//  Pupil
//
//  Root layout for Pupil Settings, modeled directly after Glance's SettingsWindowView:
//  one `.sidebar` material behind the whole window, the selected page scrolling beneath
//  a transparent progressive-blur header (traffic lights + live status pill) and a
//  floating capsule tab bar pinned to the bottom.
//

import AppKit
import SwiftUI

public struct SettingsWindowView: View {
    @Bindable var coordinator: SecurityCoordinator
    @State private var selection: SettingsTab = .general

    public init(coordinator: SecurityCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        ZStack {
            VisualEffectView()
            SettingsMetrics.windowTintColor
            contentPage
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(WindowConfigurator())
        .tint(PupilTheme.accent)
        .background(
            SettingsTabSwipeRecognizer { direction in
                selectAdjacentTab(for: direction)
            }
        )
    }

    private var contentPage: some View {
        ScrollView(.vertical, showsIndicators: false) {
            pageBody
                .padding(.horizontal, SettingsMetrics.contentHorizontalPadding)
                .padding(.top, SettingsMetrics.headerHeight + 6)
                .padding(.bottom, SettingsMetrics.pageBottomInset)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .top) {
            ZStack(alignment: .top) {
                ProgressiveHeaderBlur(height: SettingsMetrics.headerBlurHeight)
                header
            }
        }
        .overlay(alignment: .bottom) {
            SettingsTabBar(selection: $selection)
                .padding(.bottom, SettingsMetrics.tabBarBottomInset)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Spacer()
            HeaderStatusButton(coordinator: coordinator)
        }
        .padding(.horizontal, SettingsMetrics.contentHorizontalPadding)
        .frame(height: SettingsMetrics.headerHeight)
    }

    @ViewBuilder
    private var pageBody: some View {
        switch selection {
        case .general:
            GeneralSettingsPage(coordinator: coordinator)
        case .gaze:
            GazeSettingsPage(coordinator: coordinator)
        case .sensors:
            SensorsSettingsPage(coordinator: coordinator)
        case .alarm:
            AlarmSettingsPage(coordinator: coordinator)
        case .about:
            AboutSettingsPage()
        }
    }

    private func selectAdjacentTab(for direction: SwipeDirection) {
        let tabs = SettingsTab.allCases
        guard let currentIndex = tabs.firstIndex(of: selection) else { return }
        let targetIndex: Int
        switch direction {
        case .previous:
            targetIndex = currentIndex - 1
        case .next:
            targetIndex = currentIndex + 1
        }
        guard tabs.indices.contains(targetIndex) else { return }
        withAnimation(SettingsMetrics.tabSelectionAnimation) {
            selection = tabs[targetIndex]
        }
    }
}

private enum SwipeDirection {
    case previous
    case next
}

private struct SettingsTabSwipeRecognizer: NSViewRepresentable {
    let onSwipe: (SwipeDirection) -> Void

    func makeNSView(context: Context) -> SwipeMonitoringView {
        let view = SwipeMonitoringView()
        view.onSwipe = onSwipe
        return view
    }

    func updateNSView(_ nsView: SwipeMonitoringView, context: Context) {
        nsView.onSwipe = onSwipe
    }
}

private final class SwipeMonitoringView: NSView {
    var onSwipe: ((SwipeDirection) -> Void)?
    private nonisolated(unsafe) var eventMonitor: Any?
    private var accumulatedDeltaX: CGFloat = 0
    private var hasTriggeredInCurrentGesture = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            installMonitorIfNeeded()
        } else {
            removeMonitor()
        }
    }

    private func installMonitorIfNeeded() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScroll(event)
            return event
        }
    }

    private func removeMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleScroll(_ event: NSEvent) {
        guard let window, event.window === window else { return }
        guard event.hasPreciseScrollingDeltas else { return }

        if event.phase == .began {
            accumulatedDeltaX = 0
            hasTriggeredInCurrentGesture = false
        }

        guard !hasTriggeredInCurrentGesture else { return }
        guard abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) * 1.4 else { return }

        accumulatedDeltaX += event.scrollingDeltaX
        let threshold: CGFloat = 55
        if accumulatedDeltaX >= threshold {
            hasTriggeredInCurrentGesture = true
            onSwipe?(.previous)
        } else if accumulatedDeltaX <= -threshold {
            hasTriggeredInCurrentGesture = true
            onSwipe?(.next)
        }
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
