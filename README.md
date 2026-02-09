# Expense Tracker - Optimized & Production Ready

## 🎯 Project Overview
Premium personal finance and expense tracker with smart transaction detection, AI insights, and biometric security.

## ✨ Key Features

### 💳 Transaction Management
- **Smart SMS Detection** - Auto-detect bank transactions from SMS
- **Smart Notification Access** - Real-time transaction capture from notifications
- **Manual Entry** - Add transactions with rich categorization
- **Bulk Import** - Scan and import multiple SMS transactions
- **Deduplication** - Intelligent duplicate detection

### 🤖 AI-Powered Insights
- **Gemini AI Integration** - Free AI-powered spending insights
- **Category Suggestions** - Auto-suggest categories based on merchant
- **Spending Predictions** - Forecast future expenses
- **Anomaly Detection** - Identify unusual spending patterns

### 📊 Analytics & Reports
- **Visual Charts** - Beautiful spending visualizations
- **Category Breakdown** - Detailed expense analysis
- **Budget Tracking** - Set and monitor budgets
- **Recurring Transactions** - Track subscriptions and bills

### 🔒 Security
- **Biometric Lock** - Fingerprint/Face ID protection
- **Firebase Authentication** - Secure Google Sign-In
- **Local Encryption** - Sensitive data protection

### 💰 Payment Integration
- **UPI Support** - Integrated UPI payment flows
- **QR Code Scanner** - Quick payment scanning

## 🏗️ Architecture

### Clean Architecture
```
lib/
├── models/          # Data models & entities
├── screens/         # UI layer
├── services/        # Business logic
├── utils/           # Utilities & helpers
└── widgets/         # Reusable components
```

### Key Services
- **FirestoreService** - Cloud data sync
- **SMSService** - SMS transaction parsing
- **NotificationService** - Real-time notification capture
- **GeminiAIService** - AI insights generation
- **SecurityService** - Biometric authentication

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.5.0+
- Firebase project setup
- Gemini API key (optional, for AI features)

### Installation
```bash
# Clone the repository
git clone <your-repo-url>

# Install dependencies
flutter pub get

# Configure Firebase
# Add google-services.json (Android)
# Add GoogleService-Info.plist (iOS)

# Create .env file
cp .env.example .env
# Add your GEMINI_API_KEY

# Run the app
flutter run
```

## 📱 Permissions Required

### Android
- `READ_SMS` - Read bank transaction messages
- `RECEIVE_SMS` - Receive new transaction alerts
- `BIND_NOTIFICATION_LISTENER_SERVICE` - Access notifications
- `USE_BIOMETRIC` - Biometric authentication
- `INTERNET` - Firebase sync

### iOS
- Notification access
- Biometric authentication (Face ID/Touch ID)

## 🎨 Design System
- **Material Design 3** - Modern UI components
- **Dark Mode** - Full dark theme support
- **Glassmorphism** - Premium glass effects
- **Animations** - Smooth micro-interactions
- **Custom Color Palette** - Brand-consistent colors

## 🔧 Configuration

### Firebase Setup
1. Create Firebase project
2. Enable Authentication (Google Sign-In)
3. Enable Firestore Database
4. Download configuration files
5. Add to project

### Gemini AI Setup (Optional)
1. Get API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Add to `.env` file: `GEMINI_API_KEY=your_key_here`

## 📦 Dependencies

### Core
- `firebase_core` - Firebase initialization
- `firebase_auth` - Authentication
- `cloud_firestore` - Database
- `shared_preferences` - Local storage

### Features
- `another_telephony` - SMS reading
- `flutter_notification_listener` - Notification access
- `local_auth` - Biometric authentication
- `fl_chart` - Charts & graphs
- `mobile_scanner` - QR code scanning

### AI & Networking
- `http` - API calls
- `flutter_dotenv` - Environment variables

## 🧪 Testing
```bash
# Run tests
flutter test

# Run with coverage
flutter test --coverage
```

## 📦 Build

### Android
```bash
# Debug build
flutter build apk --debug

# Release build
flutter build apk --release
```

### iOS
```bash
# Debug build
flutter build ios --debug

# Release build
flutter build ios --release
```

## 🎯 Optimization Features

### Performance
- ✅ Lazy loading for heavy screens
- ✅ Efficient state management
- ✅ Optimized image loading
- ✅ Minimal rebuilds

### Code Quality
- ✅ Clean architecture
- ✅ Centralized utilities
- ✅ Singleton services
- ✅ Type-safe models

### Size Optimization
- ✅ Removed unused assets
- ✅ Optimized dependencies
- ✅ Code splitting
- ✅ Tree shaking enabled

## 📝 License
This project is licensed under the MIT License.

## 🤝 Contributing
Contributions are welcome! Please feel free to submit a Pull Request.

## 📧 Support
For issues and questions, please open an issue on GitHub.

---

**Built with ❤️ using Flutter**