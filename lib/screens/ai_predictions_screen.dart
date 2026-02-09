import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/expence.dart';
import '../models/expense_prediction.dart';
import '../services/gemini_ai_service.dart';
import '../services/firestore_service.dart';
import '../utils/app_design_system.dart';
import '../widgets/design_system_components.dart';

/// Screen displaying AI-powered expense predictions
class AIPredictionsScreen extends StatefulWidget {
  const AIPredictionsScreen({super.key});

  @override
  State<AIPredictionsScreen> createState() => _AIPredictionsScreenState();
}

class _AIPredictionsScreenState extends State<AIPredictionsScreen> {
  final GeminiAIService _aiService = GeminiAIService();
  final FirestoreService _firestoreService = FirestoreService();

  ExpensePrediction? _prediction;
  List<SpendingInsight> _insights = [];
  List<Expense> _recentExpenses = [];
  bool _isLoading = false;
  String? _errorMessage;

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
    });

    print('🚀 Starting AI predictions load...');

    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final allExpenses = await _firestoreService.getExpenses();
      if (!mounted) return;

      _recentExpenses =
          allExpenses.where((e) => e.date.isAfter(thirtyDaysAgo)).toList();

      print('📊 Found ${_recentExpenses.length} expenses in last 30 days');

      if (_recentExpenses.isEmpty) {
        print('⚠️ No recent expenses found');
        setState(() {
          _errorMessage = 'No expenses found in last 30 days.';
          _isLoading = false;
        });
        return;
      }

      // Get AI insights
      print('💡 Fetching AI insights...');
      final insights = await _aiService.generateInsights(_recentExpenses);
      print('✅ Received ${insights.length} insights');

      // Get predictions
      print('📈 Fetching predictions...');
      final prediction = await _aiService.predictFutureExpenses();
      print('✅ Predictions received: ${prediction != null ? "Yes" : "No"}');

      if (!mounted) return;

      setState(() {
        _insights = insights;
        _prediction = prediction;
        _isLoading = false;
      });

      print('🎉 AI predictions loaded successfully!');
      print('   - Insights: ${_insights.length}');
      print('   - Prediction: ${_prediction != null}');
    } catch (e) {
      print('❌ Error in _loadPredictions: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error loading predictions: $e';
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadPredictions,
          ),
        ],
      ),
      body: Center(
        child: _isLoading
            ? const DesignSystemLoading()
            : _errorMessage != null
                ? _buildErrorState()
                : (_insights.isEmpty && _prediction == null)
                    ? _buildEmptyState()
                    : _buildPredictionsContent(),
      ),
    );
  }

  Widget _buildErrorState() {
    return DesignSystemEmptyState(
      icon: Icons.error_outline,
      title: 'Wait a moment',
      message: _errorMessage ?? 'An error occurred',
      action: GradientButton(text: 'Try Again', onPressed: _loadPredictions),
    );
  }

  Widget _buildEmptyState() {
    return const DesignSystemEmptyState(
      icon: Icons.analytics_outlined,
      title: 'Analyze More',
      message: 'Add more expenses to generate AI insights.',
    );
  }

  Widget _buildPredictionsContent() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: AppDesignSystem.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppDesignSystem.s24),
            child: Text('Financial Forecast',
                style: theme.textTheme.headlineMedium),
          ),
          const VSpace.md(),
          if (_prediction != null) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDesignSystem.s24),
              child: _buildSummaryCard(),
            ),
            const VSpace.xl(),
          ],
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppDesignSystem.s24),
            child: Text('Smart Insights', style: theme.textTheme.titleLarge),
          ),
          const VSpace.md(),
          if (_insights.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppDesignSystem.s24),
              child: DesignSystemCard(
                child: Padding(
                  padding: EdgeInsets.all(AppDesignSystem.s16),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: AppDesignSystem.textMed),
                      HSpace.md(),
                      Expanded(child: Text('Analyzing your finances...')),
                    ],
                  ),
                ),
              ),
            )
          else
            _buildInsightsCarousel(),
          if (_prediction != null) ...[
            const VSpace.xl(),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDesignSystem.s24),
              child: Text('30-Day Trend', style: theme.textTheme.titleLarge),
            ),
            const VSpace.md(),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDesignSystem.s24),
              child: _buildDailyPredictionsChart(),
            ),
            const VSpace.xl(),
            _buildVisualCategoryPredictions(),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final p = _prediction!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesignSystem.s24),
      decoration: BoxDecoration(
        gradient: AppDesignSystem.primaryGradient,
        borderRadius: BorderRadius.circular(AppDesignSystem.r24),
        boxShadow: AppDesignSystem.softShadow(AppDesignSystem.brandPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.show_chart, color: Colors.white70),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'AI FORECAST',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const VSpace.xl(),
          const Text(
            'Predicted Spend (30 Days)',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const VSpace.xs(),
          Text(
            '₹${p.totalPredictedSpending.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const VSpace.lg(),
          Row(
            children: [
              _summaryMetric('Next 7 Days',
                  '₹${p.getNextWeekPrediction().toStringAsFixed(0)}'),
              const SizedBox(width: AppDesignSystem.s24),
              _summaryMetric('Daily Avg',
                  '₹${(p.totalPredictedSpending / 30).toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildInsightsCarousel() {
    return SizedBox(
      height: 170,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.s24),
        scrollDirection: Axis.horizontal,
        itemCount: _insights.length,
        separatorBuilder: (c, i) => const SizedBox(width: AppDesignSystem.s16),
        itemBuilder: (context, index) =>
            _buildVisualInsightCard(_insights[index]),
      ),
    );
  }

  Widget _buildVisualInsightCard(SpendingInsight insight) {
    // Determine color/icon based on insight.type
    final isNegative = insight.type == 'savings' || insight.type == 'anomaly';
    final color = isNegative
        ? AppDesignSystem.brandAccent
        : AppDesignSystem.brandSecondary;
    final icon = isNegative ? Icons.trending_down : Icons.trending_up;

    return Container(
      width: 260,
      padding: const EdgeInsets.all(AppDesignSystem.s20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppDesignSystem.r24),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
        boxShadow: AppDesignSystem.softShadow(Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              if (insight.value != null && insight.value! > 0)
                Text(
                  '₹${insight.value!.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(insight.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const VSpace.sm(),
          Text(insight.message,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildDailyPredictionsChart() {
    final dailyData = _prediction!.dailyPredictions;
    return DesignSystemCard(
      padding: const EdgeInsets.all(AppDesignSystem.s20),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      dailyData.length,
                      (i) => FlSpot(i.toDouble(), dailyData[i]),
                    ),
                    isCurved: true,
                    color: AppDesignSystem.brandPrimary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppDesignSystem.brandPrimary.withOpacity(0.15),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppDesignSystem.brandPrimary.withOpacity(0.3),
                          AppDesignSystem.brandPrimary.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualCategoryPredictions() {
    final categories = _prediction!.categoryPredictions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Sort by amount

    // Calculate total for percentage
    final total = categories.fold<double>(0, (sum, item) => sum + item.value);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.s24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Category Breakdown',
                  style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const VSpace.md(),
          ...categories.take(5).map((e) {
            final percentage = total > 0 ? (e.value / total) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('₹${e.value.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor:
                          Theme.of(context).dividerColor.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation(
                          AppDesignSystem.brandPrimary),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
