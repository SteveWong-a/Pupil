//
//  SettingsMetrics.swift
//  Pupil
//
//  Native macOS design tokens for the Settings window, matching Glance's SettingsMetrics.
//

import AppKit
import SwiftUI

public enum PupilTheme {
    public static let accent = Color(red: 0x0A / 255, green: 0x84 / 255, blue: 0xFF / 255)
    public static let armedGreen = Color(red: 0x30 / 255, green: 0xD1 / 255, blue: 0x58 / 255)
    public static let warningAmber = Color(red: 0xFF / 255, green: 0x9F / 255, blue: 0x0A / 255)
    public static let alarmRed = Color(red: 0xFF / 255, green: 0x45 / 255, blue: 0x3A / 255)
}

public enum SettingsMetrics {
    public static let windowSize = CGSize(width: 500, height: 620)

    public static let headerHeight: CGFloat = 52
    public static let headerButtonHeight: CGFloat = 30
    public static let headerButtonFont = Font.system(size: 13, weight: .medium)
    public static let headerBlurHeight: CGFloat = headerHeight + 28

    public static let windowTintColor = adaptiveColor(
        dark: NSColor(red: 0x37 / 255, green: 0x37 / 255, blue: 0x37 / 255, alpha: 0),
        light: NSColor(red: 0xFF / 255, green: 0xFF / 255, blue: 0xFF / 255, alpha: 0)
    )

    // MARK: - Floating Tab Bar

    public static let tabBarHeight: CGFloat = 54
    public static let tabBarBottomInset: CGFloat = 14
    public static let tabBarHorizontalPadding: CGFloat = 6
    public static let tabBarTint = adaptiveColor(
        dark: NSColor(white: 1, alpha: 0.15),
        light: NSColor(white: 1, alpha: 0.5)
    )
    public static let tabBarBorder = adaptiveColor(
        dark: NSColor(white: 1, alpha: 0.16),
        light: NSColor(white: 0, alpha: 0.08)
    )
    public static let tabItemHeight: CGFloat = 42
    public static let tabItemHorizontalPadding: CGFloat = 11
    public static let selectedTabItemHorizontalPadding: CGFloat = 14
    public static let tabGlyphSize: CGFloat = 15
    public static let tabTitleFont = Font.system(size: 13, weight: .medium)
    public static let selectedPillColor = adaptiveColor(
        dark: NSColor(white: 1, alpha: 0.10),
        light: NSColor(white: 1, alpha: 0.70)
    )
    public static let selectedPillBorder = adaptiveColor(
        dark: NSColor(white: 1, alpha: 0.12),
        light: NSColor(white: 0, alpha: 0.06)
    )
    public static let tabSelectionAnimation = Animation.spring(response: 0.35, dampingFraction: 0.82)
    public static let tabLabelRevealOffset: CGFloat = 10
    public static let tabLabelRevealBlur: CGFloat = 4

    public static let pageBottomInset: CGFloat = tabBarHeight + tabBarBottomInset + 18

    // MARK: - Adaptive Typography & Surfaces

    public static let textPrimary = adaptiveColor(
        dark: NSColor(red: 0xEE / 255, green: 0xEE / 255, blue: 0xEE / 255, alpha: 1),
        light: NSColor(white: 0, alpha: 0.85)
    )
    public static let textSecondary = adaptiveColor(
        dark: NSColor(red: 0xBF / 255, green: 0xBF / 255, blue: 0xBF / 255, alpha: 1),
        light: NSColor(white: 0, alpha: 0.50)
    )
    public static let textTertiary = adaptiveColor(
        dark: NSColor(red: 0x99 / 255, green: 0x99 / 255, blue: 0x99 / 255, alpha: 1),
        light: NSColor(white: 0, alpha: 0.40)
    )

    public static let rowHeight: CGFloat = 44
    public static let rowRadius: CGFloat = 16
    public static let rowColor = adaptiveColor(
        dark: NSColor(white: 1, alpha: 0.08),
        light: NSColor(white: 1, alpha: 0.75)
    )
    public static let rowBorder = adaptiveColor(
        dark: NSColor(white: 0.8, alpha: 0.12),
        light: NSColor(white: 0, alpha: 0.15)
    )
    public static let rowBorderWidth: CGFloat = 1
    public static let rowFont = Font.system(size: 13, weight: .regular)
    public static let rowSpacing: CGFloat = 12
    public static let rowHorizontalInset: CGFloat = 14
    public static let rowSubtitleMaxWidth: CGFloat = 240
    public static let sliderRowVerticalPadding: CGFloat = 12

    // MARK: - Buttons & Pills

    public static let pickerPillFill = adaptiveColor(
        dark: NSColor(white: 1, alpha: 0.06),
        light: NSColor(white: 0, alpha: 0.08)
    )
    public static let neutralButtonFill = adaptiveColor(
        dark: NSColor(white: 1, alpha: 0.08),
        light: NSColor(white: 0, alpha: 0.06)
    )
    public static let destructiveFill = Color(red: 0xFF / 255, green: 0x45 / 255, blue: 0x3A / 255).opacity(0.85)

    // MARK: - Option Tiles (Glance Double-Ring + Outset Spec)

    public static let optionItemSpacing: CGFloat = 10
    public static let optionCardVerticalPadding: CGFloat = 12
    public static let optionPreviewHeight: CGFloat = 46
    public static let optionTileWidth: CGFloat = 76
    public static let optionPreviewFill = adaptiveColor(
        dark: NSColor(white: 1, alpha: 0.05),
        light: NSColor(white: 0, alpha: 0.05)
    )
    public static let optionPreviewSelectedTintOpacity: Double = 0.12
    public static let optionPreviewCornerRadius: CGFloat = 13
    public static let optionPreviewBorderWidth: CGFloat = 1
    public static let optionPreviewOuterStrokeWidth: CGFloat = 1
    public static let optionPreviewOuterStroke = adaptiveColor(
        dark: NSColor(white: 0, alpha: 0.35),
        light: NSColor(white: 0, alpha: 0)
    )
    public static let optionPreviewShadowColor = adaptiveColor(
        dark: NSColor(white: 0, alpha: 0.25),
        light: NSColor(white: 0, alpha: 0.05)
    )
    public static let optionPreviewShadowRadius: CGFloat = 4
    public static let triggerOptionPreviewSize = CGSize(width: 72, height: 44)
    public static let styleOptionPreviewSize = CGSize(width: 96, height: 52)
    public static let optionLabelFont = Font.system(size: 11, weight: .medium)
    public static let optionSelectionOutset: CGFloat = 2.5
    public static let optionSelectionStrokeWidth: CGFloat = 2.0

    public static let sectionTitleFont = Font.system(size: 12, weight: .medium)
    public static let sectionTitleHorizontalInset: CGFloat = 10
    public static let sectionTitleVerticalPadding: CGFloat = 4
    public static let contentHorizontalPadding: CGFloat = 16
    public static let stateTransitionAnimation = Animation.easeInOut(duration: 0.25)

    private static func adaptiveColor(dark: NSColor, light: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}
