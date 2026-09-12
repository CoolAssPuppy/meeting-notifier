#!/bin/bash
#
# Set up and tear down local state for the Meeting Notifier Pro sandbox pass.
#
#   ./scripts/test-state.sh status          what is configured right now
#   ./scripts/test-state.sh backup          snapshot the app's UserDefaults
#   ./scripts/test-state.sh restore         put the snapshot back
#   ./scripts/test-state.sh accounts N      keep only the first N accounts
#   ./scripts/test-state.sh clear-license   forget the license and the cache
#   ./scripts/test-state.sh run             launch the Debug build
#   ./scripts/test-state.sh quit            stop it, which `xcodebuild test` needs
#
# Why this exists: the Debug build carries the same bundle id as the copy in
# /Applications, so it reads the same UserDefaults and the same Keychain. There
# is no separate sandbox profile to test against. Every command here therefore
# operates on real configuration, and every mutating one snapshots first.
#
# What it will not touch: the OAuth tokens. Removing an account through the app
# UI clears its Keychain entry and costs a re-authorization; trimming the
# accounts list here only rewrites UserDefaults, so the tokens survive and
# `restore` brings the account back intact.
#
# Expect a Keychain prompt the first time the Debug build reads your tokens, and
# possibly another from the release build afterwards. The Debug build is signed
# "Apple Development" and the shipped app is signed "Developer ID", so macOS sees
# two different programs asking for the same items even though the bundle id and
# team match. Click Always Allow. Clicking Deny leaves the app unable to read a
# token, which costs a re-authorization for that account.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_ID="com.strategicnerds.meetingnotifier"
PREFS="$HOME/Library/Preferences/$BUNDLE_ID.plist"
BACKUP_DIR="$REPO_ROOT/dist/test-state"
BACKUP="$BACKUP_DIR/$BUNDLE_ID.backup.plist"
APP="$REPO_ROOT/dist/debug/MeetingNotifier.app"
KEYCHAIN_SERVICE="$BUNDLE_ID"
ENTITLEMENT_KEY="entitlement.record.v1"

usage() {
  sed -n '3,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 1
}

# `defaults` caches aggressively and the app may be holding the file open, so
# every read and write is bracketed by a sync.
sync_prefs() {
  killall -u "$USER" cfprefsd >/dev/null 2>&1 || true
  sleep 0.3
}

require_backup() {
  if [[ ! -f "$BACKUP" ]]; then
    echo "Error: no backup at $BACKUP"
    echo "       Run './scripts/test-state.sh backup' before anything that mutates state."
    exit 1
  fi
}

accounts_json() {
  sync_prefs
  python3 - "$BUNDLE_ID" <<'PY' 2>/dev/null || echo "[]"
import json, plistlib, subprocess, sys
bundle = sys.argv[1]
raw = subprocess.run(["defaults", "export", bundle, "-"],
                     capture_output=True).stdout
if not raw:
    print("[]"); raise SystemExit
prefs = plistlib.loads(raw)
blob = prefs.get("accounts")
print(json.dumps(json.loads(blob) if blob else []))
PY
}

print_accounts() {
  python3 - "$1" <<'PYEOF'
import json, sys
accounts = json.loads(sys.argv[1] or "[]")
if not accounts:
    print("  (none)")
for index, account in enumerate(accounts):
    slot = "FREE slot" if index == 0 else "needs subscription"
    print("  %d. %-34s %-10s enabled=%-5s auth=%-10s [%s]"
          % (index + 1,
             account.get("email", "?"),
             account.get("provider", "?"),
             account.get("isEnabled"),
             account.get("authStatus"),
             slot))
PYEOF
}

cmd_status() {
  echo "Bundle:      $BUNDLE_ID"
  echo "Prefs:       $PREFS"
  if [[ -f "$BACKUP" ]]; then
    echo "Backup:      $BACKUP ($(date -r "$BACKUP" '+%Y-%m-%d %H:%M'))"
  else
    echo "Backup:      none — run 'backup' first"
  fi

  echo ""
  echo "Accounts:"
  print_accounts "$(accounts_json)"

  echo ""
  echo "Entitlement:"
  sync_prefs
  local record
  record="$(defaults read "$BUNDLE_ID" "$ENTITLEMENT_KEY" 2>/dev/null || true)"
  if [[ -z "$record" ]]; then
    echo "  no cached record (free tier)"
  else
    echo "  cached record present"
  fi

  echo ""
  echo "Keychain:"
  for account in license.key license.activation_id; do
    if security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$account" >/dev/null 2>&1; then
      echo "  $account: stored"
    else
      echo "  $account: absent"
    fi
  done

  echo ""
  echo "Baked Polar config in $APP:"
  if [[ -d "$APP" ]]; then
    for key in PolarOrgID PolarBenefitID PolarCheckoutURL PolarPortalURL PolarAPIBase; do
      value="$(defaults read "$APP/Contents/Info" "$key" 2>/dev/null || echo "")"
      [[ "$value" == '$('* ]] && value="(unsubstituted)"
      [[ -z "$value" ]] && value="(empty)"
      printf '  %-18s %s\n' "$key" "$value"
    done
  else
    echo "  no Debug build at $APP"
  fi
}

cmd_backup() {
  sync_prefs
  mkdir -p "$BACKUP_DIR"
  defaults export "$BUNDLE_ID" "$BACKUP"
  echo "Backed up UserDefaults to $BACKUP"
  echo "Note: this does not back up the Keychain. OAuth tokens are untouched by"
  echo "      every command here, so they need no snapshot."
}

cmd_restore() {
  require_backup
  sync_prefs
  defaults import "$BUNDLE_ID" "$BACKUP"
  sync_prefs
  echo "Restored UserDefaults from $BACKUP"
}

cmd_accounts() {
  local keep="${1:-}"
  if [[ ! "$keep" =~ ^[0-9]+$ ]]; then
    echo "Error: 'accounts' needs a number. e.g. ./scripts/test-state.sh accounts 1"
    exit 1
  fi
  require_backup
  sync_prefs

  python3 - "$BUNDLE_ID" "$keep" <<'PY'
import json, plistlib, subprocess, sys
bundle, keep = sys.argv[1], int(sys.argv[2])
raw = subprocess.run(["defaults", "export", bundle, "-"], capture_output=True).stdout
prefs = plistlib.loads(raw)
accounts = json.loads(prefs.get("accounts") or "[]")
trimmed = accounts[:keep]
subprocess.run(["defaults", "write", bundle, "accounts", "-data",
                json.dumps(trimmed).encode().hex()], check=True)
print(f"Kept {len(trimmed)} of {len(accounts)} accounts:")
for a in trimmed:
    print(f"  {a.get('email')}")
PY
  sync_prefs
  echo "OAuth tokens are untouched. 'restore' brings the others back intact."
}

cmd_clear_license() {
  require_backup
  sync_prefs
  defaults delete "$BUNDLE_ID" "$ENTITLEMENT_KEY" 2>/dev/null || true
  for account in license.key license.activation_id; do
    security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$account" >/dev/null 2>&1 || true
  done
  sync_prefs
  echo "Forgot the license key, the activation id, and the cached entitlement."
  echo "The activation is still claimed in Polar's customer portal. Release it"
  echo "there if you are re-running the activation-ceiling test."
}

cmd_run() {
  if [[ ! -d "$APP" ]]; then
    echo "Error: no Debug build at $APP"
    echo "       Run './scripts/debug.sh --polar --no-launch' first."
    exit 1
  fi
  pkill -x MeetingNotifier 2>/dev/null || true
  sleep 1
  open "$APP"
  echo "Launched $APP"
}

cmd_quit() {
  pkill -x MeetingNotifier 2>/dev/null || true
  echo "Stopped MeetingNotifier."
}

case "${1:-}" in
  status)        cmd_status ;;
  backup)        cmd_backup ;;
  restore)       cmd_restore ;;
  accounts)      shift; cmd_accounts "$@" ;;
  clear-license) cmd_clear_license ;;
  run)           cmd_run ;;
  quit)          cmd_quit ;;
  *)             usage ;;
esac
