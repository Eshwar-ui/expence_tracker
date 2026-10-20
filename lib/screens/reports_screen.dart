import 'dart:async';
import 'dart:math' as math;

import 'package:expence_tracker/models/analytics.dart';
import 'package:expence_tracker/services/analytics_service.dart';
import 'package:expence_tracker/utils/app_design_system.dart';
import 'package:expence_tracker/widgets/design_system_components.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/sky_background.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.loadAnalytics});

  final Future<AnalyticsData> Function(DateTime start, DateTime end)?
      loadAnalytics;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  AnalyticsData? _data;
  bool _loading = true;
  String? _loadError;
  DateTime _selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);

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
      final data = widget.loadAnalytics != null
          ? await widget.loadAnalytics!(_selectedMonth, end)
          : await AnalyticsService().getAnalyticsData(
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
    if (picked == null || !mounted) return;
    setState(() => _selectedMonth = DateTime(picked.year, picked.month, 1));
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PremiumAppBar(
        title: 'Reports',
        showBackButton: false,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh reports',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: SkyBackground()),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.all(AppDesignSystem.s24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _monthSelector(),
                    const VSpace.lg(),
                    if (_loading)
                      const DesignSystemCard(
                        liquidGlass: true,
                        child:
                            SizedBox(height: 240, child: DesignSystemLoading()),
                      )
                    else if (_loadError != null)
                      DesignSystemCard(
                          liquidGlass: true, child: _buildErrorState())
                    else if (_data == null)
                      DesignSystemCard(
                          liquidGlass: true, child: _buildEmptyState())
                    else
                      FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _animationController,
                          curve: Curves.easeOutCubic,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _overviewCard(),
                            const VSpace.md(),
                            _buildMonthSummary(),
                            const VSpace.xl(),
                            _quickStats(),
                            const VSpace.xl(),
                            _section(
                              'Spending trend',
                              'Daily expenses for this month',
                              _trendChart(),
                            ),
                            const VSpace.xl(),
                            _section(
                              'Where your money goes',
                              'Your spending, grouped by category',
                              _categorySection(),
                            ),
                            const VSpace.xl(),
                            _insightsSection(),
                            const VSpace.xl(),
                            _budgetSection(),
                          ],
                        ),
                      ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthSelector() {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: _selectMonth,
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.s8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              DateFormat('MMMM yyyy').format(_selectedMonth),
              semanticsLabel:
                  'Reporting month, ${DateFormat('MMMM yyyy').format(_selectedMonth)}. Select month',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
          const HSpace.sm(),
          const Icon(Icons.expand_more_rounded, size: 20),
        ],
      ),
    );
  }

  Widget _overviewCard() {
    final d = _data!;
    final theme = Theme.of(context);
    return DesignSystemCard(
      liquidGlass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text('Monthly balance',
                    style: theme.textTheme.titleMedium)),
            Icon(Icons.account_balance_wallet_outlined,
                color: theme.colorScheme.onSurface, size: AppDesignSystem.s24),
          ]),
          const VSpace.md(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(_money(d.balance),
                style: theme.textTheme.displayMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const VSpace.xs(),
          Text(d.balance >= 0 ? 'Closing balance' : 'Negative cash flow',
              style: theme.textTheme.bodyMedium),
          const VSpace.lg(),
          Row(children: [
            Expanded(
                child: _miniStat('Income', _compact(d.totalIncome),
                    Icons.south_west_rounded)),
            const HSpace.sm(),
            Expanded(
                child: _miniStat('Expenses', _compact(d.totalExpenses),
                    Icons.north_east_rounded)),
            const HSpace.sm(),
            Expanded(
                child: _miniStat('Opening', _compact(d.openingBalance),
                    Icons.stacked_line_chart_rounded)),
          ]),
          const VSpace.lg(),
          _progress('Savings rate', d.savingsPercentage),
          const VSpace.md(),
          _progress('Expense load', d.expensePercentage),
        ],
      ),
    );
  }

  Widget _buildMonthSummary() {
    final data = _data!;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
              child: _summaryPill('Entries', '${data.recentExpenses.length}',
                  Icons.receipt_long_outlined, AppDesignSystem.brandInfo)),
          const HSpace.sm(),
          Expanded(
              child: _summaryPill(
                  'Active days',
                  '${data.dailyBreakdown.length}',
                  Icons.calendar_today_outlined,
                  AppDesignSystem.brandPrimary)),
          const HSpace.sm(),
          Expanded(
              child: _summaryPill(
                  'Budget',
                  data.budgetStatus.totalBudget == 0
                      ? 'Not set'
                      : '${data.budgetStatus.budgetUtilizationPercentage.toStringAsFixed(0)}%',
                  Icons.donut_large_rounded,
                  AppDesignSystem.brandSecondary)),
        ],
      ),
    );
  }

  Widget _summaryPill(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return DesignSystemCard(
      liquidGlass: true,
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ]),
    );
  }

  Widget _miniStat(String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: theme.colorScheme.onSurface, size: AppDesignSystem.s20),
      const VSpace.sm(),
      Text(label, style: theme.textTheme.bodySmall),
      const VSpace.xs(),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      ),
    ]);
  }

  Widget _progress(String label, double value) {
    final theme = Theme.of(context);
    final safe = value.clamp(0, 100);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        const HSpace.sm(),
        Text('${safe.toStringAsFixed(0)}%', style: theme.textTheme.labelLarge),
      ]),
      const VSpace.sm(),
      ClipRRect(
        borderRadius: BorderRadius.circular(AppDesignSystem.rFull),
        child: LinearProgressIndicator(
          value: safe / 100,
          minHeight: AppDesignSystem.s8,
          backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          valueColor: AlwaysStoppedAnimation<Color>(label == 'Savings rate'
              ? AppDesignSystem.brandSecondary
              : AppDesignSystem.brandPrimary),
        ),
      ),
    ]);
  }

  Widget _quickStats() {
    final d = _data!;
    final top = _sortedCategories.isNotEmpty ? _sortedCategories.first : null;
    final avg = d.dailyBreakdown.isEmpty
        ? 0.0
        : d.totalExpenses / math.max(d.dailyBreakdown.length, 1);
    final average = _metricCard(
        'Avg per active day',
        _compact(avg),
        '${d.dailyBreakdown.length} days with expenses',
        AppDesignSystem.brandAccent,
        Icons.calendar_view_week_rounded);
    final category = _metricCard(
        'Top category',
        top?.key ?? 'No expenses yet',
        top == null
            ? 'Add expenses to see your top category'
            : '${_compact(top.value)} spent',
        AppDesignSystem.brandSecondary,
        Icons.pie_chart_outline_rounded);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('At a glance', style: Theme.of(context).textTheme.titleLarge),
      const VSpace.md(),
      LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.2) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                average,
                const VSpace.md(),
                category,
              ]);
        }
        return IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: average),
          const HSpace.md(),
          Expanded(child: category),
        ]));
      }),
    ]);
  }

  Widget _metricCard(
      String title, String value, String subtitle, Color color, IconData icon) {
    return DesignSystemCard(
      liquidGlass: true,
      padding: const EdgeInsets.all(AppDesignSystem.s20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon,
              color: Theme.of(context).colorScheme.onSurface,
              size: AppDesignSystem.s20),
          const HSpace.sm(),
          Expanded(
              child: Text(title, style: Theme.of(context).textTheme.bodySmall)),
        ]),
        const VSpace.md(),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        const VSpace.xs(),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
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
          DesignSystemCard(
              liquidGlass: true,
              padding: const EdgeInsets.all(AppDesignSystem.s20),
              child: child),
        ],
      );

  Widget _trendChart() {
    final sorted = _data!.dailyBreakdown.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final spots = List.generate(
        sorted.length, (i) => FlSpot(i.toDouble(), sorted[i].value));
    if (spots.isEmpty) {
      return const SizedBox(
          height: 220,
          child: Center(child: Text('No expense activity in this month')));
    }
    final peak = sorted.reduce((a, b) => a.value > b.value ? a : b);
    var maxVal = spots.map((s) => s.y).reduce(math.max);
    if (maxVal < 1000) maxVal = 1000;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: _pill('Peak day',
                '${DateFormat('MMM d').format(DateTime.parse(peak.key))} | ${_compact(peak.value)}')),
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
              getDrawingHorizontalLine: (_) => FlLine(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.12),
                  dashArray: const [5, 5]),
            ),
            titlesData: FlTitlesData(
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: (spots.length / 5).clamp(1, 31).toDouble(),
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= sorted.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                          DateFormat('d').format(DateTime.parse(sorted[i].key)),
                          style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color)),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 48,
                  interval: maxVal / 4,
                  getTitlesWidget: (value, meta) => value == 0
                      ? const SizedBox.shrink()
                      : Text(_axis(value),
                          style: TextStyle(
                              fontSize: 9,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color)),
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.95),
                getTooltipItems: (spots) => spots.map((spot) {
                  final date = DateTime.parse(sorted[spot.x.toInt()].key);
                  return LineTooltipItem(
                    '${DateFormat('MMM d').format(date)}\n',
                    TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontWeight: FontWeight.w700),
                    children: [
                      TextSpan(
                          text: _money(spot.y),
                          style: const TextStyle(
                              color: AppDesignSystem.brandPrimary,
                              fontWeight: FontWeight.w900))
                    ],
                  );
                }).toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                preventCurveOverShooting: true,
                barWidth: 4,
                gradient: const LinearGradient(colors: [
                  AppDesignSystem.brandPrimary,
                  AppDesignSystem.brandInfo
                ]),
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 3.2,
                      color: Colors.white,
                      strokeWidth: 2,
                      strokeColor: AppDesignSystem.brandPrimary),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(colors: [
                    AppDesignSystem.brandPrimary.withValues(alpha: 0.22),
                    AppDesignSystem.brandPrimary.withValues(alpha: 0)
                  ]),
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
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppDesignSystem.r16),
          border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.12)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const VSpace.xs(),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _categorySection() {
    final entries = _sortedCategories;

    if (entries.isEmpty) {
      return const SizedBox(
          height: 220,
          child: Center(child: Text('No categorized expenses found')));
    }
    return Column(children: [
      LayoutBuilder(builder: (context, constraints) {
        final diameter = math.min(constraints.maxWidth, 240.0);
        return SizedBox(
          height: diameter,
          child: Stack(alignment: Alignment.center, children: [
            PieChart(PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: diameter * 0.23,
              sections: List.generate(
                  entries.length,
                  (i) => PieChartSectionData(
                        value: entries[i].value,
                        showTitle: false,
                        radius: diameter * 0.23,
                        color: _categoryColor(i),
                      )),
            )),
            SizedBox(
              width: diameter * 0.40,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Expenses', style: Theme.of(context).textTheme.bodySmall),
                const VSpace.xs(),
                FittedBox(
                    child: Text(_compact(_data!.totalExpenses),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800))),
              ]),
            ),
          ]),
        );
      }),
      const VSpace.lg(),
      ...List.generate(entries.length, (i) {
        final share = _data!.totalExpenses == 0
            ? 0.0
            : (entries[i].value / _data!.totalExpenses) * 100;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDesignSystem.s12),
          child: Row(children: [
            Container(
                height: 12,
                width: 12,
                decoration: BoxDecoration(
                    color: _categoryColor(i),
                    borderRadius: BorderRadius.circular(99))),
            const HSpace.md(),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entries[i].key,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const VSpace.xs(),
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppDesignSystem.rFull),
                      child: LinearProgressIndicator(
                        value: (share / 100).clamp(0, 1),
                        minHeight: 6,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.08),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_categoryColor(i)),
                      ),
                    ),
                  ]),
            ),
            const HSpace.md(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_compact(entries[i].value),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text('${share.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall),
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
              liquidGlass: true,
              padding: const EdgeInsets.all(AppDesignSystem.s16),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(AppDesignSystem.s12),
                  decoration: BoxDecoration(
                    color: _insightColor(insight.type).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDesignSystem.r12),
                  ),
                  child: Icon(_insightIcon(insight.type),
                      color: _insightColor(insight.type), size: 20),
                ),
                const HSpace.md(),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(insight.title,
                            style: Theme.of(context).textTheme.titleSmall),
                        Text(insight.description,
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                ),
              ]),
            ),
          )),
    ]);
  }

  Widget _budgetSection() {
    final budgets = _data!.budgetStatus.categories.values.toList()
      ..sort(
          (a, b) => b.utilizationPercentage.compareTo(a.utilizationPercentage));
    if (budgets.isEmpty) return const SizedBox.shrink();
    final totalBudget = _data!.budgetStatus.totalBudget;
    final totalSpent = _data!.budgetStatus.totalSpent;
    final totalUsage =
        totalBudget == 0 ? 0.0 : (totalSpent / totalBudget) * 100;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Budget Insights', style: Theme.of(context).textTheme.titleLarge),
      const VSpace.md(),
      DesignSystemCard(
        liquidGlass: true,
        padding: const EdgeInsets.all(AppDesignSystem.s20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('Overall budget utilization',
                    style: Theme.of(context).textTheme.titleMedium)),
            Text('${totalUsage.toStringAsFixed(0)}%',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ]),
          const VSpace.sm(),
          Text('${_compact(totalSpent)} spent of ${_compact(totalBudget)}',
              style: Theme.of(context).textTheme.bodyMedium),
          const VSpace.md(),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDesignSystem.rFull),
            child: LinearProgressIndicator(
              value: (totalUsage / 100).clamp(0, 1),
              minHeight: 8,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(totalUsage > 100
                  ? AppDesignSystem.error
                  : AppDesignSystem.brandSecondary),
            ),
          ),
          const VSpace.lg(),
          ...budgets.map((c) {
            final hasBudget = c.budget > 0;
            final color = c.isOverBudget
                ? AppDesignSystem.error
                : AppDesignSystem.brandSecondary;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDesignSystem.s12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(c.category,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700))),
                      Text('${c.utilizationPercentage.toStringAsFixed(0)}%',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                  color: color, fontWeight: FontWeight.w800)),
                    ]),
                    const VSpace.xs(),
                    Text('${_compact(c.spent)} / ${_compact(c.budget)}',
                        style: Theme.of(context).textTheme.bodySmall),
                    const VSpace.xs(),
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppDesignSystem.rFull),
                      child: LinearProgressIndicator(
                        value: hasBudget ? (c.spent / c.budget).clamp(0, 1) : 0,
                        minHeight: 7,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.08),
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
    if (value.abs() >= 100000) {
      return '${_rs()}${(value / 100000).toStringAsFixed(1)}L';
    }
    if (value.abs() >= 1000) {
      return '${_rs()}${(value / 1000).toStringAsFixed(1)}K';
    }
    return '${_rs()}${value.toStringAsFixed(0)}';
  }

  String _axis(double value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  String _rs() => '\u20B9';
}
