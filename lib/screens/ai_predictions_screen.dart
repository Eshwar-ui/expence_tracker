import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/expence.dart';
import '../models/expense_prediction.dart';
import '../services/ai_expense_service.dart';
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
  final AIExpenseService _aiService = AIExpenseService();
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

    try {
      final initialized = await _aiService.initialize();
      if (!mounted) return;
      if (!initialized) {
        setState(() {
          _errorMessage = 'AI model not available.';
          _isLoading = false;
        });
        return;
      }

      final allExpenses = await _firestoreService.getExpenses();
      if (!mounted) return;
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      _recentExpenses = allExpenses
          .where((e) => e.date.isAfter(thirtyDaysAgo))
          .toList();

      if (_recentExpenses.isEmpty) {
        setState(() {
          _errorMessage = 'No expenses found in last 30 days.';
          _isLoading = false;
        });
        return;
      }

      final prediction = await _aiService.predictFutureExpenses();
      if (!mounted) return;
      if (prediction != null) {
        final insights = _aiService.generateInsights(
          prediction,
          _recentExpenses,
        );
        setState(() {
          _prediction = prediction;
          _insights = insights;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Not enough data for predictions.';
          _isLoading = false;
        });
      }
    } catch (e) {
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
      body: _isLoading
          ? const DesignSystemLoading()
          : _errorMessage != null
          ? _buildErrorState()
          : _prediction == null
          ? _buildEmptyState()
          : _buildPredictionsContent(),
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
      padding: const EdgeInsets.all(AppDesignSystem.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(),
          const VSpace.xl(),
          if (_insights.isNotEmpty) ...[
            Text('Insights', style: theme.textTheme.titleLarge),
            const VSpace.md(),
            ..._insights.map(
              (insight) => Padding(
                padding: const EdgeInsets.only(bottom: AppDesignSystem.s12),
                child: _buildInsightCard(insight),
              ),
            ),
            const VSpace.xl(),
          ],
          Text('30-Day Forecast', style: theme.textTheme.titleLarge),
          const VSpace.md(),
          _buildDailyPredictionsChart(),
          const VSpace.xl(),
          _buildCategoryPredictions(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final p = _prediction!;
    return DesignSystemCard(
      glass: true,
      padding: const EdgeInsets.all(AppDesignSystem.s24),
      child: Column(
        children: [
          _summaryRow('Next 7 Days', p.getNextWeekPrediction()),
          const VSpace.md(),
          _summaryRow('Next 30 Days', p.totalPredictedSpending),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppDesignSystem.brandPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard(SpendingInsight insight) {
    return DesignSystemCard(
      child: ListTile(
        leading: Icon(Icons.auto_awesome, color: AppDesignSystem.brandPrimary),
        title: Text(insight.title),
        subtitle: Text(insight.message),
      ),
    );
  }

  Widget _buildDailyPredictionsChart() {
    final dailyData = _prediction!.dailyPredictions;
    return DesignSystemCard(
      padding: const EdgeInsets.all(AppDesignSystem.s20),
      child: SizedBox(
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
                belowBarData: BarAreaData(
                  show: true,
                  color: AppDesignSystem.brandPrimary.withOpacity(0.1),
                ),
                dotData: const FlDotData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPredictions() {
    final categories = _prediction!.categoryPredictions.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('By Category', style: Theme.of(context).textTheme.titleLarge),
        const VSpace.md(),
        ...categories.map(
          (e) => DesignSystemCard(
            // margin: const EdgeInsets.only(bottom: AppDesignSystem.s12),
            child: ListTile(
              title: Text(e.key),
              trailing: Text(
                '₹${e.value.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _aiService.dispose();
    super.dispose();
  }
}
