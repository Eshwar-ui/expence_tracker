import 'dart:async';
import 'dart:math' as math;

import 'package:expence_tracker/models/analytics.dart';
import 'package:expence_tracker/services/analytics_service.dart';
import 'package:expence_tracker/utils/app_design_system.dart';
import 'package:expence_tracker/widgets/design_system_components.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with TickerProviderStateMixin {
  final AnalyticsService _analytics = AnalyticsService();
  late final AnimationController _animationController;
  AnalyticsData? _data;
  bool _loading = true;
  String? _loadError;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _load();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final end = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
        23,
        59,
        59,
      );
      final data = await _analytics.getAnalyticsData(
        startDate: _selectedMonth,
        endDate: end,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _loadError = null;
      });
      _animationController.reset();
      unawaited(_animationController.forward());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Unable to load reports for this month.';
      });
    }
  }

  Future<void> _selectMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month + 1, 0),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null) return;
    setState(() => _selectedMonth = DateTime(picked.year, picked.month, 1));
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: GestureDetector(
          onTap: _selectMonth,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(DateFormat('MMMM yyyy').format(_selectedMonth)),
              const HSpace.xs(),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const DesignSystemLoading()
          : _loadError != null
              ? _buildErrorState()
              : _data == null
                  ? _buildEmptyState()
              : FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _animationController,
                    curve: Curves.easeOutCubic,
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(AppDesignSystem.s24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMonthSummary(),
                        const VSpace.xl(),
                        _overviewCard(),
                        const VSpace.xl(),
                        _quickStats(),
                        const VSpace.xl(),
                        _section(
                          'Spending Trend',
                          'Daily expense pattern across the selected month',
                          _trendChart(),
                        ),
                        const VSpace.xl(),
                        _section(
                          'Category Breakdown',
                          'Largest expense buckets and their share of spending',
                          _categorySection(),
                        ),
                        const VSpace.xl(),
                        _insightsSection(),
                        const VSpace.xl(),
                        _budgetSection(),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _overviewCard() {
    final d = _data!;
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.s24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppDesignSystem.brandPrimary.withValues(alpha: 0.95),
            AppDesignSystem.brandInfo.withValues(alpha: 0.82),
            AppDesignSystem.brandSecondary.withValues(alpha: 0.68),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDesignSystem.r24),
        boxShadow: AppDesignSystem.softShadow(AppDesignSystem.brandPrimary),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Monthly Financial Snapshot',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                )),
        const VSpace.sm(),
        Text(_money(d.balance),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                )),
        Text(d.balance >= 0 ? 'Closing balance' : 'Negative cash flow',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                )),
        const VSpace.lg(),
        Row(children: [
          Expanded(child: _miniStat('Income', _compact(d.totalIncome), Icons.arrow_downward_rounded)),
          const HSpace.md(),
          Expanded(child: _miniStat('Expenses', _compact(d.totalExpenses), Icons.arrow_upward_rounded)),
          const HSpace.md(),
          Expanded(child: _miniStat('Opening', _compact(d.openingBalance), Icons.stacked_line_chart_rounded)),
        ]),
        const VSpace.lg(),
        _progress('Savings rate', d.savingsPercentage),
        const VSpace.md(),
        _progress('Expense load', d.expensePercentage),
      ]),
    );
  }

  Widget _buildMonthSummary() {
    final data = _data!;
    final transactionCount = data.recentExpenses.length;
    final recordedDays = data.dailyBreakdown.length;
    final budgetUsage = data.budgetStatus.budgetUtilizationPercentage;

    return Row(children: [
      Expanded(
        child: _summaryPill(
          'Month',
          DateFormat('MMM yyyy').format(_selectedMonth),
          Icons.calendar_month_rounded,
          AppDesignSystem.brandPrimary,
        ),
      ),
      const HSpace.md(),
      Expanded(
        child: _summaryPill(
          'Transactions',
          '$transactionCount',
          Icons.receipt_long_rounded,
          AppDesignSystem.brandInfo,
        ),
      ),
      const HSpace.md(),
      Expanded(
        child: _summaryPill(
          'Budget',
          data.budgetStatus.totalBudget == 0
              ? 'Not set'
              : '${budgetUsage.toStringAsFixed(0)}%',
          Icons.pie_chart_rounded,
          AppDesignSystem.brandAccent,
          subtitle: '$recordedDays active days',
        ),
      ),
    ]);
  }

  Widget _summaryPill(
    String label,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return DesignSystemCard(
      glass: true,
      padding: const EdgeInsets.all(AppDesignSystem.s16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppDesignSystem.r12),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const VSpace.sm(),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const VSpace.xs(),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        if (subtitle != null) ...[
          const VSpace.xs(),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ]),
    );
  }

  Widget _miniStat(String label, String value, IconData icon) => Container(
        padding: const EdgeInsets.all(AppDesignSystem.s16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDesignSystem.r16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.92), size: 18),
          const VSpace.sm(),
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  )),
          const VSpace.xs(),
          Text(value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  )),
        ]),
      );

  Widget _progress(String label, double value) {
    final safe = value.clamp(0, 100);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                )),
        const Spacer(),
        Text('${safe.toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                )),
      ]),
      const VSpace.xs(),
      ClipRRect(
        borderRadius: BorderRadius.circular(AppDesignSystem.rFull),
        child: LinearProgressIndicator(
          value: safe / 100,
          minHeight: 8,
          backgroundColor: Colors.white.withValues(alpha: 0.16),
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    ]);
  }

  Widget _quickStats() {
    final d = _data!;
    final top = _sortedCategories.isNotEmpty ? _sortedCategories.first : null;
    final avg = d.dailyBreakdown.isEmpty ? 0.0 : d.totalExpenses / math.max(d.dailyBreakdown.length, 1);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Quick Stats', style: Theme.of(context).textTheme.titleLarge),
      const VSpace.md(),
      Row(children: [
        Expanded(child: _metricCard('Avg per day', _compact(avg), '${d.dailyBreakdown.length} active days', AppDesignSystem.brandAccent, Icons.calendar_view_week_rounded)),
        const HSpace.md(),
        Expanded(child: _metricCard('Transactions', '${d.recentExpenses.length}', 'Entries this month', AppDesignSystem.brandInfo, Icons.receipt_long_rounded)),
      ]),
      const VSpace.md(),
      _metricCard(
        'Top category',
        top?.key ?? 'No expense data',
        top == null ? 'Start logging expenses to see ranking' : '${_compact(top.value)} spent',
        AppDesignSystem.brandSecondary,
        Icons.pie_chart_outline_rounded,
      ),
    ]);
  }

  Widget _metricCard(String title, String value, String subtitle, Color color, IconData icon) {
    return DesignSystemCard(
      glass: true,
      padding: const EdgeInsets.all(AppDesignSystem.s20),
      child: Row(children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppDesignSystem.r16),
          ),
          child: Icon(icon, color: color),
        ),
        const HSpace.md(),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const VSpace.xs(),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const VSpace.xs(),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ]),
    );
  }

  Widget _section(String title, String subtitle, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const VSpace.xs(),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const VSpace.md(),
          DesignSystemCard(glass: true, padding: const EdgeInsets.all(AppDesignSystem.s20), child: child),
        ],
      );

  Widget _trendChart() {
    final sorted = _data!.dailyBreakdown.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final spots = List.generate(sorted.length, (i) => FlSpot(i.toDouble(), sorted[i].value));
    if (spots.isEmpty) {
      return const SizedBox(height: 220, child: Center(child: Text('No expense activity in this month')));
    }
    final peak = sorted.reduce((a, b) => a.value > b.value ? a : b);
    var maxVal = spots.map((s) => s.y).reduce(math.max);
    if (maxVal < 1000) maxVal = 1000;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _pill('Peak day', '${DateFormat('MMM d').format(DateTime.parse(peak.key))} | ${_compact(peak.value)}')),
        const HSpace.sm(),
        Expanded(child: _pill('Recorded days', '${sorted.length}')),
      ]),
      const VSpace.lg(),
      SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxVal * 1.18,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxVal / 4,
              getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withValues(alpha: 0.06), dashArray: const [5, 5]),
            ),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: (spots.length / 5).clamp(1, 31).toDouble(),
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= sorted.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(DateFormat('d').format(DateTime.parse(sorted[i].key)), style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.64))),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 48,
                  interval: maxVal / 4,
                  getTitlesWidget: (value, meta) => value == 0 ? const SizedBox.shrink() : Text(_axis(value), style: TextStyle(fontSize: 9, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.56))),
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                getTooltipItems: (spots) => spots.map((spot) {
                  final date = DateTime.parse(sorted[spot.x.toInt()].key);
                  return LineTooltipItem(
                    '${DateFormat('MMM d').format(date)}\n',
                    TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontWeight: FontWeight.w700),
                    children: [TextSpan(text: _money(spot.y), style: const TextStyle(color: AppDesignSystem.brandPrimary, fontWeight: FontWeight.w900))],
                  );
                }).toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                barWidth: 4,
                gradient: const LinearGradient(colors: [AppDesignSystem.brandPrimary, AppDesignSystem.brandAccent]),
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 3.2, color: Colors.white, strokeWidth: 2, strokeColor: AppDesignSystem.brandPrimary),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(colors: [AppDesignSystem.brandPrimary.withValues(alpha: 0.22), AppDesignSystem.brandPrimary.withValues(alpha: 0)]),
                ),
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _pill(String label, String value) => Container(
        padding: const EdgeInsets.all(AppDesignSystem.s12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppDesignSystem.r16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const VSpace.xs(),
          Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _categorySection() {
    final entries = _sortedCategories.take(5).toList();
    if (entries.isEmpty) {
      return const SizedBox(height: 220, child: Center(child: Text('No categorized expenses found')));
    }
    return Column(children: [
      SizedBox(
        height: 220,
        child: PieChart(
          PieChartData(
            sectionsSpace: 3,
            centerSpaceRadius: 54,
            sections: List.generate(entries.length, (i) {
              final share = _data!.totalExpenses == 0 ? 0.0 : (entries[i].value / _data!.totalExpenses) * 100;
              return PieChartSectionData(
                value: entries[i].value,
                title: '${share.toStringAsFixed(0)}%',
                radius: 62,
                color: _categoryColor(i),
                titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              );
            }),
          ),
        ),
      ),
      const VSpace.lg(),
      ...List.generate(entries.length, (i) {
        final share = _data!.totalExpenses == 0 ? 0.0 : (entries[i].value / _data!.totalExpenses) * 100;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDesignSystem.s12),
          child: Row(children: [
            Container(height: 12, width: 12, decoration: BoxDecoration(color: _categoryColor(i), borderRadius: BorderRadius.circular(99))),
            const HSpace.md(),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(entries[i].key, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const VSpace.xs(),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDesignSystem.rFull),
                  child: LinearProgressIndicator(
                    value: (share / 100).clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(_categoryColor(i)),
                  ),
                ),
              ]),
            ),
            const HSpace.md(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_compact(entries[i].value), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text('${share.toStringAsFixed(0)}%', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ]),
        );
      }),
    ]);
  }

  Widget _insightsSection() {
    final insights = _data!.insights;
    if (insights.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Financial Insights', style: Theme.of(context).textTheme.titleLarge),
      const VSpace.md(),
      ...insights.map((insight) => Padding(
            padding: const EdgeInsets.only(bottom: AppDesignSystem.s12),
            child: DesignSystemCard(
              padding: const EdgeInsets.all(AppDesignSystem.s16),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(AppDesignSystem.s12),
                  decoration: BoxDecoration(
                    color: _insightColor(insight.type).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDesignSystem.r12),
                  ),
                  child: Icon(_insightIcon(insight.type), color: _insightColor(insight.type), size: 20),
                ),
                const HSpace.md(),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(insight.title, style: Theme.of(context).textTheme.titleSmall),
                    Text(insight.description, style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
              ]),
            ),
          )),
    ]);
  }

  Widget _budgetSection() {
    final budgets = _data!.budgetStatus.categories.values.toList()
      ..sort((a, b) => b.utilizationPercentage.compareTo(a.utilizationPercentage));
    if (budgets.isEmpty) return const SizedBox.shrink();
    final totalBudget = _data!.budgetStatus.totalBudget;
    final totalSpent = _data!.budgetStatus.totalSpent;
    final totalUsage = totalBudget == 0 ? 0.0 : (totalSpent / totalBudget) * 100;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Budget Insights', style: Theme.of(context).textTheme.titleLarge),
      const VSpace.md(),
      DesignSystemCard(
        glass: true,
        padding: const EdgeInsets.all(AppDesignSystem.s20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Overall budget utilization', style: Theme.of(context).textTheme.titleMedium)),
            Text('${totalUsage.toStringAsFixed(0)}%', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ]),
          const VSpace.sm(),
          Text('${_compact(totalSpent)} spent of ${_compact(totalBudget)}', style: Theme.of(context).textTheme.bodyMedium),
          const VSpace.md(),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDesignSystem.rFull),
            child: LinearProgressIndicator(
              value: (totalUsage / 100).clamp(0, 1),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(totalUsage > 100 ? AppDesignSystem.error : AppDesignSystem.brandSecondary),
            ),
          ),
          const VSpace.lg(),
          ...budgets.map((c) {
            final hasBudget = c.budget > 0;
            final color = c.isOverBudget ? AppDesignSystem.error : AppDesignSystem.brandSecondary;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDesignSystem.s12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(c.category, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                  Text('${c.utilizationPercentage.toStringAsFixed(0)}%', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w800)),
                ]),
                const VSpace.xs(),
                Text('${_compact(c.spent)} / ${_compact(c.budget)}', style: Theme.of(context).textTheme.bodySmall),
                const VSpace.xs(),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDesignSystem.rFull),
                  child: LinearProgressIndicator(
                    value: hasBudget ? (c.spent / c.budget).clamp(0, 1) : 0,
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ]),
            );
          }),
        ]),
      ),
    ]);
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(AppDesignSystem.s24),
      child: DesignSystemEmptyState(
        icon: Icons.analytics_rounded,
        title: 'Reports unavailable',
        message: _loadError,
        action: TextButton(
          onPressed: _load,
          child: const Text('Retry'),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(AppDesignSystem.s24),
      child: DesignSystemEmptyState(
        icon: Icons.analytics_rounded,
        title: 'No insights yet',
        message: 'Add transactions to see your financial patterns.',
      ),
    );
  }

  List<MapEntry<String, double>> get _sortedCategories {
    final entries = _data!.categoryBreakdown.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  Color _categoryColor(int index) {
    const colors = [
      AppDesignSystem.brandPrimary,
      AppDesignSystem.brandSecondary,
      AppDesignSystem.brandAccent,
      AppDesignSystem.brandInfo,
      Color(0xFFF97316),
      Color(0xFFEC4899),
    ];
    return colors[index % colors.length];
  }

  Color _insightColor(InsightType type) {
    switch (type) {
      case InsightType.warning:
        return AppDesignSystem.error;
      case InsightType.success:
        return AppDesignSystem.success;
      case InsightType.info:
        return AppDesignSystem.brandInfo;
      case InsightType.tip:
        return AppDesignSystem.brandAccent;
    }
  }

  IconData _insightIcon(InsightType type) {
    switch (type) {
      case InsightType.warning:
        return Icons.warning_amber_rounded;
      case InsightType.success:
        return Icons.check_circle_outline_rounded;
      case InsightType.info:
        return Icons.info_outline_rounded;
      case InsightType.tip:
        return Icons.lightbulb_outline_rounded;
    }
  }

  String _money(double value) => '${_rs()}${value.toStringAsFixed(0)}';
  String _compact(double value) {
    if (value.abs() >= 100000) return '${_rs()}${(value / 100000).toStringAsFixed(1)}L';
    if (value.abs() >= 1000) return '${_rs()}${(value / 1000).toStringAsFixed(1)}K';
    return '${_rs()}${value.toStringAsFixed(0)}';
  }

  String _axis(double value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  String _rs() => '\u20B9';
}
