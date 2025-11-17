Vibe Rooms feature module

This folder contains the initial scaffolding for the Vibe Rooms feature (mood-based ephemeral group chat).

Files:
- `models.dart` — data models for rooms, participants, messages.
- `selector.dart` — mood selection UI (entry point).
- `chat.dart` — room chat screen scaffold.
- `repository.dart` — matching and room management stubs (Firestore integration TODO).
- `utils.dart` — helpers (mood list, crisis keywords).

Notes:
- This is a scaffolded, non-invasive starting point so the designer and devs know where the feature lives.
- No production Firestore logic has been wired yet — `repository.dart` contains TODOs for implementation.
