import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_upi_india/flutter_upi_india.dart';
import '../utils/upi_payment_helper.dart';
import '../widgets/design_system_components.dart';

/// UPI India Service for payment integration with app selection and status tracking
///
/// This implementation uses the `flutter_upi_india` package.
/// Documentation: https://pub.dev/packages/flutter_upi_india
///
/// This service provides:
/// - Fetching installed UPI apps (Google Pay, PhonePe, Paytm, BHIM, etc.)
/// - Showing app selection bottom sheet
/// - Initiating UPI payments with proper parameters
/// - Handling payment responses (SUCCESS, SUBMITTED, FAILURE)
///
/// USAGE:
/// ```dart
/// // 1. Show app selector and get selected app
/// final selectedApp = await UpiIndiaService.showUpiAppSelector(context);
///
/// // 2. Initiate payment
/// if (selectedApp != null) {
///   final response = await UpiIndiaService.payNow(
///     amount: '100.00',
///     app: selectedApp,
///     receiverUpiAddress: 'merchant@upi',
///     receiverName: 'Merchant Name',
///     transactionNote: 'Payment for order',
///   );
///
///   // 3. Handle response
///   UpiIndiaService.handlePaymentResponse(response, context);
/// }
/// ```
class UpiIndiaService {
  static const _paymentChannel =
      MethodChannel('com.eshwar.expensetracker/upi_payment');

  /// Fetches all installed UPI apps on the device
  /// Returns a list of ApplicationMeta objects representing available UPI apps
  static Future<List<ApplicationMeta>> getInstalledUpiApps() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final apps = await _paymentChannel
                .invokeListMethod<dynamic>('getInstalledApps') ??
            [];
        return apps.map((item) {
          final data = Map<String, dynamic>.from(item as Map);
          return ApplicationMeta.android(
            UpiApplication(
                androidPackageName: data['packageName'] as String,
                appName: data['appName'] as String),
            data['icon'] as Uint8List,
            0,
            0,
          );
        }).toList();
      }
      debugPrint('🔍 Attempting to fetch installed UPI apps...');
      debugPrint('📦 Using flutter_upi_india package');
      debugPrint('🔧 Calling: UpiPay.getInstalledUpiApplications()');

      // iOS discovery continues to use the plugin.
      final apps = await UpiPay.getInstalledUpiApplications();

      debugPrint('📱 Found ${apps.length} installed UPI apps');
      if (apps.isEmpty) {
        debugPrint('⚠️ WARNING: No UPI apps found!');
        debugPrint('');
        debugPrint('🔍 Possible causes:');
        debugPrint('   1. No UPI apps installed on device');
        debugPrint('   2. Android 11+ package visibility restrictions');
        debugPrint(
          '   3. Missing <queries> declarations in AndroidManifest.xml',
        );
        debugPrint(
          '   4. App needs to be COMPLETELY UNINSTALLED and reinstalled',
        );
        debugPrint('   5. Package names in <queries> might be incorrect');
        debugPrint('');
        debugPrint('💡 SOLUTIONS TO TRY:');
        debugPrint('   ✅ Uninstall the app completely from device');
        debugPrint('   ✅ Run: flutter clean');
        debugPrint('   ✅ Run: flutter pub get');
        debugPrint('   ✅ Run: flutter run (fresh install)');
        debugPrint(
          '   ✅ Verify UPI apps are installed (Google Pay, PhonePe, Paytm)',
        );
        debugPrint('   ✅ Check AndroidManifest.xml has correct package names');
        debugPrint('   ✅ Ensure <queries> section is inside <manifest> tag');
      } else {
        debugPrint('✅ UPI Apps successfully detected:');
        for (var app in apps) {
          final appName = _getAppDisplayName(app);
          debugPrint('   📱 $appName');
          debugPrint('      Full: ${app.toString()}');
        }
      }

      return apps;
    } on MissingPluginException {
      throw PlatformException(
        code: 'APP_UPDATE_REQUIRED',
        message:
            'Payment app detection needs the updated Android app. Rebuild and reinstall the app; hot reload cannot update this feature.',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching UPI apps: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      debugPrint('');
      debugPrint('💡 TROUBLESHOOTING:');
      debugPrint('   - Check AndroidManifest.xml has <queries> section');
      debugPrint('   - Verify package names are correct');
      debugPrint('   - Completely uninstall and reinstall app');
      debugPrint('   - Check if method name is correct');
      // A detection failure does not mean that no payment apps are installed.
      Error.throwWithStackTrace(e, stackTrace);
    }
  }

  /// Shows a bottom sheet with list of installed UPI apps for user selection
  /// Returns the selected ApplicationMeta, or null if user cancels
  static Future<ApplicationMeta?> showUpiAppSelector(
    BuildContext context, {
    String? title,
  }) async {
    try {
      // Fetch installed UPI apps
      final apps = await getInstalledUpiApps();

      if (apps.isEmpty) {
        // No UPI apps installed
        if (context.mounted) {
          showDesignSystemSnackBar(
            context: context,
            message:
                'No UPI apps found. Please install a UPI app like Google Pay, PhonePe, or Paytm.',
            isError: true,
          );
        }
        return null;
      }

      // Show bottom sheet with app selection
      if (!context.mounted) return null;

      return await showModalBottomSheet<ApplicationMeta>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  title ?? 'Select UPI App',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              // App list
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: apps.length,
                  itemBuilder: (context, index) {
                    final app = apps[index];
                    final appName = _getAppDisplayName(app);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.payment,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        appName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      onTap: () {
                        Navigator.pop(context, app);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error showing UPI app selector: $e');
      if (context.mounted) {
        showDesignSystemSnackBar(
          context: context,
          message: e is PlatformException
              ? (e.message ?? 'Could not check payment apps. Try again.')
              : 'Could not check payment apps. Try again or pay directly in your payment app.',
          isError: true,
        );
      }
      return null;
    }
  }

  /// Helper to get app display name from ApplicationMeta
  static String _getAppDisplayName(ApplicationMeta app) {
    return app.upiApplication.appName;
  }

  /// Helper to extract UpiApplication from ApplicationMeta
  static UpiApplication _getUpiApplicationFromMeta(ApplicationMeta app) {
    return app.upiApplication;
  }

  /// Initiates a UPI payment transaction
  ///
  /// PARAMETERS:
  /// - amount: Payment amount as string (e.g., "100.00" or "100")
  /// - app: Selected ApplicationMeta from showUpiAppSelector()
  /// - receiverUpiAddress: Receiver's UPI ID (e.g., "merchant@upi")
  /// - receiverName: Receiver's display name
  /// - transactionNote: Optional note for the transaction
  /// - transactionRef: Optional transaction reference (auto-generated if not provided)
  ///
  /// RETURNS: UpiTransactionResponse with status (SUCCESS, SUBMITTED, FAILURE, etc.)
  static Future<UpiTransactionResponse> payNow({
    required String amount,
    required ApplicationMeta app,
    required String receiverUpiAddress,
    required String receiverName,
    String? transactionNote,
    String? transactionRef,
    String? originalUpiUri,
  }) async {
    final parsedAmount = double.tryParse(amount);
    if (parsedAmount == null || !UPIPaymentHelper.isValidAmount(parsedAmount)) {
      throw ArgumentError(
          'Enter a valid amount with up to two decimal places.');
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final uri = originalUpiUri != null
          ? UPIPaymentHelper.updateUpiAmount(originalUpiUri, parsedAmount,
              note: transactionNote)
          : UPIPaymentHelper.buildUpiUri(
              upiId: receiverUpiAddress,
              name: receiverName,
              amount: parsedAmount,
              note: transactionNote ?? '');
      final raw = await _paymentChannel.invokeMethod<String>('pay', {
        'uri': uri,
        'packageName': app.upiApplication.androidPackageName,
      });
      if (raw == null || raw.trim().isEmpty) {
        throw PlatformException(
            code: 'UNCONFIRMED',
            message:
                'No confirmation returned. Check your payment app or bank before trying again.');
      }
      return parseAndroidResponse(raw);
    }
    // Generate unique transaction reference if not provided
    final txnRef =
        transactionRef ?? 'TXN${DateTime.now().millisecondsSinceEpoch}';

    debugPrint('═══════════════════════════════════════════');
    debugPrint('💳 INITIATING UPI PAYMENT');
    debugPrint('═══════════════════════════════════════════');
    debugPrint('📱 App: ${_getAppDisplayName(app)}');
    debugPrint('💰 Amount: ₹$amount');
    debugPrint('👤 Receiver: $receiverName ($receiverUpiAddress)');
    debugPrint('📝 Note: ${transactionNote ?? "N/A"}');
    debugPrint('🆔 Transaction Ref: $txnRef');
    debugPrint('═══════════════════════════════════════════');

    try {
      // Non-Android fallback uses the selected application directly.
      final upiApp = _getUpiApplicationFromMeta(app);

      final response = await UpiPay.initiateTransaction(
        amount: amount,
        app: upiApp,
        receiverName: receiverName,
        receiverUpiAddress: receiverUpiAddress,
        transactionRef: txnRef,
        transactionNote: transactionNote ?? 'Payment',
      );

      debugPrint('═══════════════════════════════════════════');
      debugPrint('📥 UPI PAYMENT RESPONSE RECEIVED');
      debugPrint('═══════════════════════════════════════════');
      debugPrint('📊 Status: ${response.status}');
      debugPrint('🆔 Transaction ID: ${response.txnId ?? "N/A"}');
      debugPrint('📝 Response Code: ${response.responseCode ?? "N/A"}');
      debugPrint('💬 Approval Ref: ${response.approvalRefNo ?? "N/A"}');
      debugPrint('═══════════════════════════════════════════');

      return response;
    } catch (e, stackTrace) {
      debugPrint('❌ Error initiating UPI payment: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      debugPrint(
        '💡 Tip: Check package documentation for correct parameter names',
      );

      // Re-throw to let caller handle
      rethrow;
    }
  }

  /// Opens the payment app's home screen; this never establishes payment status.
  static Future<void> openPaymentApp(ApplicationMeta app) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Opening payment apps directly requires Android.');
    }
    await _paymentChannel.invokeMethod<void>('openApp', {
      'packageName': app.upiApplication.androidPackageName,
    });
  }

  /// Missing, unknown or contradictory responses cannot establish success.
  @visibleForTesting
  static UpiTransactionResponse parseAndroidResponse(String raw) {
    final fields = Uri.splitQueryString(raw)
        .map((key, value) => MapEntry(key.toLowerCase(), value));
    final status = fields['status']?.trim().toLowerCase();
    if (!['success', 's', 'submitted', 'failure', 'failed'].contains(status)) {
      throw PlatformException(
          code: 'UNCONFIRMED',
          message:
              'The payment app did not return a clear result. Check your payment app or bank before trying again.');
    }
    if ((status == 'success' || status == 's') &&
        fields['responsecode']?.isNotEmpty == true &&
        fields['responsecode'] != '00') {
      throw PlatformException(
          code: 'UNCONFIRMED',
          message:
              'The payment result could not be confirmed. Check your payment app or bank before trying again.');
    }
    return UpiTransactionResponse.android(
        fields.entries.map((entry) => '${entry.key}=${entry.value}').join('&'));
  }

  /// Handles UPI payment response and shows appropriate UI feedback
  ///
  /// STATUS HANDLING:
  /// - SUCCESS: Payment completed successfully
  /// - SUBMITTED: Payment submitted but not yet confirmed
  /// - FAILURE: Payment failed
  /// - OTHER: Handle other statuses as needed
  static void handlePaymentResponse(
    UpiTransactionResponse response,
    BuildContext context,
  ) {
    if (!context.mounted) return;

    switch (response.status) {
      case UpiTransactionStatus.success:
        // Payment successful
        _showSuccessDialog(
          context,
          transactionId: response.txnId ?? 'N/A',
          approvalRefNo: response.approvalRefNo ?? 'N/A',
        );
        break;

      case UpiTransactionStatus.submitted:
        // Payment submitted but not confirmed
        _showSubmittedSnackBar(context, response);
        break;

      case UpiTransactionStatus.failure:
        // Payment failed
        _showFailureDialog(
          context,
          error: response.responseCode ?? 'Unknown error',
        );
        break;

      default:
        // Other statuses
        _showInfoSnackBar(context, 'Payment status: ${response.status}');
        break;
    }
  }

  /// Shows success dialog when payment is successful
  static void _showSuccessDialog(
    BuildContext context, {
    required String transactionId,
    required String approvalRefNo,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Payment Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your payment has been completed successfully.'),
            const SizedBox(height: 16),
            _buildInfoRow('Transaction ID', transactionId),
            _buildInfoRow('Approval Ref', approvalRefNo),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Shows failure dialog when payment fails
  static void _showFailureDialog(
    BuildContext context, {
    required String error,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Payment Failed'),
          ],
        ),
        content: Text(
            'The payment app reported a failure.\n\nCode: $error\n\nIf it rejects this handoff, scan the original QR directly in your payment app. Bank SMS or payment alerts can still track the expense.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Shows snackbar for submitted status
  static void _showSubmittedSnackBar(
    BuildContext context,
    UpiTransactionResponse response,
  ) {
    showDesignSystemSnackBar(
      context: context,
      message:
          'Payment submitted. Status: ${response.responseCode ?? "Pending"}',
      icon: Icons.info_outline_rounded,
    );
  }

  /// Shows info snackbar
  static void _showInfoSnackBar(BuildContext context, String message) {
    showDesignSystemSnackBar(
      context: context,
      message: message,
    );
  }

  /// Helper to build info row in dialog
  static Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  /// Helper method to extract UPI parameters from scanned QR code
  static Map<String, String> extractUpiParamsFromQr(String qrData) {
    try {
      final uri = Uri.parse(qrData);
      if (uri.scheme != 'upi' || uri.host != 'pay') {
        return {};
      }
      return Map<String, String>.from(uri.queryParameters);
    } catch (e) {
      debugPrint('❌ Error parsing UPI QR: $e');
      return {};
    }
  }
}
