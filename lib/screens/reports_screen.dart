import 'package:flutter/material.dart';
import 'package:expence_tracker/services/analytics_service.dart';
import 'package:expence_tracker/models/analytics.dart';
import 'package:expence_tracker/utils/app_design_system.dart';
import 'package:expence_tracker/widgets/design_system_components.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with TickerProviderStateMixin {
  final AnalyticsService _analytics = AnalyticsService();
  bool _loading = true;
  AnalyticsData? _data;
  late AnimationController _animationController;
  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
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
    setState(() => _loading = true);
    try {
      final start = _selectedMonth;
      final end = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
        23,
        59,
        59,
      );

      final data = await _analytics.getAnalyticsData(
        startDate: start,
        endDate: end,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
      _animationController.reset();
      _animationController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
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

    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
      _load();
    }
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
          : _data == null
              ? const DesignSystemEmptyState(
                  icon: Icons.analytics_rounded,
                  title: 'No Insights',
                  message: 'Add transactions to see your financial patterns.',
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(AppDesignSystem.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummarySection(),
          const VSpace.xl(),
          _buildChartSection('Spending Trend', _buildTrendChart()),
          const VSpace.xl(),
          _buildChartSection('Category Breakdown', _buildCategoryChart()),
          const VSpace.xl(),
          _buildInsightsSection(),
          const VSpace.xl(),
          _buildBudgetInsight(),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    final d = _data!;
    return Row(
      children: [
        _buildMiniStat(
          'Income',
          '₹${d.totalIncome.toStringAsFixed(0)}',
          AppDesignSystem.success,
        ),
        const HSpace.md(),
        _buildMiniStat(
          'Expense',
          '₹${d.totalExpenses.toStringAsFixed(0)}',
          AppDesignSystem.error,
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Expanded(
      child: DesignSystemCard(
        padding: const EdgeInsets.all(AppDesignSystem.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: color, fontSize: 22),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(String title, Widget chart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const VSpace.md(),
        DesignSystemCard(
          padding: const EdgeInsets.all(AppDesignSystem.s20),
          child: SizedBox(height: 220, child: chart),
        ),
      ],
    );
  }

  Widget _buildTrendChart() {
    final theme = Theme.of(context);
    final sortedEntries = _data!.dailyBreakdown.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final spots = List.generate(sortedEntries.length, (i) {
      return FlSpot(i.toDouble(), sortedEntries[i].value);
    });

    if (spots.isEmpty) return const Center(child: Text('Insufficient data'));

    double maxVal = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (maxVal < 1000) maxVal = 1000;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxVal * 1.2,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => theme.colorScheme.surface.withOpacity(0.9),
            tooltipRoundedRadius: 8,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final dateStr = sortedEntries[spot.x.toInt()].key;
                final date = DateTime.parse(dateStr);
                return LineTooltipItem(
                  '${DateFormat('MMM d').format(date)}\n',
                  TextStyle(
                    color: theme.textTheme.bodyMedium?.color ??
                        AppDesignSystem.textMed,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: '₹${spot.y.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: AppDesignSystem.brandPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxVal / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withOpacity(0.05),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
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
                final index = value.toInt();
                if (index < 0 || index >= sortedEntries.length)
                  return const SizedBox.shrink();
                final dateStr = sortedEntries[index].key;
                final date = DateTime.parse(dateStr);
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat('d').format(date),
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: maxVal / 4,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                String text = '';
                if (value >= 1000) {
                  text = '${(value / 1000).toStringAsFixed(1)}k';
                } else {
                  text = value.toStringAsFixed(0);
                }
                return Text(
                  text,
                  style: TextStyle(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.left,
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                AppDesignSystem.brandPrimary,
                AppDesignSystem.brandAccent,
              ],
            ),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 3,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: AppDesignSystem.brandPrimary,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppDesignSystem.brandPrimary.withOpacity(0.2),
                  AppDesignSystem.brandPrimary.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection() {
    final insights = _data!.insights;
    if (insights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Financial Insights',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const VSpace.md(),
        ...insights.map(
          (insight) => Padding(
            padding: const EdgeInsets.only(bottom: AppDesignSystem.s12),
            child: DesignSystemCard(
              padding: const EdgeInsets.all(AppDesignSystem.s16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppDesignSystem.s12),
                    decoration: BoxDecoration(
                      color: _getInsightColor(insight.type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppDesignSystem.r12),
                    ),
                    child: Icon(
                      _getInsightIcon(insight.type),
                      color: _getInsightColor(insight.type),
                      size: 20,
                    ),
                  ),
                  const HSpace.md(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          insight.description,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getInsightColor(InsightType type) {
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

  IconData _getInsightIcon(InsightType type) {
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

  Widget _buildCategoryChart() {
    final entries = _data!.categoryBreakdown.entries.toList();
    if (entries.isEmpty) return const Center(child: Text('No data'));

    return PieChart(
      PieChartData(
        sectionsSpace: 4,
        centerSpaceRadius: 40,
        sections: entries.map((e) {
          final color =
              Colors.primaries[entries.indexOf(e) % Colors.primaries.length];
          return PieChartSectionData(
            value: e.value,
            title: '',
            color: color,
            radius: 50,
            badgeWidget: _buildChartBadge(e.key, color),
            badgePositionPercentageOffset: 1.3,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChartBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBudgetInsight() {
    final d = _data!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Budget Insights', style: Theme.of(context).textTheme.titleLarge),
        const VSpace.md(),
        ...d.budgetStatus.categories.values.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: AppDesignSystem.s12),
            child: DesignSystemCard(
              padding: const EdgeInsets.all(AppDesignSystem.s16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.category,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const VSpace.sm(),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (c.spent / c.budget).clamp(0, 1),
                            color: c.isOverBudget
                                ? AppDesignSystem.error
                                : AppDesignSystem.brandSecondary,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const HSpace.md(),
                  Text(
                    '${c.utilizationPercentage.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
