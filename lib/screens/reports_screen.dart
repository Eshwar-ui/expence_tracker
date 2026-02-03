import 'package:flutter/material.dart';
import 'package:expence_tracker/services/analytics_service.dart';
import 'package:expence_tracker/models/analytics.dart';
import 'package:expence_tracker/utils/app_design_system.dart';
import 'package:expence_tracker/widgets/design_system_components.dart';
import 'package:fl_chart/fl_chart.dart';

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
      final data = await _analytics.getAnalyticsData();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
      _animationController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Insights'),
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
    final spots = _data!.monthlyBreakdown.entries
        .map((e) => FlSpot(double.parse(e.key.split('-')[1]), e.value))
        .toList();
    if (spots.isEmpty) return const Center(child: Text('Insufficient data'));

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: Colors.white.withOpacity(0.1), strokeWidth: 1),
        ),
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
