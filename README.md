# Expense Tracker

Premium personal finance and expense tracker with smart OCR, UPI integration, and biometric security.

## Requirements

- Flutter SDK (see `environment.sdk` in `pubspec.yaml`)
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

The app can use a `.env` file for optional config (e.g. API keys). A template:

```bash
# .env (create from this; do not commit real secrets)
# KEY=value
```

- Create `.env` in the project root if needed.
- `.env` is listed under `flutter.assets` and is in `.gitignore`; keep secrets out of version control.

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
  flutter build appbundle
  ```

  Output: `build/app/outputs/bundle/release/app-release.aab`

- **APK:**

  ```bash
  flutter build apk --release
  ```

  Output: `build/app/outputs/flutter-apk/app-release.apk`

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

## Notification listener (Android)

The app uses notification access to parse transaction notifications (e.g. UPI). Two services are declared:

- **flutter_notification_listener** plugin: `NotificationsHandlerService` (from the plugin).
- **App-specific**: `NotificationCaptureService` (in `android/app/...`).

Both are bound to the same Notification Listener capability; the app coordinates parsing and deduplication. Users must enable “Notification access” for **Expense Tracker** in system Settings.

## License

See repository license file.
