# Firebase Setup Guide for Expense Tracker

This guide will help you set up Firebase for your Expense Tracker app with authentication and cloud storage.

## Prerequisites

1. A Google account
2. Flutter development environment set up
3. Android Studio or VS Code with Flutter extensions

## Step 1: Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or "Add project"
3. Enter project name: `expense-tracker-app` (or your preferred name)
4. Enable Google Analytics (optional but recommended)
5. Click "Create project"

## Step 2: Add Android App to Firebase

1. In your Firebase project, click "Add app" and select Android
2. Enter your Android package name: `com.example.expence_tracker`
3. Enter app nickname: `Expense Tracker Android`
4. Enter SHA-1 fingerprint (optional for development)
5. Click "Register app"
6. Download the `google-services.json` file
7. Place the `google-services.json` file in `android/app/` directory

## Step 3: Add iOS App to Firebase (if developing for iOS)

1. In your Firebase project, click "Add app" and select iOS
2. Enter your iOS bundle ID: `com.example.expenceTracker`
3. Enter app nickname: `Expense Tracker iOS`
4. Click "Register app"
5. Download the `GoogleService-Info.plist` file
6. Place the `GoogleService-Info.plist` file in `ios/Runner/` directory

## Step 4: Enable Authentication

1. In Firebase Console, go to "Authentication"
2. Click "Get started"
3. Go to "Sign-in method" tab
4. Enable "Email/Password" authentication
5. Enable "Google" authentication
6. For Google auth, add your project's SHA-1 fingerprint

## Step 5: Set up Firestore Database

1. In Firebase Console, go to "Firestore Database"
2. Click "Create database"
3. Choose "Start in test mode" (for development)
4. Select a location for your database
5. Click "Done"

## Step 6: Configure Firestore Security Rules

1. In Firestore Database, go to "Rules" tab
2. Replace the default rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId}/expenses/{document} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Users can only access their own profile
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Step 7: Update Firebase Configuration

1. Open `lib/firebase_options.dart`
2. Replace the placeholder values with your actual Firebase configuration:

```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'your-actual-android-api-key',
  appId: 'your-actual-android-app-id',
  messagingSenderId: 'your-actual-sender-id',
  projectId: 'your-actual-project-id',
  storageBucket: 'your-actual-project-id.appspot.com',
);
```

You can find these values in:
- Firebase Console → Project Settings → General → Your apps

## Step 8: Update Android Configuration

1. Open `android/app/build.gradle`
2. Add the following at the top:

```gradle
plugins {
    id 'com.google.gms.google-services'
}
```

3. Open `android/build.gradle`
4. Add the following in dependencies:

```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.3.15'
}
```

## Step 9: Update iOS Configuration (if developing for iOS)

1. Open `ios/Runner.xcworkspace` in Xcode
2. Add the `GoogleService-Info.plist` to the Runner project
3. Make sure it's added to the Runner target

## Step 10: Test the Setup

1. Run `flutter clean`
2. Run `flutter pub get`
3. Run `flutter run`

## Troubleshooting

### Common Issues:

1. **"No Firebase App '[DEFAULT]' has been created"**
   - Make sure `google-services.json` is in the correct location
   - Run `flutter clean` and `flutter pub get`

2. **"Google Sign-In failed"**
   - Check SHA-1 fingerprint in Firebase Console
   - Make sure Google Sign-In is enabled in Authentication

3. **"Permission denied"**
   - Check Firestore security rules
   - Make sure user is authenticated

4. **"Network error"**
   - Check internet connection
   - Verify Firebase project is active

### Getting SHA-1 Fingerprint:

For debug builds:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

For release builds:
```bash
keytool -list -v -keystore path/to/your/keystore.jks -alias your-key-alias
```

## Security Best Practices

1. **Never commit sensitive data**: Add `google-services.json` and `GoogleService-Info.plist` to `.gitignore`
2. **Use environment variables**: For production, use environment variables for API keys
3. **Review security rules**: Regularly review and update Firestore security rules
4. **Enable App Check**: For production apps, enable Firebase App Check

## Production Considerations

1. **Change Firestore rules**: Update rules to be more restrictive for production
2. **Enable App Check**: Add App Check for additional security
3. **Monitor usage**: Set up monitoring and alerts in Firebase Console
4. **Backup data**: Set up automated backups for Firestore
5. **Performance monitoring**: Enable Firebase Performance Monitoring

## Additional Features You Can Add

1. **Push Notifications**: Using Firebase Cloud Messaging
2. **Analytics**: Firebase Analytics for user behavior tracking
3. **Crashlytics**: Firebase Crashlytics for crash reporting
4. **Remote Config**: Firebase Remote Config for feature flags
5. **Storage**: Firebase Storage for file uploads (receipt images)

## Support

If you encounter issues:
1. Check Firebase Console for error logs
2. Review Flutter and Firebase documentation
3. Check Firebase status page for service outages
4. Join Firebase community forums for help

Remember to keep your Firebase configuration files secure and never commit them to public repositories!
