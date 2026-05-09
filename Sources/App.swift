//
//  App.swift
//  AISwitch
//
//  Menu-bar-only app entry. The Dock is hidden via LSUIElement=true in
//  Info.plist. The single MenuBarExtra hosts the popover defined by
//  MenuBarView.
//

import SwiftUI

@main
struct AISwitchApp: App {
    @StateObject private var store = ProfileStore.shared
    @StateObject private var settings = AppSettings.shared
    @StateObject private var nudger = Nudger.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
                .environmentObject(settings)
                .preferredColorScheme(settings.model.appearance.colorScheme)
                .environment(\.locale, settings.model.appLanguage.locale)
                .frame(width: 320)
        } label: {
            // SF Symbol works well as a template image in the menu bar.
            Image(systemName: "rectangle.2.swap")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(settings)
                .preferredColorScheme(settings.model.appearance.colorScheme)
                .environment(\.locale, settings.model.appLanguage.locale)
                .frame(width: 520, height: 420)
        }
    }
}
