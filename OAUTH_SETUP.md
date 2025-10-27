# OAuth Setup Guide

This guide walks you through setting up OAuth credentials for MeetingNotifier.

## Important: Secret Files

The following files contain your OAuth secrets and are **gitignored**:
- `MeetingNotifier/MeetingNotifier/Managers/GoogleOAuthSecret.swift`
- `MeetingNotifier/MeetingNotifier/Managers/MicrosoftOAuthSecret.swift`

Template files are provided in the repository:
- `GoogleOAuthSecret.swift.template`
- `MicrosoftOAuthSecret.swift.template`

---

## Setup Instructions

### 1. Create Secret Files

```bash
cd MeetingNotifier/MeetingNotifier/Managers/
cp GoogleOAuthSecret.swift.template GoogleOAuthSecret.swift
cp MicrosoftOAuthSecret.swift.template MicrosoftOAuthSecret.swift
```

### 2. Configure Google OAuth

#### Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the **Google Calendar API**
4. Go to **OAuth consent screen**:
   - User Type: **External**
   - App name: Your app name
   - User support email: Your email
   - Developer contact: Your email
5. Add scope: `.../auth/calendar.readonly`
6. Add test users (your email addresses)

#### Create OAuth Credentials

1. Go to **Credentials** > **Create Credentials** > **OAuth client ID**
2. Application type: **Desktop app**
3. Name: `MeetingNotifier macOS` (or any name)
4. Click **Create**
5. Copy the **Client ID** and **Client secret**

#### Update Code

Edit `GoogleOAuthSecret.swift`:
```swift
static let secret = "YOUR_CLIENT_SECRET_HERE"
```

Edit `GoogleOAuthManager.swift`:
```swift
static let clientID = "YOUR_CLIENT_ID.apps.googleusercontent.com"
static let redirectURL = "com.googleusercontent.apps.YOUR_NUMERIC_ID:/oauthredirect"
```

Edit `Info.plist` (add Google URL scheme):
```xml
<string>com.googleusercontent.apps.YOUR_NUMERIC_ID</string>
```

**Note:** The numeric ID is the beginning part of your Client ID before the first dash.
Example: If Client ID is `123456-abc.apps.googleusercontent.com`, use `123456`

---

### 3. Configure Microsoft OAuth

#### Create Azure App Registration

1. Go to [Azure Portal](https://portal.azure.com/)
2. Navigate to **App registrations** > **New registration**
3. Name: `MeetingNotifier`
4. Supported account types: **Accounts in any organizational directory and personal Microsoft accounts**
5. Redirect URI: Leave empty for now
6. Click **Register**

#### Configure Authentication

1. In your new app, go to **Authentication**
2. Under **Platform configurations** > **Mobile and desktop applications**
3. Add custom redirect URI: `com.strategicnerds.meetingnotifier://oauthredirect`
   - Use **double slashes** `://`
4. Click **Save**

#### Create Client Secret

1. Go to **Certificates & secrets** > **Client secrets** > **New client secret**
2. Description: `MeetingNotifier macOS`
3. Expires: Choose expiration (24 months recommended)
4. Click **Add**
5. **IMPORTANT:** Copy the secret **Value** immediately (you won't see it again!)

#### Add API Permissions

1. Go to **API permissions** > **Add a permission**
2. Select **Microsoft Graph** > **Delegated permissions**
3. Search and add:
   - `Calendars.Read`
   - `offline_access`
4. Click **Add permissions**

#### Update Code

Edit `MicrosoftOAuthSecret.swift`:
```swift
static let secret = "YOUR_CLIENT_SECRET_VALUE"
```

Edit `MicrosoftOAuthManager.swift`:
```swift
static let clientID = "YOUR_APPLICATION_CLIENT_ID"
static let redirectURL = "com.strategicnerds.meetingnotifier://oauthredirect"
```

Edit `Info.plist` (add Microsoft URL scheme):
```xml
<string>com.strategicnerds.meetingnotifier</string>
```

---

## Bundle ID Configuration

The app uses bundle ID: `com.strategicnerds.meetingnotifier`

If you want to use a different bundle ID:

1. Edit `project.yml`:
   ```yaml
   PRODUCT_BUNDLE_IDENTIFIER: com.yourdomain.yourapp
   ```

2. Regenerate Xcode project:
   ```bash
   cd MeetingNotifier
   xcodegen generate
   ```

3. Update OAuth redirect URLs to match your new bundle ID

---

## Verification

### Build the Project

```bash
cd MeetingNotifier
xcodebuild -project MeetingNotifier.xcodeproj -scheme MeetingNotifier build
```

If you see errors about missing secrets:
- Make sure you created `GoogleOAuthSecret.swift` and `MicrosoftOAuthSecret.swift`
- Make sure they're in the `Managers/` directory

### Test OAuth

1. Run the app in Xcode (⌘ + R)
2. Click the calendar emoji in the menu bar
3. Click "Add Account"
4. Try adding both Google and Microsoft accounts
5. You should be redirected to sign in pages
6. After authentication, you should return to the app successfully

---

## Security Notes

- **Never commit** `*Secret.swift` files to version control
- Secret files are automatically ignored by `.gitignore`
- Template files are safe to commit (they contain no real secrets)
- Rotate secrets periodically for security
- Use different OAuth credentials for development vs production

---

## Troubleshooting

### "Missing GoogleOAuthSecret" build error
- You forgot to create `GoogleOAuthSecret.swift` from the template

### "redirect_uri_mismatch" error
- Check that your redirect URI exactly matches what's in the code
- For Google: Must match format `com.googleusercontent.apps.NUMBERS:/oauthredirect`
- For Microsoft: Must use double slashes `://` not single `:/`

### "Invalid client" error
- Check that Client ID and Secret are correct
- Make sure you copied the secret Value (not Secret ID) from Azure

### OAuth redirects to wrong app
- Check that URL schemes in Info.plist are unique
- Rebuild the app and restart
- Quit other apps using similar URL schemes

---

## Reference

- [Google OAuth Desktop Apps Guide](https://developers.google.com/identity/protocols/oauth2/native-app)
- [Microsoft OAuth Native Apps Guide](https://learn.microsoft.com/en-us/azure/active-directory/develop/scenario-desktop-overview)
- [AppAuth iOS Library](https://github.com/openid/AppAuth-iOS)
