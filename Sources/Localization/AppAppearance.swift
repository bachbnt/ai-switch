//
//  AppAppearance.swift
//  AISwitch
//
//  Light / Dark / follow-system. Applied via `.preferredColorScheme(_:)`.
//

import Foundation
import SwiftUI

public enum AppAppearance: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark

    /// nil = follow system, .light / .dark = override.
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
