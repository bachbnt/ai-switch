//
//  ProfileStore.swift
//  AISwitch
//
//  Provider-namespaced profile storage rooted at:
//      ~/Library/Application Support/AISwitch/providers/<providerId>/
//
//  This class is the single source of truth for:
//    - the list of profiles per provider (loaded from disk)
//    - which profile is active per provider (per-provider active.json)
//    - alias uniqueness within a provider
//    - ordering within a provider section
//
//  All disk writes are atomic (temp file + rename). The store is an
//  ObservableObject so SwiftUI can reactively render the menu bar UI.
//
//  See §4 and §6 of the plan.
//

import Foundation
import Combine

/// Store-level errors surfaced to the UI.
public enum ProfileStoreError: LocalizedError {
    case duplicateAlias(provider: String, alias: String)
    case profileNotFound(UUID)
    case providerNotFound(String)
    case ioFailure(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .duplicateAlias(let provider, let alias):
            return "A profile named \"\(alias)\" already exists in \(provider)."
        case .profileNotFound(let id):
            return "Profile \(id) not found."
        case .providerNotFound(let id):
            return "Unknown provider \(id)."
        case .ioFailure(let err):
            return "Disk error: \(err.localizedDescription)"
        }
    }
}

@MainActor
public final class ProfileStore: ObservableObject {
    // Process-wide singleton. The init is @MainActor-isolated (the class is),
    // but `static let` initialization runs in a non-isolated context. We
    // bridge with MainActor.assumeIsolated, which traps if we somehow get
    // here off-main. In this app every first-access path is from MainActor
    // (App init / @StateObject), so it never traps in practice.
    public static let shared: ProfileStore = MainActor.assumeIsolated {
        ProfileStore()
    }

    /// Profiles keyed by providerId. Each provider's array is sorted by `order`.
    @Published public private(set) var profilesByProvider: [String: [Profile]] = [:]

    /// Active profile id keyed by providerId.
    @Published public private(set) var activeStateByProvider: [String: ActiveState] = [:]

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        do {
            try ensureDirectoryStructure()
            try reloadAll()
        } catch {
            // We can't crash on first launch if the disk is read-only; surface
            // it via empty state and let the UI display the error on first
            // user action.
            NSLog("[ProfileStore] init failed: \(error)")
        }
    }

    // MARK: - Paths

    /// `~/Library/Application Support/AISwitch/`
    public var rootDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory,
                                          in: .userDomainMask)[0]
        return appSupport.appendingPathComponent(AppConstants.App.appSupportFolder,
                                                 isDirectory: true)
    }

    public func providerDirectory(_ providerId: String) -> URL {
        rootDirectory
            .appendingPathComponent(AppConstants.Storage.providersFolder, isDirectory: true)
            .appendingPathComponent(providerId, isDirectory: true)
    }

    public func profilesDirectory(_ providerId: String) -> URL {
        providerDirectory(providerId)
            .appendingPathComponent(AppConstants.Storage.profilesFolder, isDirectory: true)
    }

    public func profileDirectory(providerId: String, profileId: UUID) -> URL {
        profilesDirectory(providerId)
            .appendingPathComponent(profileId.uuidString.lowercased(),
                                    isDirectory: true)
    }

    public func surfaceSnapshotDirectory(providerId: String,
                                         profileId: UUID,
                                         surfaceId: String) -> URL {
        profileDirectory(providerId: providerId, profileId: profileId)
            .appendingPathComponent(surfaceId, isDirectory: true)
    }

    private func metaURL(providerId: String, profileId: UUID) -> URL {
        profileDirectory(providerId: providerId, profileId: profileId)
            .appendingPathComponent(AppConstants.Storage.metaFile)
    }

    private func activeStateURL(_ providerId: String) -> URL {
        providerDirectory(providerId)
            .appendingPathComponent(AppConstants.Storage.activeFile)
    }

    // MARK: - Bootstrap

    private func ensureDirectoryStructure() throws {
        try fileManager.createDirectory(at: rootDirectory,
                                        withIntermediateDirectories: true)
        for descriptor in ProviderRegistry.shared.providers {
            try fileManager.createDirectory(at: profilesDirectory(descriptor.id),
                                            withIntermediateDirectories: true)
        }
    }

    public func reloadAll() throws {
        var loadedProfiles: [String: [Profile]] = [:]
        var loadedActive: [String: ActiveState] = [:]

        for descriptor in ProviderRegistry.shared.providers {
            let id = descriptor.id
            loadedProfiles[id] = try loadProfiles(forProvider: id)
                .sorted { $0.order < $1.order }
            loadedActive[id] = (try? loadActiveState(forProvider: id)) ?? .empty
        }
        self.profilesByProvider = loadedProfiles
        self.activeStateByProvider = loadedActive
    }

    private func loadProfiles(forProvider providerId: String) throws -> [Profile] {
        let dir = profilesDirectory(providerId)
        guard let entries = try? fileManager.contentsOfDirectory(at: dir,
                                                                 includingPropertiesForKeys: nil) else {
            return []
        }
        return entries.compactMap { folder -> Profile? in
            let meta = folder.appendingPathComponent(AppConstants.Storage.metaFile)
            guard fileManager.fileExists(atPath: meta.path) else { return nil }
            do {
                let data = try Data(contentsOf: meta)
                return try decoder.decode(Profile.self, from: data)
            } catch {
                NSLog("[ProfileStore] skipping malformed profile at \(meta.path): \(error)")
                return nil
            }
        }
    }

    private func loadActiveState(forProvider providerId: String) throws -> ActiveState {
        let url = activeStateURL(providerId)
        guard fileManager.fileExists(atPath: url.path) else { return .empty }
        let data = try Data(contentsOf: url)
        return try decoder.decode(ActiveState.self, from: data)
    }

    // MARK: - Public read API

    public func profiles(forProvider providerId: String) -> [Profile] {
        profilesByProvider[providerId] ?? []
    }

    public func activeProfile(forProvider providerId: String) -> Profile? {
        guard let activeId = activeStateByProvider[providerId]?.activeProfileId else {
            return nil
        }
        return profiles(forProvider: providerId).first { $0.id == activeId }
    }

    public func isAliasAvailable(_ alias: String,
                                 inProvider providerId: String,
                                 excluding excluded: UUID? = nil) -> Bool {
        let normalized = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { return false }
        return !profiles(forProvider: providerId).contains { profile in
            profile.id != excluded
                && profile.alias.trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased() == normalized
        }
    }

    // MARK: - Public write API

    /// Add a brand-new profile. Throws on alias collision.
    @discardableResult
    public func addProfile(_ profile: Profile) throws -> Profile {
        guard ProviderRegistry.shared.provider(withId: profile.providerId) != nil else {
            throw ProfileStoreError.providerNotFound(profile.providerId)
        }
        guard isAliasAvailable(profile.alias, inProvider: profile.providerId) else {
            throw ProfileStoreError.duplicateAlias(provider: profile.providerId,
                                                   alias: profile.alias)
        }

        var stored = profile
        // Append at end of order.
        let existing = profiles(forProvider: profile.providerId)
        stored.order = (existing.map(\.order).max() ?? -1) + 1

        let folder = profileDirectory(providerId: stored.providerId, profileId: stored.id)
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            try writeMeta(stored)
        } catch {
            throw ProfileStoreError.ioFailure(underlying: error)
        }

        var list = existing
        list.append(stored)
        list.sort { $0.order < $1.order }
        profilesByProvider[stored.providerId] = list
        return stored
    }

    /// Update mutable fields on an existing profile.
    public func updateProfile(_ profile: Profile) throws {
        guard isAliasAvailable(profile.alias,
                               inProvider: profile.providerId,
                               excluding: profile.id) else {
            throw ProfileStoreError.duplicateAlias(provider: profile.providerId,
                                                   alias: profile.alias)
        }
        do {
            try writeMeta(profile)
        } catch {
            throw ProfileStoreError.ioFailure(underlying: error)
        }
        var list = profiles(forProvider: profile.providerId)
        guard let idx = list.firstIndex(where: { $0.id == profile.id }) else {
            throw ProfileStoreError.profileNotFound(profile.id)
        }
        list[idx] = profile
        list.sort { $0.order < $1.order }
        profilesByProvider[profile.providerId] = list
    }

    /// Delete a profile and its on-disk folder. If the profile was active for
    /// its provider, the provider's active.json is cleared.
    public func deleteProfile(_ profile: Profile) throws {
        let folder = profileDirectory(providerId: profile.providerId, profileId: profile.id)
        do {
            if fileManager.fileExists(atPath: folder.path) {
                try fileManager.removeItem(at: folder)
            }
        } catch {
            throw ProfileStoreError.ioFailure(underlying: error)
        }

        var list = profiles(forProvider: profile.providerId)
        list.removeAll { $0.id == profile.id }
        profilesByProvider[profile.providerId] = list

        if activeStateByProvider[profile.providerId]?.activeProfileId == profile.id {
            try setActive(nil, forProvider: profile.providerId)
        }
    }

    /// Reorder profiles within a provider. `orderedIds` must contain every
    /// profile currently in the provider.
    public func reorder(providerId: String, orderedIds: [UUID]) throws {
        var list = profiles(forProvider: providerId)
        var lookup = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })

        for (index, id) in orderedIds.enumerated() {
            guard var profile = lookup[id] else { continue }
            profile.order = index
            lookup[id] = profile
            try writeMeta(profile)
        }
        list = orderedIds.compactMap { lookup[$0] }
        profilesByProvider[providerId] = list
    }

    /// Mark a profile as active for its provider. Pass nil to clear.
    public func setActive(_ profileId: UUID?, forProvider providerId: String) throws {
        let state = ActiveState(activeProfileId: profileId, lastSwitchedAt: Date())
        do {
            try writeActiveState(state, forProvider: providerId)
        } catch {
            throw ProfileStoreError.ioFailure(underlying: error)
        }
        activeStateByProvider[providerId] = state

        if let profileId, var profile = profiles(forProvider: providerId)
            .first(where: { $0.id == profileId }) {
            profile.lastUsedAt = Date()
            try? writeMeta(profile)
            var list = profiles(forProvider: providerId)
            if let idx = list.firstIndex(where: { $0.id == profile.id }) {
                list[idx] = profile
                profilesByProvider[providerId] = list
            }
        }
    }

    // MARK: - Atomic disk writes

    private func writeMeta(_ profile: Profile) throws {
        let folder = profileDirectory(providerId: profile.providerId, profileId: profile.id)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = metaURL(providerId: profile.providerId, profileId: profile.id)
        let data = try encoder.encode(profile)
        try atomicWrite(data: data, to: url)
    }

    private func writeActiveState(_ state: ActiveState, forProvider providerId: String) throws {
        try fileManager.createDirectory(at: providerDirectory(providerId),
                                        withIntermediateDirectories: true)
        let data = try encoder.encode(state)
        try atomicWrite(data: data, to: activeStateURL(providerId))
    }

    private func atomicWrite(data: Data, to url: URL) throws {
        // Single-step write with FileManager's atomic flag. This already does
        // temp-file + rename internally, so we don't need to manage a sibling
        // .tmp ourselves — and we don't risk leaving stragglers around if
        // something fails partway.
        try data.write(to: url, options: [.atomic])
    }
}
