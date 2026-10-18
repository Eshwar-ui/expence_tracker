import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/expence.dart';
import '../utils/app_design_system.dart';
import 'design_system_components.dart';

/// A Monday-first, 13-week calendar of expense amounts in local time.
class ExpenseHeatmap extends StatefulWidget {
  const ExpenseHeatmap(
      {super.key,
      required this.expenses,
      this.today,
      this.liquidGlass = false});

  final List<Expense> expenses;
  final DateTime? today;
  final bool liquidGlass;

  static DateTime startDate(DateTime today) {
    final day = DateUtils.dateOnly(today.toLocal());
    return DateTime(day.year, day.month, day.day - day.weekday + 1 - 12 * 7);
  }

  static Map<DateTime, double> dailyTotals(
      List<Expense> expenses, DateTime today) {
    final end = DateUtils.dateOnly(today.toLocal());
    final start = startDate(end);
    final totals = <DateTime, double>{};
    for (final expense in expenses) {
      final day = DateUtils.dateOnly(expense.date.toLocal());
      if (expense.type != TransactionType.expense ||
          !expense.amount.isFinite ||
          expense.amount <= 0 ||
          day.isBefore(start) ||
          day.isAfter(end)) {
        continue;
      }
      totals.update(day, (value) => value + expense.amount,
          ifAbsent: () => expense.amount);
    }
    return totals;
  }

  @override
  State<ExpenseHeatmap> createState() => _ExpenseHeatmapState();
}

class _ExpenseHeatmapState extends State<ExpenseHeatmap> {
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final today =
        DateUtils.dateOnly((widget.today ?? DateTime.now()).toLocal());
    final start = ExpenseHeatmap.startDate(today);
    final totals = ExpenseHeatmap.dailyTotals(widget.expenses, today);
    final peak = totals.values.fold<double>(0, math.max);
    final selected = _selectedDay != null &&
            !_selectedDay!.isBefore(start) &&
            !_selectedDay!.isAfter(today)
        ? _selectedDay!
        : today;
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final empty =
        dark ? AppDesignSystem.darkSurface : AppDesignSystem.lightBorder;
    final palette = <Color>[
      empty,
      Color.lerp(empty, AppDesignSystem.brandSecondary, 0.30)!,
      Color.lerp(empty, AppDesignSystem.brandSecondary, 0.55)!,
      Color.lerp(empty, AppDesignSystem.brandSecondary, 0.80)!,
      AppDesignSystem.brandSecondary,
    ];

    int level(double amount) =>
        amount <= 0 || peak == 0 ? 0 : (amount / peak * 4).ceil().clamp(1, 4);

    DateTime dayAt(int index) =>
        DateTime(start.year, start.month, start.day + index);

    const legendWidth = 36.0;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: DesignSystemCard(
        glass: true,
        liquidGlass: widget.liquidGlass,
        padding: const EdgeInsets.all(AppDesignSystem.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Daily spending',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall),
                ),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    '${DateFormat('d MMM').format(selected)} · ${currency.format(totals[selected] ?? 0)}',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ],
            ),
            const VSpace.sm(),
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                const gap = AppDesignSystem.s4;
                final monthHeight =
                    MediaQuery.textScalerOf(context).scale(11) * 1.5;
                final cell = math
                    .min(
                      (constraints.maxWidth - legendWidth - gap * 13) / 13,
                      (constraints.maxHeight - monthHeight - gap * 6) / 7,
                    )
                    .clamp(4.0, 28.0);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var week = 0; week < 13; week++) ...[
                      if (week > 0) const SizedBox(width: gap),
                      Column(
                        children: [
                          SizedBox(
                            width: cell,
                            height: monthHeight,
                            child: OverflowBox(
                              alignment: Alignment.topLeft,
                              maxWidth: 80,
                              child: Text(
                                week == 0 ||
                                        dayAt(week * 7).month !=
                                            dayAt((week - 1) * 7).month
                                    ? DateFormat.MMM().format(dayAt(week * 7))
                                    : '',
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          ),
                          for (var weekday = 0; weekday < 7; weekday++)
                            Padding(
                              padding: EdgeInsets.only(
                                  bottom: weekday < 6 ? gap : 0),
                              child: Builder(builder: (context) {
                              final day = dayAt(week * 7 + weekday);
                              if (day.isAfter(today)) {
                                return SizedBox(width: cell, height: cell);
                              }
                              final amount = totals[day] ?? 0;
                              final description =
                                  '${DateFormat.yMMMd().format(day)}: ${currency.format(amount)} spent';
                              return Semantics(
                                label: description,
                                button: true,
                                selected: day == selected,
                                child: Tooltip(
                                  message: description,
                                  child: InkWell(
                                    key: ValueKey(
                                        'expense-day-${DateFormat('yyyy-MM-dd').format(day)}'),
                                    onTap: () =>
                                        setState(() => _selectedDay = day),
                                    borderRadius: BorderRadius.circular(gap),
                                    child: Container(
                                      width: cell,
                                      height: cell,
                                      decoration: BoxDecoration(
                                        color: palette[level(amount)],
                                        borderRadius:
                                            BorderRadius.circular(gap),
                                        border: day == selected
                                            ? Border.all(
                                                color:
                                                    theme.colorScheme.onSurface,
                                                width: 2,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                              }),
                            ),
                        ],
                      ),
                    ],
                    SizedBox(
                      width: legendWidth + gap,
                      height: monthHeight + cell * 7 + gap * 6,
                      child: Padding(
                        padding: EdgeInsets.only(left: gap, top: monthHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('More',
                                    style: theme.textTheme.labelSmall),
                              ),
                            ),
                            for (final color in palette.reversed)
                              Container(
                                width: AppDesignSystem.s8,
                                height: AppDesignSystem.s8,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Less',
                                    style: theme.textTheme.labelSmall),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
