import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/design_system_components.dart';

/// Builds payment links without inventing merchant identity or payment modes.
class UPIPaymentHelper {
  static const String kUpiCurrency = 'INR';

  static bool isValidAmount(double amount) =>
      amount.isFinite &&
      amount > 0 &&
      amount < 100000000 &&
      (amount * 100 - (amount * 100).round()).abs() < 0.000001;

  static String buildUpiUri({
    required String upiId,
    required String name,
    required double amount,
    String note = '',
  }) {
    if (!isValidAmount(amount)) {
      throw ArgumentError(
          'Enter a valid amount with up to two decimal places.');
    }
    final uri = _encode({
      'pa': upiId.trim(),
      if (name.trim().isNotEmpty) 'pn': name.trim(),
      'am': amount.toStringAsFixed(2),
      'cu': kUpiCurrency,
      if (note.trim().isNotEmpty) 'tn': note.trim(),
    });
    if (!validateUpiUri(Uri.parse(uri))) throw ArgumentError('Invalid UPI ID');
    return uri;
  }

  // encodeComponent keeps literal '+' and spaces distinct in non-HTTP links.
  static String _encode(Map<String, String> params) =>
      'upi://pay?${params.entries.map(
            (entry) =>
                '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
          ).join('&')}';

  static Map<String, String> extractUpiParams(String value) {
    try {
      return Map<String, String>.from(Uri.parse(value).queryParameters);
    } on FormatException {
      return {};
    }
  }

  static bool validateUpiUri(Uri uri) {
    try {
      if (uri.scheme != 'upi' || uri.host != 'pay' || uri.fragment.isNotEmpty) {
        return false;
      }
      // Ambiguous duplicate fields must not name one payee in the UI and another in the intent.
      if (uri.queryParametersAll.values.any((values) => values.length != 1)) {
        return false;
      }
      final params = uri.queryParameters;
      if (!RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+$')
          .hasMatch(params['pa'] ?? '')) {
        return false;
      }
      if (params.containsKey('cu') && params['cu'] != 'INR') return false;
      if (params.containsKey('am')) {
        final amount = double.tryParse(params['am']!);
        if (amount == null || !isValidAmount(amount)) return false;
      }
      return true;
    } on FormatException {
      return false;
    }
  }

  static bool hasProtectedDetails(String original) {
    final params = extractUpiParams(original);
    return ['sign', 'tr', 'tid'].any((key) => params[key]?.isNotEmpty == true);
  }

  /// Signed QR data must be forwarded byte for byte; order references are kept.
  static String updateUpiAmount(String original, double amount,
      {String? note}) {
    final uri = Uri.parse(original);
    if (!validateUpiUri(uri) || !isValidAmount(amount)) {
      throw ArgumentError('Invalid UPI payment details');
    }
    final params = Map<String, String>.from(uri.queryParameters);
    if (hasProtectedDetails(original)) {
      final fixedAmount = double.tryParse(params['am'] ?? '');
      if (fixedAmount != null && fixedAmount != amount) {
        throw ArgumentError(
            'This QR has a fixed amount. Scan a new QR to change it.');
      }
      if (params['sign']?.isNotEmpty == true) {
        if (fixedAmount == null ||
            (note != null && note != (params['tn'] ?? ''))) {
          throw ArgumentError(
              'Signed QR details cannot be edited. Complete this payment in your payment app.');
        }
        return original;
      }
    }
    params['am'] = amount.toStringAsFixed(2);
    params.putIfAbsent('cu', () => kUpiCurrency);
    if (note != null) {
      if (note.trim().isEmpty) {
        params.remove('tn');
      } else {
        params['tn'] = note.trim();
      }
    }
    return _encode(params);
  }

  /// Opening an external app never establishes that payment succeeded.
  static Future<bool> launchUpiPayment(
      BuildContext context, String value) async {
    try {
      final uri = Uri.parse(value);
      if (!validateUpiUri(uri)) throw ArgumentError('Invalid UPI payment link');
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        showDesignSystemSnackBar(
            context: context,
            message:
                'Could not open this payment link. Try scanning in your payment app.',
            isError: true);
      }
      return false;
    }
  }

  static String getValidationErrorMessage(String value) =>
      'Invalid UPI QR. Check the payee, currency and amount, or scan it directly in your payment app.';
}
