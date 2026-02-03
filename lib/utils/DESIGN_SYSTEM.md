# 🎨 Design System Documentation

This document explains how to use the Expense Tracker Design System for consistent UI across the app.

## 📋 Table of Contents

- [Overview](#overview)
- [Colors](#colors)
- [Typography](#typography)
- [Spacing](#spacing)
- [Components](#components)
- [Usage Examples](#usage-examples)

## Overview

The Design System provides a centralized set of design tokens and reusable components to ensure consistency across the entire application.

**Location**: `lib/utils/app_design_system.dart`  
**Components**: `lib/widgets/design_system_components.dart`

## Colors

### Primary Colors
```dart
AppDesignSystem.primary        // #6366F1 - Indigo
AppDesignSystem.primaryLight   // #818CF8
AppDesignSystem.primaryDark    // #4F46E5
```

### Secondary Colors
```dart
AppDesignSystem.secondary      // #8B5CF6 - Purple
AppDesignSystem.secondaryLight // #A78BFA
AppDesignSystem.secondaryDark  // #7C3AED
```

### Semantic Colors
```dart
AppDesignSystem.success        // #10B981 - Green
AppDesignSystem.error          // #EF4444 - Red
AppDesignSystem.warning        // #F59E0B - Orange
AppDesignSystem.info           // #3B82F6 - Blue
```

### Background Colors
```dart
AppDesignSystem.background         // #0F0F23 - Deep Dark
AppDesignSystem.backgroundElevated // #1E1B4B - Dark Indigo
AppDesignSystem.backgroundCard     // #1E1B4B
AppDesignSystem.backgroundInput    // #312E81
```

### Text Colors
```dart
AppDesignSystem.textPrimary    // #F8FAFC - Main text
AppDesignSystem.textSecondary  // #F1F5F9 - Secondary text
AppDesignSystem.textTertiary   // #94A3B8 - Tertiary text
AppDesignSystem.textDisabled   // #64748B - Disabled text
```

### Usage Example
```dart
Container(
  color: AppDesignSystem.primary,
  child: Text(
    'Hello',
    style: TextStyle(color: AppDesignSystem.textPrimary),
  ),
)
```

## Typography

### Display Styles
```dart
AppDesignSystem.displayLarge   // 57px, Bold
AppDesignSystem.displayMedium  // 45px, Bold
AppDesignSystem.displaySmall   // 36px, Bold
```

### Headline Styles
```dart
AppDesignSystem.headlineLarge  // 32px, Semi-bold
AppDesignSystem.headlineMedium // 28px, Semi-bold
AppDesignSystem.headlineSmall  // 24px, Semi-bold
```

### Title Styles
```dart
AppDesignSystem.titleLarge      // 22px, Semi-bold
AppDesignSystem.titleMedium     // 16px, Semi-bold
AppDesignSystem.titleSmall      // 14px, Semi-bold
```

### Body Styles
```dart
AppDesignSystem.bodyLarge       // 16px, Regular
AppDesignSystem.bodyMedium      // 14px, Regular
AppDesignSystem.bodySmall       // 12px, Regular
```

### Label Styles
```dart
AppDesignSystem.labelLarge      // 14px, Semi-bold
AppDesignSystem.labelMedium     // 12px, Semi-bold
AppDesignSystem.labelSmall      // 11px, Semi-bold
```

### Usage Example
```dart
Text(
  'Welcome',
  style: AppDesignSystem.headlineLarge,
)

Text(
  'Description text',
  style: AppDesignSystem.bodyMedium,
)
```

## Spacing

### Spacing Scale (4px base unit)
```dart
AppDesignSystem.spaceXS    // 4px
AppDesignSystem.spaceSM    // 8px
AppDesignSystem.spaceMD    // 16px
AppDesignSystem.spaceLG    // 24px
AppDesignSystem.spaceXL   // 32px
AppDesignSystem.spaceXXL  // 48px
```

### Padding
```dart
AppDesignSystem.paddingXS
AppDesignSystem.paddingSM
AppDesignSystem.paddingMD
AppDesignSystem.paddingLG
AppDesignSystem.paddingXL

// Directional padding
AppDesignSystem.paddingHorizontalMD
AppDesignSystem.paddingVerticalMD
```

### Usage Example
```dart
Container(
  padding: AppDesignSystem.paddingLG,
  margin: AppDesignSystem.marginMD,
  child: Text('Content'),
)
```

## Border Radius

```dart
AppDesignSystem.radiusXS    // 4px
AppDesignSystem.radiusSM    // 8px
AppDesignSystem.radiusMD   // 12px
AppDesignSystem.radiusLG  // 16px
AppDesignSystem.radiusXL  // 20px
AppDesignSystem.radiusRound // 999px (fully rounded)

// BorderRadius objects
AppDesignSystem.borderRadiusMD
AppDesignSystem.borderRadiusLG
```

### Usage Example
```dart
Container(
  decoration: BoxDecoration(
    borderRadius: AppDesignSystem.borderRadiusLG,
    color: AppDesignSystem.backgroundCard,
  ),
)
```

## Shadows

```dart
AppDesignSystem.shadowXS
AppDesignSystem.shadowSM
AppDesignSystem.shadowMD
AppDesignSystem.shadowLG
AppDesignSystem.shadowXL

// Colored shadows
AppDesignSystem.shadowPrimary(0.3)
AppDesignSystem.shadowSuccess(0.3)
AppDesignSystem.shadowError(0.3)
```

### Usage Example
```dart
Container(
  decoration: BoxDecoration(
    boxShadow: AppDesignSystem.shadowMD,
  ),
)
```

## Components

### Buttons

#### Primary Button
```dart
PrimaryButton(
  text: 'Submit',
  onPressed: () {},
  icon: Icons.check,
)
```

#### Secondary Button
```dart
SecondaryButton(
  text: 'Cancel',
  onPressed: () {},
)
```

#### Success Button
```dart
SuccessButton(
  text: 'Save',
  onPressed: () {},
)
```

#### Outlined Button
```dart
OutlinedPrimaryButton(
  text: 'Learn More',
  onPressed: () {},
)
```

### Cards

```dart
DesignSystemCard(
  padding: AppDesignSystem.paddingLG,
  elevated: true,
  onTap: () {},
  child: Text('Card Content'),
)
```

### Text Fields

```dart
DesignSystemTextField(
  label: 'Email',
  hint: 'Enter your email',
  controller: _controller,
  prefixIcon: Icons.email,
  validator: (value) {
    if (value?.isEmpty ?? true) return 'Required';
    return null;
  },
)
```

### Spacers

```dart
// Vertical spacing
const VSpace.lg()  // 24px
const VSpace.md()  // 16px
const VSpace.sm()  // 8px

// Horizontal spacing
const HSpace.md()  // 16px
```

### Badges

```dart
DesignSystemBadge.success(text: 'Active')
DesignSystemBadge.error(text: 'Error')
DesignSystemBadge.warning(text: 'Warning')
DesignSystemBadge.info(text: 'Info')
```

### Empty States

```dart
DesignSystemEmptyState(
  icon: Icons.inbox,
  title: 'No Items',
  message: 'You don\'t have any items yet.',
  action: PrimaryButton(
    text: 'Add Item',
    onPressed: () {},
  ),
)
```

### Loading Indicators

```dart
DesignSystemLoading()

// Custom size and color
DesignSystemLoading(
  size: 40,
  color: AppDesignSystem.primary,
)
```

## Usage Examples

### Complete Card Example
```dart
DesignSystemCard(
  padding: AppDesignSystem.paddingLG,
  margin: AppDesignSystem.marginMD,
  elevated: true,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Card Title',
        style: AppDesignSystem.titleLarge,
      ),
      const VSpace.md(),
      Text(
        'Card description text',
        style: AppDesignSystem.bodyMedium,
      ),
      const VSpace.lg(),
      PrimaryButton(
        text: 'Action',
        onPressed: () {},
      ),
    ],
  ),
)
```

### Form Example
```dart
Column(
  children: [
    DesignSystemTextField(
      label: 'Name',
      controller: _nameController,
      prefixIcon: Icons.person,
    ),
    const VSpace.md(),
    DesignSystemTextField(
      label: 'Email',
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      prefixIcon: Icons.email,
    ),
    const VSpace.lg(),
    PrimaryButton(
      text: 'Submit',
      onPressed: _handleSubmit,
      width: double.infinity,
    ),
  ],
)
```

## Best Practices

1. **Always use design system tokens** instead of hardcoded values
2. **Use components** from `design_system_components.dart` when available
3. **Maintain consistency** - if a component doesn't exist, create it using design tokens
4. **Follow spacing scale** - use predefined spacing values
5. **Use semantic colors** - success, error, warning, info for appropriate contexts
6. **Typography hierarchy** - use appropriate text styles for headings, body, labels

## Migration Guide

When updating existing code:

1. Replace hardcoded colors with `AppDesignSystem.colorName`
2. Replace hardcoded padding/margins with `AppDesignSystem.padding*` or `AppDesignSystem.margin*`
3. Replace hardcoded border radius with `AppDesignSystem.borderRadius*`
4. Replace hardcoded text styles with `AppDesignSystem.textStyle*`
5. Use design system components instead of custom widgets where possible

## Questions?

Refer to the source files:
- `lib/utils/app_design_system.dart` - All design tokens
- `lib/widgets/design_system_components.dart` - Reusable components

