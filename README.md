# Garden Town County

Offline-first Flutter database app for the Garden Town County Assembly.

**Platforms:** Windows · macOS · Linux · Android · iOS · Web (static deploy)

## Features

- Full-screen county logo landing page
- Left navigation drawer (Search, Member Info, SOS, Global 528/928, LRO, Activities)
- Members CRUD with suburb / town / postal-code lookup tables (Add / Edit / Delete)
- Global search across all member fields
- File upload per member (Documents folder picker; PDF / DOCX / XLSX / any type)
- File metadata: upload date/time, logged-in user, brief description, file name/icon (A–Z)
- SOS messaging via WhatsApp (`whatsapp://`) and Email (`mailto:`)
- Activity log with GPS, date/time, and user name
- SQLite local store + Firebase Firestore / Storage sync engine (offline-first)

## Sign in

Use an operator account created by an Admin (Recording Secretary Rights).

In **debug builds only**, a seeded local Admin account may be available for
development — credentials are not published here. Release builds do not
pre-fill or display demo passwords.

When Firebase Auth is configured (`DefaultFirebaseOptions.isConfigured = true`),
email/password cloud accounts are used exclusively (no silent local fallback).

## Quick start

```bash
flutter pub get
flutter run -d linux      # or windows / macos / chrome / android
```

Requires **Flutter ≥ 3.44** (Dart 3.12), matching `pubspec.yaml` / Docker image tag.

## Firebase setup

1. Create a Firebase project.
2. Enable Authentication (Email/Password), Cloud Firestore, and Storage.
3. Run:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

4. Open `lib/firebase_options.dart` and set:

```dart
static const bool isConfigured = true;
```

5. Deploy security rules and functions:

```bash
firebase deploy --only firestore:rules,storage,functions
```

Until `isConfigured` is true, the app runs **SQLite-only** (fully usable offline).

## Architecture

| Layer | Role |
|-------|------|
| `DatabaseService` | SQLite schema + CRUD (domain mixins under `lib/services/database/`) |
| `SyncEngine` | Push pending local rows → Firestore; listen for remote changes |
| `FileStorageService` | Pick files, copy locally, upload bytes to Firebase Storage |
| `AuthService` | Firebase Auth or local session; tracks display name for uploads |
| Riverpod providers | App state, repositories, section navigation |

Writes always go to SQLite first (`pendingSync = 1`), then sync when cloud is available.

## Backup & Restore (Admin)

1. Sign in as Admin.
2. Open **Backup & Restore**.
3. Authorize the device and set a **backup password** (≥ 8 characters) for GTB2 encryption.
4. Use **Create Backup** / **Restore** (confirm when prompted).
5. Encrypted `.gtb` files go to `Documents/GardenTown/Backups/` (desktop).

## Deploy

### GitHub Pages (automatic)

On every push to `main`, GitHub Actions builds Flutter web and publishes Pages.

**App URL:** https://taipan-lgm.github.io/GardenTownCounty/

### Render (Docker Web Service — not Static Site)

**TL;DR:** Delete any existing **Static Site** and create a **new Web Service** with Docker. Static Sites cannot run a Dockerfile.

Repo already has:

1. Multi-stage `Dockerfile` → builds Flutter web with `ghcr.io/gmeligio/flutter-web:3.44.8`
2. nginx serves `build/web` on Render’s `$PORT`
3. `render.yaml` Blueprint → `type: web` + `runtime: docker`

#### Migrate off Static Site

1. Open [Render Dashboard](https://dashboard.render.com/)
2. Open the old **Static Site** (if any) → **Settings** → **Delete Web Service** / delete the static site
3. Create the Docker service (pick one):
   - **Blueprint:** New → Blueprint → connect `Taipan-LGM/GardenTownCounty` → apply `render.yaml`
   - **Manual:** New → **Web Service** → connect the repo → **Language: Docker** → Dockerfile Path `./Dockerfile` → Create
4. Wait for the first build (Flutter image pull + `flutter build web` can take several minutes)
5. Open the `.onrender.com` URL from the service overview

Do **not** choose Static Site, Node, or a native runtime for this project.

## Tests

```bash
flutter test
```
