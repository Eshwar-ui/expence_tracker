import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/expence.dart';
import '../models/expense_prediction.dart';
import '../services/ai_expense_service.dart';
import '../services/firestore_service.dart';
import '../services/gemini_ai_service.dart';
import '../utils/app_design_system.dart';
import '../widgets/design_system_components.dart';

class AIPredictionsScreen extends StatefulWidget {
  const AIPredictionsScreen({super.key});

  @override
  State<AIPredictionsScreen> createState() => _AIPredictionsScreenState();
}

class _AIPredictionsScreenState extends State<AIPredictionsScreen> {
  final GeminiAIService _aiService = GeminiAIService();
  final AIExpenseService _mlService = AIExpenseService();
  final FirestoreService _firestoreService = FirestoreService();
  final NumberFormat _money =
      NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

  ExpensePrediction? _prediction;
  List<SpendingInsight> _insights = [];
  List<Expense> _recentExpenses = [];
  bool _isLoading = false;
  bool _usingFallbackInsights = false;
  String _predictionSource = 'fallback'; // 'tflite' | 'fallback' | 'none'
  String? _predictionNote;
  String? _errorMessage;
  DateTime? _analysisStart;
  DateTime? _analysisEnd;

  @override
  void initState() {
    super.initState();
    _loadPredictions();
  }

  Future<void> _loadPredictions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _usingFallbackInsights = false;
    });

    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 30));
      _analysisStart = start;
      _analysisEnd = now;

      final allExpenses = await _firestoreService.getExpenses();
      if (!mounted) return;

      _recentExpenses = allExpenses.where((expense) => expense.date.isAfter(start)).toList();

      if (_recentExpenses.isEmpty) {
        setState(() {
          _errorMessage = 'No expenses found in the last 30 days.';
          _isLoading = false;
        });
        return;
      }

      final insightsFuture = _aiService.generateInsights(_recentExpenses);
      final predictionFuture = _mlService.predictWithFallback();
      final results = await Future.wait<dynamic>([
        insightsFuture,
        predictionFuture,
      ]);
      final insights = results[0] as List<SpendingInsight>;
      final predictionResult = results[1] as PredictionResult?;

      if (!mounted) return;
      setState(() {
        _insights = insights;
        _prediction = predictionResult?.prediction;
        _predictionSource = predictionResult?.source ?? 'none';
        _predictionNote = predictionResult?.note;
        _usingFallbackInsights = !_aiService.isConfigured;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load AI insights: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PremiumAppBar(
        title: 'AI Insights',
        actions: [
          IconButton(
            onPressed: _loadPredictions,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Center(
        child: _isLoading
            ? const DesignSystemLoading()
            : _errorMessage != null
                ? _buildErrorState()
                : (_prediction == null && _insights.isEmpty)
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadPredictions,
                        child: _buildContent(),
                      ),
      ),
    );
  }

  Widget _buildErrorState() {
    return DesignSystemEmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Could not load AI insights',
      message: _errorMessage ?? 'Please try again.',
      action: GradientButton(text: 'Retry', onPressed: _loadPredictions),
    );
  }

  Widget _buildEmptyState() {
    return const DesignSystemEmptyState(
      icon: Icons.psychology_alt_rounded,
      title: 'Not enough data yet',
      message: 'Add recent transactions to generate a reliable forecast.',
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(AppDesignSystem.s24),
      children: [
        _buildStatusBanner(),
        const VSpace.lg(),
        _buildForecastHero(),
        const VSpace.lg(),
        _buildMetricsRow(),
        const VSpace.lg(),
        _buildInsightsSection(),
        const VSpace.lg(),
        if (_prediction != null) _buildTrendSection(),
        if (_prediction != null) const VSpace.lg(),
        if (_prediction != null) _buildCategorySection(),
        const VSpace.lg(),
        _buildDataContextCard(),
        const SizedBox(height: 96),
      ],
    );
  }

  Widget _buildStatusBanner() {
    final theme = Theme.of(context);

    final geminiOk = !_usingFallbackInsights;
    final tfliteOk = _predictionSource == 'tflite';

    final bannerColor = (geminiOk && tfliteOk)
        ? AppDesignSystem.brandInfo
        : AppDesignSystem.brandAccent;
    final icon =
        (geminiOk && tfliteOk) ? Icons.auto_awesome_rounded : Icons.science_rounded;

    final title = (geminiOk && tfliteOk)
        ? 'AI analysis available'
        : (!geminiOk && !tfliteOk)
            ? 'Rule-based mode'
            : !tfliteOk
                ? 'AI insights · Estimated forecast'
                : 'On-device forecast · Rule-based insights';

    final parts = <String>[];
    if (!geminiOk) {
      parts.add(
        'Gemini key not configured — insights come from local heuristics.',
      );
    }
    if (!tfliteOk) {
      parts.add(
        _predictionNote ??
            'Local TFLite predictor unavailable — using a 30-day rolling average.',
      );
    }
    if (parts.isEmpty) {
      parts.add(
        'Insights come from Gemini; the 30-day forecast is from your on-device model. Review before acting.',
      );
    }
    final message = parts.join(' ');

    return DesignSystemCard(
      glass: true,
      padding: const EdgeInsets.all(AppDesignSystem.s16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bannerColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: bannerColor),
          ),
          const HSpace.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const VSpace.xs(),
                Text(message, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastHero() {
    final prediction = _prediction;
    final amount = prediction?.totalPredictedSpending ?? 0.0;
    final lastUpdated = prediction?.predictionDate ?? DateTime.now();

    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.s20),
      decoration: BoxDecoration(
        gradient: AppDesignSystem.primaryGradient,
        borderRadius: BorderRadius.circular(AppDesignSystem.r24),
        boxShadow: AppDesignSystem.softShadow(AppDesignSystem.brandPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph_rounded, color: Colors.white),
              const HSpace.sm(),
              Text(
                '30-Day Spending Forecast',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Text(
                DateFormat('dd MMM').format(lastUpdated),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const VSpace.md(),
          Text(
            _money.format(amount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const VSpace.xs(),
          Text(
            _usingFallbackInsights
                ? 'Rule-based estimate for the next 30 days'
                : 'Estimated total expense for the next 30 days',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow() {
    final prediction = _prediction;
    final nextWeek = prediction?.getNextWeekPrediction() ?? 0.0;
    final avgDay = (prediction?.totalPredictedSpending ?? 0.0) / 30;
    final anomaly = ((prediction?.anomalyScore ?? 0.0) * 100).clamp(0, 100);

    return Row(
      children: [
        Expanded(
          child: _metricCard(
            title: 'Next 7 Days',
            value: _money.format(nextWeek),
            icon: Icons.calendar_view_week_rounded,
          ),
        ),
        const HSpace.sm(),
        Expanded(
          child: _metricCard(
            title: 'Daily Avg',
            value: _money.format(avgDay),
            icon: Icons.today_rounded,
          ),
        ),
        const HSpace.sm(),
        Expanded(
          child: _metricCard(
            title: 'Anomaly',
            value: '${anomaly.toStringAsFixed(0)}%',
            icon: Icons.warning_amber_rounded,
          ),
        ),
      ],
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return DesignSystemCard(
      glass: true,
      padding: const EdgeInsets.all(AppDesignSystem.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppDesignSystem.brandPrimary),
          const VSpace.xs(),
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const VSpace.xs(),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Key Insights', style: Theme.of(context).textTheme.titleLarge),
        const VSpace.sm(),
        if (_insights.isEmpty)
          const DesignSystemCard(
            child: Padding(
              padding: EdgeInsets.all(AppDesignSystem.s16),
              child: Text('No insights generated yet. Pull to refresh.'),
            ),
          )
        else
          ..._insights.take(6).map(_insightTile),
      ],
    );
  }

  Widget _insightTile(SpendingInsight insight) {
    final visual = _insightVisual(insight.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignSystem.s12),
      child: DesignSystemCard(
        padding: const EdgeInsets.all(AppDesignSystem.s16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: visual.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(visual.icon, color: visual.color, size: 18),
            ),
            const HSpace.md(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const VSpace.xs(),
                  Text(
                    insight.message,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (insight.value != null && insight.value! > 0) ...[
              const HSpace.sm(),
              Text(
                _money.format(insight.value),
                style: TextStyle(
                  color: visual.color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrendSection() {
    final daily = _prediction!.dailyPredictions;
    final spots = List.generate(
      daily.length,
      (index) => FlSpot(index.toDouble(), daily[index]),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trend Projection', style: Theme.of(context).textTheme.titleLarge),
        const VSpace.sm(),
        DesignSystemCard(
          padding: const EdgeInsets.all(AppDesignSystem.s16),
          child: SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (daily.length - 1).toDouble(),
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: _niceInterval(daily),
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.35),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: _niceInterval(daily),
                      getTitlesWidget: (value, meta) => Text(
                        _money.format(value),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 5,
                      getTitlesWidget: (value, meta) {
                        final day = value.toInt() + 1;
                        return Text(
                          'D$day',
                          style: Theme.of(context).textTheme.labelSmall,
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppDesignSystem.brandPrimary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppDesignSystem.brandPrimary.withValues(alpha: 0.22),
                          AppDesignSystem.brandPrimary.withValues(alpha: 0.02),
                        ],
                      ),
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

  Widget _buildCategorySection() {
    final entries = _prediction!.categoryPredictions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (sum, item) => sum + item.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category Contribution',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const VSpace.sm(),
        DesignSystemCard(
          padding: const EdgeInsets.all(AppDesignSystem.s16),
          child: Column(
            children: entries.take(6).map((entry) {
              final pct = total > 0 ? (entry.value / total) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDesignSystem.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${(pct * 100).toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const HSpace.sm(),
                        Text(
                          _money.format(entry.value),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0, 1),
                        minHeight: 7,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.22),
                        valueColor: const AlwaysStoppedAnimation(
                          AppDesignSystem.brandPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDataContextCard() {
    final expenseOnly =
        _recentExpenses.where((expense) => expense.type == TransactionType.expense).length;
    final incomeOnly =
        _recentExpenses.where((expense) => expense.type == TransactionType.income).length;
    final rangeText = (_analysisStart != null && _analysisEnd != null)
        ? '${DateFormat('dd MMM').format(_analysisStart!)} - ${DateFormat('dd MMM').format(_analysisEnd!)}'
        : 'Last 30 days';

    return DesignSystemCard(
      padding: const EdgeInsets.all(AppDesignSystem.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Model Context', style: Theme.of(context).textTheme.titleMedium),
          const VSpace.sm(),
          Text(
            'Analysis Range: $rangeText',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const VSpace.xs(),
          Text(
            'Transactions analyzed: ${_recentExpenses.length} '
            '(Expenses: $expenseOnly, Income: $incomeOnly)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const VSpace.xs(),
          Text(
            _usingFallbackInsights
                ? 'Insight source: rule-based fallback forecast and heuristics.'
                : 'Insight source: Gemini-assisted insight generation with rule-based forecasting.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const VSpace.xs(),
          Text(
            'Tip: The forecast improves when at least 30-60 days of consistent spending data is available.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  double _niceInterval(List<double> values) {
    if (values.isEmpty) return 100;
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    if (maxValue <= 100) return 25;
    if (maxValue <= 500) return 100;
    if (maxValue <= 2000) return 250;
    if (maxValue <= 5000) return 500;
    return 1000;
  }

  _InsightVisual _insightVisual(String type) {
    switch (type.toLowerCase()) {
      case 'anomaly':
        return const _InsightVisual(
          Icons.warning_amber_rounded,
          AppDesignSystem.error,
        );
      case 'savings':
        return const _InsightVisual(
          Icons.savings_rounded,
          AppDesignSystem.success,
        );
      case 'category':
        return const _InsightVisual(
          Icons.pie_chart_rounded,
          AppDesignSystem.brandPrimary,
        );
      case 'trend':
      default:
        return const _InsightVisual(
          Icons.trending_up_rounded,
          AppDesignSystem.brandSecondary,
        );
    }
  }
}

class _InsightVisual {
  final IconData icon;
  final Color color;

  const _InsightVisual(this.icon, this.color);
}
