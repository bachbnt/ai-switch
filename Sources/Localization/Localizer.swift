//
//  Localizer.swift
//  AISwitch
//
//  Runtime-switchable string lookup. Reads `AppLanguage` and resolves the
//  matching `<lang>.lproj/Localizable.strings` bundle.
//
//  SwiftUI's built-in `Text(LocalizedStringKey)` honors the system locale
//  but doesn't react cleanly to in-app language changes — so we route every
//  user-visible string through `Localizer.translate(_:language:)` (or the
//  shorthand `AppSettings.t(_:)` extension below) and force a re-render by
//  observing AppSettings via @EnvironmentObject in each view.
//

import Foundation

public enum Localizer {
    /// Resolve a key to a localized string for the given language.
    /// Falls back to Bundle.main (system locale) if the .lproj is missing.
    public static func translate(_ key: String, language: AppLanguage) -> String {
        let bundle = bundle(forLanguage: language) ?? .main
        return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
    }

    /// Resolve a key with `String(format:)` arguments.
    public static func translate(_ key: String,
                                 language: AppLanguage,
                                 _ args: CVarArg...) -> String {
        let format = translate(key, language: language)
        return String(format: format, locale: language.locale, arguments: args)
    }

    private static func bundle(forLanguage language: AppLanguage) -> Bundle? {
        switch language {
        case .system:
            return .main
        case .english:
            return lprojBundle(named: "en")
        case .vietnamese:
            return lprojBundle(named: "vi")
        }
    }

    private static var bundleCache: [String: Bundle] = [:]

    private static func lprojBundle(named code: String) -> Bundle? {
        if let cached = bundleCache[code] { return cached }

        // Try the standard API first.
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            bundleCache[code] = bundle
            return bundle
        }

        // Defensive fallback: walk Bundle.main's resourcePath looking for a
        // <code>.lproj directory. Helps when XcodeGen produced a layout the
        // standard lookup doesn't recognize.
        if let resourcePath = Bundle.main.resourcePath {
            let candidate = (resourcePath as NSString)
                .appendingPathComponent("\(code).lproj")
            if FileManager.default.fileExists(atPath: candidate),
               let bundle = Bundle(path: candidate) {
                bundleCache[code] = bundle
                return bundle
            }
        }

        // Last resort: log once so the dev sees the bundle is malformed.
        NSLog("[Localizer] no \(code).lproj found in Bundle.main. " +
              "Localized strings will fall back to keys.")
        return nil
    }
}

// MARK: - AppSettings convenience

public extension AppSettings {
    /// Translate a key under the user's chosen language. Re-evaluates on
    /// every render in views that observe AppSettings, which is how runtime
    /// language switching works without relaunching the app.
    func t(_ key: LK) -> String {
        Localizer.translate(key.rawValue, language: model.appLanguage)
    }

    /// Same as `t(_:)` but with `String(format:)` arguments interpolated.
    func t(_ key: LK, _ args: CVarArg...) -> String {
        let format = Localizer.translate(key.rawValue, language: model.appLanguage)
        return String(format: format, locale: model.appLanguage.locale, arguments: args)
    }
}
