//
//  AppSettings.swift
//  AISwitch
//
//  App-level settings persisted to ~/Library/Application Support/AISwitch/config.json.
//  Holds per-provider notification cadence and provider-level toggles.
//

import Foundation
import Combine

public struct ProviderSettings: Codable, Equatable, Sendable {
    /// Hours between reminder banners. nil disables the reminder for this provider.
    public var reminderEveryHours: Double?
    /// If true, switcher will skip restore-from-snapshot and instead clear
    /// vendor state, forcing a full relogin. Used as a safety valve when
    /// hardware-bound auth refuses snapshotted tokens (see §12).
    public var forceReloginFallback: Bool

    public init(reminderEveryHours: Double? = 3.0, forceReloginFallback: Bool = false) {
        self.reminderEveryHours = reminderEveryHours
        self.forceReloginFallback = forceReloginFallback
    }
}

public struct AppSettingsModel: Codable, Equatable, Sendable {
    public var providerSettings: [String: ProviderSettings]
    public var launchAtLogin: Bool
    public var appLanguage: AppLanguage
    public var appearance: AppAppearance

    public init(providerSettings: [String: ProviderSettings] = [:],
                launchAtLogin: Bool = false,
                appLanguage: AppLanguage = .system,
                appearance: AppAppearance = .system) {
        self.providerSettings = providerSettings
        self.launchAtLogin = launchAtLogin
        self.appLanguage = appLanguage
        self.appearance = appearance
    }

    /// Custom decoder so old config.json files (written before language /
    /// appearance existed) keep loading without losing the user's other
    /// settings.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.providerSettings = try c.decodeIfPresent([String: ProviderSettings].self,
                                                      forKey: .providerSettings) ?? [:]
        self.launchAtLogin    = try c.decodeIfPresent(Bool.self,
                                                      forKey: .launchAtLogin) ?? false
        self.appLanguage      = try c.decodeIfPresent(AppLanguage.self,
                                                      forKey: .appLanguage) ?? .system
        self.appearance       = try c.decodeIfPresent(AppAppearance.self,
                                                      forKey: .appearance) ?? .system
    }

    public static let `default` = AppSettingsModel(
        providerSettings: [
            AppConstants.ProviderID.anthropic: ProviderSettings(reminderEveryHours: 3.0,
                                                                forceReloginFallback: false),
            AppConstants.ProviderID.openai:    ProviderSettings(reminderEveryHours: nil,
                                                                forceReloginFallback: false),
        ],
        launchAtLogin: false,
        appLanguage: .system,
        appearance: .system
    )
}

@MainActor
public final class AppSettings: ObservableObject {
    public static let shared: AppSettings = MainActor.assumeIsolated {
        AppSettings()
    }

    @Published public var model: AppSettingsModel {
        didSet { persist() }
    }

    private let url: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.url = appSupport
            .appendingPathComponent(AppConstants.App.appSupportFolder, isDirectory: true)
            .appendingPathComponent(AppConstants.Storage.configFile)

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if let data = try? Data(contentsOf: url),
           let loaded = try? decoder.decode(AppSettingsModel.self, from: data) {
            self.model = loaded
        } else {
            self.model = .default
        }
    }

    public func providerSettings(for providerId: String) -> ProviderSettings {
        model.providerSettings[providerId] ?? ProviderSettings()
    }

    public func updateProviderSettings(_ providerId: String,
                                       _ mutate: (inout ProviderSettings) -> Void) {
        var settings = providerSettings(for: providerId)
        mutate(&settings)
        model.providerSettings[providerId] = settings
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(model)
            try data.write(to: url, options: [.atomic])
        } catch {
            NSLog("[AppSettings] persist failed: \(error)")
        }
    }
}
