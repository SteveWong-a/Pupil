//
//  LaunchAtLogin.swift
//  Pupil
//
//  Native macOS 13+ ServiceManagement wrapper for Launch at Login,
//  modeled after Glance's LaunchAtLogin.swift.
//

import Foundation
import ServiceManagement

public enum LaunchAtLogin {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        }
    }
}

