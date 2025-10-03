# Expense Tracker

A beautiful and feature-rich Flutter expense tracking application with Firebase cloud integration, Google and Email authentication, and real-time data synchronization across devices.

## Features

### 🎯 Core Functionality
- **Add Expenses**: Quickly add new expenses with title, amount, category, date, and description
- **Edit Expenses**: Modify existing expenses with a simple tap
- **Delete Expenses**: Remove expenses with confirmation dialog
- **Category Management**: Organize expenses by categories (Food, Transportation, Entertainment, Shopping, Bills, Healthcare, Education, Other)
- **SMS Transaction Scanning**: Automatically detect credit and debit transactions from bank SMS messages

### 📊 Statistics & Insights
- **Total Amount Display**: See your total expenses at a glance
- **Transaction Count**: Track the number of transactions
- **Category Filtering**: Filter expenses by specific categories
- **Beautiful Summary Card**: Gradient card showing key metrics

### 🎨 User Experience
- **Modern UI Design**: Clean, intuitive interface with Material Design 3
- **Responsive Layout**: Works perfectly on different screen sizes
- **Color-coded Categories**: Each category has its own color and icon
- **Form Validation**: Comprehensive input validation with helpful error messages
- **Date Picker**: Easy date selection for expense entries
- **Empty State**: Helpful guidance when no expenses are present
- **Smart SMS Scanning**: One-tap transaction detection from bank messages
- **Transaction Preview**: Review detected transactions before adding them

### 💾 Data Management
- **Cloud Storage**: Uses Firebase Firestore for cloud data persistence
- **Real-time Sync**: Data synchronizes across all devices in real-time
- **Authentication**: Secure Google and Email authentication
- **User Isolation**: Each user's data is completely isolated and secure
- **Offline Support**: Works offline with automatic sync when connected
- **Error Handling**: Robust error handling with user-friendly messages

## Screenshots

The app features:
- A beautiful gradient summary card showing total expenses
- Category filter chips for easy navigation
- Individual expense cards with category icons and colors
- A comprehensive add/edit expense dialog with form validation
- Responsive design that works on all screen sizes

## Getting Started

### Prerequisites
- Flutter SDK (3.9.2 or higher)
- Dart SDK
- Android Studio / VS Code with Flutter extensions

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd expence_tracker
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## Dependencies

- `flutter`: Flutter SDK
- `firebase_core`: ^3.6.0 - Firebase core functionality
- `firebase_auth`: ^5.3.1 - Firebase authentication
- `cloud_firestore`: ^5.4.3 - Firebase Firestore database
- `google_sign_in`: ^6.2.1 - Google Sign-In integration
- `intl`: ^0.19.0 - For date formatting
- `cupertino_icons`: ^1.0.8 - iOS-style icons
- `provider`: ^6.1.2 - State management
- `permission_handler`: ^11.3.1 - Permission management
- **Note**: SMS scanning currently uses mock data for demonstration. Real SMS integration can be added later.

## Project Structure

```
lib/
├── main.dart                 # App entry point with Firebase initialization
├── firebase_options.dart     # Firebase configuration
├── models/
│   ├── expence.dart         # Expense data model
│   └── transaction_sms.dart # SMS transaction model
├── screens/
│   ├── home.dart            # Main home screen with all functionality
│   ├── auth_screen.dart     # Authentication screen (Google & Email)
│   ├── profile_screen.dart  # User profile and settings
│   └── scan_screen.dart     # SMS transaction scanning screen
└── services/
    ├── auth_service.dart    # Firebase authentication service
    ├── firestore_service.dart # Firestore cloud database service
    └── sms_service.dart     # SMS reading and parsing service
```

## Usage

### Getting Started
1. **Sign Up/Sign In**: Use Google Sign-In or create an account with email and password
2. **Profile Management**: Access your profile and settings via the profile button
3. **Data Sync**: Your data automatically syncs across all devices when signed in

### Managing Expenses
1. **Adding an Expense**: Tap the floating action button to open the add expense dialog
2. **Scanning SMS Transactions**: Tap the scan button in the app bar to detect transactions from bank SMS messages
3. **Viewing Expenses**: All expenses are displayed in a scrollable list with category filtering
4. **Editing an Expense**: Tap the menu button on any expense card and select "Edit"
5. **Deleting an Expense**: Tap the menu button on any expense card and select "Delete"
6. **Filtering by Category**: Use the category filter chips at the top to filter expenses
7. **Real-time Updates**: Changes are instantly synced across all your devices

### SMS Transaction Scanning
1. **Mock Data**: Currently uses simulated bank transaction data for demonstration
2. **Review Transactions**: Preview detected transactions with bank name, amount, and date
3. **Add Transactions**: Tap the + button on any transaction to add it to your expenses
4. **Smart Categorization**: Transactions are automatically categorized based on description
5. **Bank Support**: Simulates major Indian banks (HDFC, ICICI, SBI, Axis, Kotak, etc.)
6. **Future Enhancement**: Real SMS integration can be added for actual bank message scanning

## Features in Detail

### Expense Categories
- **Food** 🍽️ - Restaurant meals, groceries, snacks
- **Transportation** 🚗 - Gas, public transport, rideshare
- **Entertainment** 🎬 - Movies, games, subscriptions
- **Shopping** 🛍️ - Clothes, electronics, miscellaneous purchases
- **Bills** 📄 - Utilities, rent, insurance
- **Healthcare** 🏥 - Medical expenses, pharmacy
- **Education** 📚 - Books, courses, school supplies
- **Other** 📦 - Miscellaneous expenses

### Data Persistence
The app uses Firebase Firestore to store expense data in the cloud. Each user's data is completely isolated and secure. Data automatically syncs across all devices in real-time, and the app works offline with automatic synchronization when connectivity is restored.

### Form Validation
- Title is required and cannot be empty
- Amount must be a valid positive number
- Category selection is required
- Date picker ensures valid date selection
- Description is optional

## Firebase Setup

**IMPORTANT**: Before running the app, you need to set up Firebase:

1. **Create Firebase Project**: Go to [Firebase Console](https://console.firebase.google.com/) and create a new project
2. **Add Android App**: Add your Android app with package name `com.example.expence_tracker`
3. **Download Configuration**: Download `google-services.json` and place it in `android/app/`
4. **Enable Authentication**: Enable Email/Password and Google Sign-In in Firebase Console
5. **Set up Firestore**: Create a Firestore database in test mode
6. **Update Configuration**: Replace placeholder values in `lib/firebase_options.dart` with your actual Firebase config

See `FIREBASE_SETUP.md` for detailed setup instructions.

## Future Enhancements

Potential features for future versions:
- Dark mode support
- Export to CSV/PDF
- Budget tracking and alerts
- Charts and graphs for spending analysis
- Multiple currency support
- Receipt photo attachment (Firebase Storage)
- Recurring expense tracking
- Push notifications (Firebase Cloud Messaging)
- Advanced analytics (Firebase Analytics)
- Data export and backup features

## Contributing

Feel free to contribute to this project by:
1. Forking the repository
2. Creating a feature branch
3. Making your changes
4. Submitting a pull request

## License

This project is open source and available under the MIT License.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
