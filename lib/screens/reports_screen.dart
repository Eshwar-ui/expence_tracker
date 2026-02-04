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
    final sortedEntries = _data!.dailyBreakdown.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final spots = List.generate(sortedEntries.length, (i) {
      return FlSpot(i.toDouble(), sortedEntries[i].value);
    });

    if (spots.isEmpty) return const Center(child: Text('Insufficient data'));

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppDesignSystem.brandPrimary,
            barWidth: 4,
            belowBarData: BarAreaData(
              show: true,
              color: AppDesignSystem.brandPrimary.withOpacity(0.1),
            ),
            dotData: const FlDotData(show: false),
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
