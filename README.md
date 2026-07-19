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

## Demo login

| Field    | Value                 |
|----------|-----------------------|
| Username | `admin`               |
| Password | `garden2026`          |

When Firebase Auth is configured, email/password accounts are preferred; demo login remains as a fallback.

## Quick start

```bash
flutter pub get
flutter run -d linux      # or windows / macos / chrome / android
```

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

Until that flag is true, the app runs **SQLite-only** (fully usable offline).

## Architecture

| Layer | Role |
|-------|------|
| `DatabaseService` | SQLite schema + CRUD |
| `SyncEngine` | Push pending local rows → Firestore; listen for remote changes |
| `FileStorageService` | Pick files, copy locally, upload bytes to Firebase Storage |
| `AuthService` | Firebase Auth or demo session; tracks display name for uploads |
| Riverpod providers | App state, repositories, section navigation |

Writes always go to SQLite first (`pendingSync = 1`), then sync when cloud is available.

## Deploy

### GitHub Pages (automatic)

On every push to `main`, GitHub Actions builds Flutter web and publishes Pages.

**App URL:** https://taipan-lgm.github.io/GardenTownCounty/

### Render

`render.yaml` builds Flutter web as a static site.

1. Render → New → Blueprint → select this repo  
2. Or create a Static Site using the build command in `render.yaml`

> Web uses an in-memory database (session-only). Desktop/mobile keep full SQLite offline storage.

## Tests

```bash
flutter test
```
