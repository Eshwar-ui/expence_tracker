/// Model for expense predictions from AI
class ExpensePrediction {
  final List<double>
  dailyPredictions; // Predicted daily spending for next N days
  final Map<String, double>
  categoryPredictions; // Predicted spending by category
  final double totalPredictedSpending; // Total predicted spending
  final double anomalyScore; // Anomaly detection score (0-1)
  final DateTime predictionDate; // When prediction was made
  final DateTime predictionStartDate; // Start date of predictions

  ExpensePrediction({
    required this.dailyPredictions,
    required this.categoryPredictions,
    required this.totalPredictedSpending,
    required this.anomalyScore,
    required this.predictionDate,
    required this.predictionStartDate,
  });

  /// Get predicted spending for a specific date range
  double getPredictedSpendingForRange(DateTime start, DateTime end) {
    if (start.isBefore(predictionStartDate) ||
        end.isAfter(
          predictionStartDate.add(Duration(days: dailyPredictions.length)),
        )) {
      return 0.0;
    }

    final startOffset = start.difference(predictionStartDate).inDays;
    final endOffset = end.difference(predictionStartDate).inDays;

    if (startOffset < 0 || endOffset >= dailyPredictions.length) {
      return 0.0;
    }

    double total = 0.0;
    for (
      int i = startOffset;
      i <= endOffset && i < dailyPredictions.length;
      i++
    ) {
      total += dailyPredictions[i];
    }
    return total;
  }

  /// Get predicted spending for next week
  double getNextWeekPrediction() {
    final nextWeek = predictionStartDate.add(const Duration(days: 7));
    return getPredictedSpendingForRange(predictionStartDate, nextWeek);
  }

  /// Get predicted spending for next month
  double getNextMonthPrediction() {
    final nextMonth = predictionStartDate.add(const Duration(days: 30));
    return getPredictedSpendingForRange(predictionStartDate, nextMonth);
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'dailyPredictions': dailyPredictions,
      'categoryPredictions': categoryPredictions,
      'totalPredictedSpending': totalPredictedSpending,
      'anomalyScore': anomalyScore,
      'predictionDate': predictionDate.toIso8601String(),
      'predictionStartDate': predictionStartDate.toIso8601String(),
    };
  }

  /// Create from JSON
  factory ExpensePrediction.fromJson(Map<String, dynamic> json) {
    return ExpensePrediction(
      dailyPredictions: List<double>.from(json['dailyPredictions'] ?? []),
      categoryPredictions: Map<String, double>.from(
        json['categoryPredictions'] ?? {},
      ),
      totalPredictedSpending: (json['totalPredictedSpending'] ?? 0.0)
          .toDouble(),
      anomalyScore: (json['anomalyScore'] ?? 0.0).toDouble(),
      predictionDate: DateTime.parse(json['predictionDate']),
      predictionStartDate: DateTime.parse(json['predictionStartDate']),
    );
  }
}

/// Spending insights derived from predictions
class SpendingInsight {
  final String type; // 'trend', 'anomaly', 'category', 'budget'
  final String title;
  final String message;
  final double? value;
  final String? category;
  final DateTime? date;

  SpendingInsight({
    required this.type,
    required this.title,
    required this.message,
    this.value,
    this.category,
    this.date,
  });
}
