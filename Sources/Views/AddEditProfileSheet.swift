//
//  AddEditProfileSheet.swift
//  AISwitch
//
//  Add / Rename / Edit sheet from §6 of the plan. Provider is locked (set by
//  which `+ Add` button was clicked, or implied by the profile being edited).
//
//  Validation:
//    - alias non-empty, unique within provider
//    - at least one surface checked
//

import SwiftUI

enum AddEditMode {
    case add
    case edit(Profile)
}

struct AddEditProfileSheet: View {
    let provider: ProviderDescriptor
    let mode: AddEditMode
    let dismiss: () -> Void

    @EnvironmentObject var store: ProfileStore
    @EnvironmentObject var settings: AppSettings

    @State private var alias: String
    @State private var email: String
    @State private var colorHex: String
    @State private var iconSymbol: String?
    @State private var selectedSurfaces: Set<String>
    @State private var captureFromCurrent: Bool
    @State private var errorMessage: String?
    @State private var working = false

    init(provider: ProviderDescriptor, mode: AddEditMode, dismiss: @escaping () -> Void) {
        self.provider = provider
        self.mode = mode
        self.dismiss = dismiss
        switch mode {
        case .add:
            _alias = State(initialValue: "")
            _email = State(initialValue: "")
            _colorHex = State(initialValue: provider.defaultProfileColors.first ?? "#888888")
            _iconSymbol = State(initialValue: nil)
            _selectedSurfaces = State(initialValue: Set(provider.surfaces.map(\.id)))
            _captureFromCurrent = State(initialValue: true)
        case .edit(let profile):
            _alias = State(initialValue: profile.alias)
            _email = State(initialValue: profile.email ?? "")
            _colorHex = State(initialValue: profile.colorHex)
            _iconSymbol = State(initialValue: profile.iconSymbol)
            _selectedSurfaces = State(initialValue: Set(profile.surfaces))
            _captureFromCurrent = State(initialValue: false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                form.padding(16)
            }
            Divider()
            footer
        }
        .frame(width: 420)
        .frame(minHeight: 480)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: provider.iconSymbol)
                .foregroundStyle(Color(provider.brandColorAssetName, bundle: .main))
            Text(headerTitle)
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var headerTitle: String {
        switch mode {
        case .add:  return settings.t(.profileTitleNew, provider.displayName)
        case .edit: return settings.t(.profileTitleEdit, provider.displayName)
        }
    }

    // MARK: - Form

    private var form: some View {
        VStack(alignment: .leading, spacing: 14) {
            field(label: settings.t(.profileFieldAlias)) {
                TextField(settings.t(.profileFieldAliasHint), text: $alias)
                    .textFieldStyle(.roundedBorder)
            }

            field(label: settings.t(.profileFieldEmail)) {
                TextField(settings.t(.profileFieldEmailHint), text: $email)
                    .textFieldStyle(.roundedBorder)
            }

            field(label: settings.t(.profileFieldColor)) {
                ColorSwatchPicker(palette: provider.defaultProfileColors,
                                  selection: $colorHex)
            }

            field(label: settings.t(.profileFieldIcon)) {
                IconPickerView(selection: $iconSymbol)
            }

            field(label: settings.t(.profileFieldSurfaces)) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(provider.surfaces) { surface in
                        Toggle(isOn: Binding(
                            get: { selectedSurfaces.contains(surface.id) },
                            set: { included in
                                if included { selectedSurfaces.insert(surface.id) }
                                else        { selectedSurfaces.remove(surface.id) }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(surface.displayName)
                                Text(surface.kind == .cli
                                     ? settings.t(.surfaceKindCLI)
                                     : settings.t(.surfaceKindDesktop))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if case .add = mode {
                field(label: settings.t(.profileFieldInitialState)) {
                    Picker("", selection: $captureFromCurrent) {
                        Text(settings.t(.profileInitialCapture)).tag(true)
                        Text(settings.t(.profileInitialEmpty)).tag(false)
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private func field<Content: View>(label: String,
                                       @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button(settings.t(.cancel), action: dismiss)
                .keyboardShortcut(.cancelAction)
            Button(saveButtonTitle) {
                Task { await save() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!isValid || working)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var saveButtonTitle: String {
        switch mode {
        case .add:  return settings.t(.add)
        case .edit: return settings.t(.save)
        }
    }

    private var isValid: Bool {
        let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard !selectedSurfaces.isEmpty else { return false }
        let excluding: UUID? = {
            if case .edit(let p) = mode { return p.id }
            return nil
        }()
        return store.isAliasAvailable(trimmed, inProvider: provider.id, excluding: excluding)
    }

    // MARK: - Save

    private func save() async {
        working = true
        defer { working = false }
        do {
            switch mode {
            case .add:
                let profile = Profile(
                    providerId: provider.id,
                    alias: alias.trimmingCharacters(in: .whitespacesAndNewlines),
                    email: email.isEmpty ? nil : email,
                    colorHex: colorHex,
                    iconSymbol: iconSymbol,
                    surfaces: provider.surfaces.map(\.id).filter { selectedSurfaces.contains($0) }
                )
                let stored = try store.addProfile(profile)
                if captureFromCurrent {
                    try await SwitchEngine.shared.captureCurrentState(into: stored)
                }
            case .edit(let original):
                var updated = original
                updated.alias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
                updated.email = email.isEmpty ? nil : email
                updated.colorHex = colorHex
                updated.iconSymbol = iconSymbol
                updated.surfaces = provider.surfaces.map(\.id)
                    .filter { selectedSurfaces.contains($0) }
                try store.updateProfile(updated)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
