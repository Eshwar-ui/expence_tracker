import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/expence.dart';
import '../models/expense_prediction.dart';
import 'firestore_service.dart';

/// Service for AI-powered expense insights using Google Gemini API (Free)
///
/// Get your free API key from: https://makersuite.google.com/app/apikey
/// Add it to .env file as: GEMINI_API_KEY=your_key_here
class GeminiAIService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash-lite:generateContent';

  final FirestoreService _firestoreService = FirestoreService();

  /// Generate AI insights from expense data
  Future<List<SpendingInsight>> generateInsights(
    List<Expense> expenses,
  ) async {
    print('🔍 Generating insights for ${expenses.length} expenses');

    if (_apiKey.isEmpty) {
      print('⚠️ Gemini API key not configured in .env file');
      print('📊 Using fallback insights');
      return _getFallbackInsights(expenses);
    }

    try {
      // Prepare expense summary for AI
      final expenseSummary = _prepareExpenseSummary(expenses);
      print('📝 Prepared expense summary for AI analysis');

      // Create prompt for Gemini
      final prompt = '''
Analyze the following expense data and provide 3-5 actionable financial insights:

$expenseSummary

Please provide insights in the following JSON format:
{
  "insights": [
    {
      "type": "trend|category|anomaly|savings",
      "title": "Brief title",
      "message": "Detailed insight message",
      "value": 0.0
    }
  ]
}

Focus on:
1. Spending trends (increasing/decreasing)
2. Top spending categories
3. Unusual patterns or anomalies
4. Money-saving opportunities
5. Budget recommendations
''';

      // Call Gemini API
      print('🌐 Calling Gemini API...');
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 1024,
          }
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Gemini API call successful');
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'];
        print(
            '📄 API Response: ${text.substring(0, text.length > 100 ? 100 : text.length)}...');

        // Extract JSON from response
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
        if (jsonMatch != null) {
          final insightsJson = jsonDecode(jsonMatch.group(0)!);
          final insightsList = insightsJson['insights'] as List;

          print('💡 Generated ${insightsList.length} AI insights');

          return insightsList
              .map((i) => SpendingInsight(
                    type: i['type'] ?? 'general',
                    title: i['title'] ?? 'Insight',
                    message: i['message'] ?? '',
                    value: (i['value'] as num?)?.toDouble() ?? 0.0,
                  ))
              .toList();
        } else {
          print('⚠️ Could not extract JSON from API response');
        }
      } else {
        print('❌ Gemini API error: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('❌ Error calling Gemini API: $e');
    }

    // Fallback to rule-based insights
    print('📊 Using fallback insights');
    return _getFallbackInsights(expenses);
  }

  /// Prepare expense summary for AI analysis
  String _prepareExpenseSummary(List<Expense> expenses) {
    final expenseOnly =
        expenses.where((e) => e.type == TransactionType.expense).toList();
    final incomeOnly =
        expenses.where((e) => e.type == TransactionType.income).toList();

    // Calculate totals
    final totalExpense =
        expenseOnly.fold<double>(0.0, (sum, e) => sum + e.amount);
    final totalIncome =
        incomeOnly.fold<double>(0.0, (sum, e) => sum + e.amount);

    // Category breakdown
    final categoryTotals = <String, double>{};
    for (final expense in expenseOnly) {
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0.0) + expense.amount;
    }

    // Sort categories by amount
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final buffer = StringBuffer();
    buffer.writeln('Period: Last 30 days');
    buffer.writeln('Total Expenses: ₹${totalExpense.toStringAsFixed(2)}');
    buffer.writeln('Total Income: ₹${totalIncome.toStringAsFixed(2)}');
    buffer.writeln('Net: ₹${(totalIncome - totalExpense).toStringAsFixed(2)}');
    buffer.writeln('\nTop Categories:');

    for (var i = 0; i < sortedCategories.length && i < 5; i++) {
      final entry = sortedCategories[i];
      final percentage = (entry.value / totalExpense * 100).toStringAsFixed(1);
      buffer.writeln(
          '- ${entry.key}: ₹${entry.value.toStringAsFixed(2)} ($percentage%)');
    }

    buffer.writeln(
        '\nTransaction Count: ${expenseOnly.length} expenses, ${incomeOnly.length} income');

    return buffer.toString();
  }

  /// Fallback rule-based insights when API is unavailable
  List<SpendingInsight> _getFallbackInsights(List<Expense> expenses) {
    final insights = <SpendingInsight>[];

    final expenseOnly =
        expenses.where((e) => e.type == TransactionType.expense).toList();

    if (expenseOnly.isEmpty) {
      return [
        SpendingInsight(
          type: 'info',
          title: 'No Data Yet',
          message: 'Add more expenses to get AI-powered insights.',
          value: 0.0,
        ),
      ];
    }

    // Calculate totals by category
    final categoryTotals = <String, double>{};
    double totalExpense = 0.0;

    for (final expense in expenseOnly) {
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0.0) + expense.amount;
      totalExpense += expense.amount;
    }

    // Top category insight
    if (categoryTotals.isNotEmpty) {
      final topCategory =
          categoryTotals.entries.reduce((a, b) => a.value > b.value ? a : b);
      final percentage = (topCategory.value / totalExpense * 100);

      insights.add(
        SpendingInsight(
          type: 'category',
          title: 'Top Spending Category',
          message:
              '${topCategory.key} accounts for ${percentage.toStringAsFixed(1)}% of your spending (₹${topCategory.value.toStringAsFixed(0)}).',
          value: topCategory.value,
          category: topCategory.key,
        ),
      );
    }

    // Average daily spending
    final avgDaily = totalExpense / 30;
    insights.add(
      SpendingInsight(
        type: 'trend',
        title: 'Daily Average',
        message:
            'You spend an average of ₹${avgDaily.toStringAsFixed(0)} per day.',
        value: avgDaily,
      ),
    );

    // Savings opportunity
    if (categoryTotals.length > 1) {
      final sortedCategories = categoryTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (sortedCategories.length >= 2) {
        final secondCategory = sortedCategories[1];
        insights.add(
          SpendingInsight(
            type: 'savings',
            title: 'Savings Opportunity',
            message:
                'Consider reducing ${secondCategory.key} expenses. Even a 10% reduction could save ₹${(secondCategory.value * 0.1).toStringAsFixed(0)} per month.',
            value: secondCategory.value * 0.1,
            category: secondCategory.key,
          ),
        );
      }
    }

    return insights;
  }

  /// Predict future expenses (simplified version)
  Future<ExpensePrediction?> predictFutureExpenses() async {
    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final expenses = await _firestoreService.getExpensesByDateRange(
        thirtyDaysAgo,
        now,
      );

      final expenseOnly =
          expenses.where((e) => e.type == TransactionType.expense).toList();

      if (expenseOnly.isEmpty) {
        return null;
      }

      // Simple prediction: average of last 30 days
      final totalExpense =
          expenseOnly.fold<double>(0.0, (sum, e) => sum + e.amount);
      final avgDaily = totalExpense / 30;

      // Predict next 30 days
      final dailyPredictions = List<double>.filled(30, avgDaily);

      // Category predictions
      final categoryTotals = <String, double>{};
      for (final expense in expenseOnly) {
        categoryTotals[expense.category] =
            (categoryTotals[expense.category] ?? 0.0) + expense.amount;
      }

      return ExpensePrediction(
        dailyPredictions: dailyPredictions,
        categoryPredictions: categoryTotals,
        totalPredictedSpending: avgDaily * 30,
        anomalyScore: 0.0,
        predictionDate: now,
        predictionStartDate: now.add(const Duration(days: 1)),
      );
    } catch (e) {
      print('Error predicting expenses: $e');
      return null;
    }
  }
}
