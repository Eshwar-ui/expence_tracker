import 'package:expence_tracker/screens/expense_dialog.dart';
import 'package:expence_tracker/screens/pending_transactions_screen.dart';
import 'package:expence_tracker/screens/scan_screen.dart';
import 'package:expence_tracker/utils/app_design_system.dart';
import 'package:expence_tracker/widgets/design_system_components.dart';
import 'package:flutter/material.dart';

class SmartInboxScreen extends StatelessWidget {
  const SmartInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: PremiumAppBar(
          title: 'Smart Inbox',
          actions: [
            IconButton(
              tooltip: 'Add manually',
              icon: const Icon(Icons.add_rounded),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => ExpenseDialog(
                    onTransactionSaved: () {},
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDesignSystem.s24,
                AppDesignSystem.s8,
                AppDesignSystem.s24,
                AppDesignSystem.s12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All detected and unreviewed transaction intake lives here.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const VSpace.md(),
                  Container(
                    padding: const EdgeInsets.all(AppDesignSystem.s4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppDesignSystem.r16),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: TabBar(
                      indicator: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(
                          AppDesignSystem.r12,
                        ),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabAlignment: TabAlignment.fill,
                      splashBorderRadius:
                          BorderRadius.circular(AppDesignSystem.r12),
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor:
                          theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.notifications_active_rounded),
                          text: 'Review',
                        ),
                        Tab(
                          icon: Icon(Icons.sms_rounded),
                          text: 'SMS Inbox',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  PendingTransactionsScreen(showScaffold: false),
                  ScanScreen(showScaffold: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
