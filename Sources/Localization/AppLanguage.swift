//
//  AppLanguage.swift
//  AISwitch
//
//  Language preference for the in-app translator. `system` defers to the
//  user's macOS language; `english` and `vietnamese` force a specific
//  locale regardless of system setting.
//

import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case system
    case english
    case vietnamese

    /// Locale code corresponding to the language. `system` returns nil so
    /// callers can fall through to Bundle.main's default.
    public var localeIdentifier: String? {
        switch self {
        case .system:     return nil
        case .english:    return "en"
        case .vietnamese: return "vi"
        }
    }

    /// Foundation Locale instance, or the system locale.
    public var locale: Locale {
        guard let id = localeIdentifier else { return .current }
        return Locale(identifier: id)
    }

    /// Native name to show in the picker (so a Vietnamese user finds
    /// "Tiếng Việt" even when the rest of the UI is in English).
    public var nativeDisplayName: String {
        switch self {
        case .system:     return "System"
        case .english:    return "English"
        case .vietnamese: return "Tiếng Việt"
        }
    }
}
