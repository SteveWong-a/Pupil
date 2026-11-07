//
//  SettingsTab.swift
//  Pupil
//
//  Tab definitions for the floating Settings tab bar.
//

import SwiftUI

public enum SettingsTabIcon: Sendable, Equatable {
    case system(String)
}

public enum SettingsTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case general
    case gaze
    case sensors
    case alarm
    case about

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .general: return "General"
        case .gaze: return "Gaze"
        case .sensors: return "Sensors"
        case .alarm: return "Alarm"
        case .about: return "About"
        }
    }

    public var icon: SettingsTabIcon {
        switch self {
        case .general: return .system("gearshape.fill")
        case .gaze: return .system("eye.fill")
        case .sensors: return .system("bolt.shield.fill")
        case .alarm: return .system("speaker.wave.3.fill")
        case .about: return .system("info.circle.fill")
        }
    }
}
