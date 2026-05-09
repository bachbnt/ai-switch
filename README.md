# AISwitch

A macOS menu-bar app that switches between multiple authenticated accounts across **Anthropic** (Claude desktop, Claude Code CLI) and **OpenAI** (ChatGPT desktop, Codex CLI) — without re-doing email verification each time.

The architecture is provider-pluggable: Anthropic and OpenAI are isolated namespaces today, and a third vendor is two new files later.

---

## Features

- Independent per-provider active state — you can be on Anthropic profile A and OpenAI profile X simultaneously.
- Switch by clicking. Snapshots the outgoing profile's tokens before restoring the new one (OAuth refresh tokens rotate on use; this keeps every profile's stored state fresh).
- Profile snapshots encrypted at rest (AES-256-GCM, key in app's own Keychain entry).
- Time-based reminder banners per provider (off by default for OpenAI, every 3h for Anthropic — both configurable).
- In-app **English / Tiếng Việt** language switch (no relaunch).
- In-app **Light / Dark / System** appearance toggle.
- All preferences persist across launches at `~/Library/Application Support/AISwitch/config.json`.
- Free coverage of VSCode + Cursor + Windsurf + Antigravity (extensions read CLI state, so a CLI switch is enough).

---

## Status

v0.1 scaffold. All Phase 1–5 code from the implementation plan is in place. Phase 0 (Keychain service-name discovery on a real Mac) needs to run once before the actual switching will work — see [Phase 0 — Discovery](#phase-0--discovery) below.

---

## Quickstart (build & install on your own Mac)

```sh
# One-time
bash scripts/setup.sh

# Build a Release .app (ad-hoc signed, fine for personal use)
bash scripts/build_release.sh

# Install
cp -R build/Release/AISwitch.app /Applications/
open /Applications/AISwitch.app

# Phase 0 — discover Keychain service/account names, then edit the four
# *Switcher.swift files. (Required before switching will work.)
bash scripts/phase0_discovery.sh
```

The first time you launch from `/Applications`, macOS Gatekeeper will warn that the app comes from an unidentified developer. Right-click the app → **Open**, then click **Open** in the dialog. macOS remembers the choice.

---

## Build paths

There are three ways to build, all using the same source tree.

### A. Build with Xcode (GUI)

Best for active development.

```sh
brew install xcodegen
xcodegen generate
open AISwitch.xcodeproj
```

In Xcode:

1. Select the `AISwitch` scheme in the toolbar.
2. Pick a signing team in *Signing & Capabilities* (or leave **Sign to Run Locally** for personal use).
3. Press **⌘R** to build and run, or **Product → Archive** for a Release build.

`AISwitch.xcodeproj/` is generated and gitignored — `project.yml` is the source of truth. Re-run `xcodegen generate` whenever you add or remove source files.

### B. Build from CLI

Best for CI or scripted release pipelines.

```sh
# Ad-hoc signed (personal use)
bash scripts/build_release.sh

# Output: build/Release/AISwitch.app
```

Under the hood, this runs:

```sh
xcodebuild -project AISwitch.xcodeproj \
           -scheme AISwitch \
           -configuration Release \
           -derivedDataPath build/DerivedData \
           CODE_SIGN_IDENTITY="-" \
           CODE_SIGNING_REQUIRED=NO \
           clean build
```

To sign with a Developer ID certificate:

```sh
DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" \
    bash scripts/build_release.sh
```

### C. Build a `.dmg` installer

Best for sharing with others.

```sh
brew install create-dmg                   # optional but produces a nicer layout
bash scripts/build_dmg.sh
# Output: dist/AISwitch-0.1.0.dmg
```

The DMG contains the `.app` plus a drag-to-`/Applications` shortcut. If `create-dmg` isn't installed, the script falls back to plain `hdiutil` — works the same, just without the polished window layout.

---

## Sharing the installer with coworkers

For your own personal Mac, an **ad-hoc-signed** `.app` or `.dmg` (the default output of `build_release.sh` / `build_dmg.sh`) works fine. The first launch hits Gatekeeper; right-click → Open and macOS remembers.

For coworkers to install **without** the Gatekeeper warning, the binary needs to be signed with a *Developer ID Application* certificate AND notarized by Apple. The recipe:

1. **Get a Developer ID certificate** (one-time, $99/year for Apple Developer Program). In Xcode → Settings → Accounts → Manage Certificates → click **+** → *Developer ID Application*.

2. **Sign the build:**
   ```sh
   DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" \
       bash scripts/build_release.sh
   DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" \
       bash scripts/build_dmg.sh
   ```

3. **Store an app-specific password** for `notarytool` (one-time):
   ```sh
   xcrun notarytool store-credentials AISwitchNotary \
       --apple-id you@example.com \
       --team-id TEAMID \
       --password <app-specific-password>
   ```
   (Generate the app-specific password at https://appleid.apple.com → Sign-In and Security → App-Specific Passwords.)

4. **Notarize the DMG:**
   ```sh
   xcrun notarytool submit dist/AISwitch-0.1.0.dmg \
       --keychain-profile AISwitchNotary --wait
   xcrun stapler staple dist/AISwitch-0.1.0.dmg
   ```

5. Share `dist/AISwitch-0.1.0.dmg`. Coworkers double-click → drag to Applications → launch normally, no warnings.

For **personal-only** use, skip steps 1, 3, 4, 5 and you're done.

---

## Phase 0 — Discovery

Before AISwitch can actually switch accounts, it needs the real Keychain service/account strings used by Claude.app, Claude Code CLI, ChatGPT.app, and Codex CLI on your Mac. These vary by vendor app version, so we discover them rather than hardcode them.

```sh
bash scripts/phase0_discovery.sh
```

This dumps every Keychain entry that mentions `claude`, `anthropic`, `openai`, `chatgpt`, or `codex`, plus the relevant Application Support directories. Copy the exact `service` / `account` strings into:

- `Sources/Switcher/Anthropic/ClaudeCLISwitcher.swift`
- `Sources/Switcher/Anthropic/ClaudeDesktopSwitcher.swift`
- `Sources/Switcher/OpenAI/CodexCLISwitcher.swift`
- `Sources/Switcher/OpenAI/ChatGPTDesktopSwitcher.swift`

(Search for `TODO(Phase0)` to find the exact lines.)

Then run the snapshot/restore proof end-to-end on **one** surface before adding more profiles. The implementation plan's §12 lists the failure modes to watch for (hardware-bound auth, MDM device attestation, etc.).

---

## Storage layout

Provider-namespaced from day 1:

```
~/Library/Application Support/AISwitch/
├── config.json                 # language, appearance, per-provider reminder cadence
└── providers/
    ├── anthropic/
    │   ├── profiles/<uuid>/
    │   │   ├── meta.json
    │   │   ├── claude-cli/         # snapshot of ~/.claude
    │   │   ├── claude-desktop/     # snapshot of Application Support
    │   │   └── keychain.bin        # encrypted keychain blob
    │   └── active.json
    └── openai/
        ├── profiles/<uuid>/
        │   ├── meta.json
        │   ├── codex-cli/
        │   ├── chatgpt-desktop/
        │   └── keychain.bin
        └── active.json
```

Each provider has its own `active.json`. Switching Anthropic does not touch OpenAI.

---

## Refresh-token rule (non-negotiable)

OAuth refresh tokens rotate on use. Every switch *out of* a profile snapshots the live state back into that profile's folder before restoring the target — so each profile's stored tokens are always the freshest version we've seen. See `Sources/Switcher/SwitchEngine.swift` and §5 of the plan.

## Token storage at rest

Refresh tokens on disk are encrypted with **AES-256-GCM** via Apple's CryptoKit. The key is stored in the app's own Keychain entry (`com.bachbnt.AISwitch / encryption-key`). A stolen profile folder alone is not enough to impersonate the account.

---

## Localization

Strings live in `Resources/<lang>.lproj/Localizable.strings` (`en` and `vi` currently). Adding a string:

1. Add a case to `Sources/Localization/LocalizationKey.swift`.
2. Add the key to **both** `en.lproj/Localizable.strings` and `vi.lproj/Localizable.strings`.
3. Use it in views via `settings.t(.yourKey)`.

The active language is read from `AppSettings.model.appLanguage` and applied via `Localizer.translate(_:language:)`. Switching language in *Settings → General* updates immediately without a relaunch.

Adding a third language: create `Resources/<code>.lproj/Localizable.strings`, add the code to `CFBundleLocalizations` in `Resources/Info.plist`, add a case to `AppLanguage`, and add a row to the `Settings` picker.

---

## Project layout

```
ai-switch/
├── README.md
├── project.yml                       # XcodeGen spec (generates AISwitch.xcodeproj)
├── Resources/
│   ├── Info.plist                    # Hand-written; LSUIElement=true, CFBundleLocalizations=[en,vi]
│   ├── AISwitch.entitlements         # App Sandbox off, Hardened Runtime on
│   ├── Assets.xcassets/              # AppIcon + brand color sets
│   ├── en.lproj/Localizable.strings
│   └── vi.lproj/Localizable.strings
├── scripts/
│   ├── setup.sh                      # First-time: brew install + xcodegen
│   ├── build_release.sh              # xcodebuild Release → build/Release/AISwitch.app
│   ├── build_dmg.sh                  # → dist/AISwitch-<version>.dmg
│   └── phase0_discovery.sh           # Keychain + path probe
└── Sources/
    ├── App.swift                     # @main, MenuBarExtra, applies locale + colorScheme
    ├── Constants/AppConstants.swift  # IDs, asset names, bundle IDs (no UI strings)
    ├── Localization/
    │   ├── AppLanguage.swift
    │   ├── AppAppearance.swift
    │   ├── LocalizationKey.swift     # type-safe enum of every UI key
    │   └── Localizer.swift           # bundle-resolving translator
    ├── Model/
    │   ├── Profile.swift             # struct matching meta.json
    │   ├── ActiveState.swift         # per-provider active.json
    │   ├── ProfileStore.swift        # CRUD, alias-uniqueness, ordering
    │   ├── AppSettings.swift         # config.json (language, appearance, reminders)
    │   └── ProviderDescriptor.swift  # provider/surface metadata + registry
    ├── Providers/
    │   ├── AnthropicProvider.swift
    │   └── OpenAIProvider.swift
    ├── Switcher/
    │   ├── Switcher.swift            # protocol
    │   ├── SwitchEngine.swift        # 5-step lifecycle (§5 of plan)
    │   ├── Shared/
    │   │   ├── KeychainHelper.swift          # Security.framework + AES-256-GCM
    │   │   ├── EncryptedSnapshotStore.swift
    │   │   ├── FileSnapshot.swift            # atomic dir copy with backup-on-failure
    │   │   └── AppLifecycle.swift            # quit / launch via NSWorkspace
    │   ├── Anthropic/
    │   │   ├── ClaudeCLISwitcher.swift
    │   │   └── ClaudeDesktopSwitcher.swift
    │   └── OpenAI/
    │       ├── CodexCLISwitcher.swift
    │       └── ChatGPTDesktopSwitcher.swift
    ├── Views/
    │   ├── MenuBarView.swift
    │   ├── ProviderSectionView.swift
    │   ├── ProfileRowView.swift
    │   ├── AddEditProfileSheet.swift
    │   ├── ColorSwatchPicker.swift
    │   ├── IconPickerView.swift
    │   └── SettingsView.swift
    └── Notifications/
        └── Nudger.swift              # UNUserNotificationCenter
```

---

## ToS line

This tool helps you **manually** switch between accounts you legitimately own at different employers. It does not detect rate limits. It does not auto-switch on cap. It does not fan a single workload across multiple accounts of the same provider. The notification is a time-based nudge.

These boundaries apply equally to Anthropic and OpenAI. Both vendors have usage policies that prohibit using multiple accounts to circumvent rate limits on the same workload; neither prohibits a person legitimately holding accounts at two different employers. Keep the tool on the right side of that distinction — that's what makes it shippable.

## License

TBD.
