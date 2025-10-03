import 'package:flutter/material.dart';
import 'package:expence_tracker/models/transaction_sms.dart';
import 'package:expence_tracker/services/sms_service.dart';
import 'package:expence_tracker/services/sms_tracking_service.dart';
import 'package:expence_tracker/screens/sms_transaction_dialog.dart';
import 'package:intl/intl.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final SMSService _smsService = SMSService();
  final SMSTrackingService _trackingService = SMSTrackingService();

  List<TransactionSMS> _transactions = [];
  Set<String> _addedTransactions = {};
  bool _isLoading = false;
  bool _hasPermission = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAddedTransactions();
    _checkPermissionAndScan();
  }

  Future<void> _loadAddedTransactions() async {
    try {
      final addedTransactions = await _trackingService.getAddedTransactionIds();
      if (!mounted) return;
      setState(() {
        _addedTransactions = addedTransactions;
      });
    } catch (e) {
      print('Failed to load added transactions: $e');
    }
  }

  Future<void> _checkPermissionAndScan() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // First run the test to see what's happening
      await _smsService.testSMSScanning();

      if (!await _smsService.hasSMSPermission()) {
        final granted = await _smsService.requestSMSPermission();
        if (!granted) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _errorMessage = 'SMS permission is required to scan transactions';
          });
          return;
        }
      }

      if (!mounted) return;
      setState(() => _hasPermission = true);
      await _scanTransactions();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to scan transactions: $e';
      });
    }
  }

  Future<void> _scanTransactions() async {
    try {
      final transactions = await _smsService.getRecentTransactions(limit: 30);
      if (!mounted) return;
      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to scan transactions: $e';
      });
    }
  }

  void _showEditTransactionDialog(TransactionSMS transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SMSTransactionDialog(
        smsTransaction: transaction,
        onTransactionAdded: () async {
          try {
            await _trackingService.markTransactionAsAdded(transaction.id);
            if (!mounted) return;
            setState(() {
              _addedTransactions.add(transaction.id);
            });
          } catch (e) {
            print('Failed to mark transaction as added: $e');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Scan Transactions',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: _scanTransactions,
            tooltip: 'Rescan',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Scanning SMS messages...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (!_hasPermission) {
      return _buildPermissionState();
    }

    if (_transactions.isEmpty) {
      return _buildEmptyState();
    }

    return _buildTransactionList();
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _checkPermissionAndScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security, size: 64, color: Colors.orange[300]),
            const SizedBox(height: 16),
            Text(
              'Permission Required',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We need SMS permission to scan your transaction messages. This helps automatically detect your expenses.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _checkPermissionAndScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Grant Permission',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sms_failed, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Transactions Found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We couldn\'t find any recent transaction messages in your SMS. Make sure you have received bank alerts recently.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _scanTransactions,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Scan Again',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _transactions.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.sms, color: Colors.white, size: 32),
                const SizedBox(height: 8),
                Text(
                  'Found ${_transactions.length} Transactions',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_addedTransactions.length} Added to Expenses',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap the + button to edit and add transactions to your expense list',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: const Text(
                    'Demo Mode - Using Mock Data',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final transaction = _transactions[index - 1];
        return _buildTransactionCard(transaction);
      },
    );
  }

  Widget _buildTransactionCard(TransactionSMS transaction) {
    final isAdded = _addedTransactions.contains(transaction.id);
    final isDebit = transaction.transactionType == 'debit';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: isAdded ? Border.all(color: Colors.green, width: 2) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDebit
                    ? Colors.red.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isDebit ? Icons.arrow_downward : Icons.arrow_upward,
                color: isDebit ? Colors.red : Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${transaction.bankName} • ${DateFormat('MMM dd, yyyy').format(transaction.date)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Balance: ${transaction.balance}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  if (transaction.referenceNumber != 'N/A') ...[
                    const SizedBox(height: 2),
                    Text(
                      'Ref: ${transaction.referenceNumber}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 10),
                    ),
                  ],
                  if (isAdded) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Added',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isDebit ? '-' : '+'}₹${transaction.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDebit ? Colors.red : Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                if (!isAdded)
                  IconButton(
                    onPressed: () => _showEditTransactionDialog(transaction),
                    icon: const Icon(
                      Icons.add_circle,
                      color: Colors.deepPurple,
                    ),
                    tooltip: 'Add to expenses',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
