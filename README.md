# SIP Phones

Native macOS 14+ SwiftUI SIP softphone using PJSIP, secure Keychain credential storage, SQLite call history, native notifications, and CoreAudio-backed device selection.

The app is provider-neutral. It can register with standard SIP servers, PBXs, SIP trunks, and PRI deployments that expose calling through a SIP/PRI gateway.

## Requirements

- macOS 14 or newer
- Xcode 16 or newer with Swift 6
- Apple Silicon Mac
- PJSIP built for `arm64-apple-darwin`
- SIP account credentials, SIP server details, and calling permissions

## Build PJSIP

```bash
chmod +x Scripts/build-pjsip-macos.sh
PREFIX=/opt/pjsip Scripts/build-pjsip-macos.sh
```

If you install PJSIP elsewhere, edit `sip-phones/Config/PJSIP.xcconfig` and set `PJSIP_ROOT`.

## Build The App

Select full Xcode if necessary:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Then build:

```bash
xcodebuild -project sip-phones.xcodeproj -scheme sip-phones -configuration Release build
```

## Run

Open `sip-phones.xcodeproj`, choose the `sip-phones` scheme, and run. On first launch, grant microphone and notification permissions. Enter SIP credentials in Settings and click `Save and Register`. Credentials are stored in macOS Keychain; the password is never persisted in plaintext.

## Package, Sign, And Notarize

Set `DEVELOPMENT_TEAM` in `sip-phones/Config/Release.xcconfig`, then archive:

```bash
chmod +x Scripts/package-release.sh
Scripts/package-release.sh
```

Create a drag-to-Applications DMG:

```bash
chmod +x Scripts/make-dmg.sh
Scripts/make-dmg.sh
```

Create a PKG installer:

```bash
chmod +x Scripts/make-pkg.sh
Scripts/make-pkg.sh
```

To sign the PKG with a Developer ID Installer certificate:

```bash
INSTALLER_SIGN_IDENTITY="Developer ID Installer: Your Name (TEAMID)" Scripts/make-pkg.sh
```

Notarize the exported app, DMG, or PKG with:

```bash
xcrun notarytool submit path/to/sip-phones.zip --keychain-profile "AC_NOTARY" --wait
xcrun stapler staple path/to/sip-phones.app
```

For DMG notarization:

```bash
xcrun notarytool submit build/sip-phones.dmg --keychain-profile "AC_NOTARY" --wait
xcrun stapler staple build/sip-phones.dmg
```

For PKG notarization:

```bash
xcrun notarytool submit build/sip-phones.pkg --keychain-profile "AC_NOTARY" --wait
xcrun stapler staple build/sip-phones.pkg
```

## SIP Notes

- UDP, TCP, and TLS transports are created at startup.
- Outbound dialing accepts plain extensions/numbers or SIP URIs.
- TLS is used when the account transport is set to `TLS`.
- RTP audio, DTMF, hold/resume, mute, and device routing are handled by PJSIP.
- Call history is stored in `~/Library/Application Support/sip-phones/CallHistory.sqlite`.
