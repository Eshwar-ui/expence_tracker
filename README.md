# Expense Tracker

A premium personal-finance app for the Indian market — smart UPI/SMS detection, voice quick-add, one-tap notification confirmation, CSV/PDF export, daily streak gamification, AI-powered insights, and biometric security. Built with Flutter and Firebase.

## Features

- **Add transactions fast** — manual modal with hero amount card and an in-modal numeric keypad that auto-shrinks when the soft keyboard opens.
- **Voice quick-add** — tap the **mic** half of the center pill in the bottom nav and say *"250 for coffee"* / *"5k salary"*. A deterministic parser extracts the amount, type, category and title, then opens the modal pre-filled for review.
- **UPI / SMS auto-detection** — listens to bank SMS and UPI app notifications (Google Pay, PhonePe, Paytm, BHIM, SBI Pay) and creates pending transactions for review.
- **One-tap Confirm from notification (Android)** — detected transactions surface as a heads-up alert with **Confirm** and **Review** buttons. Confirm saves the expense without opening the app.
- **Search & advanced filter** — full-text search + date-range chips (This Month / Last 30 / Last 90 / Custom) + ₹-prefixed amount range + category filter.
- **CSV / PDF export** — share a spreadsheet or printable PDF for any time range. PDF uses Noto Sans so ₹, emoji and regional scripts render correctly.
- **Streak + gamification** — flame badge on the home screen tracks consecutive logging days, with milestone toasts at 3 / 7 / 14 / 30 / 60 / 100 / 365 days.
- **Budget planner, recurring transactions, AI predictions** (TFLite) and **Gemini-powered insights**.
- **Biometric / PIN app lock**, **Android home-screen widget** for current balance, **dark mode** (follows system).

## Requirements

- Flutter SDK (Dart `^3.5.0` — see `environment.sdk` in `pubspec.yaml`)
- Firebase project (Auth, Firestore, Messaging, Crashlytics)
- Android: JDK 11+, Android SDK
- iOS: Xcode (for iOS/macOS builds)

## Setup

### 1. Clone and install dependencies

```bash
git clone <repo-url>
cd expence_tracker
flutter pub get
```

### 2. Firebase

- Create a Firebase project at [Firebase Console](https://console.firebase.google.com).
- Enable **Authentication** (e.g. Email/Password, Google), **Firestore**, **Cloud Messaging**, and **Crashlytics**.
- Run **FlutterFire CLI** to link the app and regenerate options:

  ```bash
  dart pub global activate flutterfire_cli
  flutterfire configure
  ```

- This updates `lib/firebase_options.dart` and adds/updates `android/app/google-services.json` and iOS config. Do not commit `google-services.json` if it contains secrets; the generated `firebase_options.dart` is typically safe to commit for client apps.

### 3. Environment variables (`.env`)

The app uses a `.env` file for optional config (e.g. the Gemini API key for AI insights). A template:

```bash
# .env (create from this; do not commit real secrets)
GEMINI_API_KEY=your_gemini_api_key_here
```

- Create `.env` in the project root if needed.
- `.env` is listed under `flutter.assets` and is in `.gitignore`; keep secrets out of version control.
- AI insights & predictions work without the key (regex-based parsing falls back gracefully), but Gemini-enriched summaries require it.

### 4. Android release signing (`key.properties`)

For release builds (Play Store or local APK/App Bundle), configure signing:

1. Create a keystore (if you don’t have one):

   ```bash
   keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Create `android/key.properties` (this file is gitignored):

   ```properties
   storePassword=<your-keystore-password>
   keyPassword=<your-key-password>
   keyAlias=upload
   storeFile=upload-keystore.jks
   ```

   Use a path relative to `android/` (e.g. `storeFile=upload-keystore.jks` if the JKS is in `android/app/` then set `storeFile=app/upload-keystore.jks`), or an absolute path.

3. Do not commit `key.properties` or `.jks` files.

Without a valid `key.properties` and keystore, the **release** build will fail with a Gradle error (by design).

## Running the app

```bash
flutter run
```

For a specific device:

```bash
flutter devices
flutter run -d <device-id>
```

## Building for production

### Android

- **App Bundle (recommended for Play Store):**

  ```bash
  flutter build appbundle --no-tree-shake-icons
  ```

  Output: `build/app/outputs/bundle/release/app-release.aab`

- **APK:**

  ```bash
  flutter build apk --release --no-tree-shake-icons
  ```

  Output: `build/app/outputs/flutter-apk/app-release.apk`

> **Why `--no-tree-shake-icons`?** Categories rebuild `IconData` at runtime from stored code points (see `lib/models/category.dart`), which the icon tree-shaker cannot statically analyse. Omitting the flag causes the release build to fail.

Release builds use ProGuard/R8 (minify + shrink) and require a configured signing key (see **Android release signing** above).

### iOS

```bash
flutter build ios
```

Then open `ios/Runner.xcworkspace` in Xcode, select signing team and device/simulator, and archive/export as needed.

## Tests

```bash
flutter test
```

- Unit tests: e.g. `test/notification_parsing_test.dart`, `test/notification_validation_test.dart`
- Widget test: `test/widget_test.dart` (app load smoke test)

## Android permissions

Declared in `android/app/src/main/AndroidManifest.xml`:

| Permission | Used for |
|---|---|
| `USE_BIOMETRIC` | Biometric app lock |
| `READ_SMS` / `RECEIVE_SMS` | Bank SMS parsing |
| `POST_NOTIFICATIONS` | Heads-up alerts for detected transactions + daily reminders (Android 13+ requires runtime grant) |
| `RECORD_AUDIO` | Voice quick-add |

A `<queries>` entry for `android.speech.RecognitionService` is also declared so the speech recognizer can be resolved on Android 11+.

## Notification listener (Android)

The app uses notification access to parse transaction notifications (e.g. UPI). Two services are declared:

- **flutter_notification_listener** plugin: `NotificationsHandlerService` (from the plugin).
- **App-specific**: `NotificationCaptureService` (in `android/app/...`).

Both are bound to the same Notification Listener capability; the app coordinates parsing and deduplication. Users must enable "Notification access" for **Expense Tracker** in system Settings.

When a transaction is detected, the app fires its own heads-up notification (channel `pending_transaction_alert`) with **Confirm** / **Review** actions. Tapping **Confirm** saves the detection straight to Firestore via `PendingTransactionService.confirmPending()`. Notification taps that occur while the app is killed are replayed on launch via `getNotificationAppLaunchDetails()`.

## Project layout

```
lib/
├── main.dart                          # App bootstrap, global navigator key, notification action routing
├── screens/
│   ├── home.dart                      # Dashboard with streak badge + quick actions
│   ├── main_scaffold.dart             # Bottom nav + split-pill add/voice button
│   ├── expense_dialog.dart            # Redesigned add/edit modal (with shrinking keypad)
│   ├── voice_capture_sheet.dart       # Voice quick-add sheet
│   ├── export_sheet.dart              # CSV/PDF export sheet
│   ├── transactions_screen.dart       # List + search + advanced filter
│   └── pending_transactions_screen.dart
├── services/
│   ├── pending_notification_service.dart   # Heads-up alerts with Confirm/Review actions
│   ├── pending_transaction_service.dart    # Pending CRUD + confirmPending()
│   ├── export_service.dart                 # CSV writer + PDF builder (Noto Sans)
│   ├── reminder_service.dart               # Daily reminder + streak tracking
│   └── notification_listener_service.dart  # Reads UPI app notifications via method channel
└── utils/
    ├── app_design_system.dart        # Tokens, colors, gradients, typography
    └── voice_expense_parser.dart     # Deterministic transcript → Expense parser
```

## License

See repository license file.
