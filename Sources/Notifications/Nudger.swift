//
//  Nudger.swift
//  AISwitch
//
//  Time-based reminder nudges (§8). For each provider that has
//  `reminderEveryHours` set in AppSettings, schedule a single non-repeating
//  UNNotificationRequest. Whenever the user switches profiles or the
//  cadence changes, we re-schedule — that gives us the "x hours since the
//  last switch" semantics the plan calls out.
//
//  Strict policy: this is a *time* nudge, not a quota probe. We don't read
//  rate-limit endpoints; that would be an unrelated and ToS-sensitive feature.
//
//  Concurrency: the class is `@MainActor` so it can hold the @Published
//  subscriptions and touch ProfileStore/AppSettings without hopping. The two
//  `UNUserNotificationCenterDelegate` callbacks (which the system delivers
//  off-main) live on a private `nonisolated` helper class.
//

import Foundation
import UserNotifications
import AppKit
import Combine

@MainActor
public final class Nudger: NSObject, ObservableObject {
    public static let shared: Nudger = MainActor.assumeIsolated {
        Nudger()
    }

    private let center = UNUserNotificationCenter.current()
    private var cancellables: Set<AnyCancellable> = []

    /// Tracks the last known authorization status. We honor "denied" by
    /// silently skipping all scheduling, instead of spamming logs every
    /// time `center.add` fails. Updated by `requestAuthorizationIfNeeded`
    /// and re-checked at the top of `rescheduleAll`.
    private var isAuthorized: Bool = false

    private override init() {
        super.init()

        let delegate = NudgerDelegate()
        center.delegate = delegate
        self.delegate = delegate

        registerCategory()

        Task { await self.requestAuthorizationIfNeeded() }

        AppSettings.shared.$model
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor in await self?.rescheduleAll() }
            }
            .store(in: &cancellables)

        ProfileStore.shared.$activeStateByProvider
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor in await self?.rescheduleAll() }
            }
            .store(in: &cancellables)

        Task { await self.rescheduleAll() }
    }

    /// Strong-held delegate. UNUserNotificationCenter holds its delegate
    /// weakly — without this property the delegate would deallocate.
    private var delegate: NudgerDelegate?

    // MARK: - Permission + category

    private func requestAuthorizationIfNeeded() async {
        // First check current status so we don't pop the system prompt on
        // every launch.
        let current = await center.notificationSettings()
        switch current.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            isAuthorized = true
            return
        case .denied:
            // User explicitly said no. Don't ask again; reminders are a
            // bonus feature, not a core one.
            isAuthorized = false
            return
        case .notDetermined:
            break  // fall through to request
        @unknown default:
            break
        }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            isAuthorized = granted
        } catch {
            // Common on ad-hoc-signed builds when Launch Services hasn't
            // registered the bundle yet (UNErrorDomain Code=1). Not fatal:
            // just disables reminders for this run. Once the app is in
            // /Applications and properly registered, this clears up.
            NSLog("[Nudger] notifications unavailable (\(error.localizedDescription)). Reminders disabled.")
            isAuthorized = false
        }
    }

    private func registerCategory() {
        let language = AppSettings.shared.model.appLanguage
        let actionTitle = Localizer.translate(LK.notifActionOpenSwitcher.rawValue,
                                              language: language)
        let action = UNNotificationAction(
            identifier: AppConstants.Notifications.actionOpenSwitcher,
            title: actionTitle,
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: AppConstants.Notifications.categoryReminder,
            actions: [action],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories(Set([category]))
    }

    // MARK: - Scheduling

    /// Re-build the set of pending reminder requests from the latest
    /// settings + active state. Called after every switch and after any
    /// settings change.
    public func rescheduleAll() async {
        // Skip silently when we don't have permission. Saves a flood of
        // "Notifications are not allowed" log lines on ad-hoc builds.
        guard isAuthorized else { return }

        center.removeAllPendingNotificationRequests()

        // Re-register category with the up-to-date localization for the
        // "Open Switcher" action title.
        registerCategory()

        let language = AppSettings.shared.model.appLanguage

        for provider in ProviderRegistry.shared.providers {
            let providerSettings = AppSettings.shared.providerSettings(for: provider.id)
            guard let everyHours = providerSettings.reminderEveryHours, everyHours > 0
            else { continue }

            let activeProfileAlias = ProfileStore.shared
                .activeProfile(forProvider: provider.id)?.alias

            let content = UNMutableNotificationContent()
            content.title = Localizer.translate(LK.notifReminderTitle.rawValue,
                                                language: language)
            if let alias = activeProfileAlias {
                content.body = Localizer.translate(
                    LK.notifReminderBodyActive.rawValue,
                    language: language,
                    alias, provider.displayName, Int(everyHours)
                )
            } else {
                content.body = Localizer.translate(
                    LK.notifReminderBodyInactive.rawValue,
                    language: language,
                    provider.displayName
                )
            }
            content.categoryIdentifier = AppConstants.Notifications.categoryReminder
            content.sound = .default

            let interval = max(60, everyHours * 3600) // sanity-clamp
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval,
                                                            repeats: false)
            let request = UNNotificationRequest(
                identifier: AppConstants.Notifications.reminderRequestPrefix + provider.id,
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
            } catch {
                NSLog("[Nudger] schedule failed for \(provider.id): \(error)")
            }
        }
    }
}

// MARK: - Delegate (non-isolated, called off-main by the system)

private final class NudgerDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action = response.actionIdentifier
        if action == AppConstants.Notifications.actionOpenSwitcher
            || action == UNNotificationDefaultActionIdentifier {
            Task { @MainActor in
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        completionHandler()
    }
}
