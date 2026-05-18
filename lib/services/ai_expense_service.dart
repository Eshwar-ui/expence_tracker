import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:convert';
import 'dart:math' as math;
import '../models/expence.dart';
import '../models/expense_prediction.dart';
import 'firestore_service.dart';

/// Outcome of a prediction attempt — bundles the prediction with the source
/// (tflite or rule-based fallback) so the UI can label what it shows.
class PredictionResult {
  final ExpensePrediction prediction;
  final String source; // 'tflite' | 'fallback'
  final String? note;

  const PredictionResult({
    required this.prediction,
    required this.source,
    this.note,
  });
}

/// Service for AI-powered expense prediction using TensorFlow Lite
class AIExpenseService {
  static AIExpenseService? _instance;
  Interpreter? _interpreter;
  bool _isInitialized = false;
  Map<String, dynamic>? _modelMetadata;
  final FirestoreService _firestoreService = FirestoreService();

  // Model configuration
  static const String _modelPath = 'assets/models/expense_predictor.tflite';
  static const String _metadataPath =
      'assets/models/expense_predictor_stats.json';
  static const int _sequenceLength = 30;
  static const int _predictionHorizon = 30;
  static const int _numFeatures = 17; // 7 base + 10 categories

  AIExpenseService._();

  factory AIExpenseService() {
    _instance ??= AIExpenseService._();
    return _instance!;
  }

  /// Initialize the TFLite model
  Future<bool> initialize() async {
    if (_isInitialized && _interpreter != null) {
      return true;
    }

    try {
      await _loadMetadata();

      final Uint8List modelBuffer;
      try {
        final modelBytes = await rootBundle.load(_modelPath);
        modelBuffer = modelBytes.buffer.asUint8List();
        if (modelBuffer.isEmpty) {
          throw Exception('Model file is empty');
        }
      } catch (e) {
        if (e.toString().contains('Unable to load asset') ||
            e.toString().contains('not found')) {
          throw Exception(
            'Model file not found at $_modelPath. '
            'Make sure the asset exists and rebuild.',
          );
        }
        rethrow;
      }

      // Interpreter.fromBuffer holds native handles, so it can't run in a
      // background isolate via compute(). Yield one frame before the
      // synchronous constructor so the UI can paint (splash, loaders, etc.)
      // before the main thread gets blocked parsing the model graph.
      await Future<void>.delayed(Duration.zero);
      _interpreter = Interpreter.fromBuffer(modelBuffer);
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();
      if (inputTensors.isEmpty || outputTensors.isEmpty) {
        throw Exception('Invalid model: missing input or output tensors');
      }
      _isInitialized = true;
      return true;
    } catch (e, st) {
      debugPrint('AIExpenseService.initialize failed: $e\n$st');
      _interpreter = null;
      _isInitialized = false;
      return false;
    }
  }

  /// Try TFLite first, fall back to a 30-day averaging predictor if TFLite
  /// is unavailable or there isn't enough history for the model.
  Future<PredictionResult?> predictWithFallback({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final tflite = await predictFutureExpenses(
      startDate: startDate,
      endDate: endDate,
    );
    if (tflite != null) {
      return PredictionResult(prediction: tflite, source: 'tflite');
    }

    final fallback = await _averagingPredict();
    if (fallback == null) return null;
    return PredictionResult(
      prediction: fallback,
      source: 'fallback',
      note: 'Local TFLite model unavailable or not enough history — using a '
          '30-day rolling average.',
    );
  }

  Future<ExpensePrediction?> _averagingPredict() async {
    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final expenses = await _firestoreService.getExpensesByDateRange(
        thirtyDaysAgo,
        now,
      );
      final expenseOnly =
          expenses.where((e) => e.type == TransactionType.expense).toList();
      if (expenseOnly.isEmpty) return null;

      final total =
          expenseOnly.fold<double>(0.0, (sum, e) => sum + e.amount);
      final avgDaily = total / 30;
      final dailyPredictions = List<double>.filled(30, avgDaily);

      final categoryTotals = <String, double>{};
      for (final e in expenseOnly) {
        categoryTotals[e.category] =
            (categoryTotals[e.category] ?? 0.0) + e.amount;
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
      debugPrint('AIExpenseService._averagingPredict failed: $e');
      return null;
    }
  }

  /// Load model metadata (feature stats, categories, etc.)
  Future<void> _loadMetadata() async {
    try {
      final metadataString = await rootBundle.loadString(_metadataPath);
      _modelMetadata = json.decode(metadataString);
    } catch (_) {
      // Use default metadata
      _modelMetadata = {
        'sequence_length': _sequenceLength,
        'prediction_horizon': _predictionHorizon,
        'num_features': _numFeatures,
        'feature_stats': {'mean': 0.0, 'std': 1.0, 'categories': []},
      };
    }
  }

  /// Predict future expenses based on historical data
  Future<ExpensePrediction?> predictFutureExpenses({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!_isInitialized || _interpreter == null) {
      final initialized = await initialize();
      if (!initialized) {
        return null;
      }
    }

    try {
      // Get historical expenses (last 3 months for better predictions)
      final now = DateTime.now();
      final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);

      List<Expense> expenses;
      if (startDate != null || endDate != null) {
        // Use provided date range
        final start = startDate ?? threeMonthsAgo;
        final end = endDate ?? now;
        expenses = await _firestoreService.getExpensesByDateRange(start, end);
      } else {
        // Get last 3 months
        expenses = await _firestoreService.getExpensesByDateRange(
          threeMonthsAgo,
          now,
        );
      }

      if (expenses.isEmpty) return null;

      final filteredExpenses = expenses
          .where((e) => e.type == TransactionType.expense)
          .toList();
      if (filteredExpenses.isEmpty) return null;

      filteredExpenses.sort((a, b) => a.date.compareTo(b.date));

      final features = _prepareFeatures(filteredExpenses);
      if (features == null) return null;

      final predictions = _runInference(features);
      return _processPredictions(predictions, filteredExpenses);
    } catch (e, st) {
      debugPrint('AIExpenseService.predictFutureExpenses failed: $e\n$st');
      return null;
    }
  }

  /// Prepare features from expense data
  List<List<double>>? _prepareFeatures(List<Expense> expenses) {
    if (expenses.isEmpty) return null;

    final minDate = expenses.first.date;
    final maxDate = expenses.last.date;
    final daysDiff = maxDate.difference(minDate).inDays;
    if (daysDiff < _sequenceLength) return null;

    // Get categories from metadata or expenses
    final categories =
        _modelMetadata?['feature_stats']?['categories'] as List<dynamic>? ?? [];
    final categoryList = categories.map((c) => c.toString()).toList();

    // Create daily aggregates
    final dailyData = <DateTime, Map<String, dynamic>>{};
    final dateRange = <DateTime>[];

    for (int i = 0; i <= daysDiff; i++) {
      final date = minDate.add(Duration(days: i));
      dateRange.add(date);
      dailyData[date] = {
        'total': 0.0,
        'count': 0,
        'categories': <String, double>{},
      };
    }

    // Aggregate expenses by day
    for (final expense in expenses) {
      if (expense.type != TransactionType.expense) continue;

      final date = DateTime(
        expense.date.year,
        expense.date.month,
        expense.date.day,
      );
      if (dailyData.containsKey(date)) {
        dailyData[date]!['total'] =
            (dailyData[date]!['total'] as double) + expense.amount;
        dailyData[date]!['count'] = (dailyData[date]!['count'] as int) + 1;
        final cats = dailyData[date]!['categories'] as Map<String, double>;
        cats[expense.category] =
            (cats[expense.category] ?? 0.0) + expense.amount;
      }
    }

    // Get the most recent sequence
    final recentDates = dateRange.sublist(
      math.max(0, dateRange.length - _sequenceLength),
    );

    final features = <List<double>>[];

    for (final date in recentDates) {
      final data = dailyData[date]!;
      final dayOfWeek = date.weekday; // 1=Monday, 7=Sunday
      final dayOfMonth = date.day;
      final isWeekend = (dayOfWeek >= 6) ? 1.0 : 0.0;
      final isMonthEnd = (dayOfMonth >= 28) ? 1.0 : 0.0;
      final isMonthStart = (dayOfMonth <= 5) ? 1.0 : 0.0;

      final featureVector = <double>[
        data['total'] as double,
        (data['count'] as int).toDouble(),
        dayOfWeek / 7.0, // Normalize
        dayOfMonth / 31.0, // Normalize
        isWeekend,
        isMonthEnd,
        isMonthStart,
      ];

      // Add category features
      final cats = data['categories'] as Map<String, double>;
      for (final category in categoryList) {
        featureVector.add(cats[category] ?? 0.0);
      }

      // Pad if needed
      while (featureVector.length < _numFeatures) {
        featureVector.add(0.0);
      }

      features.add(featureVector);
    }

    if (features.length != _sequenceLength) return null;

    final mean = _modelMetadata?['feature_stats']?['mean'] ?? 0.0;
    final std = _modelMetadata?['feature_stats']?['std'] ?? 1.0;
    for (int i = 0; i < features.length; i++) {
      for (int j = 0; j < features[i].length; j++) {
        features[i][j] = (features[i][j] - mean) / (std + 1e-8);
      }
    }
    return features;
  }

  /// Run inference on prepared features
  List<double> _runInference(List<List<double>> features) {
    // Capture once so dispose() during inference can't null this out mid-flight.
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('Model not initialized');
    }

    if (features.length != _sequenceLength) {
      throw Exception(
        'Feature sequence length mismatch: expected $_sequenceLength, got ${features.length}',
      );
    }

    // Validate feature dimensions
    for (int i = 0; i < features.length; i++) {
      if (features[i].length != _numFeatures) {
        throw Exception(
          'Feature vector $i length mismatch: expected $_numFeatures, got ${features[i].length}',
        );
      }
    }

    try {
      // Prepare input as flat list of float32
      final inputList = <double>[];
      for (final dayFeatures in features) {
        inputList.addAll(dayFeatures);
      }

      // Reshape to [1, sequence_length, num_features]
      final inputData = _reshapeList(inputList, [
        1,
        _sequenceLength,
        _numFeatures,
      ]);

      // Validate input shape
      if (inputData.length != 1 ||
          (inputData[0] as List).length != _sequenceLength) {
        throw Exception('Input reshape failed');
      }

      // Get output tensor details
      final outputTensors = interpreter.getOutputTensors();
      final outputTensor = outputTensors[0];
      final outputShape = outputTensor.shape;
      final outputSize = outputShape.reduce((a, b) => a * b);

      // Prepare output buffer
      final output = List.filled(outputSize, 0.0);

      interpreter.run(inputData, output);

      // Extract predictions
      // Output is flat list from TFLite, shape is [1, prediction_horizon]
      // So we take the first prediction_horizon elements
      final predictions = output
          .take(_predictionHorizon)
          .map((e) => (e as num).toDouble())
          .toList();

      // Apply inverse log transform (model outputs log(1+x))
      final transformedPredictions = predictions.map((p) {
        final value = math.exp(p) - 1;
        return value < 0 ? 0.0 : value; // Ensure non-negative
      }).toList();

      return transformedPredictions;
    } catch (_) {
      rethrow;
    }
  }

  /// Process raw predictions into ExpensePrediction object
  ExpensePrediction _processPredictions(
    List<double> rawPredictions,
    List<Expense> historicalExpenses,
  ) {
    final now = DateTime.now();
    final predictionStartDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));

    // Calculate total predicted spending
    final totalPredictedSpending = rawPredictions.fold(
      0.0,
      (sum, p) => sum + p,
    );

    // Estimate category distribution from historical data
    final categoryTotals = <String, double>{};
    double totalHistorical = 0.0;

    for (final expense in historicalExpenses) {
      if (expense.type == TransactionType.expense) {
        categoryTotals[expense.category] =
            (categoryTotals[expense.category] ?? 0.0) + expense.amount;
        totalHistorical += expense.amount;
      }
    }

    final categoryPredictions = <String, double>{};
    if (totalHistorical > 0) {
      for (final entry in categoryTotals.entries) {
        final proportion = entry.value / totalHistorical;
        categoryPredictions[entry.key] = totalPredictedSpending * proportion;
      }
    }

    // Calculate anomaly score (simplified - based on prediction variance)
    final meanPrediction = totalPredictedSpending / rawPredictions.length;
    final variance =
        rawPredictions
            .map((p) => math.pow(p - meanPrediction, 2))
            .fold(0.0, (sum, v) => sum + v) /
        rawPredictions.length;
    final anomalyScore = math.min(
      1.0,
      variance / (meanPrediction * meanPrediction + 1e-8),
    );

    return ExpensePrediction(
      dailyPredictions: rawPredictions,
      categoryPredictions: categoryPredictions,
      totalPredictedSpending: totalPredictedSpending,
      anomalyScore: anomalyScore,
      predictionDate: now,
      predictionStartDate: predictionStartDate,
    );
  }

  /// Reshape list to given shape
  List _reshapeList(List list, List<int> shape) {
    if (shape.isEmpty) return list;
    if (shape.length == 1) return list.sublist(0, shape[0]);
    final size = shape.reduce((a, b) => a * b);
    if (list.length != size) {
      throw Exception(
        'Cannot reshape list of length ${list.length} to shape $shape',
      );
    }
    return _reshapeRecursive(list, shape);
  }

  List _reshapeRecursive(List list, List<int> shape) {
    if (shape.length == 1) return list.sublist(0, shape[0]);
    final chunkSize = shape.sublist(1).reduce((a, b) => a * b);
    final result = <List>[];
    for (int i = 0; i < shape[0]; i++) {
      final start = i * chunkSize;
      final end = start + chunkSize;
      result.add(_reshapeRecursive(list.sublist(start, end), shape.sublist(1)));
    }
    return result;
  }

  /// Generate spending insights from predictions
  List<SpendingInsight> generateInsights(
    ExpensePrediction prediction,
    List<Expense> recentExpenses,
  ) {
    final insights = <SpendingInsight>[];

    // Calculate recent average spending
    final recentTotal = recentExpenses
        .where((e) => e.type == TransactionType.expense)
        .fold(0.0, (sum, e) => sum + e.amount);
    final recentDays = recentExpenses.isEmpty
        ? 1
        : DateTime.now().difference(recentExpenses.first.date).inDays + 1;
    final recentAverage = recentTotal / recentDays;

    // Trend insight
    final predictedAverage =
        prediction.totalPredictedSpending / prediction.dailyPredictions.length;
    final trendChange =
        ((predictedAverage - recentAverage) / (recentAverage + 1e-8)) * 100;

    if (trendChange > 10) {
      insights.add(
        SpendingInsight(
          type: 'trend',
          title: 'Spending Increase Predicted',
          message:
              'Your spending is predicted to increase by ${trendChange.toStringAsFixed(1)}% in the coming month.',
          value: trendChange,
        ),
      );
    } else if (trendChange < -10) {
      insights.add(
        SpendingInsight(
          type: 'trend',
          title: 'Spending Decrease Predicted',
          message:
              'Your spending is predicted to decrease by ${(-trendChange).toStringAsFixed(1)}% in the coming month.',
          value: trendChange,
        ),
      );
    }

    // Anomaly insight
    if (prediction.anomalyScore > 0.7) {
      insights.add(
        SpendingInsight(
          type: 'anomaly',
          title: 'Unusual Spending Pattern Detected',
          message:
              'The AI detected unusual spending patterns. Review your expenses to ensure everything is correct.',
          value: prediction.anomalyScore,
        ),
      );
    }

    // Category insights
    final topCategory = prediction.categoryPredictions.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );
    insights.add(
      SpendingInsight(
        type: 'category',
        title: 'Top Spending Category',
        message:
            '${topCategory.key} is predicted to be your highest spending category (₹${topCategory.value.toStringAsFixed(0)}).',
        value: topCategory.value,
        category: topCategory.key,
      ),
    );

    return insights;
  }

  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}
