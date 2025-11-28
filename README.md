# WVSU Space — A Safe Place for WVSU Students

WVSU Space is a friendly mobile app for students of West Visayas State University (WVSU). It helps them find another peer from the same university to have short, anonymous conversations — for studying, checking in, or sharing a quick word of encouragement.

This project is built to be a welcoming, low-pressure space where students can connect with peers who likely understand the same campus life and academic context.

---

## For students (quick, plain language)

- Sign up with your WVSU email address when prompted.
- You'll be shown the Terms & Conditions and asked to read and accept them before creating an account.
- If you change your mind, you can delete your account from the app settings at any time.

If you're not technical and just want to try the app, that's all you need to know — create an account with your WVSU email and follow the app prompts. Be respectful and kind in conversations.

---

## What you can do in WVSU Space

- Quick Chat: brief anonymous 1:1 chats with another WVSU student either pure random or search via interests.
- Vibe Rooms: join group chats by topic or interest or host one.
- Gratitude Wall: post short notes to share appreciation or kindness.
- Account management: sign up, verify your email, and delete your account if you wish.

---

## Quick Start (for developers / evaluators)

These commands help you run and build the app locally. They are optional if you only want to try the published app.

### Prerequisites

- Flutter SDK (stable channel)
- Android SDK (or Xcode for iOS) and at least one device or emulator
- Git (for cloning the repository)

### Install dependencies

```powershell
flutter pub get
```

### Run the app (development)

```powershell
flutter run -d <device-id>
```

### Build a release APK (Android)

```powershell
flutter build apk --release
```

### Install the release APK (example)

```powershell
flutter install --release -d <device-id>
```

---

## Firebase & Safe Testing

- The app uses Firebase for auth and backend features. Do NOT commit platform credential files.
  Keep these local:
  - `android/app/google-services.json` (Android)
  - `ios/Runner/GoogleService-Info.plist` (iOS)
- For testing destructive flows (like account deletion) use the Firebase Emulator Suite so you don't affect production data.

If you use FlutterFire CLI, you can run `flutterfire configure` locally to generate `lib/firebase_options.dart`.

---

## Testing & code checks

- Run tests:
```powershell
flutter test --reporter=expanded
```
- Static analysis:
```powershell
flutter analyze
```
- Reformat code (recommended before committing):
```powershell
dart format .
```

---

## Terms & Account Deletion (for users)

- Terms & Conditions are shown at sign-up; users must view and accept them before creating an account.
- Account deletion is available from the app settings. For safety, deletion may require you to re-authenticate.

---

## Contributing

Small, focused contributions are welcome — UI polish, documentation, or bug fixes. (This is highly appreciated by us the developers)

- Before opening a PR, run `flutter analyze` and `flutter test` locally.
- Use a clear branch name and provide a short PR description explaining the change.

---

## Troubleshooting (common fixes)

- If the app fails after recent changes:
```powershell
flutter clean
flutter pub get
```
- On Windows, enabling Developer Mode may be required for some builds (symlink support).

---

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

---

## Download the release APK

A signed release APK built for Android is included in this repository for convenience:

- `releases/wvsu_space-release.apk`

You can copy that file to your Android device and install it (e.g., via `adb install -r`).
