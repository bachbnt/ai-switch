//
//  LocalizationKey.swift
//  AISwitch
//
//  Type-safe wrappers around the keys in Resources/<lang>.lproj/Localizable.strings.
//
//  Adding a string:
//    1. Add a case here.
//    2. Add the key to BOTH en.lproj/Localizable.strings AND
//       vi.lproj/Localizable.strings.
//    3. Use it via `settings.t(.yourKey)` in views.
//
//  Keys are namespaced with dots (e.g. "menu.quit") so `genstrings` and
//  diff tools group related strings.
//

import Foundation

public enum LK: String, CaseIterable, Sendable {
    // MARK: - Common buttons / actions
    case ok                         = "common.ok"
    case cancel                     = "common.cancel"
    case save                       = "common.save"
    case add                        = "common.add"
    case edit                       = "common.edit"
    case delete                     = "common.delete"
    case close                      = "common.close"

    // MARK: - Menu bar footer
    case menuSettings               = "menu.settings"
    case menuQuit                   = "menu.quit"
    case menuBarTooltip             = "menu.tooltip"

    // MARK: - Provider section
    case providerNoProfiles         = "provider.no_profiles"
    case providerAddAccount         = "provider.add_account_format"   // "Add %@ Account"

    // MARK: - Errors
    case errorSwitchFailed          = "error.switch_failed.title"
    case errorGeneric               = "error.generic"

    // MARK: - Add / Edit profile sheet
    case profileTitleNew            = "profile.title.new_format"      // "New %@ Profile"
    case profileTitleEdit           = "profile.title.edit_format"     // "Edit %@ Profile"
    case profileFieldAlias          = "profile.field.alias"
    case profileFieldAliasHint      = "profile.field.alias.hint"      // placeholder
    case profileFieldEmail          = "profile.field.email"
    case profileFieldEmailHint      = "profile.field.email.hint"
    case profileFieldColor          = "profile.field.color"
    case profileFieldIcon           = "profile.field.icon"
    case profileFieldSurfaces       = "profile.field.surfaces"
    case profileFieldInitialState   = "profile.field.initial_state"
    case profileInitialCapture      = "profile.initial.capture"
    case profileInitialEmpty        = "profile.initial.empty"

    // MARK: - Surface kind labels
    case surfaceKindCLI             = "surface.kind.cli"
    case surfaceKindDesktop         = "surface.kind.desktop"

    // MARK: - Settings
    case settingsTabProviders       = "settings.tab.providers"
    case settingsTabGeneral         = "settings.tab.general"
    case settingsTabAbout           = "settings.tab.about"

    case settingsLanguage           = "settings.language"
    case settingsAppearance         = "settings.appearance"
    case settingsLaunchAtLogin      = "settings.launch_at_login"
    case settingsLaunchAtLoginHelp  = "settings.launch_at_login.help"

    case settingsReminderBanner     = "settings.reminder.banner"
    case settingsReminderEvery      = "settings.reminder.every"
    case settingsReminderHoursUnit  = "settings.reminder.hours_unit"  // "h"
    case settingsForceRelogin       = "settings.force_relogin"
    case settingsForceReloginHelp   = "settings.force_relogin.help"

    // MARK: - Language / appearance picker labels
    case languageSystem             = "language.system"
    case languageEnglish            = "language.english"
    case languageVietnamese         = "language.vietnamese"

    case appearanceSystem           = "appearance.system"
    case appearanceLight            = "appearance.light"
    case appearanceDark             = "appearance.dark"

    // MARK: - About
    case aboutTagline               = "about.tagline"
    case aboutVersionFormat         = "about.version_format"          // "Version %@"

    // MARK: - Icon picker
    case iconUseProviderDefault     = "icon.use_provider_default"

    // MARK: - Accessibility
    case a11yColorFormat            = "a11y.color_format"             // "Color %@"

    // MARK: - Notifications
    case notifReminderTitle         = "notif.reminder.title"
    case notifReminderBodyActive    = "notif.reminder.body_active_format"   // "%1$@ … %2$@ … %3$d"
    case notifReminderBodyInactive  = "notif.reminder.body_inactive_format" // "%@"
    case notifActionOpenSwitcher    = "notif.action.open_switcher"
}
