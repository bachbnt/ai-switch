//
//  MenuBarView.swift
//  AISwitch
//
//  The popover host. Renders one ProviderSectionView per registered provider,
//  with a divider between them, plus a footer (Settings / Quit). Layout
//  follows §7 of the plan.
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var store: ProfileStore
    @EnvironmentObject var settings: AppSettings

    @Environment(\.openSettings) private var openSettings

    @State private var collapsedProviders: Set<String> = []

    private var providers: [ProviderDescriptor] { ProviderRegistry.shared.providers }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(providers.enumerated()), id: \.element.id) { index, provider in
                if index > 0 {
                    Divider()
                        .padding(.vertical, 4)
                }
                ProviderSectionView(
                    provider: provider,
                    isCollapsed: Binding(
                        get: { collapsedProviders.contains(provider.id) },
                        set: { newValue in
                            if newValue { collapsedProviders.insert(provider.id) }
                            else        { collapsedProviders.remove(provider.id) }
                        }
                    )
                )
            }

            Divider().padding(.vertical, 4)

            HStack {
                Button(settings.t(.menuSettings)) {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }
                .buttonStyle(.plain)

                Spacer()

                Button(settings.t(.menuQuit)) {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .padding(.vertical, 4)
    }
}
