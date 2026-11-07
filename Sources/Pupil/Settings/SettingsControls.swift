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
            .foregroundStyle(SettingsMetrics.textSecondary)
            .padding(.horizontal, SettingsMetrics.sectionTitleHorizontalInset)
            .padding(.top, 4)
    }
}

public struct SettingsCaption: View {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(SettingsMetrics.textTertiary)
            .padding(.horizontal, SettingsMetrics.sectionTitleHorizontalInset)
    }
}

public struct SettingsOptionTile<Preview: View>: View {
    public let title: String
    public let isSelected: Bool
    public let action: () -> Void
    public var previewHeight: CGFloat = SettingsMetrics.triggerOptionPreviewSize.height
    public var previewWidth: CGFloat = SettingsMetrics.triggerOptionPreviewSize.width
    @ViewBuilder public var preview: () -> Preview

    public init(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void,
        previewHeight: CGFloat = SettingsMetrics.triggerOptionPreviewSize.height,
        previewWidth: CGFloat = SettingsMetrics.triggerOptionPreviewSize.width,
        @ViewBuilder preview: @escaping () -> Preview
    ) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
        self.previewHeight = previewHeight
        self.previewWidth = previewWidth
        self.preview = preview
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: SettingsMetrics.optionPreviewCornerRadius, style: .continuous)
                        .fill(SettingsMetrics.optionPreviewFill)
                    if isSelected {
                        RoundedRectangle(cornerRadius: SettingsMetrics.optionPreviewCornerRadius, style: .continuous)
                            .fill(PupilTheme.accent.opacity(0.14))
                    }
                    preview()
                }
                .frame(width: previewWidth, height: previewHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: SettingsMetrics.optionPreviewCornerRadius, style: .continuous)
                        .strokeBorder(
                            isSelected ? PupilTheme.accent : SettingsMetrics.rowBorder,
                            lineWidth: isSelected ? SettingsMetrics.optionSelectionStrokeWidth : 1
                        )
                )

                Text(title)
                    .font(SettingsMetrics.optionLabelFont)
                    .foregroundStyle(isSelected ? SettingsMetrics.textPrimary : SettingsMetrics.textSecondary)
            }
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
    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyFilterForCurrentAppearance()
    }

    public func applyFilterForCurrentAppearance() {
        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(isDark ? 1.2 : 1.75, forKey: "inputSaturation")
            layer?.filters = [filter]
        }
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
