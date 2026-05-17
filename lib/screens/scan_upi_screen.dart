import 'dart:async';

import 'package:expence_tracker/models/expence.dart';
import 'package:expence_tracker/services/firestore_service.dart';
import 'package:expence_tracker/services/upi_india_service.dart';
import 'package:expence_tracker/utils/upi_payment_helper.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_upi_india/flutter_upi_india.dart';
import '../widgets/design_system_components.dart';

class ScanUPIScreen extends StatefulWidget {
  const ScanUPIScreen({super.key});

  @override
  State<ScanUPIScreen> createState() => _ScanUPIScreenState();
}

class _ScanUPIScreenState extends State<ScanUPIScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool isProcessing = false;
  bool _hasDetected = false; // Prevent multiple detections
  final FirestoreService _firestoreService = FirestoreService();

  void _onDetect(BarcodeCapture capture) async {
    // CRITICAL: Prevent multiple detections and ensure scanner stability
    if (isProcessing || !mounted || _hasDetected) {
      debugPrint(
        '🔒 Scanner detection blocked: isProcessing=$isProcessing, mounted=$mounted, hasDetected=$_hasDetected',
      );
      return;
    }

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawData = barcodes.first.rawValue ?? '';
    final data = rawData.trim();

    debugPrint('═══════════════════════════════════════════');
    debugPrint('📷 QR CODE DETECTED');
    debugPrint('═══════════════════════════════════════════');
    debugPrint('📱 Raw data: $rawData');
    debugPrint('🔍 Trimmed data: $data');
    debugPrint('✅ Is UPI: ${data.toLowerCase().startsWith('upi://pay')}');
    debugPrint('═══════════════════════════════════════════');

    if (data.toLowerCase().startsWith('upi://pay')) {
      // CRITICAL: Mark as detected and stop scanner IMMEDIATELY
      // This prevents multiple triggers from the same QR code
      _hasDetected = true;
      setState(() => isProcessing = true);

      debugPrint('🛑 Stopping scanner immediately after UPI QR detection');
      await controller.stop();

      // Validate UPI URI
      if (!mounted) return;
      final uri = Uri.parse(data);

      debugPrint('🔍 Validating UPI URI...');
      if (!UPIPaymentHelper.validateUpiUri(uri)) {
        final errorMsg = UPIPaymentHelper.getValidationErrorMessage(data);
        debugPrint('❌ UPI URI validation failed: $errorMsg');
        showDesignSystemSnackBar(
          context: context,
          message: errorMsg,
          isError: true,
        );
        // Reset state and restart scanner on validation failure
        setState(() {
          isProcessing = false;
          _hasDetected = false;
        });
        unawaited(controller.start());
        return;
      }

      debugPrint('✅ UPI URI validation passed');
      debugPrint('🚀 Navigating to payment confirmation screen');

      // Navigate to payment confirmation page
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UPIPaymentConfirmationScreen(upiUri: data),
        ),
      );

      // If payment was completed, save transaction
      if (result != null && result is Map<String, dynamic>) {
        debugPrint(
          '💾 Saving transaction: ${result['payee']} - ₹${result['amount']}',
        );
        await _saveTransaction(result['payee'], result['amount'].toString());
      }

      // Reset detection flag and go back
      if (mounted) {
        setState(() {
          isProcessing = false;
          _hasDetected = false;
        });
        Navigator.pop(context);
      }
    }
  }

  Future<void> _saveTransaction(String payee, String amount) async {
    final sanitizedPayee = payee.trim().isEmpty ? 'UPI Payment' : payee.trim();
    final parsedAmount = double.tryParse(amount.trim());
    final expenseAmount = parsedAmount ?? 0.0;

    final expense = Expense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: sanitizedPayee,
      amount: expenseAmount,
      date: DateTime.now(),
      category: 'UPI Payment',
      description: 'UPI payment recorded via QR scan',
      type: TransactionType.expense,
      paymentMethod: 'UPI',
    );

    try {
      await _firestoreService.addExpense(expense);
      if (!mounted) return;
      final amountDisplay = parsedAmount != null
          ? '₹${expenseAmount.toStringAsFixed(2)}'
          : '₹${expenseAmount.toStringAsFixed(2)} (amount not provided)';
      showDesignSystemSnackBar(
        context: context,
        message: 'Transaction saved for $sanitizedPayee ($amountDisplay)',
        icon: Icons.account_balance_wallet_rounded,
      );
    } catch (e) {
      if (!mounted) return;
      showDesignSystemSnackBar(
        context: context,
        message: 'Failed to save transaction: $e',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan & Pay')),
      body: MobileScanner(controller: controller, onDetect: _onDetect),
    );
  }

  @override
  void dispose() {
    debugPrint('🧹 Disposing scanner controller');
    controller.dispose();
    super.dispose();
  }
}

// Payment Confirmation Screen
class UPIPaymentConfirmationScreen extends StatefulWidget {
  final String upiUri;

  const UPIPaymentConfirmationScreen({super.key, required this.upiUri});

  @override
  State<UPIPaymentConfirmationScreen> createState() =>
      _UPIPaymentConfirmationScreenState();
}

class _UPIPaymentConfirmationScreenState
    extends State<UPIPaymentConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isProcessing = false;

  String _payeeName = '';
  String _payeeUPI = '';
  String? _suggestedAmount;

  @override
  void initState() {
    super.initState();
    _parseUPIData();

    debugPrint('═══════════════════════════════════════════');
    debugPrint('📱 UPI PAYMENT CONFIRMATION SCREEN INIT');
    debugPrint('═══════════════════════════════════════════');
    debugPrint('🔗 Original UPI URI: ${widget.upiUri}');
    debugPrint('═══════════════════════════════════════════');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _parseUPIData() {
    try {
      final params = UPIPaymentHelper.extractUpiParams(widget.upiUri);

      debugPrint('🔍 Parsing UPI data from QR...');
      debugPrint('   Raw params: $params');

      // CRITICAL: pn is optional in many valid UPI QRs - provide smart fallback
      _payeeName = params['pn']?.trim().isNotEmpty == true
          ? params['pn']!
          : (params['pa']?.split('@').first ?? 'Merchant');
      _payeeUPI = params['pa'] ?? '';
      _suggestedAmount = params['am'];

      debugPrint('✅ Parsed UPI data:');
      debugPrint('   Payee Name: $_payeeName');
      debugPrint('   Payee UPI: $_payeeUPI');
      debugPrint('   Suggested Amount: $_suggestedAmount');

      // Pre-fill amount if available in QR
      if (_suggestedAmount != null && _suggestedAmount!.isNotEmpty) {
        _amountController.text = _suggestedAmount!;
        debugPrint('   ✅ Pre-filled amount: $_suggestedAmount');
      }
    } catch (e, stackTrace) {
      _payeeName = 'Merchant';
      debugPrint('❌ Error parsing UPI data: $e');
      debugPrint('📚 Stack trace: $stackTrace');
    }
  }

  Future<void> _proceedToPayment() async {
    if (!_formKey.currentState!.validate()) {
      debugPrint('❌ Form validation failed');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final amount = double.parse(_amountController.text.trim());

      // CRITICAL: Validate amount before proceeding
      if (amount <= 0) {
        throw Exception('Amount must be greater than zero');
      }

      debugPrint('═══════════════════════════════════════════');
      debugPrint('💳 PROCEEDING TO PAYMENT');
      debugPrint('═══════════════════════════════════════════');
      debugPrint('💰 Amount: ₹$amount');
      debugPrint('👤 Payee: $_payeeName ($_payeeUPI)');
      debugPrint('📝 Note: ${_noteController.text.trim()}');
      debugPrint('═══════════════════════════════════════════');

      if (!mounted) return;

      // Step 1: Show UPI app selector
      final selectedApp = await UpiIndiaService.showUpiAppSelector(
        context,
        title: 'Select UPI App',
      );

      if (selectedApp == null) {
        // User cancelled app selection
        debugPrint('❌ User cancelled UPI app selection');
        setState(() => _isProcessing = false);
        return;
      }

      if (!mounted) return;

      // Step 2: Initiate payment using upi_pay package
      final response = await UpiIndiaService.payNow(
        amount: amount.toStringAsFixed(2),
        app: selectedApp,
        receiverUpiAddress: _payeeUPI,
        receiverName: _payeeName,
        transactionNote: _noteController.text.trim().isEmpty
            ? 'Payment via Expense Tracker'
            : _noteController.text.trim(),
      );

      if (!mounted) return;

      // Step 3: Handle payment response based on status
      setState(() => _isProcessing = false);

      if (response.status == UpiTransactionStatus.success) {
        // Payment successful - show success dialog and save transaction
        if (!mounted) return;

        // Show success dialog with option to save
        unawaited(showDialog(
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
                Text(
                  'Your payment of ₹${amount.toStringAsFixed(2)} to $_payeeName has been completed successfully.',
                ),
                const SizedBox(height: 16),
                Text(
                  'Transaction ID: ${response.txnId ?? 'N/A'}',
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back without saving
                },
                child: const Text('Skip'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  // Return data to save transaction
                  Navigator.pop(context, {
                    'payee': _payeeName,
                    'amount': amount,
                  });
                },
                child: const Text('Save Transaction'),
              ),
            ],
          ),
        ));
      } else {
        // Payment failed or submitted - handlePaymentResponse will show appropriate message
        UpiIndiaService.handlePaymentResponse(response, context);
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      debugPrint('═══════════════════════════════════════════');
      debugPrint('❌ ERROR IN PAYMENT FLOW');
      debugPrint('═══════════════════════════════════════════');
      debugPrint('💥 Error: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      debugPrint('═══════════════════════════════════════════');

      showDesignSystemSnackBar(
        context: context,
        message: 'Payment error: ${e.toString()}',
        isError: true,
      );
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Payment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Payee Information Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.account_circle,
                              size: 32,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Paying to',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _payeeName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                                if (_payeeUPI.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _payeeUPI,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Amount Input
              Text(
                'Enter Amount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 16, top: 12),
                    child: Text(
                      '₹',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  hintText: '0.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Note (Optional)
              Text(
                'Add Note (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  hintText: 'What\'s this payment for?',
                  prefixIcon: const Icon(Icons.note_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
                maxLines: 2,
              ),

              const SizedBox(height: 40),

              // Proceed Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _proceedToPayment,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.payment),
                  label: Text(
                    _isProcessing ? 'Processing...' : 'Proceed to Pay',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Info Text
              Center(
                child: Text(
                  'You will be redirected to your UPI app',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
