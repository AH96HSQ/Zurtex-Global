# F-Droid Submission Guide for Zurtex Global

This guide helps you prepare and submit Zurtex Global to F-Droid.

## Prerequisites

Before submitting to F-Droid, ensure:

1. ✅ App is fully open source (GPL-3.0-or-later license)
2. ✅ No proprietary dependencies or SDKs
3. ✅ No tracking or analytics libraries
4. ✅ Source code is publicly available on GitHub
5. ✅ App builds reproducibly from source

## F-Droid Requirements Checklist

### Code Requirements
- [x] All dependencies are from F-Droid, Maven Central, or reproducible sources
- [x] No proprietary libraries (Google Play Services, Firebase, etc.)
- [x] No anti-features (ads, tracking, non-free dependencies)
- [x] Source code matches the APK

### Metadata Files Created
```
fastlane/metadata/android/en-US/
  ├── title.txt
  ├── short_description.txt
  └── full_description.txt

metadata/
  └── com.zurtex.global.yml (F-Droid build metadata)
```

## Steps to Submit

### 1. Check Dependencies

Review `pubspec.yaml` for any non-free dependencies:

```bash
flutter pub deps
```

**Current dependencies status:**
- ✅ `flutter_v2ray` - Open source
- ✅ `http`, `dio` - Open source HTTP clients
- ✅ `cached_network_image` - Open source
- ✅ All other Flutter packages are open source

### 2. Remove Non-Free Features

F-Droid requires removal of:
- ❌ Crashlytics (if any)
- ❌ Google Analytics (if any)
- ❌ Firebase (if any)
- ❌ Proprietary payment SDKs

**Action needed:** The app uses Litecoin payment which is decentralized and open source - this is acceptable.

### 3. Prepare Repository

```bash
# Create LICENSE file
cat > LICENSE << 'EOF'
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
...
EOF

# Add CHANGELOG
cat > CHANGELOG.md << 'EOF'
# Changelog

## [1.1.3] - 2025-10-26
### Added
- V2Ray protocol support
- Multiple server locations
- Connection monitoring
- Litecoin payment integration

### Fixed
- Connection stability improvements
- UI enhancements
EOF
```

### 4. Test F-Droid Build

F-Droid builds apps in a clean environment. Test locally:

```bash
# Build release APK without signing
flutter build apk --release

# Verify APK
adb install build/app/outputs/flutter-apk/app-release.apk
```

### 5. Add Screenshots

F-Droid requires screenshots. Add to:

```
fastlane/metadata/android/en-US/images/phoneScreenshots/
  ├── 1_main_screen.png
  ├── 2_server_selection.png
  ├── 3_connection_stats.png
  └── 4_settings.png
```

Screenshot requirements:
- PNG or JPEG format
- At least 320px on shortest side
- No more than 3840px on longest side

### 6. Submit to F-Droid

#### Option A: Submit via GitLab Merge Request (Recommended)

1. Fork the F-Droid data repository:
   ```bash
   git clone https://gitlab.com/fdroid/fdroiddata.git
   cd fdroiddata
   ```

2. Create your app metadata:
   ```bash
   mkdir -p metadata/com.zurtex.global
   cp /path/to/Zurtex/metadata/com.zurtex.global.yml metadata/
   ```

3. Test the build:
   ```bash
   fdroid build -v -l com.zurtex.global
   ```

4. Submit merge request:
   ```bash
   git checkout -b add-zurtex-global
   git add metadata/com.zurtex.global.yml
   git commit -m "New app: Zurtex Global"
   git push origin add-zurtex-global
   ```

5. Create merge request on GitLab

#### Option B: Request For Packaging (RFP)

Create an issue at: https://gitlab.com/fdroid/rfp/-/issues

### 7. F-Droid Review Process

F-Droid maintainers will:
1. Review your metadata
2. Check for anti-features
3. Verify source code matches APK
4. Build the app in their environment
5. Test the app functionality

**Average review time:** 2-8 weeks

## Anti-Features Declaration

F-Droid categorizes certain features as "anti-features." For Zurtex:

- **NonFreeNet**: Uses proprietary backend servers (declare this)
- **NoSourceSince**: Mark if any dependency becomes closed source

Update metadata:
```yaml
AntiFeatures:
  - NonFreeNet:
      en-US: Connects to proprietary VPN servers
```

## Important Notes

### Payment System
The Litecoin payment integration is acceptable for F-Droid as:
- ✅ It's decentralized (no proprietary payment processor)
- ✅ Uses open protocols (Bitcoin/Litecoin)
- ✅ No tracking or data collection

However, you should:
1. Clearly document payment requirements
2. Consider adding a note about subscription costs
3. Ensure no payment SDK is proprietary

### Backend Services
F-Droid allows apps that connect to proprietary servers, but they must:
- Declare "NonFreeNet" anti-feature
- Be transparent about server connectivity
- Not track users

## Reproducible Builds

For reproducible builds (recommended):

1. Use specific dependency versions
2. Pin Flutter SDK version
3. Document build environment

Add to metadata:
```yaml
Builds:
  - versionName: 1.1.3
    versionCode: 4
    commit: v1.1.3
    output: app-release.apk
    srclibs:
      - FlutterSDK@3.8.1
    prebuild: echo "flutter.sdk=$$FlutterSDK$$" > local.properties
```

## Common F-Droid Rejection Reasons

Avoid these issues:
1. ❌ Proprietary dependencies
2. ❌ Tracking/analytics libraries
3. ❌ Non-reproducible builds
4. ❌ Missing source code
5. ❌ Incorrect package name
6. ❌ Build failures in F-Droid environment

## Useful Commands

```bash
# Validate metadata
fdroid readmeta

# Test build locally
fdroid build -v -l com.zurtex.global

# Check for anti-features
fdroid scanner com.zurtex.global

# Lint metadata
fdroid lint com.zurtex.global
```

## Resources

- F-Droid Documentation: https://f-droid.org/docs/
- Inclusion Policy: https://f-droid.org/docs/Inclusion_Policy/
- Build Metadata Reference: https://f-droid.org/docs/Build_Metadata_Reference/
- RFP Issues: https://gitlab.com/fdroid/rfp/-/issues

## Support

If you need help:
- F-Droid Forum: https://forum.f-droid.org/
- Matrix: #fdroid:f-droid.org
- IRC: #fdroid on Libera.Chat

## After Submission

Once approved:
1. App appears in F-Droid repository
2. Users can install via F-Droid app
3. Updates are built automatically
4. You maintain the source repository

Keep your repository updated and respond to F-Droid maintainer feedback promptly!
