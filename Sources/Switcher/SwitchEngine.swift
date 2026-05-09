//
//  SwitchEngine.swift
//  AISwitch
//
//  Orchestrates a switch from "currently-active profile A" to "target profile B"
//  for one provider. Implements the four-step lifecycle from §5:
//
//      1. snapshotOut(A)   for every surface A manages
//      2. quitRunningInstance() for every desktop surface in the union of A and B
//      3. restoreIn(B)     for every surface B manages
//      4. relaunch()       for every desktop surface B manages
//      5. update active.json for the provider
//
//  Errors during step 1 abort the switch (we haven't touched live state yet).
//  Errors during steps 3-4 are surfaced but the switch is *committed* — we
//  don't try to roll the live state back, because partial rollback is worse
//  than telling the user "we got most of the way there, please re-check".
//

import Foundation

@MainActor
public final class SwitchEngine {
    public static let shared: SwitchEngine = MainActor.assumeIsolated {
        SwitchEngine()
    }

    private let store: ProfileStore
    private let registry: ProviderRegistry

    // No default-arg DI here on purpose. In Swift, default-argument
    // expressions are evaluated in a nonisolated context regardless of
    // where the function is declared, which means `= .shared` would fail
    // to reference a `@MainActor` static let. Reading the singletons
    // directly inside the init body works because the init body inherits
    // the class's @MainActor isolation.
    private init() {
        self.store = ProfileStore.shared
        self.registry = ProviderRegistry.shared
    }

    /// Switch to `target` for its provider. Snapshots whichever profile is
    /// currently active (if any), then restores `target`, then relaunches
    /// any desktop surfaces.
    public func switchTo(_ target: Profile) async throws {
        guard let provider = registry.provider(withId: target.providerId) else {
            throw ProfileStoreError.providerNotFound(target.providerId)
        }
        let outgoing = store.activeProfile(forProvider: target.providerId)

        // Step 1 — freshen outgoing snapshots.
        if let outgoing, outgoing.id != target.id {
            try await snapshotOut(profile: outgoing, provider: provider)
        }

        // Step 2 — quit running desktop instances for any surface that the
        // outgoing or incoming profile manages.
        let desktopSurfaces = unionDesktopSurfaces(outgoing: outgoing,
                                                   target: target,
                                                   provider: provider)
        for surface in desktopSurfaces {
            try await surface.switcherFactory().quitRunningInstance()
        }

        // Step 3 — restore target snapshots.
        try await restoreIn(profile: target, provider: provider)

        // Step 4 — relaunch desktop surfaces the target manages.
        for surfaceId in target.surfaces {
            guard let surface = provider.surface(withId: surfaceId),
                  surface.kind == .desktopApp else { continue }
            try await surface.switcherFactory().relaunch()
        }

        // Step 5 — commit active.json.
        try store.setActive(target.id, forProvider: provider.id)
    }

    /// Capture the live state of the surfaces in `profile` into its on-disk
    /// folder, without changing what's active. Used by the "Capture from
    /// current state" option in the Add Profile sheet, and the "Capture
    /// into ****" menu item that appears for empty profiles after a manual
    /// login.
    public func captureCurrentState(into profile: Profile) async throws {
        guard let provider = registry.provider(withId: profile.providerId) else {
            throw ProfileStoreError.providerNotFound(profile.providerId)
        }
        try await snapshotOut(profile: profile, provider: provider)

        // If no profile is currently active for this provider, mark the new
        // one as active — the live state we just snapshotted *is* this profile.
        // Otherwise, leave active.json alone.
        let currentActiveId = store.activeStateByProvider[profile.providerId]?.activeProfileId
        if currentActiveId == nil {
            try store.setActive(profile.id, forProvider: profile.providerId)
        }
    }

    // MARK: - Step helpers

    private func snapshotOut(profile: Profile,
                             provider: ProviderDescriptor) async throws {
        for surfaceId in profile.surfaces {
            guard let surface = provider.surface(withId: surfaceId) else {
                throw SwitcherError.unknownSurface(surfaceId)
            }
            let dir = try FileSnapshot.ensureDirectory(
                store.surfaceSnapshotDirectory(providerId: provider.id,
                                               profileId: profile.id,
                                               surfaceId: surfaceId)
            )
            try await surface.switcherFactory().snapshotOut(into: dir)
        }
    }

    private func restoreIn(profile: Profile,
                           provider: ProviderDescriptor) async throws {
        for surfaceId in profile.surfaces {
            guard let surface = provider.surface(withId: surfaceId) else {
                throw SwitcherError.unknownSurface(surfaceId)
            }
            let dir = store.surfaceSnapshotDirectory(providerId: provider.id,
                                                    profileId: profile.id,
                                                    surfaceId: surfaceId)
            try await surface.switcherFactory().restoreIn(from: dir)
        }
    }

    private func unionDesktopSurfaces(outgoing: Profile?,
                                      target: Profile,
                                      provider: ProviderDescriptor) -> [SurfaceDescriptor] {
        var ids = Set<String>()
        if let outgoing { ids.formUnion(outgoing.surfaces) }
        ids.formUnion(target.surfaces)
        return ids.compactMap { provider.surface(withId: $0) }
            .filter { $0.kind == .desktopApp }
    }
}
