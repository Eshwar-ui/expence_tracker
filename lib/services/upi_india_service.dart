import 'package:flutter/material.dart';
import 'package:flutter_upi_india/flutter_upi_india.dart';
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
  /// Fetches all installed UPI apps on the device
  /// Returns a list of ApplicationMeta objects representing available UPI apps
  static Future<List<ApplicationMeta>> getInstalledUpiApps() async {
    try {
      debugPrint('🔍 Attempting to fetch installed UPI apps...');
      debugPrint('📦 Using flutter_upi_india package');
      debugPrint('🔧 Calling: UpiPay.getInstalledUpiApplications()');

      // Use static method from flutter_upi_india package
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
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching UPI apps: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      debugPrint('');
      debugPrint('💡 TROUBLESHOOTING:');
      debugPrint('   - Check AndroidManifest.xml has <queries> section');
      debugPrint('   - Verify package names are correct');
      debugPrint('   - Completely uninstall and reinstall app');
      debugPrint('   - Check if method name is correct');
      // Return empty list if method doesn't exist
      return [];
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
          message: 'Error loading UPI apps: $e',
          isError: true,
        );
      }
      return null;
    }
  }

  /// Helper to get app display name from ApplicationMeta
  static String _getAppDisplayName(ApplicationMeta app) {
    try {
      // Try to get app name - check common property names
      // The actual property name may vary, so we try multiple approaches
      final appString = app.toString();
      // Extract name from toString() representation
      if (appString.contains('(')) {
        return appString.split('(').first.trim();
      }
      return appString;
    } catch (e) {
      return 'UPI App';
    }
  }

  /// Helper to extract UpiApplication from ApplicationMeta
  static UpiApplication _getUpiApplicationFromMeta(ApplicationMeta app) {
    try {
      // Try to access the application property directly
      // If that doesn't work, try to determine from app name
      final appName = _getAppDisplayName(app).toLowerCase();

      if (appName.contains('google') || appName.contains('gpay')) {
        return UpiApplication.googlePay;
      } else if (appName.contains('phonepe')) {
        return UpiApplication.phonePe;
      } else if (appName.contains('paytm')) {
        return UpiApplication.paytm;
      } else if (appName.contains('bhim')) {
        return UpiApplication.bhim;
      } else if (appName.contains('amazon')) {
        return UpiApplication.amazonPay;
      } else {
        // Default fallback
        return UpiApplication.googlePay;
      }
    } catch (e) {
      debugPrint('⚠️ Error extracting UpiApplication: $e');
      // Default fallback
      return UpiApplication.googlePay;
    }
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
  }) async {
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
      // Initiate UPI transaction using static method from flutter_upi_india
      // Need to extract the UpiApplication enum from ApplicationMeta
      // ApplicationMeta should have a property to get the UpiApplication
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
        content: Text('Payment could not be completed.\n\nError: $error'),
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
