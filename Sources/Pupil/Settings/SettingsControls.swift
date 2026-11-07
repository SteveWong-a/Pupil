//
//  SettingsControls.swift
//  Pupil
//
//  Reusable macOS System Settings components, AppearanceAdaptiveVisualEffectView,
//  and WindowConfigurator modeled directly after Glance's SettingsControls.
//

import AppKit
import CoreImage
import SwiftUI

public struct SettingsInfoButton: View {
    public let text: String
    @State private var isPresented = false

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(SettingsMetrics.textTertiary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More information")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(SettingsMetrics.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 220, alignment: .leading)
                .padding(12)
        }
    }
}

public struct SettingsRow<Trailing: View>: View {
    public let title: String
    public var subtitle: String?
    public var info: String?
    @ViewBuilder public var trailing: () -> Trailing

    public init(
        title: String,
        subtitle: String? = nil,
        info: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.info = info
        self.trailing = trailing
    }

    public var body: some View {
        SettingsRowContent(title: title, subtitle: subtitle, info: info, trailing: trailing)
            .background(SettingsMetrics.rowColor)
            .overlay(
                RoundedRectangle(cornerRadius: SettingsMetrics.rowRadius)
                    .strokeBorder(SettingsMetrics.rowBorder, lineWidth: SettingsMetrics.rowBorderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: SettingsMetrics.rowRadius))
    }
}

public struct SettingsRowContent<Trailing: View>: View {
    public let title: String
    public var subtitle: String?
    public var subtitleMaxWidth: CGFloat?
    public var info: String?
    @ViewBuilder public var trailing: () -> Trailing

    public init(
        title: String,
        subtitle: String? = nil,
        subtitleMaxWidth: CGFloat? = nil,
        info: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.subtitleMaxWidth = subtitleMaxWidth
        self.info = info
        self.trailing = trailing
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(SettingsMetrics.rowFont)
                        .foregroundStyle(SettingsMetrics.textPrimary)
                    if let info {
                        SettingsInfoButton(text: info)
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(SettingsMetrics.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: subtitleMaxWidth, alignment: .leading)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, SettingsMetrics.rowHorizontalInset)
        .frame(minHeight: SettingsMetrics.rowHeight)
        .padding(.vertical, subtitle == nil ? 0 : 10)
    }
}

public struct SettingsGroup<Content: View>: View {
    @ViewBuilder public var content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(SettingsMetrics.rowColor)
        .overlay(
            RoundedRectangle(cornerRadius: SettingsMetrics.rowRadius)
                .strokeBorder(SettingsMetrics.rowBorder, lineWidth: SettingsMetrics.rowBorderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: SettingsMetrics.rowRadius))
    }
}

public struct SettingsGroupDivider: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(SettingsMetrics.rowBorder)
            .frame(height: SettingsMetrics.rowBorderWidth)
            .padding(.horizontal, SettingsMetrics.rowHorizontalInset)
    }
}

public struct PupilToggle: View {
    @Binding public var isOn: Bool

    public init(isOn: Binding<Bool>) {
        self._isOn = isOn
    }

    public var body: some View {
        Toggle("", isOn: $isOn)
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)
            .tint(PupilTheme.accent)
    }
}

public struct SettingsMenuPickerPill<MenuContent: View>: View {
    public let label: String
    @ViewBuilder public var menuContent: () -> MenuContent

    public init(label: String, @ViewBuilder menuContent: @escaping () -> MenuContent) {
        self.label = label
        self.menuContent = menuContent
    }

    public var body: some View {
        Menu {
            menuContent()
        } label: {
            HStack(spacing: 6) {
                Text(label)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(SettingsMetrics.textPrimary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SettingsMetrics.textSecondary)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Capsule().fill(SettingsMetrics.pickerPillFill))
            .overlay {
                Capsule()
                    .strokeBorder(SettingsMetrics.rowBorder, lineWidth: SettingsMetrics.rowBorderWidth)
            }
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .tint(SettingsMetrics.textPrimary)
    }
}

public struct SettingsSteppedSliderRowContent: View {
    public let title: String
    public let valueLabel: String
    @Binding public var index: Double
    public let stopCount: Int

    public init(title: String, valueLabel: String, index: Binding<Double>, stopCount: Int) {
        self.title = title
        self.valueLabel = valueLabel
        self._index = index
        self.stopCount = stopCount
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(SettingsMetrics.rowFont)
                    .foregroundStyle(SettingsMetrics.textPrimary)
                Spacer(minLength: 8)
                Text(valueLabel)
                    .font(SettingsMetrics.rowFont)
                    .foregroundStyle(SettingsMetrics.textSecondary)
            }
            Slider(value: $index, in: 0...Double(max(stopCount - 1, 1)), step: 1)
                .controlSize(.regular)
                .tint(PupilTheme.accent)
                .padding(.top, 8)
        }
        .padding(.horizontal, SettingsMetrics.rowHorizontalInset)
        .padding(.vertical, SettingsMetrics.sliderRowVerticalPadding)
    }
}

/// Discrete slider with stop labels directly beneath the track (matching Glance's SettingsOptionSliderRowContent).
public struct SettingsOptionSliderRowContent: View {
    public let title: String
    public let stepLabels: [String]
    @Binding public var index: Double
    public let stopCount: Int

    public init(title: String, stepLabels: [String], index: Binding<Double>, stopCount: Int) {
        self.title = title
        self.stepLabels = stepLabels
        self._index = index
        self.stopCount = stopCount
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(SettingsMetrics.rowFont)
                .foregroundStyle(SettingsMetrics.textPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Slider(value: $index, in: 0...Double(max(stopCount - 1, 1)), step: 1)
                    .controlSize(.regular)
                    .tint(PupilTheme.accent)
                HStack {
                    ForEach(Array(stepLabels.enumerated()), id: \.offset) { position, label in
                        Text(label)
                            .font(.system(size: 12))
                            .foregroundStyle(SettingsMetrics.textTertiary)
                            .frame(maxWidth: .infinity, alignment: alignment(at: position))
                    }
                }
            }
        }
        .padding(.horizontal, SettingsMetrics.rowHorizontalInset)
        .padding(.vertical, SettingsMetrics.sliderRowVerticalPadding)
    }

    private func alignment(at position: Int) -> Alignment {
        if position == 0 { return .leading }
        if position == stepLabels.count - 1 { return .trailing }
        return .center
    }
}

public struct SettingsPrimaryButton: View {
    public let title: String
    public var isEnabled: Bool = true
    public var compact: Bool = false
    public let action: () -> Void

    public init(title: String, isEnabled: Bool = true, compact: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.compact = compact
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, compact ? 14 : 16)
                .padding(.vertical, compact ? 6 : 7)
                .background(PupilTheme.accent)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

public struct PillActionButton: View {
    public let title: String
    public let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SettingsMetrics.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(SettingsMetrics.neutralButtonFill)
                .overlay(
                    Capsule().strokeBorder(SettingsMetrics.rowBorder, lineWidth: SettingsMetrics.rowBorderWidth)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Press-and-hold destructive confirmation button (matching Glance's HoldToConfirmButton).
public struct HoldToConfirmButton: View {
    public let title: String
    public var holdDuration: TimeInterval = 2.0
    public let action: () -> Void

    @State private var fillProgress: CGFloat = 0

    public init(title: String, holdDuration: TimeInterval = 2.0, action: @escaping () -> Void) {
        self.title = title
        self.holdDuration = holdDuration
        self.action = action
    }

    public var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(SettingsMetrics.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        SettingsMetrics.neutralButtonFill
                        Rectangle()
                            .fill(SettingsMetrics.destructiveFill)
                            .frame(width: proxy.size.width * fillProgress)
                    }
                }
            }
            .overlay(
                Capsule().strokeBorder(SettingsMetrics.rowBorder, lineWidth: SettingsMetrics.rowBorderWidth)
            )
            .clipShape(Capsule())
            .contentShape(Capsule())
            .onLongPressGesture(minimumDuration: holdDuration) {
                action()
            } onPressingChanged: { isPressing in
                withAnimation(.linear(duration: isPressing ? holdDuration : 0.18)) {
                    fillProgress = isPressing ? 1 : 0
                }
            }
    }
}

public struct SettingsActionRowContent: View {
    public let title: String
    public var subtitle: String?
    public let buttonTitle: String
    public var isDestructive: Bool = false
    public var isEnabled: Bool = true
    public let action: () -> Void

    public init(
        title: String,
        subtitle: String? = nil,
        buttonTitle: String,
        isDestructive: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.buttonTitle = buttonTitle
        self.isDestructive = isDestructive
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        SettingsRowContent(title: title, subtitle: subtitle) {
            Button(action: action) {
                Text(buttonTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(isDestructive ? PupilTheme.alarmRed.opacity(0.88) : PupilTheme.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.4)
        }
    }
}

public struct SettingsSectionTitle: View {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(SettingsMetrics.sectionTitleFont)
            .foregroundStyle(SettingsMetrics.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, SettingsMetrics.sectionTitleHorizontalInset)
            .padding(.top, SettingsMetrics.sectionTitleVerticalPadding)
    }
}

public struct SettingsCaption: View {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(SettingsMetrics.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, SettingsMetrics.sectionTitleHorizontalInset)
    }
}

/// Top-aligned label + wrapped subtitle on the leading edge and fixed-size option tiles on the trailing edge.
public struct SettingsLabeledOptionRow<Content: View>: View {
    public let title: String
    public var subtitle: String?
    @ViewBuilder public var content: () -> Content

    public init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SettingsMetrics.rowFont)
                    .foregroundStyle(SettingsMetrics.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(SettingsMetrics.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: SettingsMetrics.rowSubtitleMaxWidth, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 12)

            HStack(alignment: .top, spacing: SettingsMetrics.optionItemSpacing) {
                content()
            }
            .layoutPriority(1)
        }
        .padding(.horizontal, SettingsMetrics.rowHorizontalInset)
        .padding(.vertical, SettingsMetrics.optionCardVerticalPadding)
    }
}

/// Selectable preview tile with Glance's double-ring border + outset selection ring.
public struct SettingsOptionTile<Preview: View>: View {
    public let title: String
    public let isSelected: Bool
    public let action: () -> Void
    public var previewHeight: CGFloat = SettingsMetrics.optionPreviewHeight
    public var previewWidth: CGFloat? = nil
    @ViewBuilder public var preview: () -> Preview

    public init(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void,
        previewHeight: CGFloat = SettingsMetrics.optionPreviewHeight,
        previewWidth: CGFloat? = nil,
        @ViewBuilder preview: @escaping () -> Preview
    ) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
        self.previewHeight = previewHeight
        self.previewWidth = previewWidth
        self.preview = preview
    }

    public static func previewTint(isSelected: Bool) -> Color {
        isSelected
            ? SettingsMetrics.textPrimary.opacity(0.75)
            : SettingsMetrics.textSecondary.opacity(0.65)
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                preview()
                    .frame(width: previewWidth)
                    .frame(maxWidth: previewWidth == nil ? .infinity : nil)
                    .frame(height: previewHeight)
                    .background {
                        SettingsMetrics.optionPreviewFill
                        if isSelected {
                            PupilTheme.accent.opacity(SettingsMetrics.optionPreviewSelectedTintOpacity)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: SettingsMetrics.optionPreviewCornerRadius, style: .continuous))
                    .compositingGroup()
                    .shadow(
                        color: SettingsMetrics.optionPreviewShadowColor,
                        radius: SettingsMetrics.optionPreviewShadowRadius,
                        x: 0,
                        y: 0
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: SettingsMetrics.optionPreviewCornerRadius + SettingsMetrics.optionPreviewOuterStrokeWidth,
                            style: .continuous
                        )
                        .strokeBorder(
                            SettingsMetrics.optionPreviewOuterStroke,
                            lineWidth: SettingsMetrics.optionPreviewOuterStrokeWidth
                        )
                        .padding(-SettingsMetrics.optionPreviewOuterStrokeWidth)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: SettingsMetrics.optionPreviewCornerRadius, style: .continuous)
                            .strokeBorder(
                                SettingsMetrics.rowBorder,
                                lineWidth: SettingsMetrics.optionPreviewBorderWidth
                            )
                    )
                    .overlay {
                        if isSelected {
                            let expansion = SettingsMetrics.optionSelectionOutset + SettingsMetrics.optionSelectionStrokeWidth
                            RoundedRectangle(
                                cornerRadius: SettingsMetrics.optionPreviewCornerRadius + expansion,
                                style: .continuous
                            )
                            .strokeBorder(
                                PupilTheme.accent,
                                lineWidth: SettingsMetrics.optionSelectionStrokeWidth
                            )
                            .padding(-expansion)
                        }
                    }

                Text(title)
                    .font(SettingsMetrics.optionLabelFont)
                    .foregroundStyle(isSelected ? SettingsMetrics.textPrimary : SettingsMetrics.textSecondary)
            }
            .frame(maxWidth: previewWidth == nil ? .infinity : nil)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AppKit Vibrancy & Window Chrome Configuration

public struct VisualEffectView: NSViewRepresentable {
    public var material: NSVisualEffectView.Material = .sidebar
    public var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    public var state: NSVisualEffectView.State = .followsWindowActiveState

    public init(
        material: NSVisualEffectView.Material = .sidebar,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .followsWindowActiveState
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    public func makeNSView(context: Context) -> AppearanceAdaptiveVisualEffectView {
        let view = AppearanceAdaptiveVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.wantsLayer = true
        view.applyFilterForCurrentAppearance()
        return view
    }

    public func updateNSView(_ nsView: AppearanceAdaptiveVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

public final class AppearanceAdaptiveVisualEffectView: NSVisualEffectView {
    private static let lightSaturationFilter: CIFilter? = {
        let f = CIFilter(name: "CIColorControls")
        f?.setValue(1.75, forKey: kCIInputSaturationKey)
        return f
    }()

    private static let darkSaturationFilter: CIFilter? = {
        let f = CIFilter(name: "CIColorControls")
        f?.setValue(1.20, forKey: kCIInputSaturationKey)
        return f
    }()

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyFilterForCurrentAppearance()
    }

    public func applyFilterForCurrentAppearance() {
        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let filter = isDark ? Self.darkSaturationFilter : Self.lightSaturationFilter
        layer?.filters = filter.map { [$0] }
    }
}

public struct WindowConfigurator: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> WindowConfiguringView {
        WindowConfiguringView()
    }

    public func updateNSView(_ nsView: WindowConfiguringView, context: Context) {}
}

public final class WindowConfiguringView: NSView {
    private var hasConfigured = false

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window, !hasConfigured else { return }
        hasConfigured = true

        DispatchQueue.main.async { [weak window] in
            guard let window else { return }
            Self.configure(window)
        }
    }

    private static func configure(_ window: NSWindow) {
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden

        let toolbar = NSToolbar(identifier: "PupilSettingsToolbar")
        window.toolbar = toolbar
        window.toolbarStyle = .unified

        window.isMovableByWindowBackground = true
        window.hasShadow = true

        let target = SettingsMetrics.windowSize
        var frame = window.frame
        frame.origin.y += frame.height - target.height
        frame.size = NSSize(width: target.width, height: target.height)
        window.setFrame(frame, display: true)

        window.minSize = target
        window.maxSize = target

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
