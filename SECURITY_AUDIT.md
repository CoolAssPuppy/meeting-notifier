# Security Audit – MeetingNotifier

Date: 2026-04-20  
Scope: Full repository static review focused on account-compromise paths (OAuth, token handling, link handling, persistence, logging, and entitlements).

## Executive Summary

I reviewed authentication, token lifecycle, calendar API integration, meeting-link parsing/opening, local persistence, and app entitlement scope.

### Overall risk posture
- **High risk issues:** 1
- **Medium risk issues:** 5
- **Low risk issues:** 2

The most serious issue that could plausibly lead to credential theft/account compromise is **overly-permissive meeting-link validation**, which currently accepts any URL string containing trusted domain substrings (e.g., attacker-controlled hostnames containing `zoom.us` in the query/path).

---

## Findings

## 1) High — Meeting link validation is vulnerable to domain confusion/phishing

**Impact:** A malicious calendar invite can cause the app to open attacker-controlled pages that look like legitimate meeting/auth pages and steal credentials/session cookies.

**Evidence:**
- Meeting links are considered valid using substring checks (`contains`) instead of strict URL host allowlisting.  
- This impacts parsing and opening flows from both Google and Microsoft event payloads.

**Relevant code paths:**
- `MeetingLinkParser.isValidMeetingLink` uses `contains("zoom.us")`, `contains("meet.google.com")`, etc.
- Calendar managers trust this validation to accept conference links.
- `URLOpener` then opens whatever URL passes validation.

**Exploit sketch:**
- Attacker creates event with URL like `https://evil.example/login?next=https://teams.microsoft.com`.
- Current validation accepts it because the URL string contains `teams.microsoft.com`.
- App opens it; victim is phished.

**Recommendation:**
- Parse with `URLComponents` and enforce exact/suffix host matches (`meet.google.com`, `*.zoom.us`, `teams.microsoft.com`, etc.).
- Enforce `https` scheme.
- Reject userinfo (`user@host`) ambiguities.

---

## 2) Medium — OAuth callback relies on custom URL schemes (interception risk)

**Impact:** On desktop platforms, custom URL scheme callbacks can be intercepted/hijacked by another local app registering the same scheme, risking auth code/token interception in hostile local environments.

**Evidence:**
- OAuth redirects are custom schemes:
  - `com.googleusercontent.apps...:/oauthredirect`
  - `com.strategicnerds.meetingnotifier://oauthredirect`
- Callback handling depends on string prefix matching.

**Recommendation:**
- Prefer loopback redirect URIs (localhost) + PKCE when provider/app registration allows.
- If staying with custom schemes, harden callback validation and keep AppAuth state/nonce enforcement strict.

---

## 3) Medium — ID token claims are decoded but not cryptographically validated by app code

**Impact:** Identity binding depends on upstream library behavior; app logic extracts email directly from decoded JWT payload without local claim validation (`iss`, `aud`, `exp`, `nonce`).

**Evidence:**
- Both OAuth managers split/decode JWT payload and directly read `email` / `preferred_username`.

**Recommendation:**
- Prefer identity from a validated userinfo endpoint or validated token object APIs from AppAuth.
- If decoding ID tokens manually, validate signature and required claims.

---

## 4) Medium — Token/key storage policy can be hardened

**Impact:** Keychain item accessibility currently uses `kSecAttrAccessibleAfterFirstUnlock`; this broadens exposure window compared with stricter classes. API keys are intentionally syncable, increasing blast radius if a synced account is compromised.

**Evidence:**
- Keychain writes set `kSecAttrAccessibleAfterFirstUnlock` for all stored secrets.
- API keys are marked syncable; OAuth tokens are local by account naming convention.

**Recommendation:**
- Use stricter accessibility for high-value secrets (e.g., `WhenUnlockedThisDeviceOnly` for OAuth refresh/access tokens).
- Consider user-configurable sync policy for third-party AI API keys.

---

## 5) Medium — Potential sensitive-data leakage through logs

**Impact:** AI API error logging writes response body with `privacy: .public`. Depending on provider behavior, this may include prompt/transcript fragments, account metadata, or diagnostic tokens.

**Evidence:**
- Summarizer logs `responseBody` publicly on non-200 responses.

**Recommendation:**
- Log only status code + request ID.
- Redact response body by default or mark private.

---

## 6) Medium — Crash recovery transcript is persisted in plaintext

**Impact:** Active transcript (potentially sensitive meeting content) is periodically written to `Application Support` as JSON.

**Evidence:**
- Auto-save every 30s writes `active-transcript.json`.

**Recommendation:**
- Encrypt at rest (e.g., keychain-derived key / FileProtection equivalent on macOS policy) or minimize retained fields.
- Ensure strict file permissions and immediate cleanup on success.

---

## 7) Low — Camera entitlement appears broader than required behavior

**Impact:** Increases app permission surface and user concern; unnecessary entitlements are security debt.

**Evidence:**
- Camera entitlement is enabled.
- Camera detection logic is disabled in runtime comments.

**Recommendation:**
- Remove camera entitlement unless an active feature truly needs it.

---

## 8) Low — URL handling for custom meeting app path could use additional validation

**Impact:** A tampered local preference could force links to open in an unexpected binary. This is mostly local-user threat model, but hardening is cheap.

**Evidence:**
- `customMeetAppPath` is loaded from `UserDefaults` and used directly as app URL.

**Recommendation:**
- Validate app bundle signature/identifier before launching.
- Require path existence + `.app` bundle checks.

---

## What was reviewed

- OAuth/account flow: `AuthManager`, `GoogleOAuthManager`, `MicrosoftOAuthManager`
- Token storage: `KeychainManager`
- Calendar ingestion: `GoogleCalendarManager`, `MicrosoftCalendarManager`
- Meeting link parsing/opening: `MeetingLinkParser`, `URLOpener`
- Transcript and AI paths: `TranscriptionCoordinator`, `OpenAISummarizer`
- App capability scope: `MeetingNotifier.entitlements`, `Info.plist`, project config
- Repo-level secret hygiene: `.gitignore`, tracked files, secret-pattern scan

## Priority Remediation Plan

1. **Immediately** fix meeting link host validation (strict host parsing + https only).  
2. Harden OAuth redirect/callback model (loopback redirect where feasible).  
3. Stop logging raw AI error bodies.  
4. Tighten keychain accessibility classes for OAuth tokens.  
5. Reassess local plaintext recovery storage and unnecessary entitlements.

## Expected Application Behavior Changes (if remediations are implemented)

- **Meeting link hardening (host allowlist + https only):**  
  Users may see some previously-accepted (but suspicious/malformed) links no longer open from the app. This is an intentional security behavior change.
- **OAuth redirect hardening:**  
  Depending on provider/app registration, sign-in flow UX may slightly change (e.g., loopback callback vs custom scheme), but expected successful auth outcomes remain the same.
- **Log redaction for AI failures:**  
  Fewer details in logs. User-facing behavior is unchanged; only diagnostics verbosity changes.
- **Keychain accessibility tightening:**  
  In some edge cases, secrets may require an unlocked session before use. Normal daily behavior should remain unchanged.
- **Recovery-file protection improvements:**  
  No intended UI/feature changes; only at-rest data handling changes.

## Personal-Use Context Note

For a personal-use app that has not been distributed, secret **rotation is not required** to complete the hardening steps above.  
Focus should be on forward security posture (validation, storage policy, and logging hygiene), then rotate only if you suspect prior exposure.
