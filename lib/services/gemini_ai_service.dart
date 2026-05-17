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

  bool get isConfigured => _apiKey.isNotEmpty;

  /// Generate AI insights from expense data
  Future<List<SpendingInsight>> generateInsights(
    List<Expense> expenses,
  ) async {
    if (_apiKey.isEmpty) {
      return _getFallbackInsights(expenses);
    }

    try {
      final expenseSummary = _prepareExpenseSummary(expenses);

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
        final text = _extractTextFromGeminiResponse(response.body);
        if (text == null || text.isEmpty) {
          return _getFallbackInsights(expenses);
        }

        final insightsJson = _extractInsightsJson(text);
        if (insightsJson == null) {
          return _getFallbackInsights(expenses);
        }

        final rawList = insightsJson['insights'];
        if (rawList is! List) {
          return _getFallbackInsights(expenses);
        }

        return rawList
            .whereType<Map>()
            .map((i) => SpendingInsight(
                  type: (i['type'] as String?) ?? 'general',
                  title: (i['title'] as String?) ?? 'Insight',
                  message: (i['message'] as String?) ?? '',
                  value: (i['value'] as num?)?.toDouble() ?? 0.0,
                ))
            .toList();
      }
    } catch (_) {
      // Swallow and fall back; never crash the insights screen on AI errors.
    }

    return _getFallbackInsights(expenses);
  }

  /// Safely walk Gemini's response shape to extract the model text.
  /// Returns null if any expected field is missing or has the wrong type.
  String? _extractTextFromGeminiResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final candidates = decoded['candidates'];
      if (candidates is! List || candidates.isEmpty) return null;
      final content = (candidates.first as Map?)?['content'];
      if (content is! Map) return null;
      final parts = content['parts'];
      if (parts is! List || parts.isEmpty) return null;
      final text = (parts.first as Map?)?['text'];
      return text is String ? text : null;
    } catch (_) {
      return null;
    }
  }

  /// Find the first balanced JSON object in `text` that contains an
  /// "insights" key. Falls back to the first balanced object if none match.
  /// Tolerates markdown code fences and surrounding prose.
  Map<String, dynamic>? _extractInsightsJson(String text) {
    Map<String, dynamic>? firstParsed;
    final length = text.length;
    for (int i = 0; i < length; i++) {
      if (text[i] != '{') continue;
      int depth = 0;
      bool inString = false;
      bool escape = false;
      for (int j = i; j < length; j++) {
        final ch = text[j];
        if (escape) {
          escape = false;
          continue;
        }
        if (ch == r'\') {
          escape = true;
          continue;
        }
        if (ch == '"') {
          inString = !inString;
          continue;
        }
        if (inString) continue;
        if (ch == '{') depth++;
        if (ch == '}') {
          depth--;
          if (depth == 0) {
            try {
              final parsed = jsonDecode(text.substring(i, j + 1));
              if (parsed is Map<String, dynamic>) {
                firstParsed ??= parsed;
                if (parsed['insights'] is List) return parsed;
              }
            } catch (_) {
              // Not valid JSON; keep scanning.
            }
            break;
          }
        }
      }
    }
    return firstParsed;
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
    } catch (_) {
      return null;
    }
  }
}
