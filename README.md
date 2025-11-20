# WVSU Space

Connect with fellow WVSU students through anonymous, interest‑based 1:1 chats. Pick topics you care about, or hop into a quick random chat when you just want to talk. It’s simple, friendly, and privacy‑first.

## Why this app exists

Campus life can be busy and a little overwhelming. WVSU Space gives you a low‑pressure way to meet people, ask for help, and share interests without worrying about judgment or exposing your identity. You choose what to talk about; we help you find someone who’s into the same thing.

## What you can do

- Sign up or log in with your email and password
- Turn on “Remember me” so your email is filled in next time
- Forgot your password? Send yourself a reset link instantly
- Quick Chat: let the app find you a random partner
- Interest Match: tap from a colorful grid of interests (or add your own) and get matched

## How it works (simple overview)

1) From Home, choose Quick Chat or Interest Match.
2) The Lobby shows either the random chat screen or a grid of interests.
3) Tap “Start Chat.” We look for a partner who’s also ready. You can cancel anytime.
4) When a match is found, you’ll be taken to a chat session. (Messaging UI is coming soon; for now you’ll see the session ID.)

## Features at a glance

- Clean, modern UI (Material 3)
- Keyword‑based interest picker with colored icons and an “Add Custom” option
- Sticky action buttons with clear feedback
- Matchmaking MVP powered by Firebase (Firestore + Auth)
- Anonymous by design: no public identity in chats

## Under the hood (short, not scary)

- Flutter app with a central router (`lib/router/app_router.dart`)
- Firebase Auth for sign‑in/up and Firestore for a lightweight matching queue
- SharedPreferences for “Remember me”
- Client‑side matching stub today; planned move to Cloud Functions for robust, race‑free pairing

## Roadmap (what we’re building next)

- Full chat experience: message list, composer, typing indicator, read markers
- Safety tools: report a chat, post‑chat rating, and admin review hooks
- Vibe Rooms (join ongoing groups by topic)
- Gratitude Wall (share something positive), Community Standing, Profiles & Settings
- Firestore security rules and emulator tests
- Admin portal (web) for moderation basics

## Project layout

```
lib/
	main.dart               # App bootstrap & Firebase init
	router/app_router.dart  # Central named routing
	getting_started.dart    # Onboarding
	log_in.dart             # Sign-in screen
	sign_up.dart            # Sign-up screen
	home.dart               # Home with primary actions
	chat_lobby.dart         # Random/Keyword lobby & matching
	chat_session.dart       # Placeholder for chat UI (session view)
```

## Getting set up (developers)

1) Install Flutter (stable) and set up a Firebase project.
2) Generate local Firebase config (don’t commit these):
	 - Android: `android/app/google-services.json`
	 - iOS: `ios/Runner/GoogleService-Info.plist`
	 - Dart: `lib/firebase_options.dart` via FlutterFire CLI
3) Copy `.env.example` to `.env` and fill in anything you plan to load at runtime.
4) Install packages and run:

```powershell
flutter pub get
flutter run
```

Run tests:

```powershell
flutter test
```

### Privacy & safety

- Anonymous by default: the chat doesn’t reveal your identity
- You can cancel matching at any time
- Secrets are kept out of the repository (see .gitignore); use `.env.example` as your guide

Already ignored (do not commit):

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `.env` files, Android/iOS signing keys and certificates

### Troubleshooting (friendly tips)

- Stuck on “Searching…”? Tap Cancel and try again.
- Firestore says “requires index”? That happens when sorting + filtering. Create the suggested index in Firebase or temporarily simplify the query.
- See an error mentioning “defunct” element? That’s a Flutter lifecycle guard. We’ve fixed common causes; if it reappears, share the stack trace so we can tighten it further.

## Contributing

Ideas, designs, code—everything helps. Issues and PRs are welcome, especially around chat UI, safety, and matching. Please don’t commit real keys or signing files; stick to `.env.example` and keep platform configs local.

## License

MIT
