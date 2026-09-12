#!/bin/bash
#
# Refuse to ship a binary with a credential compiled into it.
#
#   ./scripts/check-no-secrets.sh <path-to-binary-or-.app>
#
# Why this exists: gitignore protects the repository and says nothing about the
# product. `*Secret.swift` has always been ignored and the real values have
# never been committed, so every repo-level scan reported clean while both the
# Google and Microsoft OAuth client secrets shipped inside every DMG, findable
# with one `strings` command. Nothing in the release path looked at the built
# artifact. This does.
#
# Run against the exported .app before notarizing.

set -euo pipefail

TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <path-to-binary-or-.app>"
  exit 2
fi

# Accept either a bundle or a bare executable.
if [[ -d "$TARGET" ]]; then
  NAME="$(basename "$TARGET" .app)"
  BIN="$TARGET/Contents/MacOS/$NAME"
else
  BIN="$TARGET"
fi

if [[ ! -f "$BIN" ]]; then
  echo "Error: no executable at $BIN"
  exit 2
fi

# A Debug build is not a valid subject. Debug and Release embed string constants
# differently: on 2026-09-12 a Debug build showed zero occurrences of a secret
# that a Release build of the same source embedded twice. Scanning Debug gives a
# false all-clear, which is worse than not scanning at all.
if [[ "$BIN" == *"/Debug/"* || "$BIN" == *"/dist/debug/"* ]]; then
  echo "Error: refusing to scan a Debug build. Debug omits constants that Release embeds,"
  echo "       so a clean result here would mean nothing. Scan the exported Release .app."
  exit 2
fi

# Each entry is "label<TAB>extended-regex". Patterns match the *shape* of a
# credential, so a newly minted one is caught without this file ever holding a
# real value.
# Google's installed-app secret is deliberately NOT here. It cannot be removed:
# verified 2026-09-12 that omitting it returns "client_secret is missing." from
# Google's token endpoint for this exact Desktop client, so emptying it stops
# every Google account refreshing. Google's own guidance is that an installed
# app's secret "is obviously not treated as a secret"; PKCE is the real boundary.
# If that ever changes, add: "Google OAuth client secret\tGOCSPX-[A-Za-z0-9_-]{20,}"
PATTERNS=(
  "Microsoft Entra client secret	[A-Za-z0-9]{3}[0-9]Q~[A-Za-z0-9_.~-]{30,}"
  "AWS access key id	AKIA[0-9A-Z]{16}"
  "Slack token	xox[baprs]-[0-9A-Za-z-]{10,}"
  "Stripe secret key	sk_live_[0-9A-Za-z]{20,}"
  "Private key block	BEGIN (RSA |EC |OPENSSH |PGP )?PRIVATE KEY"
)

echo "==> Scanning $(basename "$BIN") for embedded credentials"
FOUND=0
STRINGS="$(strings -a "$BIN")"

while IFS=$'\t' read -r label pattern; do
  [[ -z "$label" ]] && continue
  count=$(printf '%s\n' "$STRINGS" | grep -cE "$pattern" || true)
  if [[ "$count" -gt 0 ]]; then
    echo "  FAIL: $label found ($count occurrence(s))"
    FOUND=$((FOUND + count))
  fi
done < <(printf '%s\n' "${PATTERNS[@]}")

if [[ "$FOUND" -gt 0 ]]; then
  cat <<'MSG'

Refusing to ship. A credential is compiled into this binary, which means anyone
who downloads the app can read it with `strings`.

If the value is genuinely public (an OAuth client *id*, a PostHog project key),
widen the pattern in scripts/check-no-secrets.sh and say why in the comment.
Otherwise empty the constant, reconfigure the provider as a public client, and
rotate the value.
MSG
  exit 1
fi

echo "  Clean: no known credential shapes in the binary."
