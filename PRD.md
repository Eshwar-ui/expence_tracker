# Product Requirements Document (PRD)
## Expense Tracker Mobile Application

---

## 1. Executive Summary

### 1.1 Product Overview
The Expense Tracker is a comprehensive personal finance management mobile application built with Flutter, designed to help users track, analyze, and manage their income and expenses efficiently. The app features cloud synchronization, intelligent SMS transaction scanning, and advanced analytics capabilities.

### 1.2 Product Vision
To empower users with intelligent financial tracking tools that provide insights into spending patterns, automate transaction recording, and help achieve better financial health through data-driven decision making.

### 1.3 Target Audience
- **Primary**: Working professionals and individuals aged 25-45 who want to track personal finances
- **Secondary**: Students, freelancers, and small business owners seeking expense management
- **Geographic Focus**: Initially targeting Indian users with SMS banking integration

---

## 2. Product Goals & Objectives

### 2.1 Primary Goals
- **Automate Expense Tracking**: Reduce manual data entry through SMS transaction scanning
- **Provide Financial Insights**: Offer analytics and reports to help users understand spending patterns
- **Ensure Data Security**: Maintain user privacy with secure cloud storage and authentication
- **Cross-Platform Accessibility**: Enable seamless data synchronization across multiple devices

### 2.2 Success Metrics
- **User Engagement**: Daily active users, session duration, feature adoption rate
- **Data Accuracy**: Transaction detection accuracy, user satisfaction with categorization
- **Performance**: App load time < 3 seconds, offline functionality, sync reliability
- **User Retention**: Monthly active users, churn rate, user lifetime value

---

## 3. Product Features

### 3.1 Core Features

#### 3.1.1 Transaction Management
- **Redesigned Add/Edit Modal**: Hero amount card with accent gradient, gradient-driven Expense/Income toggle, premium category pills, in-modal numeric keypad. Keypad automatically shrinks when the soft keyboard appears so the note field stays accessible.
- **Manual Entry**: Tap the center **+** in the bottom nav pill to open the modal.
- **Voice Quick-Add**: Tap the **mic** half of the center pill to dictate a transaction. The speech recognizer captures phrases like *"250 for coffee"* or *"5k salary"*, parses them into amount + type + category + title, and pre-fills the modal for review-then-save.
- **Edit / Delete**: Tap any transaction to edit; long-swipe / detail-sheet action to delete with confirmation.
- **Transaction Types**: Expense and income with type-specific accent colors throughout.
- **Categories**: Predefined + user-defined, with icon-in-circle pills in the modal.
- **Transaction Details**: Title, amount, date, category, description, payment method, location, tags.
- **Recurring Quick-Fill Chips**: One-tap pre-fill from saved recurring transactions inside the modal.

#### 3.1.2 SMS & Notification-Based Transaction Detection
- **Bank Integration**: Support for 30+ major Indian banks (HDFC, ICICI, SBI, Axis, Kotak, etc.).
- **Notification Listener**: Reads UPI app notifications (Google Pay, PhonePe, Paytm, BHIM, SBI Pay) on Android and converts them into pending transactions awaiting user approval.
- **Automatic Detection**: Parses bank SMS + UPI notifications for amount, merchant, and direction (debit/credit).
- **Smart Categorization**: Heuristic merchant → category mapping (Swiggy → Food, Uber → Transport, Amazon → Shopping, …).
- **Quick-Add from Notification (Android)**: When a transaction is detected, a heads-up notification appears with two action buttons:
  - **Confirm** — saves the detection as a real expense in one tap, without opening the app to the modal.
  - **Review** — opens the Smart Inbox / Pending Transactions screen for edits.
  Notification taps from a killed app are replayed via `getNotificationAppLaunchDetails()` so Confirm still works after a cold start.
- **Pending Transactions Screen**: Centralized review queue for all detected transactions with bulk approve / reject.
- **Permission Management**: Securely handles SMS, notification access, microphone, and `POST_NOTIFICATIONS` permissions.

#### 3.1.3 Authentication & User Management
- **Email/Password Authentication**: Traditional sign-up and sign-in
- **Google Sign-In**: One-tap authentication with Google accounts
- **Password Reset**: Email-based password recovery
- **User Profile**: Display name, email, profile photo management
- **Account Management**: Sign out, account deletion capabilities

#### 3.1.4 Data Synchronization
- **Cloud Storage**: Firebase Firestore for data persistence
- **Real-time Sync**: Automatic synchronization across devices
- **User Isolation**: Secure data separation between users
- **Offline Support**: Local data storage with sync when online
- **Data Backup**: Automatic cloud backup of user data

### 3.2 Analytics & Reporting Features

#### 3.2.1 Financial Overview Dashboard
- **Balance Display**: Current financial balance (Income - Expenses)
- **Income Summary**: Total income with trend indicators
- **Expense Summary**: Total expenses with trend indicators
- **Quick Actions**: Direct access to add transactions and scan SMS
- **Streak Badge**: A flame chip next to the user's first name shows the **current logging streak** (consecutive days a transaction was added). Tints amber when the current streak matches the personal best, red otherwise. Milestone toasts fire at 3 / 7 / 14 / 30 / 60 / 100 / 365 days: *"🔥 7-day streak! Keep it going."* Streak persists locally for instant first-paint and syncs to Firestore for cross-device continuity.

#### 3.2.2 Category Analytics
- **Category Breakdown**: Visual representation of spending by category
- **Percentage Analysis**: Category-wise spending percentages
- **Top Categories**: Identification of highest spending categories
- **Progress Bars**: Visual progress indicators for category spending

#### 3.2.3 Budget Management
- **Default Budgets**: Pre-configured budget limits for common categories
- **Budget Tracking**: Real-time budget utilization monitoring
- **Over-budget Alerts**: Visual indicators for exceeded budgets
- **Budget Status**: Overall budget health dashboard

#### 3.2.4 Time-based Analytics
- **Monthly Filtering**: Filter data by specific months and years
- **Daily Breakdown**: Daily spending patterns and trends
- **Monthly Reports**: Comprehensive monthly financial summaries
- **Trend Analysis**: Historical spending trend identification

#### 3.2.5 Search & Advanced Filtering (Transactions Screen)
- **Full-Text Search**: Searches title, category, and description simultaneously.
- **Type Filter**: All / Income / Expense segmented control.
- **Date Range Filter**: Chip-based presets — All Time / This Month / Last 30 Days / Last 90 Days / Custom (native date-range picker with brand theming).
- **Amount Range Filter**: Independent `Min` and `Max` ₹-prefixed inputs, applied live as you type.
- **Category Filter**: Dropdown of all defined categories.
- **Active Filter Badge**: Filter button shows a count badge for the number of active filter dimensions.
- **One-Tap Reset**: Clears all filters and search query at once.

#### 3.2.6 Data Export
- **CSV Export**: 9-column spreadsheet (Date, Type, Category, Title, Amount, Description, Payment Method, Tags, Location) with proper RFC 4180 quote escaping.
- **PDF Export**: A4 report with branded header, 4-tile summary (Income / Expense / Net / Transaction count), and a styled transaction table. Uses Noto Sans (full Unicode coverage) so ₹, emoji, and regional scripts render correctly.
- **Period Picker**: This Month / Last Month / This Year / All Time / Custom date range.
- **System Share Sheet**: One-tap share to email, WhatsApp, Drive, etc.
- **Entry Point**: Profile → Financial Hub → **Export Data**.

### 3.3 User Experience Features

#### 3.3.1 Modern UI/UX
- **Material Design 3**: Modern, clean interface following Material Design principles
- **Responsive Design**: Optimized for various screen sizes and orientations
- **Color-coded Categories**: Visual distinction between different expense categories
- **Gradient Cards**: Beautiful gradient summary cards for key metrics
- **Abstract Shapes**: Custom decorative elements for visual appeal

#### 3.3.2 Navigation & Accessibility
- **Bottom Navigation**: Easy access to main features (Home, Transactions, Reports, Profile).
- **Center Split Pill (Primary CTA)**: Gradient pill in the bottom nav split into two independently tappable halves — left **+** opens the manual-add modal, right **mic** starts voice quick-add. A soft fading hairline divider separates the two zones; each half has its own press-scale animation and tooltip.
- **Pull-to-Refresh**: Refresh data with intuitive gesture.
- **Empty States**: Helpful guidance when no data is available, including a one-tap **Clear Filters** action when the empty state is due to filters.
- **Loading States**: Clear feedback during data operations.

#### 3.3.3 Form Validation & Input
- **Comprehensive Validation**: Real-time validation for all input fields
- **Date Picker**: Intuitive date selection interface
- **Category Dropdown**: Easy category selection with visual indicators
- **Error Handling**: User-friendly error messages and recovery options

---

## 4. Technical Specifications

### 4.1 Technology Stack
- **Framework**: Flutter (Dart SDK ^3.5.0)
- **Language**: Dart
- **Backend**: Firebase (Authentication, Firestore, Cloud Messaging, Crashlytics)
- **State Management**: `StatefulWidget` + service singletons (no Provider/Riverpod/Bloc)
- **Charts**: `fl_chart`
- **Typography**: `google_fonts` (Outfit + Plus Jakarta Sans)
- **SMS Processing**: `another_telephony`
- **Notifications**: `flutter_local_notifications` (channels, heads-up alerts, action buttons), Firebase Messaging (server-pushed daily reminders)
- **Voice Quick-Add**: `speech_to_text` (system speech recognizer; on-device when available)
- **Export**: `pdf` + `printing` (loads Noto Sans for full Unicode), `share_plus`, `path_provider`
- **AI**: Google Gemini (`gemini_ai_service.dart`) + TensorFlow Lite predictions (`ai_expense_service.dart`)
- **Security**: `local_auth` (biometrics), `flutter_secure_storage`
- **Permissions**: `permission_handler`
- **Home Widget**: `home_widget` (Android home-screen balance widget)
- **Networking**: `http`, `flutter_dotenv` for environment variables

### 4.2 Platform Support
- **Android**: Primary platform with full feature support
- **iOS**: Full feature compatibility
- **Web**: Basic functionality support
- **Windows**: Desktop application support
- **macOS**: Desktop application support

### 4.3 Data Architecture

#### 4.3.1 Data Models
- **Expense Model**: Transaction data structure with comprehensive fields
- **Analytics Model**: Analytics data structure for reporting
- **Transaction SMS Model**: SMS parsing and transaction extraction
- **User Model**: User profile and authentication data

#### 4.3.2 Database Schema
- **Users Collection**: User authentication and profile data
- **Expenses Collection**: Transaction records with user isolation
- **Analytics Collection**: Cached analytics data for performance
- **Settings Collection**: User preferences and configurations

### 4.4 Security & Privacy
- **Authentication**: Firebase Authentication with email/password and Google OAuth
- **Data Encryption**: End-to-end encryption for sensitive data
- **User Isolation**: Strict data separation between users
- **Permission Handling**: Secure SMS permission management
- **Privacy Compliance**: GDPR and data protection compliance

---

## 5. User Stories & Use Cases

### 5.1 Primary User Stories

#### 5.1.1 Transaction Management
- **As a user**, I want to add new expenses quickly so that I can track my spending in real-time
- **As a user**, I want to categorize my expenses so that I can understand my spending patterns
- **As a user**, I want to edit or delete transactions so that I can correct mistakes
- **As a user**, I want to add income transactions so that I can track my total financial picture

#### 5.1.2 SMS Scanning
- **As a user**, I want to scan my bank SMS messages so that transactions are automatically recorded
- **As a user**, I want to review detected transactions before adding them so that I can ensure accuracy
- **As a user**, I want automatic categorization of scanned transactions so that I don't have to manually categorize everything

#### 5.1.3 Analytics & Insights
- **As a user**, I want to see my spending by category so that I can identify areas where I spend most
- **As a user**, I want to track my budget utilization so that I can stay within my spending limits
- **As a user**, I want to see monthly trends so that I can understand my financial patterns over time

#### 5.1.4 Data Management
- **As a user**, I want my data to sync across devices so that I can access it anywhere
- **As a user**, I want secure authentication so that my financial data is protected
- **As a user**, I want offline functionality so that I can use the app without internet

### 5.2 Use Case Scenarios

#### 5.2.1 Daily Expense Tracking
1. User opens the app and sees their current balance
2. User makes a purchase and receives bank SMS
3. User scans SMS messages to automatically detect transaction
4. User reviews and confirms the detected transaction
5. Transaction is added to expense list with automatic categorization

#### 5.2.2 Monthly Financial Review
1. User navigates to reports section
2. User selects current month to view analytics
3. User reviews category breakdown and budget status
4. User identifies overspending categories
5. User adjusts spending habits based on insights

#### 5.2.3 Multi-device Usage
1. User adds transaction on mobile device
2. Data automatically syncs to cloud
3. User opens app on tablet/desktop
4. User sees updated transaction data
5. User continues tracking on different device

---

## 6. Competitive Analysis

### 6.1 Direct Competitors
- **Money Lover**: Popular expense tracking app with similar features
- **Expense Manager**: Simple expense tracking with basic analytics
- **Spendee**: Budget tracking with family sharing features

### 6.2 Competitive Advantages
- **SMS Integration**: Unique feature for Indian banking SMS parsing
- **Real-time Analytics**: Advanced analytics with budget tracking
- **Cross-platform**: Single codebase for multiple platforms
- **Modern UI**: Material Design 3 with beautiful visual elements
- **Cloud Sync**: Seamless data synchronization across devices

### 6.3 Market Positioning
- **Target Segment**: Tech-savvy individuals seeking automated expense tracking
- **Value Proposition**: "Smart expense tracking with automatic SMS integration"
- **Differentiation**: Focus on Indian banking ecosystem and advanced analytics

---

## 7. Implementation Roadmap

### 7.1 Phase 1: Core Features (Completed)
- ✅ Basic expense tracking (add, edit, delete)
- ✅ Firebase authentication and cloud sync
- ✅ SMS transaction scanning
- ✅ Basic analytics and reporting
- ✅ Modern UI with Material Design 3

### 7.2 Phase 2: Enhanced Analytics (Completed)
- ✅ Advanced analytics dashboard
- ✅ Budget tracking and management
- ✅ Category-wise spending analysis
- ✅ Monthly and yearly filtering
- ✅ Financial overview with balance tracking

### 7.3 Phase 3: Power User & Automation (Completed)
- ✅ **Redesigned transaction modal** with hero amount card and shrinking keypad
- ✅ **Streak + gamification** with milestone toasts and home-screen badge
- ✅ **CSV / PDF export** with system share-sheet and Unicode-safe PDF rendering
- ✅ **Search & advanced filter**: full-text + date range chips + amount range + category
- ✅ **Voice quick-add** via the bottom-nav mic button (`speech_to_text` + deterministic parser)
- ✅ **Quick-add from notification**: heads-up alert with Confirm / Review actions
- ✅ **Recurring transactions** with one-tap quick-fill chips
- ✅ **Dark mode** (system-driven via `ThemeMode.system`)
- ✅ **Push notifications** for daily logging reminders (FCM + Cloud Function)
- ✅ **Biometric app lock** and PIN protection
- ✅ **Android home-screen widget** showing current balance
- ✅ **AI predictions** for future expenses (TFLite) and Gemini-powered insights

### 7.4 Phase 4: Future Considerations
- 🔄 Accounts / Wallets (transactions tied to a source: cash, HDFC card, UPI, etc.)
- 🔄 Transfers between accounts (excluded from income/expense reports)
- 🔄 Split transactions (one purchase → multiple categories)
- 🔄 Savings goals with progress tracking
- 🔄 Subscription detector (auto-flag recurring monthly merchants)
- 🔄 Bill calendar with due-date badges
- 🔄 Cash flow forecast (project end-of-month balance from current pace)
- 🔄 Receipt OCR via Gemini Vision
- 🔄 Net worth tracking (assets + liabilities)
- 🔄 Year-in-review / Spotify-Wrapped style annual summary
- 🔄 Group / shared expenses (Splitwise-lite)
- 🔄 Multiple currency support
- 🔄 True background notification confirmation (Firebase-init'd background isolate)
- 🔄 Tags as a first-class filter dimension

### 7.4 Phase 4: Enterprise Features (Future)
- 🔄 Business expense tracking
- 🔄 Team collaboration features
- 🔄 Advanced reporting for businesses
- 🔄 Integration with accounting software
- 🔄 API for third-party integrations

---

## 8. Success Criteria & KPIs

### 8.1 User Engagement Metrics
- **Daily Active Users (DAU)**: Target 70% of registered users
- **Session Duration**: Average 5+ minutes per session
- **Feature Adoption**: 80% of users use SMS scanning feature
- **Transaction Volume**: Average 10+ transactions per user per month

### 8.2 Technical Performance Metrics
- **App Load Time**: < 3 seconds on average devices
- **Sync Reliability**: 99.5% successful data synchronization
- **Crash Rate**: < 0.1% crash rate
- **Offline Functionality**: 100% core features available offline

### 8.3 Business Metrics
- **User Retention**: 60% monthly retention rate
- **User Satisfaction**: 4.5+ star rating on app stores
- **Data Accuracy**: 95%+ accuracy in SMS transaction parsing
- **Support Tickets**: < 5% of users require support

---

## 9. Risk Assessment & Mitigation

### 9.1 Technical Risks
- **SMS Permission Changes**: Android/iOS may restrict SMS access
  - *Mitigation*: Implement alternative input methods, manual entry options
- **Firebase Costs**: Cloud usage may exceed budget with scale
  - *Mitigation*: Implement data optimization, caching strategies
- **Bank SMS Format Changes**: Banks may change SMS formats
  - *Mitigation*: Regular pattern updates, user feedback system

### 9.2 Business Risks
- **Competition**: Established players may copy features
  - *Mitigation*: Focus on unique SMS integration, superior UX
- **Regulatory Changes**: Financial data regulations may change
  - *Mitigation*: Stay updated with compliance requirements
- **User Adoption**: Slow adoption of new features
  - *Mitigation*: User education, gradual feature rollout

### 9.3 Security Risks
- **Data Breach**: Unauthorized access to user financial data
  - *Mitigation*: Strong encryption, regular security audits
- **SMS Data Privacy**: Concerns about SMS access
  - *Mitigation*: Clear privacy policy, local processing, user consent

---

## 10. Conclusion

The Expense Tracker application represents a comprehensive solution for personal finance management, combining automated transaction detection with advanced analytics and a modern user experience. The product is well-positioned to serve the growing demand for intelligent financial tracking tools, particularly in the Indian market with its unique SMS banking integration.

The technical architecture is robust and scalable, built on proven technologies like Flutter and Firebase, ensuring reliable performance and future growth potential. The focus on user experience, data security, and cross-platform compatibility positions the product for success in the competitive personal finance app market.

---

**Document Version**: 1.1  
**Last Updated**: May 2026  
**Next Review**: Q3 2026

### Changelog

**v1.1 — May 2026**
- Added: redesigned add/edit modal with hero amount card and keyboard-aware keypad
- Added: streak tracking + milestone toasts + home-screen flame badge
- Added: CSV / PDF export with Unicode-safe rendering and system share sheet
- Added: search + advanced filtering (date range chips, amount range, full-text)
- Added: voice quick-add via bottom-nav mic button (`speech_to_text` parser)
- Added: heads-up notification with Confirm / Review action buttons for detected transactions
- Updated: tech stack section to reflect new dependencies (`pdf`, `printing`, `share_plus`, `path_provider`, `speech_to_text`)
- Updated: bottom navigation now uses a split gradient pill (+/mic) instead of a single circle

**v1.0 — December 2024**
- Initial PRD covering core tracking, SMS scanning, analytics, and budget features.
