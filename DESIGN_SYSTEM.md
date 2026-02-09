# 🎨 Design System Documentation
## Expense Tracker - Premium Fintech Design Language

---

## 📋 Table of Contents
1. [Design Philosophy](#design-philosophy)
2. [Color System](#color-system)
3. [Typography](#typography)
4. [Spacing & Layout](#spacing--layout)
5. [Components](#components)
6. [Animations & Interactions](#animations--interactions)
7. [Accessibility](#accessibility)
8. [Implementation Guide](#implementation-guide)

---

## 🎯 Design Philosophy

### Core Principles
- **Premium Fintech Aesthetic** - Modern, trustworthy, and sophisticated
- **Glassmorphism** - Frosted glass effects for depth and elegance
- **Dark Mode First** - Optimized for both light and dark themes
- **Micro-interactions** - Smooth animations for delightful UX
- **Accessibility** - WCAG 2.1 AA compliant

### Design Inspiration
- **Neo-banking apps** (Revolut, N26, Monzo)
- **Modern SaaS dashboards** (Linear, Notion)
- **Material Design 3** principles
- **Apple Human Interface Guidelines**

---

## 🎨 Color System

### Brand Colors

#### Primary Palette
```dart
// Electric Indigo - Main brand color
brandPrimary: #6366F1 (RGB: 99, 102, 241)

// Emerald Mint - Success & income
brandSecondary: #10B981 (RGB: 16, 185, 129)

// Amber Sun - Warnings & highlights
brandAccent: #F59E0B (RGB: 245, 158, 11)

// Royal Blue - Information
brandInfo: #3B82F6 (RGB: 59, 130, 246)
```

#### Functional Colors
```dart
success: #10B981  // Income, positive actions
error: #EF4444    // Expenses, destructive actions
warning: #F59E0B  // Alerts, cautions
info: #3B82F6     // Informational messages
```

### Neutral Colors

#### Dark Theme
```dart
darkBg: #0F172A       // Background (Slate 900)
darkCanvas: #1E293B   // Cards & surfaces (Slate 800)
darkSurface: #334155  // Elevated elements (Slate 700)
darkBorder: #475569   // Borders (Slate 600)

// Text
darkTextHigh: #F8FAFC   // Primary text (Slate 50)
darkTextMed: #CBD5E1    // Secondary text (Slate 300)
darkTextLow: #64748B    // Tertiary text (Slate 500)
```

#### Light Theme
```dart
lightBg: #F1F5F9      // Background (Slate 100)
lightCanvas: #FFFFFF  // Cards & surfaces (White)
lightSurface: #FFFFFF // Elevated elements (White)
lightBorder: #E2E8F0  // Borders (Slate 200)

// Text
textHigh: #1E293B     // Primary text (Slate 800)
textMed: #64748B      // Secondary text (Slate 500)
textLow: #94A3B8      // Tertiary text (Slate 400)
```

### Gradients

#### Primary Gradient
```dart
LinearGradient(
  colors: [#6366F1, #8B5CF6],  // Indigo to Purple
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)
```

#### Success Gradient
```dart
LinearGradient(
  colors: [#10B981, #059669],  // Emerald shades
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)
```

#### Error Gradient
```dart
LinearGradient(
  colors: [#EF4444, #DC2626],  // Red shades
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)
```

### Color Usage Guidelines

| Use Case | Light Theme | Dark Theme |
|----------|-------------|------------|
| Background | `#F1F5F9` | `#0F172A` |
| Cards | `#FFFFFF` | `#1E293B` |
| Primary Actions | `#6366F1` | `#6366F1` |
| Income | `#10B981` | `#10B981` |
| Expense | `#EF4444` | `#EF4444` |
| Borders | `#E2E8F0` | `#475569` |

---

## ✍️ Typography

### Font Families

#### Display & Headlines
**Outfit** - Modern geometric sans-serif
- Used for: Large headings, hero text, dashboard numbers
- Weights: 600 (SemiBold), 700 (Bold), 800 (ExtraBold)

#### Body & UI
**Plus Jakarta Sans** - Clean, readable sans-serif
- Used for: Body text, labels, buttons, inputs
- Weights: 400 (Regular), 500 (Medium), 600 (SemiBold), 700 (Bold)

### Type Scale

#### Display Styles
```dart
displayLarge: 48px / 800 weight / -1.0 letter-spacing
  Usage: Hero numbers, dashboard totals

displayMedium: 36px / 700 weight / -0.5 letter-spacing
  Usage: Section headers, large cards

displaySmall: 32px / 700 weight / 0 letter-spacing
  Usage: Screen titles
```

#### Headline Styles
```dart
headlineLarge: 28px / 600 weight
  Usage: Card headers, modal titles

headlineMedium: 24px / 600 weight
  Usage: Section titles, app bar titles
```

#### Title Styles
```dart
titleLarge: 20px / 700 weight
  Usage: List item titles, prominent labels

titleMedium: 16px / 600 weight
  Usage: Card titles, button text
```

#### Body Styles
```dart
bodyLarge: 16px / 400 weight
  Usage: Primary body text

bodyMedium: 14px / 400 weight
  Usage: Secondary text, descriptions

labelLarge: 14px / 600 weight
  Usage: Input labels, small buttons
```

### Typography Best Practices
- **Hierarchy**: Use size, weight, and color to create clear hierarchy
- **Line Height**: 1.5x for body text, 1.2x for headings
- **Letter Spacing**: Negative for large text, normal for body
- **Contrast**: Minimum 4.5:1 for body text, 3:1 for large text

---

## 📏 Spacing & Layout

### Spacing Scale
```dart
s4:  4px   // Micro spacing (icon padding)
s8:  8px   // Small spacing (between related items)
s12: 12px  // Medium-small spacing
s16: 16px  // Base spacing (standard padding)
s20: 20px  // Medium spacing
s24: 24px  // Large spacing (card padding)
s32: 32px  // Extra large spacing (section gaps)
s48: 48px  // XXL spacing (major sections)
```

### Border Radius
```dart
r12: 12px  // Small elements (badges, chips)
r16: 16px  // Standard elements (buttons, inputs)
r24: 24px  // Large elements (cards, modals)
rFull: 99px // Fully rounded (pills, avatars)
```

### Layout Grid
- **Mobile**: 16px margins, 8px gutters
- **Tablet**: 24px margins, 16px gutters
- **Desktop**: 32px margins, 24px gutters

### Elevation & Shadows

#### Soft Shadow (Cards)
```dart
BoxShadow(
  color: Colors.black.withOpacity(0.04),
  blurRadius: 10,
  offset: Offset(0, 4),
)
BoxShadow(
  color: Colors.black.withOpacity(0.04),
  blurRadius: 20,
  offset: Offset(0, 10),
)
```

#### Glass Effect
```dart
// Background blur
BackdropFilter(
  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
  child: Container(
    color: Colors.white.withOpacity(0.05), // Dark mode
    // or
    color: Colors.white.withOpacity(0.6),  // Light mode
  ),
)
```

---

## 🧩 Components

### 1. Buttons

#### Primary Button (Gradient)
```dart
GradientButton(
  text: 'Continue',
  icon: Icons.arrow_forward,
  onPressed: () {},
  gradient: AppDesignSystem.primaryGradient,
)
```
**Specs:**
- Height: 56px
- Border Radius: 16px
- Font: 16px / 700 weight
- Gradient: Primary gradient
- Shadow: Soft shadow

#### Secondary Button (Outlined)
```dart
SecondaryButton(
  text: 'Cancel',
  onPressed: () {},
)
```
**Specs:**
- Height: 56px
- Border Radius: 16px
- Border: 1px solid outline color
- Font: 16px / 700 weight

### 2. Cards

#### Standard Card
```dart
DesignSystemCard(
  padding: EdgeInsets.all(24),
  child: YourContent(),
)
```

#### Glass Card
```dart
DesignSystemCard(
  glass: true,
  padding: EdgeInsets.all(24),
  child: YourContent(),
)
```

**Specs:**
- Border Radius: 24px
- Border: 1.5px with opacity
- Padding: 24px default
- Shadow: Soft shadow
- Glass: Backdrop blur + semi-transparent

### 3. App Bar

```dart
PremiumAppBar(
  title: 'Dashboard',
  showBackButton: true,
  actions: [
    IconButton(icon: Icon(Icons.settings)),
  ],
)
```

**Specs:**
- Height: 56px (standard toolbar)
- Background: Glassmorphic blur
- Title: 22px / 800 weight
- Transparent background with blur

### 4. Transaction Tile

```dart
PremiumTransactionTile(
  title: 'Grocery Shopping',
  category: 'Food',
  amount: 1250.00,
  date: DateTime.now(),
  isIncome: false,
  onTap: () {},
)
```

**Specs:**
- Padding: 16px horizontal, 12px vertical
- Icon: 20px in colored circle
- Amount: Bold, colored (green/red)
- Date: Small, secondary color

### 5. Text Fields

```dart
DesignSystemTextField(
  controller: controller,
  label: 'Amount',
  hint: 'Enter amount',
  icon: Icons.currency_rupee,
  keyboardType: TextInputType.number,
)
```

**Specs:**
- Height: Auto (min 56px)
- Border Radius: 16px
- Border: 1px with primary tint
- Padding: 16px
- Icon: 20px, primary color

### 6. Badges

```dart
DesignSystemBadge(
  text: 'Added',
  color: AppDesignSystem.success,
)
```

**Specs:**
- Padding: 12px horizontal, 4px vertical
- Border Radius: Full (pill shape)
- Font: 12px / 700 weight
- Background: Color with 10% opacity

### 7. Empty States

```dart
DesignSystemEmptyState(
  icon: Icons.receipt_long_rounded,
  title: 'No transactions yet',
  message: 'Your history will appear here',
  action: GradientButton(...),
)
```

**Specs:**
- Icon: 80px, outline color
- Title: Headline medium
- Message: Body medium, centered
- Action: Optional button

### 8. Dialogs

```dart
showDesignSystemDialog(
  context: context,
  title: 'Delete Transaction',
  message: 'Are you sure?',
  confirmLabel: 'Delete',
  destructive: true,
  onConfirm: () {},
)
```

**Specs:**
- Background: Glassmorphic
- Padding: 24px
- Buttons: Row with equal width
- Backdrop: Blur effect

### 9. Snackbars

```dart
showDesignSystemSnackBar(
  context: context,
  message: 'Transaction added',
  isError: false,
  icon: Icons.check_circle,
)
```

**Specs:**
- Position: Top center
- Animation: Elastic slide from top
- Duration: 3 seconds
- Background: Glassmorphic card
- Icon: Colored circle background

---

## 🎬 Animations & Interactions

### Animation Principles
1. **Purposeful** - Every animation serves a purpose
2. **Fast** - 200-500ms for most interactions
3. **Natural** - Use easing curves (easeOut, elasticOut)
4. **Consistent** - Same duration for similar actions

### Standard Durations
```dart
Quick:    200ms  // Hover, focus states
Standard: 300ms  // Page transitions, fades
Slow:     500ms  // Complex animations, elastic
```

### Easing Curves
```dart
Curves.easeOut       // Deceleration (most common)
Curves.easeInOut     // Smooth both ends
Curves.elasticOut    // Bouncy effect (snackbars)
Curves.easeOutCubic  // Smooth deceleration
```

### Common Animations

#### Page Transition
```dart
FadeTransition + SlideTransition
Duration: 300ms
Curve: easeOutCubic
Offset: (0.1, 0) to (0, 0)
```

#### Button Press
```dart
Scale: 1.0 to 0.95
Duration: 100ms
Curve: easeOut
```

#### Card Hover (Web/Desktop)
```dart
Elevation: 2 to 8
Duration: 200ms
Curve: easeOut
```

#### Snackbar Entry
```dart
SlideTransition: Offset(0, -1.5) to (0, 0)
Duration: 500ms
Curve: elasticOut
```

---

## ♿ Accessibility

### Color Contrast
- **Body Text**: Minimum 4.5:1 contrast ratio
- **Large Text**: Minimum 3:1 contrast ratio
- **Interactive Elements**: Minimum 3:1 contrast ratio

### Touch Targets
- **Minimum Size**: 44x44 dp (iOS), 48x48 dp (Android)
- **Spacing**: 8dp minimum between targets

### Screen Reader Support
- All interactive elements have semantic labels
- Images have alt text
- Form fields have labels
- Error messages are announced

### Keyboard Navigation
- Tab order follows visual hierarchy
- Focus indicators are visible
- All actions accessible via keyboard

---

## 💻 Implementation Guide

### Setup

1. **Install Dependencies**
```yaml
dependencies:
  google_fonts: ^6.3.3
  flutter: sdk: flutter
```

2. **Import Design System**
```dart
import 'package:expence_tracker/utils/app_design_system.dart';
import 'package:expence_tracker/widgets/design_system_components.dart';
```

3. **Apply Theme**
```dart
MaterialApp(
  theme: AppDesignSystem.lightTheme,
  darkTheme: AppDesignSystem.darkTheme,
  themeMode: ThemeMode.system,
)
```

### Using Components

#### Example: Create a Card with Button
```dart
DesignSystemCard(
  glass: true,
  child: Column(
    children: [
      Text(
        'Total Balance',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      VSpace.md(),
      Text(
        '₹12,450.00',
        style: Theme.of(context).textTheme.displayMedium,
      ),
      VSpace.lg(),
      GradientButton(
        text: 'Add Transaction',
        icon: Icons.add,
        onPressed: () {},
      ),
    ],
  ),
)
```

#### Example: Form with Validation
```dart
Form(
  child: Column(
    children: [
      DesignSystemTextField(
        controller: amountController,
        label: 'Amount',
        hint: 'Enter amount',
        icon: Icons.currency_rupee,
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Required';
          }
          return null;
        },
      ),
      VSpace.md(),
      GradientButton(
        text: 'Submit',
        onPressed: () {},
      ),
    ],
  ),
)
```

### Spacing Helpers

```dart
// Vertical spacing
VSpace.xs()  // 4px
VSpace.sm()  // 8px
VSpace.md()  // 16px
VSpace.lg()  // 24px
VSpace.xl()  // 32px

// Horizontal spacing
HSpace.xs()  // 4px
HSpace.sm()  // 8px
HSpace.md()  // 16px
```

### Theme Access

```dart
// Get current theme
final theme = Theme.of(context);

// Access colors
theme.colorScheme.primary
theme.colorScheme.error
theme.scaffoldBackgroundColor

// Access text styles
theme.textTheme.displayLarge
theme.textTheme.bodyMedium
```

---

## 📱 Responsive Design

### Breakpoints
```dart
Mobile:  < 600px
Tablet:  600px - 1024px
Desktop: > 1024px
```

### Adaptive Layouts
```dart
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth < 600) {
      return MobileLayout();
    } else if (constraints.maxWidth < 1024) {
      return TabletLayout();
    } else {
      return DesktopLayout();
    }
  },
)
```

---

## 🎨 Design Tokens Summary

### Colors
- 4 Brand colors
- 4 Functional colors
- 8 Dark neutrals
- 8 Light neutrals
- 3 Gradient definitions

### Typography
- 2 Font families
- 10 Text styles
- 4 Font weights

### Spacing
- 8 Spacing values (4px - 48px)
- 4 Border radius values

### Components
- 9 Core components
- 3 Layout helpers
- 2 Feedback components

---

## 📚 Resources

### Design Files
- Figma: [Link to design file]
- Style Guide: This document

### Code
- Design System: `lib/utils/app_design_system.dart`
- Components: `lib/widgets/design_system_components.dart`

### Fonts
- Outfit: [Google Fonts](https://fonts.google.com/specimen/Outfit)
- Plus Jakarta Sans: [Google Fonts](https://fonts.google.com/specimen/Plus+Jakarta+Sans)

---

**Version**: 1.0.0  
**Last Updated**: February 2026  
**Maintained by**: Expense Tracker Team

---

*This design system is built with Flutter and follows Material Design 3 principles with custom fintech-inspired enhancements.*
