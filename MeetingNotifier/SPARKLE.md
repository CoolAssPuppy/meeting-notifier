# Sparkle auto-update setup

MeetingNotifier ships with [Sparkle 2](https://sparkle-project.org). Users get "Check for Updates…" in the status-bar menu and in Settings > Updates, plus daily automatic checks.

Appcast and release DMGs live in the **Cloudflare R2 `strategic-nerds-downloads` bucket** (shared with Agent Server and Mail Notifier — each app has its own folder under `apps/`). The bucket is exposed publicly at `https://downloads.strategicnerds.com`. The appcast URL is fronted by a Dub.co shortlink so the feed location can be moved later without re-shipping the app.

URLs:

- **Feed (baked into the app)**: `https://coolasspuppy.com/meeting-notifier-updates` (Dub shortlink)
- **Appcast destination**: `https://downloads.strategicnerds.com/apps/meeting-notifier/appcast.xml`
- **DMG pattern**: `https://downloads.strategicnerds.com/apps/meeting-notifier/MeetingNotifier-<version>.dmg`
- **Latest DMG (stable URL)**: `https://downloads.strategicnerds.com/apps/meeting-notifier/MeetingNotifier-latest.dmg` (overwritten on every release)

Do steps 1 through 5 once. Then step 6 on every release.

## 1. Generate the signing key (one time, irreversible)

Sparkle's `generate_keys` tool creates an Ed25519 key pair. The private key lives in the macOS keychain. **If you lose it, every installed copy of the app is permanently stranded** because it can no longer verify new updates. There is no recovery.

Do not reuse the Mail Notifier or Agent Server private key. Each app should have its own so a compromise in one doesn't let an attacker push fake updates to another.

After running the debug script (or opening the project in Xcode) once so SPM resolves Sparkle, the tool is at:

```
~/Library/Developer/Xcode/DerivedData/MeetingNotifier-*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
```

Run it with a keychain-account name specific to this app so it doesn't collide with other Sparkle keys:

```bash
cd ~/Library/Developer/Xcode/DerivedData/MeetingNotifier-*/SourcePackages/artifacts/sparkle/Sparkle/bin
./generate_keys --account com.strategicnerds.meetingnotifier
```

It will:
- Create a new key pair on first run, or print the existing public key on later runs.
- Store the private key in the login keychain under "Private key for signing Sparkle updates" with account `com.strategicnerds.meetingnotifier`.
- Print the base64 **public** key to stdout.

`sign_update` needs to know which account to use, since you may have several. The release script already passes `--account com.strategicnerds.meetingnotifier` to `sign_update`, so no further action is needed once the key exists in Keychain.

**Back up the private key now.** Keychain Access will not let you export it directly (Sparkle stores the key as a generic-password item and the Export menu is greyed out). Use `generate_keys -x` to dump it to a PEM file, then store the PEM contents in your password manager:

```bash
~/Library/Developer/Xcode/DerivedData/MeetingNotifier-*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys \
  --account com.strategicnerds.meetingnotifier \
  -x ~/meeting-notifier-sparkle-private.pem
```

The contents of `~/meeting-notifier-sparkle-private.pem` are stored in **Doppler** under `meeting-notifier/dev` as `SPARKLE_PRIVATE_KEY`. (This is a different Doppler project from mail-notifier so the two keys don't collide.)

After confirming the secret is in Doppler, wipe the local file:

```bash
rm -P ~/meeting-notifier-sparkle-private.pem
```

### Restoring the private key on a new machine

```bash
doppler secrets get SPARKLE_PRIVATE_KEY \
  --project meeting-notifier --config dev --plain \
  > /tmp/meeting-notifier-sparkle-private.pem

~/Library/Developer/Xcode/DerivedData/MeetingNotifier-*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys \
  --account com.strategicnerds.meetingnotifier \
  -f /tmp/meeting-notifier-sparkle-private.pem

rm -P /tmp/meeting-notifier-sparkle-private.pem
```

Verify by running `generate_keys --account com.strategicnerds.meetingnotifier -p` — it should print the same public key that lives in `Info.plist` (`SUPublicEDKey`). If it prints a different key, the restore produced a mismatched pair and any DMG signed with it will fail verification on installed apps.

Copy the public key that `generate_keys` printed. You'll paste it in step 4.

## 2. Confirm the R2 bucket

The `strategic-nerds-downloads` R2 bucket already hosts Agent Server and Mail Notifier artifacts and is public via `downloads.strategicnerds.com`. Each app lives under `apps/<app-name>/`. No new bucket needed.

The release script automatically uploads `dist/appcast.xml` to `apps/meeting-notifier/appcast.xml` on every release. The bootstrap appcast (an empty channel) is checked into `dist/appcast.xml` and looks like:

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>MeetingNotifier</title>
    <link>https://downloads.strategicnerds.com/apps/meeting-notifier/appcast.xml</link>
    <description>MeetingNotifier updates</description>
    <language>en</language>
  </channel>
</rss>
```

After the first release, verify by opening `https://downloads.strategicnerds.com/apps/meeting-notifier/appcast.xml` in a browser — you should see the XML with at least one `<item>`.

## 3. Create the Dub.co shortlink

Create it once in the Dub dashboard:

- **Short URL**: `https://coolasspuppy.com/meeting-notifier-updates`
- **Destination URL**: `https://downloads.strategicnerds.com/apps/meeting-notifier/appcast.xml`

Settings:
- Cloaking/frame: **OFF** (Sparkle needs a plain HTTP redirect, not an iframe wrapper).
- Password: **OFF**.
- Link expiration: **OFF**.

Test:

```bash
curl -sI "https://coolasspuppy.com/meeting-notifier-updates" | grep -i '^location:'
```

You should see a `location:` header pointing at the R2 URL above.

**This slug is baked into every shipped copy of the app and cannot be changed.** You can repoint the destination URL later. You cannot change the slug.

## 4. Paste the public key into project.yml

Edit `project.yml`. Replace the placeholder with the base64 public key from step 1:

```yaml
info:
  properties:
    SUPublicEDKey: "PASTE_BASE64_PUBLIC_KEY_HERE"
```

Then regenerate the project:

```bash
xcodegen generate
```

`SUFeedURL` is already `https://coolasspuppy.com/meeting-notifier-updates`. Do not point it at the raw Supabase URL.

Commit that change.

## 5. Confirm the notarytool keychain profile

The release script uses the existing `agent-server` keychain profile (reused across Strategic Nerds apps). Verify:

```bash
xcrun notarytool history --keychain-profile agent-server
```

If it doesn't work, register it with an [app-specific password](https://support.apple.com/en-us/HT204397):

```bash
xcrun notarytool store-credentials "agent-server" \
  --apple-id "you@example.com" \
  --team-id "955GSY56UT" \
  --password "app-specific-password"
```

## 6. Release flow (every release)

```bash
./scripts/release.sh 1.2.0 "<li>First Developer ID release.</li><li>Auto-updates via Sparkle.</li>"
```

The script:
1. Bumps `CFBundleShortVersionString` to the argument and increments `CFBundleVersion`.
2. Regenerates the Xcode project via `xcodegen`.
3. Archives + exports a Developer ID-signed `.app`.
4. Notarizes + staples the `.app`.
5. Builds a signed + notarized + stapled DMG and Sparkle-signs it.
6. Pulls Cloudflare R2 credentials from Doppler (`agent-server/prd`: `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `R2_BUCKET_NAME`, `R2_PUBLIC_BASE_URL`).
7. Uploads the DMG to `apps/meeting-notifier/MeetingNotifier-<version>.dmg` AND `apps/meeting-notifier/MeetingNotifier-latest.dmg`, plus the updated `dist/appcast.xml` to `apps/meeting-notifier/appcast.xml` (all via `wrangler r2 object put`).
8. Verifies the feed via the Dub shortlink.

Commit `project.yml` and `dist/appcast.xml` after a successful release.

### Verify end-to-end

On a machine running a previous version:

1. Status bar icon > "Check for Updates…"
2. You should see the update prompt with your release notes.
3. Let it download and install.

If the check says "You're up to date", something is off:
- `CFBundleVersion` didn't actually increase in the committed `project.yml`.
- `pubDate` is malformed in the appcast, so Sparkle discarded the item.
- Dub shortlink is returning HTML instead of a redirect (cloaking got turned on).

If the download fails signature verification, the Ed25519 key in Keychain doesn't match `SUPublicEDKey` in the shipped `Info.plist`, or the DMG was modified after `sign_update` ran.

## iCloud Key-Value Storage (one-time)

Settings and the account list sync across your Macs via `NSUbiquitousKeyValueStore`. Under App Store distribution this worked automatically. Under Developer ID you need to enable the capability once in the Apple Developer portal so it flows into the provisioning profile.

1. Open https://developer.apple.com/account/resources/identifiers/list
2. Click the `com.strategicnerds.meetingnotifier` identifier.
3. In **App Services**, enable **iCloud** and click **Configure**.
4. Tick **Key-Value Storage**. Leave **CloudKit** off — this app doesn't use it.
5. Save. Apple regenerates the associated provisioning profile.
6. Run `xcodegen generate` then `./scripts/debug.sh` once so automatic signing pulls the new profile down.

To verify it worked, launch the app and watch the log:

```bash
log stream --predicate 'subsystem == "com.strategicnerds.meetingnotifier" AND category == "sync"' --info --debug
```

You should see `iCloud KV store is provisioned and reachable` on every launch. If it says `NOT provisioned`, either the portal step didn't propagate to the profile, or the user is signed out of iCloud.

## Notes

- Do not amend released `<item>` entries. If you ship a bad build, bump the version again.
- Never rotate the Dub shortlink slug. You can repoint the destination URL as often as you want.
- Never rotate the Ed25519 key unless you're willing to manually reach every user. There is no key rotation mechanism in Sparkle.
- Sparkle's XPC services are embedded in the SPM product; the app is unsandboxed so no extra entitlements are needed.
- The DMG must itself be signed + notarized + stapled, not just the `.app` inside. Sparkle verifies notarization before mounting.
- Do not re-enable the App Sandbox without first reworking the Sparkle install path: the Sandbox forbids the installer XPC from writing to `/Applications`, which is how Sparkle replaces the running app.
