//
//  ProviderSectionView.swift
//  AISwitch
//
//  One section of the popover: collapsible header (chevron + brand color +
//  provider name + gear) followed by profile rows and the "+ Add Account"
//  row. Layout follows §7.
//

import SwiftUI

struct ProviderSectionView: View {
    let provider: ProviderDescriptor
    @Binding var isCollapsed: Bool

    @EnvironmentObject var store: ProfileStore
    @EnvironmentObject var settings: AppSettings
    @Environment(\.openSettings) private var openSettings

    @State private var sheetState: SheetState?
    @State private var lastError: String?

    enum SheetState: Identifiable {
        case add
        case edit(Profile)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let p): return "edit-\(p.id.uuidString)"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if !isCollapsed {
                rows
            }
        }
        .sheet(item: $sheetState) { state in
            switch state {
            case .add:
                AddEditProfileSheet(provider: provider, mode: .add) { sheetState = nil }
            case .edit(let profile):
                AddEditProfileSheet(provider: provider,
                                    mode: .edit(profile)) { sheetState = nil }
            }
        }
        .alert(settings.t(.errorSwitchFailed),
               isPresented: Binding(get: { lastError != nil },
                                    set: { if !$0 { lastError = nil } })) {
            Button(settings.t(.ok), role: .cancel) { lastError = nil }
        } message: {
            Text(lastError ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isCollapsed.toggle() }
            } label: {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .frame(width: 12)
            }
            .buttonStyle(.plain)

            Image(systemName: provider.iconSymbol)
                .foregroundStyle(brandColor)
                .imageScale(.small)

            Text(provider.displayName)
                .font(.headline)

            Spacer()

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Rows

    @ViewBuilder
    private var rows: some View {
        let profiles = store.profiles(forProvider: provider.id)
        let activeId = store.activeStateByProvider[provider.id]?.activeProfileId

        if profiles.isEmpty {
            HStack {
                Text(settings.t(.providerNoProfiles))
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        } else {
            ForEach(profiles) { profile in
                ProfileRowView(
                    profile: profile,
                    isActive: profile.id == activeId,
                    onTap: { Task { await switchTo(profile) } },
                    onEdit: { sheetState = .edit(profile) },
                    onDelete: { delete(profile) }
                )
            }
        }

        Button {
            sheetState = .add
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                Text(settings.t(.providerAddAccount, provider.displayName))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var brandColor: Color {
        Color(provider.brandColorAssetName, bundle: .main)
    }

    // MARK: - Actions

    private func switchTo(_ profile: Profile) async {
        do {
            try await SwitchEngine.shared.switchTo(profile)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func delete(_ profile: Profile) {
        do {
            try store.deleteProfile(profile)
        } catch {
            lastError = error.localizedDescription
        }
    }
}
