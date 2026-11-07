//
//  SettingsTabBar.swift
//  Pupil
//
//  Floating pill tab bar pinned to the bottom of the Settings window,
//  modeled directly after Glance's SettingsTabBar.
//

import SwiftUI

private struct TabFramePreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [SettingsTab: CGRect] = [:]
    static func reduce(value: inout [SettingsTab: CGRect], nextValue: () -> [SettingsTab: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

public struct SettingsTabBar: View {
    @Binding public var selection: SettingsTab
    @State private var tabFrames: [SettingsTab: CGRect] = [:]

    private static let coordinateSpace = "PupilSettingsTabBar"

    public init(selection: Binding<SettingsTab>) {
        self._selection = selection
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            if let frame = tabFrames[selection] {
                Capsule()
                    .fill(SettingsMetrics.selectedPillColor)
                    .overlay(
                        Capsule()
                            .strokeBorder(SettingsMetrics.selectedPillBorder, lineWidth: 1)
                    )
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)
                    .transition(.opacity)
            }

            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases) { tab in
                    item(tab)
                }
            }
        }
        .coordinateSpace(name: Self.coordinateSpace)
        .padding(.horizontal, SettingsMetrics.tabBarHorizontalPadding)
        .frame(height: SettingsMetrics.tabBarHeight)
        .background {
            Capsule()
                .fill(.regularMaterial)
            Capsule()
                .fill(SettingsMetrics.tabBarTint)
        }
        .overlay(
            Capsule()
                .strokeBorder(SettingsMetrics.tabBarBorder, lineWidth: 1)
        )
        .onPreferenceChange(TabFramePreferenceKey.self) { frames in
            withAnimation(SettingsMetrics.tabSelectionAnimation) {
                tabFrames = frames
            }
        }
    }

    private func item(_ tab: SettingsTab) -> some View {
        let isSelected = selection == tab
        return Button {
            withAnimation(SettingsMetrics.tabSelectionAnimation) {
                selection = tab
            }
        } label: {
            HStack(spacing: 7) {
                SettingsTabGlyph(icon: tab.icon)
                if isSelected {
                    Text(tab.title)
                        .font(SettingsMetrics.tabTitleFont)
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.tabLabelReveal)
                }
            }
            .foregroundStyle(SettingsMetrics.textPrimary)
            .padding(.horizontal, isSelected
                ? SettingsMetrics.selectedTabItemHorizontalPadding
                : SettingsMetrics.tabItemHorizontalPadding)
            .frame(height: SettingsMetrics.tabItemHeight)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: TabFramePreferenceKey.self,
                    value: [tab: proxy.frame(in: .named(Self.coordinateSpace))]
                )
            }
        )
        .help(tab.title)
        .accessibilityLabel(tab.title)
    }
}

private struct SettingsTabGlyph: View {
    let icon: SettingsTabIcon

    var body: some View {
        Group {
            switch icon {
            case .system(let name):
                Image(systemName: name)
                    .font(.system(size: SettingsMetrics.tabGlyphSize, weight: .medium))
            }
        }
        .frame(width: SettingsMetrics.tabGlyphSize + 4, height: SettingsMetrics.tabGlyphSize + 4)
    }
}

private struct TabLabelRevealModifier: ViewModifier {
    var progress: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .blur(radius: (1 - progress) * SettingsMetrics.tabLabelRevealBlur)
            .offset(x: (1 - progress) * -SettingsMetrics.tabLabelRevealOffset)
    }
}

private extension AnyTransition {
    static var tabLabelReveal: AnyTransition {
        .modifier(
            active: TabLabelRevealModifier(progress: 0),
            identity: TabLabelRevealModifier(progress: 1)
        )
    }
}
