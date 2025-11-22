
# WVSU Space

WVSU Space is a mobile app that helps students at Western Visayas State University (WVSU) meet online for short, meaningful, anonymous conversations. It is designed to be respectful, low-friction, and private.

Purpose
-------

Help students find a peer to talk to—about study topics, hobbies, open up thoughts, vent out or just to check in—without sharing personal details.

What you can do
---------------

- Sign up or sign in using a WVSU email (currently accepts `@wvsu.edu.ph`).
- Start a Quick Chat or choose an interest to match with someone who selected the same topic.
- Join Vibe Rooms for topic-based group discussions or post short messages on the Gratitude Wall.

Quick start (developer)
-----------------------

Prerequisites: Flutter (stable channel) and a Firebase project for local testing.

1. Fetch packages:

```powershell
flutter pub get
```

2. Add Firebase platform files locally (do not commit these):

- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`
- Optional: run FlutterFire CLI to generate `lib/firebase_options.dart`

3. Run the app:

```powershell
flutter run
```

Tests and checks
----------------

Run tests and static analysis:

```powershell
flutter test --reporter=expanded
dart analyze
```

Practical notes
---------------

- The codebase uses a feature-first layout (`lib/features/...`). If your editor shows missing imports after pulling, run `flutter pub get` and restart the Dart analysis server (in VS Code: `Dart: Restart Analysis Server`).
- Helper scripts may produce `.bak` files during batch edits; these can be removed.
- The app currently checks WVSU email domains on the client — enforce this on the server or in Firestore rules for production.

How to help (Really appreciate it if you do tysm!!!)
-----------

- Pick a small issue or UI tweak and open a pull request.
- Run `dart analyze` and `flutter test` before creating a PR.
- Use a clear branch name and explain your change in the PR description.

Troubleshooting
---------------

- App fails to start after changes:

```powershell
flutter clean
flutter pub get
```

- Matching stuck on "Searching": cancel and try again; test with two emulators to simulate two users.

Contact
-------

Open an issue if you need help or want to propose a substantial change.

License
-------

MIT — see the `LICENSE` file if present.

