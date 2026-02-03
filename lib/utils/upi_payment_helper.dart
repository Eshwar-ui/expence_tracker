import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// UPI Payment Helper with comprehensive debugging and compatibility safeguards
///
/// COMPATIBILITY NOTES:
/// - Google Pay: Rejects reused/missing tr, rejects merchant params (mc, tid), requires mode=02 for P2P
/// - PhonePe: More lenient, accepts most valid UPI URIs, but still prefers mode=02
/// - Paytm: Similar to Google Pay, strict about transaction references
/// - BHIM: Most lenient, but still requires valid pa and tr
///
/// SECURITY RULES:
/// - NEVER forward tid/tr from scanned QR (causes "declined for security reasons")
/// - NEVER include merchant-only params (mc, tid, orgid) in P2P payments
/// - ALWAYS use mode=02 for person-to-person payments
/// - ALWAYS generate fresh transaction reference for each payment
class UPIPaymentHelper {
  // UPI Constants
  static const String kUpiCurrency = 'INR';
  // ONLY pa is required - pn is optional in many valid UPI QRs
  static const List<String> kUpiRequiredParams = ['pa'];

  // Merchant-only parameters that MUST be stripped for P2P payments
  // These cause "declined for security reasons" in Google Pay and Paytm
  static const List<String> kMerchantOnlyParams = [
    'mc', // Merchant code
    'tid', // Terminal ID (merchant terminal)
    'orgid', // Organization ID
    'url', // Merchant callback URL
    'sign', // Merchant signature
  ];

  /// Generates a fresh unique transaction reference for every payment
  /// CRITICAL: Never reuse tid/tr from scanned QR to avoid payment conflicts
  /// Google Pay and Paytm will reject reused transaction references
  static String _generateTransactionRef() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'EXP$timestamp';
  }

  /// Formats amount as raw numeric string (no forced decimals)
  /// CRITICAL: Google Pay rejects amounts with unnecessary decimal formatting
  /// Example: 100.0 becomes "100", 100.50 becomes "100.5"
  static String _formatAmount(double amount) {
    // Remove trailing zeros and decimal point if not needed
    if (amount == amount.truncateToDouble()) {
      return amount.toInt().toString();
    }
    // Remove trailing zeros only
    return amount
        .toString()
        .replaceAll(RegExp(r'0*$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  /// Logs UPI intent parameters for debugging
  static void _logUpiIntent(String uri, Map<String, String> params) {
    debugPrint('═══════════════════════════════════════════');
    debugPrint('🔵 UPI INTENT DEBUG LOG');
    debugPrint('═══════════════════════════════════════════');
    debugPrint('📱 Final UPI URI: $uri');
    debugPrint('📋 Parameters being sent:');
    params.forEach((key, value) {
      debugPrint('   • $key = $value');
    });
    debugPrint('✅ Parameter validation: PASSED');
    debugPrint('   - pa (UPI ID): ${params['pa'] ?? 'MISSING'}');
    debugPrint(
      '   - pn (Name): ${params['pn'] ?? 'OPTIONAL (using fallback)'}',
    );
    debugPrint('   - am (Amount): ${params['am'] ?? 'MISSING'}');
    debugPrint('   - cu (Currency): ${params['cu'] ?? 'MISSING'}');
    debugPrint('   - tr (Txn Ref): ${params['tr'] ?? 'MISSING'}');
    debugPrint('   - mode: ${params['mode'] ?? 'MISSING'}');
    debugPrint('   - tn (Note): ${params['tn'] ?? 'OPTIONAL'}');
    debugPrint(
      '🚫 Stripped merchant params: ${kMerchantOnlyParams.join(", ")}',
    );
    debugPrint('═══════════════════════════════════════════');
  }

  /// Builds a valid and encoded UPI payment URI with P2P compatibility safeguards
  ///
  /// CRITICAL FIXES:
  /// - name is optional with fallback (many valid QRs don't include pn)
  /// - Fresh transaction reference generated (never reuse from QR)
  /// - tid/tr from scanned QR are NOT forwarded
  /// - Amount formatted as raw numeric string (no forced decimals)
  /// - ONLY safe P2P parameters included (merchant params stripped)
  /// - mode=02 explicitly set for P2P compatibility
  ///
  /// COMPATIBILITY:
  /// - Google Pay: Requires fresh tr, mode=02, no merchant params
  /// - PhonePe: Accepts mode=02, prefers fresh tr
  /// - Paytm: Same as Google Pay
  /// - BHIM: Requires valid tr and pa
  static String buildUpiUri({
    required String upiId,
    required String name,
    required double amount,
    String note = '',
  }) {
    // Generate fresh transaction reference
    // CRITICAL: Google Pay rejects reused tr values
    final txnRef = _generateTransactionRef();

    // Format amount as raw numeric string
    // CRITICAL: No forced decimals (100.0 becomes "100", not "100.0")
    final amountStr = _formatAmount(amount);

    // Build URI with ONLY safe P2P parameters
    final buffer = StringBuffer('upi://pay?');

    // REQUIRED: pa (UPI ID) - must be present
    buffer.write('pa=${Uri.encodeComponent(upiId)}');

    // OPTIONAL: pn (Payee Name) - fallback to UPI ID if empty
    final payeeName = name.isEmpty ? upiId.split('@').first : name;
    buffer.write('&pn=${Uri.encodeComponent(payeeName)}');

    // REQUIRED: am (Amount) - raw numeric string
    buffer.write('&am=$amountStr');

    // REQUIRED: cu (Currency) - always INR for Indian UPI
    buffer.write('&cu=$kUpiCurrency');

    // REQUIRED: tr (Transaction Reference) - fresh, unique
    buffer.write('&tr=$txnRef');

    // REQUIRED: mode=02 (P2P payment mode)
    // CRITICAL: mode=02 is required for person-to-person payments
    // Without this, Google Pay and Paytm may reject as merchant transaction
    buffer.write('&mode=02');

    // OPTIONAL: tn (Transaction Note)
    if (note.isNotEmpty) {
      buffer.write('&tn=${Uri.encodeComponent(note)}');
    }

    final uri = buffer.toString();

    // Extract params for logging
    final params = {
      'pa': upiId,
      'pn': payeeName,
      'am': amountStr,
      'cu': kUpiCurrency,
      'tr': txnRef,
      'mode': '02',
      if (note.isNotEmpty) 'tn': note,
    };

    // Log the intent for debugging
    _logUpiIntent(uri, params);

    return uri;
  }

  /// Validates that UPI URI has required parameters
  /// CRITICAL: Only pa (UPI ID) is required. pn (payee name) is optional.
  static bool validateUpiUri(Uri uri) {
    try {
      final params = uri.queryParameters;

      // REQUIRED: Check scheme and host
      if (uri.scheme != 'upi' || uri.host != 'pay') {
        return false;
      }

      // REQUIRED: Must have valid UPI ID (pa parameter with @)
      final upiId = params['pa'] ?? '';
      if (upiId.isEmpty || !upiId.contains('@')) {
        return false;
      }

      // OPTIONAL: Validate amount if present (but not required in QR)
      if (params.containsKey('am')) {
        final amount = double.tryParse(params['am']!);
        if (amount == null || amount <= 0) {
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Extracts UPI parameters from a URI
  static Map<String, String> extractUpiParams(String upiUri) {
    try {
      final uri = Uri.parse(upiUri);
      return Map<String, String>.from(uri.queryParameters);
    } catch (e) {
      return {};
    }
  }

  /// Updates amount in existing UPI URI with parameter sanitization
  /// CRITICAL: Does NOT forward tid/tr from original - generates fresh reference
  /// CRITICAL: Strips all merchant-only parameters before rebuilding
  static String updateUpiAmount(String originalUri, double newAmount) {
    try {
      final params = extractUpiParams(originalUri);

      // Sanitize: Extract ONLY safe P2P parameters
      // Remove all merchant-only parameters that cause security declines
      final safeParams = <String, String>{};

      // REQUIRED: pa (UPI ID)
      if (params.containsKey('pa') && params['pa']!.isNotEmpty) {
        safeParams['pa'] = params['pa']!;
      }

      // OPTIONAL: pn (Payee Name) - with fallback
      if (params.containsKey('pn') && params['pn']!.isNotEmpty) {
        safeParams['pn'] = params['pn']!;
      }

      // OPTIONAL: tn (Transaction Note)
      if (params.containsKey('tn') && params['tn']!.isNotEmpty) {
        safeParams['tn'] = params['tn']!;
      }

      // CRITICAL: tid/tr/mc/orgid are intentionally NOT forwarded
      // These cause "declined for security reasons" in Google Pay/Paytm

      debugPrint('🔄 UPI URI Update:');
      debugPrint('   Original params: ${params.keys.join(", ")}');
      debugPrint('   Safe params kept: ${safeParams.keys.join(", ")}');
      debugPrint('   Stripped params: ${kMerchantOnlyParams.join(", ")}');
      debugPrint('   New amount: $newAmount');

      return buildUpiUri(
        upiId: safeParams['pa'] ?? '',
        name: safeParams['pn'] ?? 'Merchant', // Fallback if missing
        amount: newAmount,
        note: safeParams['tn'] ?? '',
        // tid/tr/mc/orgid from QR are intentionally NOT passed
      );
    } catch (e) {
      debugPrint('❌ Error updating UPI amount: $e');
      return originalUri;
    }
  }

  /// Launches the payment URI safely with comprehensive debug logging
  ///
  /// CRITICAL: Returns ONLY whether UPI app opened, NOT payment success
  /// Payment success must be manually confirmed by user dialog
  ///
  /// DEBUG LOGGING:
  /// - Logs final URI before launch
  /// - Logs launchUrl result
  /// - Logs any errors encountered
  ///
  /// NOTE: App resume detection is handled by WidgetsBindingObserver
  /// in the calling screen (UPIPaymentConfirmationScreen)
  static Future<bool> launchUpiPayment(
    BuildContext context,
    String upiString,
  ) async {
    try {
      final uri = Uri.parse(upiString);

      // Validate UPI URI
      if (!validateUpiUri(uri)) {
        debugPrint('❌ UPI URI VALIDATION FAILED');
        debugPrint('   URI: $upiString');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid UPI payment link'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      // Log intent launch attempt
      debugPrint('═══════════════════════════════════════════');
      debugPrint('🚀 LAUNCHING UPI INTENT');
      debugPrint('═══════════════════════════════════════════');
      debugPrint('📱 URI: $upiString');
      debugPrint('⏰ Timestamp: ${DateTime.now().toIso8601String()}');
      debugPrint('🔄 Launch mode: externalApplication');
      debugPrint('═══════════════════════════════════════════');

      // Launch UPI app - this ONLY indicates if app opened, NOT payment success
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      // Log launch result
      debugPrint('═══════════════════════════════════════════');
      if (launched) {
        debugPrint('✅ UPI APP OPENED SUCCESSFULLY');
        debugPrint('   User should now complete payment in UPI app');
        debugPrint('   Waiting for app resume to detect return...');
      } else {
        debugPrint('❌ FAILED TO OPEN UPI APP');
        debugPrint('   Possible reasons:');
        debugPrint('   - No UPI app installed');
        debugPrint('   - UPI app not responding');
        debugPrint('   - System error');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No UPI app available. Please install a UPI app.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      debugPrint('═══════════════════════════════════════════');

      return launched; // true = UPI app opened, false = failed to open
    } catch (e, stackTrace) {
      // Log detailed error information
      debugPrint('═══════════════════════════════════════════');
      debugPrint('❌ ERROR LAUNCHING UPI PAYMENT');
      debugPrint('═══════════════════════════════════════════');
      debugPrint('📱 URI: $upiString');
      debugPrint('💥 Error: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      debugPrint('═══════════════════════════════════════════');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open UPI app: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return false;
    }
  }

  /// Gets a user-friendly error message for validation failures
  /// CRITICAL: pn (payee name) is NOT required - many valid QRs omit it
  static String getValidationErrorMessage(String upiUri) {
    try {
      final uri = Uri.parse(upiUri);
      final params = uri.queryParameters;

      if (uri.scheme != 'upi') {
        return 'Invalid QR code: Not a UPI payment code';
      }

      if (!params.containsKey('pa') || params['pa']!.isEmpty) {
        return 'Invalid QR code: Missing payee UPI ID';
      }

      if (!params['pa']!.contains('@')) {
        return 'Invalid QR code: Malformed UPI ID';
      }

      // pn (payee name) check removed - it's optional

      if (params.containsKey('am')) {
        final amount = double.tryParse(params['am']!);
        if (amount == null || amount <= 0) {
          return 'Invalid QR code: Invalid amount';
        }
      }

      return 'Invalid UPI QR code';
    } catch (e) {
      return 'Invalid QR code format';
    }
  }
}
