/// Match independent reports using references, or a short time/merchant window.
class TransactionIdentity {
  static String? reference(String text) {
    return RegExp(
      r'\b(?:utr|rrn|(?:upi\s+)?ref(?:erence)?(?:\s*(?:no|number))?|txn\s*id)\s*[:#.-]?\s*([a-z0-9]{8,})\b',
      caseSensitive: false,
    ).firstMatch(text)?.group(1)?.toLowerCase();
  }

  static bool matches({
    required double amount,
    required String type,
    required DateTime date,
    required String merchant,
    required String text,
    required double otherAmount,
    required String otherType,
    required DateTime otherDate,
    required String otherMerchant,
    required String otherText,
  }) {
    if (amount != otherAmount || type != otherType) return false;
    final ref = reference(text);
    final otherRef = reference(otherText);
    if (ref != null && otherRef != null) return ref == otherRef;
    if (date.difference(otherDate).abs() > const Duration(minutes: 2)) {
      return false;
    }
    String normalize(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final name = normalize(merchant);
    final otherName = normalize(otherMerchant);
    return name.length >= 3 && name == otherName;
  }
}
