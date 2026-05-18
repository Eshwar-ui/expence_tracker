import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/expence.dart';
import '../services/export_service.dart';
import '../services/firestore_service.dart';
import '../utils/app_design_system.dart';
import '../widgets/design_system_components.dart';

enum _RangePreset { thisMonth, lastMonth, thisYear, allTime, custom }

class ExportSheet extends StatefulWidget {
  const ExportSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ExportSheet(),
    );
  }

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  _RangePreset _preset = _RangePreset.thisMonth;
  DateTime? _customStart;
  DateTime? _customEnd;
  bool _busy = false;

  static final _displayFmt = DateFormat('dd MMM yyyy');

  ({DateTime? start, DateTime? end, String label}) _resolveRange() {
    final now = DateTime.now();
    switch (_preset) {
      case _RangePreset.thisMonth:
        return (
          start: DateTime(now.year, now.month, 1),
          end: now,
          label: DateFormat('MMMM yyyy').format(now),
        );
      case _RangePreset.lastMonth:
        final firstOfThis = DateTime(now.year, now.month, 1);
        final endOfLast = firstOfThis.subtract(const Duration(seconds: 1));
        final firstOfLast = DateTime(endOfLast.year, endOfLast.month, 1);
        return (
          start: firstOfLast,
          end: endOfLast,
          label: DateFormat('MMMM yyyy').format(firstOfLast),
        );
      case _RangePreset.thisYear:
        return (
          start: DateTime(now.year, 1, 1),
          end: now,
          label: '${now.year}',
        );
      case _RangePreset.allTime:
        return (start: null, end: null, label: 'All Time');
      case _RangePreset.custom:
        if (_customStart != null && _customEnd != null) {
          return (
            start: _customStart,
            end: _customEnd,
            label:
                '${_displayFmt.format(_customStart!)} – ${_displayFmt.format(_customEnd!)}',
          );
        }
        return (start: null, end: null, label: 'Custom');
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : DateTimeRange(
              start: DateTime(now.year, now.month, 1),
              end: now,
            ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: AppDesignSystem.brandPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _preset = _RangePreset.custom;
        _customStart = picked.start;
        _customEnd = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
      });
    }
  }

  Future<void> _export(ExportFormat format) async {
    if (_busy) return;
    final range = _resolveRange();

    if (_preset == _RangePreset.custom &&
        (_customStart == null || _customEnd == null)) {
      showDesignSystemSnackBar(
        context: context,
        message: 'Pick a custom date range first',
        isError: true,
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final firestore = FirestoreService();
      final List<Expense> expenses;
      if (range.start == null || range.end == null) {
        expenses = await firestore.getExpenses(limit: null);
      } else {
        expenses = await firestore.getExpensesByDateRange(
          range.start!,
          range.end!,
        );
      }

      if (!mounted) return;
      if (expenses.isEmpty) {
        showDesignSystemSnackBar(
          context: context,
          message: 'No transactions in that range',
          isError: true,
        );
        return;
      }

      await ExportService.instance.exportAndShare(
        expenses: expenses,
        format: format,
        label: range.label,
      );

      if (!mounted) return;
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e, stack) {
      debugPrint('Export failed: $e\n$stack');
      if (!mounted) return;
      final msg = e.toString();
      showDesignSystemSnackBar(
        context: context,
        message: msg.length > 120 ? "Couldn't export: ${msg.substring(0, 120)}…" : "Couldn't export: $msg",
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final range = _resolveRange();

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppDesignSystem.darkCanvas
            : AppDesignSystem.lightCanvas,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDesignSystem.r24),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppDesignSystem.s20,
        right: AppDesignSystem.s20,
        top: AppDesignSystem.s12,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDesignSystem.s24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.12),
                borderRadius:
                    BorderRadius.circular(AppDesignSystem.rFull),
              ),
            ),
          ),
          const VSpace.lg(),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppDesignSystem.brandPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDesignSystem.r12),
                ),
                child: const Icon(
                  Icons.file_download_outlined,
                  color: AppDesignSystem.brandPrimary,
                  size: 22,
                ),
              ),
              const HSpace.md(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export Transactions',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Share a CSV or PDF for your records',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const VSpace.lg(),

          Text(
            'PERIOD',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 10,
            ),
          ),
          const VSpace.sm(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PresetChip(
                label: 'This Month',
                selected: _preset == _RangePreset.thisMonth,
                onTap: () => setState(() => _preset = _RangePreset.thisMonth),
              ),
              _PresetChip(
                label: 'Last Month',
                selected: _preset == _RangePreset.lastMonth,
                onTap: () => setState(() => _preset = _RangePreset.lastMonth),
              ),
              _PresetChip(
                label: 'This Year',
                selected: _preset == _RangePreset.thisYear,
                onTap: () => setState(() => _preset = _RangePreset.thisYear),
              ),
              _PresetChip(
                label: 'All Time',
                selected: _preset == _RangePreset.allTime,
                onTap: () => setState(() => _preset = _RangePreset.allTime),
              ),
              _PresetChip(
                label: 'Custom',
                icon: Icons.date_range_rounded,
                selected: _preset == _RangePreset.custom,
                onTap: _pickCustomRange,
              ),
            ],
          ),
          const VSpace.md(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppDesignSystem.brandPrimary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppDesignSystem.r12),
              border: Border.all(
                color: AppDesignSystem.brandPrimary.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_note_rounded,
                  size: 16,
                  color: AppDesignSystem.brandPrimary,
                ),
                const HSpace.sm(),
                Expanded(
                  child: Text(
                    range.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const VSpace.lg(),
          Text(
            'FORMAT',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 10,
            ),
          ),
          const VSpace.sm(),
          Row(
            children: [
              Expanded(
                child: _FormatButton(
                  icon: Icons.table_chart_rounded,
                  label: 'CSV',
                  subtitle: 'Spreadsheet',
                  busy: _busy,
                  onTap: () => _export(ExportFormat.csv),
                ),
              ),
              const HSpace.md(),
              Expanded(
                child: _FormatButton(
                  icon: Icons.picture_as_pdf_rounded,
                  label: 'PDF',
                  subtitle: 'Printable report',
                  busy: _busy,
                  onTap: () => _export(ExportFormat.pdf),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tint = AppDesignSystem.brandPrimary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? tint.withValues(alpha: 0.12)
              : isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(AppDesignSystem.rFull),
          border: Border.all(
            color: selected
                ? tint.withValues(alpha: 0.45)
                : isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected
                    ? tint
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected
                    ? tint
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool busy;
  final VoidCallback onTap;

  const _FormatButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(AppDesignSystem.r16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(AppDesignSystem.r16),
            border: Border.all(
              color: AppDesignSystem.brandPrimary.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppDesignSystem.primaryGradient,
                  borderRadius:
                      BorderRadius.circular(AppDesignSystem.r12),
                ),
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(icon, color: Colors.white, size: 18),
              ),
              const HSpace.md(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.55),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
