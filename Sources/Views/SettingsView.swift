//
//  SettingsView.swift
//  AISwitch
//
//  Settings window. Three tabs:
//
//   - Providers — per-provider notification cadence + force-relogin fallback
//   - General  — language, appearance, launch-at-login
//   - About    — tagline + version
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    private var providers: [ProviderDescriptor] { ProviderRegistry.shared.providers }

    var body: some View {
        TabView {
            providersTab
                .tabItem {
                    Label(settings.t(.settingsTabProviders),
                          systemImage: "rectangle.2.swap")
                }
            generalTab
                .tabItem {
                    Label(settings.t(.settingsTabGeneral),
                          systemImage: "gear")
                }
            aboutTab
                .tabItem {
                    Label(settings.t(.settingsTabAbout),
                          systemImage: "info.circle")
                }
        }
        .padding()
    }

    // MARK: - Providers tab

    private var providersTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(providers) { provider in
                    providerCard(for: provider)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func providerCard(for provider: ProviderDescriptor) -> some View {
        let providerSettings = settings.providerSettings(for: provider.id)
        let reminderHoursBinding = Binding<Double>(
            get: { providerSettings.reminderEveryHours ?? 0 },
            set: { newValue in
                settings.updateProviderSettings(provider.id) { s in
                    s.reminderEveryHours = newValue == 0 ? nil : newValue
                }
            }
        )

        return GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: provider.iconSymbol)
                        .foregroundStyle(Color(provider.brandColorAssetName, bundle: .main))
                    Text(provider.displayName).font(.headline)
                }

                Toggle(settings.t(.settingsReminderBanner),
                       isOn: Binding(
                            get: { providerSettings.reminderEveryHours != nil },
                            set: { isOn in
                                settings.updateProviderSettings(provider.id) { s in
                                    s.reminderEveryHours = isOn ? 3.0 : nil
                                }
                            }
                       ))

                if providerSettings.reminderEveryHours != nil {
                    HStack {
                        Text(settings.t(.settingsReminderEvery))
                        Slider(value: reminderHoursBinding, in: 1...12, step: 1)
                            .frame(width: 200)
                        Text("\(Int(reminderHoursBinding.wrappedValue)) \(settings.t(.settingsReminderHoursUnit))")
                            .monospacedDigit()
                    }
                    .padding(.leading, 20)
                }

                Toggle(settings.t(.settingsForceRelogin),
                       isOn: Binding(
                            get: { providerSettings.forceReloginFallback },
                            set: { newValue in
                                settings.updateProviderSettings(provider.id) { s in
                                    s.forceReloginFallback = newValue
                                }
                            }
                       ))
                Text(settings.t(.settingsForceReloginHelp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
            }
            .padding(8)
        }
    }

    // MARK: - General tab

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Language picker.
            VStack(alignment: .leading, spacing: 4) {
                Text(settings.t(.settingsLanguage))
                    .font(.headline)
                Picker("", selection: Binding(
                    get: { settings.model.appLanguage },
                    set: { newValue in settings.model.appLanguage = newValue }
                )) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(languageDisplayName(lang)).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            // Appearance picker.
            VStack(alignment: .leading, spacing: 4) {
                Text(settings.t(.settingsAppearance))
                    .font(.headline)
                Picker("", selection: Binding(
                    get: { settings.model.appearance },
                    set: { newValue in settings.model.appearance = newValue }
                )) {
                    ForEach(AppAppearance.allCases, id: \.self) { appearance in
                        Text(appearanceDisplayName(appearance)).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Divider()

            // Launch at login.
            Toggle(settings.t(.settingsLaunchAtLogin),
                   isOn: Binding(
                        get: { settings.model.launchAtLogin },
                        set: { newValue in
                            settings.model.launchAtLogin = newValue
                            // TODO(distribution polish): wire SMAppService here.
                        }
                   ))
            Text(settings.t(.settingsLaunchAtLoginHelp))
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private func languageDisplayName(_ language: AppLanguage) -> String {
        switch language {
        case .system:     return settings.t(.languageSystem)
        case .english:    return settings.t(.languageEnglish)
        case .vietnamese: return settings.t(.languageVietnamese)
        }
    }

    private func appearanceDisplayName(_ appearance: AppAppearance) -> String {
        switch appearance {
        case .system: return settings.t(.appearanceSystem)
        case .light:  return settings.t(.appearanceLight)
        case .dark:   return settings.t(.appearanceDark)
        }
    }

    // MARK: - About tab

    private var aboutTab: some View {
        VStack(spacing: 8) {
            Text(AppConstants.App.displayName)
                .font(.title2).bold()
            Text(settings.t(.aboutTagline))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text(settings.t(.aboutVersionFormat, appVersion))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }
}
