# MeetingNotifier Deployment Guide

Complete step-by-step guide for deploying MeetingNotifier to TestFlight and the App Store.

---

## Table of Contents

1. [Project Structure](#project-structure)
2. [Prerequisites](#prerequisites)
3. [One-Time Setup](#one-time-setup)
4. [Regular Deployment Workflow](#regular-deployment-workflow)
5. [Troubleshooting](#troubleshooting)
6. [What Was Automated](#what-was-automated)
7. [Maintenance](#maintenance)

---

## Project Structure

This is a **standalone macOS app** (not a monorepo).

```
meeting-notifier/                           # Repository root
├── .github/
│   └── workflows/
│       ├── testflight.yml                  # Auto-deploy to TestFlight on push to main
│       └── test.yml                        # Run tests on PRs
├── .gitignore                              # Ignore secrets and build artifacts
├── README.md                               # Project documentation
└── MeetingNotifier/                        # PROJECT ROOT - All automation lives here
    ├── MeetingNotifier.xcodeproj           # Xcode project
    ├── MeetingNotifier/                    # App source code
    ├── fastlane/                           # Fastlane configuration
    │   ├── Appfile                         # App Store Connect configuration
    │   ├── Fastfile                        # Automation lanes
    │   └── app_store_connect_api_key.p8    # API key (gitignored)
    ├── Gemfile                             # Ruby dependencies
    ├── Gemfile.lock                        # Locked dependency versions
    ├── .env                                # Environment secrets (gitignored)
    ├── .env.default                        # Environment template (committed)
    ├── deploy.sh                           # Main deployment script ⭐
    ├── quick-test.sh                       # Quick test runner
    ├── update-metadata.sh                  # Metadata update helper
    ├── CHANGELOG.md                        # Version changelog
    └── DEPLOY-STEPS.md                     # This file

```

### Running Commands

All scripts work from any directory:

```bash
# From repository root:
cd meeting-notifier
MeetingNotifier/deploy.sh

# From PROJECT ROOT (MeetingNotifier/):
cd meeting-notifier/MeetingNotifier
./deploy.sh

# Both are equivalent - scripts auto-detect their location
```

---

## Prerequisites

### What You Need from Apple

- [ ] **Apple Developer Program** membership ($99/year)
  - Sign up at: https://developer.apple.com/programs/

- [ ] **Apple Developer Account** with Admin access
  - Account: `prashant_sridharan@hotmail.com`
  - Team ID: `955GSY56UT`

- [ ] **App Store Connect** access
  - Same Apple ID as above
  - Role: App Manager or Admin

### What You Need Locally

- [ ] **macOS** (14.0 or later recommended)
- [ ] **Xcode** (15.0 or later)
  - Install from App Store
  - Run once to accept license agreement

- [ ] **Xcode Command Line Tools**
  ```bash
  xcode-select --install
  ```

- [ ] **Ruby** (3.0 or later)
  - Already installed: Ruby 3.4.7 ✅
  ```bash
  ruby --version
  ```

- [ ] **Bundler**
  - Already installed ✅
  ```bash
  gem install bundler
  ```

---

## One-Time Setup

### Step 1: Register Bundle Identifier

1. Go to: https://developer.apple.com/account
2. Click **Certificates, Identifiers & Profiles**
3. Click **Identifiers** → **+** button
4. Select **App IDs** → **Continue**
5. Select **App** → **Continue**
6. Fill in:
   - **Description**: MeetingNotifier
   - **Bundle ID**: `com.strategicnerds.meetingnotifier` (Explicit)
   - **Capabilities**: Check **In-App Purchase**
7. Click **Continue** → **Register**

**Why**: Bundle identifiers must be registered before creating an app in App Store Connect.

---

### Step 2: Create App in App Store Connect

1. Go to: https://appstoreconnect.apple.com
2. Click **My Apps** → **+** button → **New App**
3. Select **macOS**
4. Fill in:
   - **Name**: MeetingNotifier
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: `com.strategicnerds.meetingnotifier` (from dropdown)
   - **SKU**: `meetingnotifier` (unique identifier)
5. Click **Create**

**Why**: The app must exist in App Store Connect before uploading builds.

---

### Step 3: Generate App Store Connect API Key

1. In App Store Connect, go to: **Users and Access** → **Keys** tab
2. Click **+** to create a new key
3. Fill in:
   - **Name**: "Fastlane CI" (or "MeetingNotifier Automation")
   - **Access**: **App Manager**
4. Click **Generate**
5. **Download the .p8 file** - you can only download it once!
6. Note the **Key ID** and **Issuer ID**

7. Save the .p8 file:
   ```bash
   # From repository root:
   cp ~/Downloads/AuthKey_*.p8 MeetingNotifier/fastlane/app_store_connect_api_key.p8

   # Or from PROJECT ROOT:
   cp ~/Downloads/AuthKey_*.p8 fastlane/app_store_connect_api_key.p8
   ```

**Why**: API keys allow automation without 2FA prompts and are more secure than using your password.

**Security Note**: The .p8 file is gitignored and never committed to your repository.

---

### Step 4: Configure Environment Variables

1. Navigate to PROJECT ROOT:
   ```bash
   cd /Users/prashant/Developer/meeting-notifier/MeetingNotifier
   ```

2. The `.env` file already exists (copied from link-opener) with values:
   ```bash
   # Verify it exists:
   ls -la .env
   ```

3. If you need to update it, edit `.env`:
   ```bash
   # Values are already set:
   FASTLANE_USER=prashant_sridharan@hotmail.com
   FASTLANE_TEAM_ID=955GSY56UT
   FASTLANE_ITC_TEAM_ID=955GSY56UT
   APP_STORE_CONNECT_API_KEY_ID=LX39DTG7L3
   APP_STORE_CONNECT_API_ISSUER_ID=69a6de75-1a97-47e3-e053-5b8c7c11a4d1
   APP_STORE_CONNECT_API_KEY_PATH=fastlane/app_store_connect_api_key.p8
   ```

**Why**: Environment variables keep secrets out of your code and allow different configurations per environment.

**Security Note**: `.env` is gitignored. Use `.env.default` as a template for team members.

---

### Step 5: Enable Xcode Automatic Code Signing

This is for **solo developers** - no Match setup needed!

1. Open `MeetingNotifier.xcodeproj` in Xcode
2. Select the **MeetingNotifier** target
3. Go to **Signing & Capabilities** tab
4. Check **"Automatically manage signing"**
5. Select your Team: **Strategic Nerds (955GSY56UT)**
6. Verify Bundle Identifier: `com.strategicnerds.meetingnotifier`

Xcode will automatically:
- Create signing certificates
- Generate provisioning profiles
- Renew expired certificates
- Handle all code signing

**Why**: Xcode automatic signing is simpler for solo developers. No need to manage certificates manually.

---

### Step 6: Install Ruby Dependencies

1. Navigate to PROJECT ROOT:
   ```bash
   cd /Users/prashant/Developer/meeting-notifier/MeetingNotifier
   ```

2. Install dependencies:
   ```bash
   bundle install
   ```

   This installs:
   - Fastlane (deployment automation)
   - All required plugins
   - Dependencies

**Why**: Ruby gems provide all the automation tools.

---

### Step 7: Set Up GitHub Secrets (for CI/CD)

For automatic TestFlight deployment on push to main:

1. Go to: https://github.com/CoolAssPuppy/meeting-notifier/settings/secrets/actions
2. Click **New repository secret** for each:

| Secret Name | Value | Where to Find |
|------------|-------|---------------|
| `FASTLANE_USER` | `prashant_sridharan@hotmail.com` | Your Apple ID |
| `FASTLANE_TEAM_ID` | `955GSY56UT` | Apple Developer Account |
| `FASTLANE_ITC_TEAM_ID` | `955GSY56UT` | Same as FASTLANE_TEAM_ID |
| `APP_STORE_CONNECT_API_KEY_ID` | `LX39DTG7L3` | From Step 3 |
| `APP_STORE_CONNECT_API_ISSUER_ID` | `69a6de75-1a97-47e3-e053-5b8c7c11a4d1` | From Step 3 |
| `APP_STORE_CONNECT_API_KEY` | Contents of .p8 file | `cat fastlane/app_store_connect_api_key.p8` |

3. For the API key, copy the entire file contents:
   ```bash
   # From PROJECT ROOT:
   cat fastlane/app_store_connect_api_key.p8
   # Copy output including -----BEGIN PRIVATE KEY----- and -----END PRIVATE KEY-----
   ```

**Why**: GitHub Actions needs these secrets to deploy automatically.

**Security Note**: Secrets are encrypted by GitHub and never exposed in logs.

---

## Regular Deployment Workflow

### Deploy to TestFlight (Beta)

**Fastest method** - No App Review required, available to internal testers immediately.

#### From Any Directory:

```bash
# Option 1: Use the interactive deploy script
cd /Users/prashant/Developer/meeting-notifier/MeetingNotifier
./deploy.sh
# Choose option 1 (TestFlight)

# Option 2: Direct Fastlane command
cd /Users/prashant/Developer/meeting-notifier/MeetingNotifier
bundle exec fastlane beta
```

**What Happens:**
1. ✅ Checks prerequisites
2. 🔨 Builds app with Release configuration
3. 📦 Creates archive
4. ⬆️ Uploads to TestFlight
5. 📧 Notifies internal testers (~10 minutes)

**Time**: 5-10 minutes (build) + 10 minutes (App Store processing)

---

### Deploy to App Store (Production)

**Requires App Review** - typically 1-3 days.

```bash
cd /Users/prashant/Developer/meeting-notifier/MeetingNotifier
./deploy.sh
# Choose option 2 (App Store)
# Choose version bump type (patch/minor/major)
```

**What Happens:**
1. ⚠️ Confirmation prompt (safety check)
2. 🧪 Runs all tests
3. 📈 Bumps version number (if selected)
4. 🔨 Builds and archives
5. ⬆️ Uploads to App Store
6. 🏷️ Creates git tag
7. ⏸️ Stops (you manually submit for review)

**Next Steps:**
1. Go to App Store Connect
2. Select your build
3. Fill in "What's New" notes
4. Submit for Review

---

### Update App Store Metadata

Update descriptions, screenshots, keywords:

```bash
cd /Users/prashant/Developer/meeting-notifier/MeetingNotifier
./update-metadata.sh
# Choose option 1 to download current metadata
# Edit files in fastlane/metadata/
# Choose option 2 to upload changes
```

---

### Run Tests Only

Quick test verification:

```bash
cd /Users/prashant/Developer/meeting-notifier/MeetingNotifier
./quick-test.sh
```

Or directly:

```bash
bundle exec fastlane test
```

---

### Version Management

Semantic versioning: `MAJOR.MINOR.PATCH`

```bash
# Patch: 1.0.0 → 1.0.1 (bug fixes)
bundle exec fastlane bump_patch

# Minor: 1.0.0 → 1.1.0 (new features)
bundle exec fastlane bump_minor

# Major: 1.0.0 → 2.0.0 (breaking changes)
bundle exec fastlane bump_major
```

Each bump:
- Updates version in Xcode project
- Commits the change to git
- Creates a version entry

---

## Automatic Deployments (CI/CD)

### TestFlight on Push to Main

**Trigger**: Any push to `main` branch

**Workflow**: `.github/workflows/testflight.yml`

**What Happens:**
1. GitHub Action detects push to main
2. Checks out code
3. Sets up Ruby and Fastlane
4. Builds app
5. Uploads to TestFlight
6. ~15-20 minutes total

**To Deploy Automatically:**
```bash
git add .
git commit -m "Release v1.0.1"
git push origin main
# Wait 20 minutes, build appears in TestFlight
```

**Monitor Progress:**
- Go to: https://github.com/CoolAssPuppy/meeting-notifier/actions

---

### Tests on Pull Requests

**Trigger**: Any PR to any branch

**Workflow**: `.github/workflows/test.yml`

**What Happens:**
1. Runs all tests
2. Reports results in PR
3. Blocks merge if tests fail

---

## Troubleshooting

### Issue: "Wrong directory" error

**Symptoms:**
```
Error: MeetingNotifier.xcodeproj not found
```

**Solution:**
```bash
# Make sure you're in PROJECT ROOT:
cd /Users/prashant/Developer/meeting-notifier/MeetingNotifier

# Or use full path to script:
/Users/prashant/Developer/meeting-notifier/MeetingNotifier/deploy.sh
```

**Why**: All Fastlane files expect to be run from the PROJECT ROOT (MeetingNotifier/ directory).

---

### Issue: Code signing failed

**Symptoms:**
```
Code signing error
Provisioning profile not found
```

**Solution:**
1. Open Xcode
2. Go to **Preferences** → **Accounts**
3. Select your Apple ID
4. Click **Download Manual Profiles**
5. In your project: **Signing & Capabilities**
6. Ensure **"Automatically manage signing"** is checked
7. Clean build folder: **Product** → **Clean Build Folder**
8. Try again

**Why**: Xcode automatic signing handles all certificates and profiles. If it's not enabled, code signing will fail.

---

### Issue: API key file not found

**Symptoms:**
```
App Store Connect API key file not found at: fastlane/app_store_connect_api_key.p8
```

**Solution:**
```bash
# Check if file exists:
ls -la /Users/prashant/Developer/meeting-notifier/MeetingNotifier/fastlane/app_store_connect_api_key.p8

# If missing, copy from Downloads:
cp ~/Downloads/AuthKey_*.p8 /Users/prashant/Developer/meeting-notifier/MeetingNotifier/fastlane/app_store_connect_api_key.p8
```

**Why**: The .p8 file is gitignored for security and must be manually placed.

---

### Issue: Bundle install fails

**Symptoms:**
```
Could not find gem 'fastlane'
```

**Solution:**
```bash
cd /Users/prashant/Developer/meeting-notifier/MeetingNotifier
bundle install
```

**Why**: Ruby dependencies need to be installed before running Fastlane.

---

### Issue: Ruby version mismatch

**Symptoms:**
```
Your Ruby version is X, but Fastlane requires Y
```

**Solution:**
```bash
# Check current version:
ruby --version

# Update Ruby via Homebrew:
brew upgrade ruby

# Or use rbenv/rvm to manage versions
```

---

### Issue: TestFlight build stuck "Processing"

**Symptoms:**
Build uploaded but stuck processing for >30 minutes

**Solution:**
- This is normal for first upload (can take 1-2 hours)
- Subsequent builds: 5-15 minutes
- Check App Store Connect for errors
- Verify binary is for macOS (not iOS)

---

### Issue: GitHub Action fails

**Symptoms:**
CI/CD deployment fails in GitHub Actions

**Solution:**
1. Go to: https://github.com/CoolAssPuppy/meeting-notifier/actions
2. Click failed workflow
3. Check logs for specific error
4. Common issues:
   - Missing GitHub secret → Add in Settings
   - Invalid API key → Regenerate in App Store Connect
   - Xcode version mismatch → Update workflow file

---

## What Was Automated

### Before Automation (Manual Process)
1. Open Xcode
2. Set version and build numbers manually
3. Product → Archive (wait 10 minutes)
4. Open Organizer
5. Distribute App → App Store Connect
6. Wait for upload (15 minutes)
7. Open App Store Connect website
8. Select build, fill in details
9. Submit for review
10. Create git tag manually
11. Update changelog manually

**Time**: ~45-60 minutes per deployment
**Error-prone**: Easy to forget steps, make typos

---

### After Automation
```bash
./deploy.sh
```

**Time**: 15 minutes (mostly waiting)
**Automated**:
- Version number management
- Build number auto-increment
- Building and archiving
- Code signing
- Upload to TestFlight/App Store
- Git tagging
- Changelog tracking
- CI/CD on push to main

**What's Still Manual:**
- Submitting for App Store review (safety check)
- Writing release notes
- Taking screenshots (one-time)

**Time Saved**: ~30-45 minutes per deployment

---

## Maintenance

### Updating Fastlane

Every few months:

```bash
cd /Users/prashant/Developer/meeting-notifier/MeetingNotifier
bundle update fastlane
```

---

### Renewing Certificates

**With Xcode Automatic Signing** (recommended for solo developers):

✅ **No action required!**

Xcode automatically:
- Renews certificates before expiration
- Creates new provisioning profiles
- Handles all code signing

**If you need to manually check:**
1. Open Xcode → **Preferences** → **Accounts**
2. Select your Apple ID
3. Click **Manage Certificates**
4. Certificates renew automatically

---

### Updating App Store Screenshots

1. Generate screenshots (if you have UI tests):
   ```bash
   bundle exec fastlane screenshots
   ```

2. Or manually:
   - Take screenshots of app
   - Save in `fastlane/screenshots/en-US/`
   - Name them: `screenshot1.png`, `screenshot2.png`, etc.

3. Upload:
   ```bash
   bundle exec fastlane upload_metadata
   ```

---

### Backup Important Files

**Critical files** to backup (not in git):

```bash
# From PROJECT ROOT:
fastlane/app_store_connect_api_key.p8
.env
```

**Recommendation**: Store in password manager or secure cloud storage.

---

## Quick Reference

### Common Commands

```bash
# Navigate to PROJECT ROOT
cd /Users/prashant/Developer/meeting-notifier/MeetingNotifier

# Deploy to TestFlight
./deploy.sh                   # Interactive
bundle exec fastlane beta     # Direct

# Deploy to App Store
./deploy.sh                   # Interactive
bundle exec fastlane release  # Direct

# Run tests
./quick-test.sh
bundle exec fastlane test

# Update metadata
./update-metadata.sh

# Version bumps
bundle exec fastlane bump_patch
bundle exec fastlane bump_minor
bundle exec fastlane bump_major

# Install/update dependencies
bundle install
bundle update fastlane
```

---

### File Locations

| File | Full Path | Purpose |
|------|----------|---------|
| Xcode Project | `/Users/prashant/Developer/meeting-notifier/MeetingNotifier/MeetingNotifier.xcodeproj` | Main project |
| Deploy Script | `/Users/prashant/Developer/meeting-notifier/MeetingNotifier/deploy.sh` | Main automation |
| Fastfile | `/Users/prashant/Developer/meeting-notifier/MeetingNotifier/fastlane/Fastfile` | Lanes |
| Environment | `/Users/prashant/Developer/meeting-notifier/MeetingNotifier/.env` | Secrets |
| API Key | `/Users/prashant/Developer/meeting-notifier/MeetingNotifier/fastlane/app_store_connect_api_key.p8` | Auth |
| Changelog | `/Users/prashant/Developer/meeting-notifier/MeetingNotifier/CHANGELOG.md` | Versions |

---

### Links

- **App Store Connect**: https://appstoreconnect.apple.com
- **Apple Developer**: https://developer.apple.com/account
- **GitHub Actions**: https://github.com/CoolAssPuppy/meeting-notifier/actions
- **Fastlane Docs**: https://docs.fastlane.tools

---

## Support

**Issues with this guide?**
- Check the Troubleshooting section above
- Review Fastlane logs: `MeetingNotifier/fastlane/report.xml`
- Check GitHub Actions logs if using CI/CD

**Fastlane errors?**
- Visit: https://docs.fastlane.tools
- Search: https://github.com/fastlane/fastlane/issues

---

**Last Updated**: 2025-10-27
**Version**: 1.0
**Setup Complete**: ✅
