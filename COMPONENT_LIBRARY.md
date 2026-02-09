# Component Library Reference
## Quick Reference Guide for Developers

---

## 🚀 Quick Start

### Import Required Packages
```dart
import 'package:expence_tracker/utils/app_design_system.dart';
import 'package:expence_tracker/widgets/design_system_components.dart';
```

---

## 📦 Component Catalog

### 1. Buttons

#### Primary Button (Gradient)
```dart
GradientButton(
  text: 'Add Transaction',
  icon: Icons.add,
  onPressed: () {
    // Your action
  },
  isLoading: false,
  gradient: AppDesignSystem.primaryGradient, // Optional
)
```

**Variants:**
- Default: Primary gradient (Indigo to Purple)
- Success: `gradient: AppDesignSystem.successGradient`
- Error: `gradient: AppDesignSystem.errorGradient`

#### Secondary Button (Outlined)
```dart
SecondaryButton(
  text: 'Cancel',
  onPressed: () {},
  isLoading: false,
)
```

---

### 2. Cards

#### Standard Card
```dart
DesignSystemCard(
  padding: EdgeInsets.all(24),
  margin: EdgeInsets.all(16),
  onTap: () {},
  child: Column(
    children: [
      Text('Card Content'),
    ],
  ),
)
```

#### Glass Card (Glassmorphism)
```dart
DesignSystemCard(
  glass: true,
  padding: EdgeInsets.all(24),
  child: YourContent(),
)
```

---

### 3. App Bar

```dart
Scaffold(
  appBar: PremiumAppBar(
    title: 'Dashboard',
    showBackButton: true,
    centerTitle: false,
    actions: [
      IconButton(
        icon: Icon(Icons.settings),
        onPressed: () {},
      ),
    ],
  ),
  body: YourContent(),
)
```

---

### 4. Text Fields

```dart
DesignSystemTextField(
  controller: _controller,
  label: 'Amount',
  hint: 'Enter amount',
  icon: Icons.currency_rupee,
  keyboardType: TextInputType.number,
  obscureText: false,
  onChanged: (value) {},
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'Required field';
    }
    return null;
  },
  suffixIcon: IconButton(
    icon: Icon(Icons.clear),
    onPressed: () => _controller.clear(),
  ),
)
```

---

### 5. Transaction Tile

```dart
PremiumTransactionTile(
  title: 'Grocery Shopping',
  category: 'Food',
  amount: 1250.00,
  date: DateTime.now(),
  isIncome: false,
  onTap: () {
    // Show details
  },
)
```

---

### 6. Badges

```dart
DesignSystemBadge(
  text: 'Added',
  color: AppDesignSystem.success,
)

// Other colors
DesignSystemBadge(text: 'Pending', color: AppDesignSystem.warning)
DesignSystemBadge(text: 'Failed', color: AppDesignSystem.error)
DesignSystemBadge(text: 'Info', color: AppDesignSystem.info)
```

---

### 7. Empty States

```dart
DesignSystemEmptyState(
  icon: Icons.receipt_long_rounded,
  title: 'No transactions yet',
  message: 'Your financial history will appear here',
  action: GradientButton(
    text: 'Add Transaction',
    onPressed: () {},
  ),
)
```

---

### 8. Loading Indicator

```dart
// Full screen loading
DesignSystemLoading()

// In a specific area
Center(
  child: DesignSystemLoading(),
)
```

---

### 9. Dialogs

```dart
showDesignSystemDialog(
  context: context,
  title: 'Delete Transaction',
  message: 'Are you sure you want to delete this transaction?',
  confirmLabel: 'Delete',
  cancelLabel: 'Cancel',
  destructive: true,
  onConfirm: () {
    // Delete action
  },
)
```

---

### 10. Snackbars

```dart
// Success message
showDesignSystemSnackBar(
  context: context,
  message: 'Transaction added successfully',
  isError: false,
  icon: Icons.check_circle,
)

// Error message
showDesignSystemSnackBar(
  context: context,
  message: 'Failed to save transaction',
  isError: true,
  icon: Icons.error,
)
```

---

## 📐 Spacing Helpers

### Vertical Spacing
```dart
VSpace.xs()  // 4px
VSpace.sm()  // 8px
VSpace.md()  // 16px
VSpace.lg()  // 24px
VSpace.xl()  // 32px
VSpace(48)   // Custom
```

### Horizontal Spacing
```dart
HSpace.xs()  // 4px
HSpace.sm()  // 8px
HSpace.md()  // 16px
HSpace(24)   // Custom
```

---

## 🎨 Using Colors

### Brand Colors
```dart
AppDesignSystem.brandPrimary    // #6366F1
AppDesignSystem.brandSecondary  // #10B981
AppDesignSystem.brandAccent     // #F59E0B
AppDesignSystem.brandInfo       // #3B82F6
```

### Functional Colors
```dart
AppDesignSystem.success   // #10B981
AppDesignSystem.error     // #EF4444
AppDesignSystem.warning   // #F59E0B
AppDesignSystem.info      // #3B82F6
```

### Theme Colors (Adaptive)
```dart
final theme = Theme.of(context);

theme.colorScheme.primary
theme.colorScheme.secondary
theme.colorScheme.error
theme.colorScheme.background
theme.colorScheme.surface
theme.colorScheme.onPrimary
theme.colorScheme.onSurface
```

---

## ✍️ Using Typography

### Text Styles
```dart
final theme = Theme.of(context);

// Display (Large numbers, hero text)
theme.textTheme.displayLarge   // 48px / 800
theme.textTheme.displayMedium  // 36px / 700
theme.textTheme.displaySmall   // 32px / 700

// Headlines (Section titles)
theme.textTheme.headlineLarge   // 28px / 600
theme.textTheme.headlineMedium  // 24px / 600

// Titles (Card headers)
theme.textTheme.titleLarge   // 20px / 700
theme.textTheme.titleMedium  // 16px / 600

// Body (Content)
theme.textTheme.bodyLarge   // 16px / 400
theme.textTheme.bodyMedium  // 14px / 400

// Labels (Small text)
theme.textTheme.labelLarge  // 14px / 600
```

### Custom Text Styling
```dart
Text(
  'Total Balance',
  style: theme.textTheme.titleMedium?.copyWith(
    color: AppDesignSystem.success,
    fontWeight: FontWeight.w700,
  ),
)
```

---

## 📏 Using Spacing Constants

### Padding
```dart
Padding(
  padding: EdgeInsets.all(AppDesignSystem.s24),
  child: YourWidget(),
)

Padding(
  padding: EdgeInsets.symmetric(
    horizontal: AppDesignSystem.s16,
    vertical: AppDesignSystem.s12,
  ),
  child: YourWidget(),
)
```

### Border Radius
```dart
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(AppDesignSystem.r16),
  ),
)

// Or use predefined
borderRadius: AppDesignSystem.borderRadiusLG  // 16px
borderRadius: AppDesignSystem.borderRadiusXL  // 24px
borderRadius: AppDesignSystem.borderRadiusRound  // 99px
```

---

## 🎨 Using Gradients

```dart
Container(
  decoration: BoxDecoration(
    gradient: AppDesignSystem.primaryGradient,
    borderRadius: BorderRadius.circular(16),
  ),
  child: YourContent(),
)

// Available gradients
AppDesignSystem.primaryGradient  // Indigo to Purple
AppDesignSystem.successGradient  // Emerald shades
AppDesignSystem.errorGradient    // Red shades
AppDesignSystem.surfaceGradient  // Subtle white overlay
```

---

## 🌓 Dark Mode Support

All components automatically adapt to dark mode. To check current theme:

```dart
final isDark = Theme.of(context).brightness == Brightness.dark;

if (isDark) {
  // Dark mode specific logic
} else {
  // Light mode specific logic
}
```

---

## 📱 Common Patterns

### Form Layout
```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    DesignSystemTextField(
      controller: titleController,
      label: 'Title',
      icon: Icons.title,
    ),
    VSpace.md(),
    DesignSystemTextField(
      controller: amountController,
      label: 'Amount',
      icon: Icons.currency_rupee,
      keyboardType: TextInputType.number,
    ),
    VSpace.lg(),
    GradientButton(
      text: 'Save',
      onPressed: _handleSave,
    ),
  ],
)
```

### Card with Action
```dart
DesignSystemCard(
  glass: true,
  child: Column(
    children: [
      Icon(Icons.account_balance_wallet, size: 48),
      VSpace.md(),
      Text(
        'Total Balance',
        style: theme.textTheme.titleMedium,
      ),
      VSpace.sm(),
      Text(
        '₹12,450.00',
        style: theme.textTheme.displayMedium?.copyWith(
          color: AppDesignSystem.success,
        ),
      ),
      VSpace.lg(),
      Row(
        children: [
          Expanded(
            child: SecondaryButton(
              text: 'Withdraw',
              onPressed: () {},
            ),
          ),
          HSpace.md(),
          Expanded(
            child: GradientButton(
              text: 'Deposit',
              onPressed: () {},
            ),
          ),
        ],
      ),
    ],
  ),
)
```

### List with Empty State
```dart
_transactions.isEmpty
  ? DesignSystemEmptyState(
      icon: Icons.receipt_long,
      title: 'No transactions',
      message: 'Add your first transaction',
    )
  : ListView.builder(
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        return PremiumTransactionTile(
          title: tx.title,
          category: tx.category,
          amount: tx.amount,
          date: tx.date,
          isIncome: tx.type == TransactionType.income,
          onTap: () => _showDetails(tx),
        );
      },
    )
```

---

## ⚡ Performance Tips

1. **Const Constructors**: Use `const` where possible
```dart
const VSpace.md()
const DesignSystemLoading()
```

2. **Reuse Controllers**: Don't create new controllers on every build
```dart
final _controller = TextEditingController();
```

3. **Avoid Nested Builders**: Extract widgets into separate classes

4. **Use Keys**: For list items that can be reordered
```dart
PremiumTransactionTile(
  key: ValueKey(transaction.id),
  ...
)
```

---

## 🐛 Common Issues

### Issue: Colors not updating in dark mode
**Solution**: Use theme colors instead of hardcoded colors
```dart
// ❌ Bad
color: Colors.black

// ✅ Good
color: Theme.of(context).colorScheme.onSurface
```

### Issue: Text overflow
**Solution**: Add maxLines and overflow
```dart
Text(
  longText,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
)
```

### Issue: Keyboard covering input
**Solution**: Wrap in SingleChildScrollView
```dart
SingleChildScrollView(
  child: Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.of(context).viewInsets.bottom,
    ),
    child: YourForm(),
  ),
)
```

---

## 📚 Additional Resources

- **Full Design System**: See `DESIGN_SYSTEM.md`
- **Code**: `lib/utils/app_design_system.dart`
- **Components**: `lib/widgets/design_system_components.dart`

---

**Happy Coding! 🚀**
