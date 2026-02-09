// lib/screens/donation/donation_flow_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/campaign.dart';
import '../../providers/donation_provider.dart';

class DonationFlowScreen extends StatefulWidget {
  final Campaign campaign;

  const DonationFlowScreen({super.key, required this.campaign});

  @override
  State<DonationFlowScreen> createState() => _DonationFlowScreenState();
}

class _DonationFlowScreenState extends State<DonationFlowScreen> {
  final _phoneController = TextEditingController();
  double? _selectedAmount;
  final List<double> _presetAmounts = [500, 1000, 5000, 10000, 25000];
  bool _isRecurring = false;
  String _recurrenceFrequency = 'monthly';
  bool _isAnonymous = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleDonation() async {
    if (_selectedAmount == null || _selectedAmount! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an amount'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number'), backgroundColor: Colors.red),
      );
      return;
    }

    final donationProvider = Provider.of<DonationProvider>(context, listen: false);

    // Step 1: Initiate donation
    final donationResult = await donationProvider.initiateDonation(
      campaignId: widget.campaign.campaignId,
      amount: _selectedAmount!,
      paymentMethod: 'mpesa',
      isRecurring: _isRecurring,
      recurrenceFrequency: _isRecurring ? _recurrenceFrequency : null,
      isAnonymous: _isAnonymous,
    );

    if (!mounted) return;

    if (!donationResult['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(donationResult['message']), backgroundColor: Colors.red),
      );
      return;
    }

    final donationId = donationResult['data']['donation_id'];

    // Step 2: Initiate M-Pesa payment
    final paymentResult = await donationProvider.processMpesaPayment(
      donationId: donationId,
      phoneNumber: _phoneController.text,
    );

    if (!mounted) return;

    if (paymentResult['success']) {
      // Show waiting dialog
      _showPaymentWaitingDialog(donationId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(paymentResult['message']), backgroundColor: Colors.red),
      );
    }
  }

  void _showPaymentWaitingDialog(String donationId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Waiting for Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Please check your phone and enter your M-Pesa PIN'),
            const SizedBox(height: 8),
            Text('Amount: KES ${NumberFormat("#,##0").format(_selectedAmount)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _checkPaymentStatus(donationId);
            },
            child: const Text('Check Status'),
          ),
        ],
      ),
    );

    // Auto-check status after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        Navigator.of(context).pop();
        _checkPaymentStatus(donationId);
      }
    });
  }

  Future<void> _checkPaymentStatus(String donationId) async {
    final donationProvider = Provider.of<DonationProvider>(context, listen: false);
    final result = await donationProvider.checkPaymentStatus(donationId);

    if (!mounted) return;

    if (result['success']) {
      final status = result['data']['donation_status'];
      if (status == 'completed') {
        _showSuccessDialog();
      } else if (status == 'failed') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment failed. Please try again.'), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment is still processing...'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Success!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text('Thank you for your donation!'),
            const SizedBox(height: 8),
            Text('Amount: KES ${NumberFormat("#,##0").format(_selectedAmount)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Make a Donation'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Campaign Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.campaign.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.campaign.categoryDisplay,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Amount Selection
            const Text(
              'Select Amount',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetAmounts.map((amount) {
                final isSelected = _selectedAmount == amount;
                return ChoiceChip(
                  label: Text(currencyFormatter.format(amount)),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedAmount = amount);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Custom Amount
            TextField(
              decoration: const InputDecoration(
                labelText: 'Custom Amount (KES)',
                prefixIcon: Icon(Icons.money),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _selectedAmount = double.tryParse(value);
                });
              },
            ),
            const SizedBox(height: 24),
            // Recurring Donation
            SwitchListTile(
              title: const Text('Make this recurring'),
              subtitle: Text(_isRecurring ? 'Monthly donation' : 'One-time donation'),
              value: _isRecurring,
              onChanged: (value) => setState(() => _isRecurring = value),
            ),
            if (_isRecurring)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButton<String>(
                  value: _recurrenceFrequency,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                    DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                  ],
                  onChanged: (value) => setState(() => _recurrenceFrequency = value!),
                ),
              ),
            const SizedBox(height: 16),
            // Anonymous Donation
            CheckboxListTile(
              title: const Text('Donate anonymously'),
              value: _isAnonymous,
              onChanged: (value) => setState(() => _isAnonymous = value!),
            ),
            const SizedBox(height: 24),
            // Phone Number
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'M-Pesa Phone Number',
                prefixIcon: Icon(Icons.phone),
                hintText: '0712345678',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            // Summary
            if (_selectedAmount != null && _selectedAmount! > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E40AF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Amount:'),
                        Text(
                          currencyFormatter.format(_selectedAmount),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (_isRecurring) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Frequency:'),
                          Text(_recurrenceFrequency, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 24),
            // Donate Button
            Consumer<DonationProvider>(
              builder: (context, donationProvider, _) {
                return ElevatedButton(
                  onPressed: donationProvider.isLoading ? null : _handleDonation,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: donationProvider.isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Text(
                    'Proceed to Payment',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}