# 💰 Modern Expense Tracker App

A beautiful, modern Flutter expense tracking application with Firebase integration, SMS transaction scanning, and comprehensive analytics.

## ✨ Features

### 🏠 **Modern Dashboard**
- **Personalized greeting** with user's first name
- **Profile image** display in app bar
- **Wallet balance** prominently displayed
- **Quick stats** with income/expense overview
- **Category analytics** with visual charts
- **Recent transactions** preview

### 📱 **Transaction Management**
- **Add transactions** manually or via SMS scan
- **Edit transactions** with full form validation
- **Delete transactions** with confirmation
- **Sort by date** (latest first)
- **Detailed transaction view** with modal bottom sheet
- **Category-based organization**

### 📊 **Analytics & Reports**
- **Visual charts** (Pie, Line, Bar charts)
- **Spending insights** and trends
- **Monthly reports** with detailed breakdowns
- **Budget tracking** and status indicators
- **Category-wise analysis**

### 📲 **SMS Transaction Scanning**
- **Automatic SMS parsing** for bank transactions
- **Smart amount extraction** with heuristics
- **Bank name detection**
- **Reference number parsing**
- **Transaction type classification** (debit/credit)
- **Mock data mode** for testing

### 👤 **User Management**
- **Firebase Authentication** with Google Sign-In
- **Profile management** with photo upload
- **Account settings** and preferences
- **Security options**

### 🎨 **Modern UI/UX**
- **Dark theme** with custom color scheme
- **Floating bottom navigation** with animations
- **Smooth transitions** and micro-interactions
- **Responsive design** for all screen sizes
- **Material Design 3** components

## 🛠️ Tech Stack

- **Framework**: Flutter
- **Backend**: Firebase (Firestore, Authentication)
- **Charts**: fl_chart
- **Icons**: Material Icons
- **Fonts**: Google Fonts (Roboto, Roboto Condensed)
- **State Management**: StatefulWidget with setState
- **Architecture**: Service-based architecture

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6
  google_sign_in: ^6.1.6
  fl_chart: ^0.66.0
  google_fonts: ^6.1.0
  intl: ^0.19.0
  permission_handler: ^11.0.1
  another_telephony: ^0.0.2
  shared_preferences: ^2.2.2
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.0+)
- Dart SDK (3.0+)
- Firebase project setup
- Android Studio / VS Code

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/expense-tracker.git
   cd expense-tracker
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a Firebase project
   - Enable Authentication (Google Sign-In)
   - Enable Firestore Database
   - Download `google-services.json` and place in `android/app/`
   - Update `lib/firebase_options.dart` with your config

4. **Run the app**
   ```bash
   flutter run
   ```

## 📱 Screenshots

### Dashboard
- Modern card-based layout
- Wallet balance display
- Quick stats overview
- Category analytics

### Transactions
- List view with latest first
- Tap for detailed view
- Edit/Delete functionality
- Smooth animations

### Reports
- Interactive charts
- Spending insights
- Monthly breakdowns
- Visual analytics

### SMS Scanning
- Automatic transaction detection
- Smart parsing algorithms
- Bank name recognition
- Amount extraction

## 🏗️ Project Structure

```
lib/
├── main.dart                 # App entry point
├── firebase_options.dart     # Firebase configuration
├── models/                   # Data models
│   ├── expence.dart
│   ├── analytics.dart
│   └── transaction_sms.dart
├── screens/                  # UI screens
│   ├── auth_screen.dart
│   ├── home.dart
│   ├── transactions_screen.dart
│   ├── reports_screen.dart
│   ├── scan_screen.dart
│   ├── profile_screen.dart
│   └── main_scaffold.dart
├── services/                 # Business logic
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── analytics_service.dart
│   ├── sms_service.dart
│   └── sms_tracking_service.dart
└── widgets/                  # Reusable widgets
    └── abstract_shapes.dart
```

## 🔧 Configuration

### Firebase Setup
1. Create Firebase project
2. Enable Authentication (Google)
3. Enable Firestore Database
4. Download configuration files
5. Update `firebase_options.dart`

### SMS Permissions
- Android: `android/app/src/main/AndroidManifest.xml`
- Add SMS read permission
- Configure for Android 11+ compatibility

## 🎯 Key Features Implementation

### SMS Parsing Algorithm
- **Regex patterns** for amount extraction
- **Heuristic filtering** to avoid phone numbers
- **Bank name detection** from SMS content
- **Transaction type classification**

### Analytics Engine
- **Real-time calculations** for spending trends
- **Category-wise breakdowns**
- **Monthly/yearly comparisons**
- **Budget tracking** and alerts

### Modern UI Components
- **SliverAppBar** with collapsible design
- **Floating bottom navigation**
- **Modal bottom sheets** for forms
- **Animated transitions**

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**Eswar** - *Full Stack Developer*
- GitHub: [@yourusername](https://github.com/yourusername)
- LinkedIn: [Your LinkedIn](https://linkedin.com/in/yourprofile)

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- Material Design for UI guidelines
- Open source community for packages

---

⭐ **Star this repository if you found it helpful!**