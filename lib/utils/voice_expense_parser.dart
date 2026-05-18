import '../models/expence.dart';
import 'transaction_parser.dart';

/// Deterministic parser for free-form voice input like
/// `"250 rupees coffee"` / `"spent 1200 on groceries"` / `"got 5000 salary"`.
///
/// Returns a partial [Expense] (with `id: ''`) suitable for pre-filling the
/// transaction modal — the user always reviews before saving.
class VoiceExpenseParser {
  VoiceExpenseParser._();

  static final _amountPattern =
      RegExp(r'(\d+(?:[.,]\d{1,2})?)\s*(?:rupees?|rs|inr|₹|k|grand)?',
          caseSensitive: false);

  static final _incomeHints = RegExp(
    r'\b(received|got|earned|salary|refund|credited|deposited|income|paid me|reimburs(?:ed|ement))\b',
    caseSensitive: false,
  );

  static final _stripWords = RegExp(
    r'\b(rupees?|rs|inr|₹|spent|spend|paid|pay|on|for|earned|got|received|i|just|today|yesterday|to|the|a|an|my|hey)\b',
    caseSensitive: false,
  );

  /// Parses [transcript]. Returns null if no amount could be extracted —
  /// the caller should keep the modal in the empty state.
  static Expense? parse(String transcript) {
    final cleaned = transcript.trim();
    if (cleaned.isEmpty) return null;

    final amount = _extractAmount(cleaned);
    if (amount == null || amount <= 0) return null;

    final lower = cleaned.toLowerCase();
    final isIncome = _incomeHints.hasMatch(lower);

    final suggestedCategory = TransactionParser.suggestCategory(cleaned);
    final category = suggestedCategory ??
        (isIncome ? 'Income' : 'Other');

    final title = _extractTitle(cleaned, category);

    return Expense(
      id: '',
      title: title,
      amount: amount,
      date: DateTime.now(),
      category: category,
      type: isIncome ? TransactionType.income : TransactionType.expense,
    );
  }

  static double? _extractAmount(String text) {
    final lower = text.toLowerCase();
    for (final m in _amountPattern.allMatches(lower)) {
      final raw = m.group(1)?.replaceAll(',', '');
      var value = double.tryParse(raw ?? '');
      if (value == null) continue;
      // Heuristic: "5 k" / "5 grand" → 5000
      final suffix = m.group(0)?.toLowerCase() ?? '';
      if (suffix.contains('k') || suffix.contains('grand')) {
        value *= 1000;
      }
      if (value > 0 && value < 10000000) return value;
    }
    return null;
  }

  static String _extractTitle(String transcript, String fallbackCategory) {
    final stripped = transcript
        .replaceAll(RegExp(r'\d+(?:[.,]\d{1,2})?'), '')
        .replaceAll(_stripWords, '')
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (stripped.isEmpty) return fallbackCategory;
    final capitalized = stripped[0].toUpperCase() + stripped.substring(1);
    return capitalized.length > 40
        ? capitalized.substring(0, 40).trim()
        : capitalized;
  }
}
