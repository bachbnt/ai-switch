#!/usr/bin/env bash
#
# phase0_discovery.sh -- run once on your Mac before relying on AISwitch.
#
# Outputs three things you'll paste into the Switcher source files:
#
#   1. Keychain service/account strings for every entry mentioning
#      claude / anthropic / openai / chatgpt / codex.
#   2. The bundle identifier of Claude.app and ChatGPT.app (so we know we
#      have the right strings in ClaudeDesktopSwitcher / ChatGPTDesktopSwitcher).
#   3. A snapshot of the live config directories ~/.claude and ~/.codex,
#      and the relevant Application Support directories -- so we know
#      they exist and are readable.
#
# Nothing is modified. Read-only.
#
# Usage:
#   bash scripts/phase0_discovery.sh
#
# (You'll need to grant Keychain Access. macOS may prompt the first time.)

set -u

separator() {
    printf '\n%s\n' '------------------------------------------------------------'
}

# ------------------------------------------------------------------
# 1. Keychain entries
# ------------------------------------------------------------------
separator
echo "[1/3] Keychain entries (service / account)"
separator

# `security dump-keychain` prints every generic-password attribute.
# We grep for service ("svce") or account ("acct") lines that mention
# any of the relevant vendor strings, then print the whole record around
# each match for context.
security dump-keychain 2>/dev/null \
    | awk '
        BEGIN { record = "" }
        /^keychain:/ { if (length(record) && match(record, /claude|anthropic|openai|chatgpt|codex/)) print record "\n---"; record = $0; next }
        { record = record "\n" $0 }
        END { if (length(record) && match(record, /claude|anthropic|openai|chatgpt|codex/)) print record "\n---" }
    ' \
    | grep -iE '("svce"|"acct"|"desc"|"labl")' \
    | sed 's/^[[:space:]]*//'

# ------------------------------------------------------------------
# 2. Bundle identifiers
# ------------------------------------------------------------------
separator
echo "[2/3] Vendor app bundle identifiers"
separator

for app in "/Applications/Claude.app" "/Applications/ChatGPT.app"; do
    if [[ -e "$app" ]]; then
        bundle_id=$(defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null \
                    || /usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" \
                       "$app/Contents/Info.plist" 2>/dev/null \
                    || echo "<unreadable>")
        printf '  %-32s  ->  %s\n' "$app" "$bundle_id"
    else
        printf '  %-32s  ->  (not installed)\n' "$app"
    fi
done

# ------------------------------------------------------------------
# 3. Live config directories
# ------------------------------------------------------------------
separator
echo "[3/3] Live config directories"
separator

for dir in \
    "$HOME/.claude" \
    "$HOME/.codex" \
    "$HOME/Library/Application Support/Claude" \
    "$HOME/Library/Application Support/ChatGPT" \
    "$HOME/Library/Application Support/com.openai.chat"
do
    if [[ -e "$dir" ]]; then
        size=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
        printf '  [yes] %-58s  (%s)\n' "$dir" "$size"
    else
        printf '  [no]  %-58s  (missing)\n' "$dir"
    fi
done

separator
cat <<'EOF'
Next steps:

  1. Copy the (svce, acct) pairs from section [1] into the
     `keychainItems` constants in:

         Sources/Switcher/Anthropic/ClaudeCLISwitcher.swift
         Sources/Switcher/Anthropic/ClaudeDesktopSwitcher.swift
         Sources/Switcher/OpenAI/CodexCLISwitcher.swift
         Sources/Switcher/OpenAI/ChatGPTDesktopSwitcher.swift

  2. If section [2] reports a bundle identifier different from the
     placeholders in the *DesktopSwitcher.swift files, update those.

  3. Snapshot/restore proof: pick *one* surface, run AISwitch, add a
     profile in capture-from-current mode, then delete the live Keychain
     entry by hand and use AISwitch to "switch back to this profile".
     If the app stays signed in, the surface is good. If not, fall back
     to the cloned-bundle approach noted in section 12 of the plan.
EOF
