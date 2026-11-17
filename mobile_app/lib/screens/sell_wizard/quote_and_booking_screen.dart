import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../orders/track_order_screen.dart';

class QuoteAndBookingScreen extends StatefulWidget {
  final BrandModel brand;
  final PhoneModelItem model;
  final StorageVariantModel variant;
  final List<String> selectedOptionCodes;

  const QuoteAndBookingScreen({
    super.key,
    required this.brand,
    required this.model,
    required this.variant,
    required this.selectedOptionCodes,
  });

  @override
  State<QuoteAndBookingScreen> createState() => _QuoteAndBookingScreenState();
}

class _QuoteAndBookingScreenState extends State<QuoteAndBookingScreen> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  bool _calculating = true;
  bool _submitting = false;

  double _estimatedPrice = 0.0;
  List<Map<String, dynamic>> _breakdown = [];
  bool _isRejection = false;
  String _rejectionReason = '';

  // Form Fields
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _pincodeController = TextEditingController(text: '641601');
  final _upiController = TextEditingController();

  String _payoutType = 'UPI';
  String _pickupSlot = 'Morning (10:00 AM - 1:00 PM)';

  @override
  void initState() {
    super.initState();
    final user = _api.currentUser;
    if (user != null) {
      _nameController.text = user.fullName;
      _phoneController.text = user.phone;
    }
    _fetchCalculation();
  }

  Future<void> _fetchCalculation() async {
    setState(() => _calculating = true);
    try {
      final res = await _api.calculateEstimate(
        widget.variant.id,
        widget.selectedOptionCodes,
      );

      if (res['rejected'] == true) {
        setState(() {
          _isRejection = true;
          _rejectionReason = res['reason'] ?? 'Device condition does not meet buyback criteria.';
          _calculating = false;
        });
        return;
      }

      final est = double.tryParse(res['estimated_price'].toString()) ?? widget.variant.basePrice;
      final List bList = res['breakdown'] ?? [];

      setState(() {
        _estimatedPrice = est;
        _breakdown = bList.cast<Map<String, dynamic>>();
        _calculating = false;
      });
    } catch (e) {
      // Fallback
      setState(() {
        _estimatedPrice = widget.variant.basePrice;
        _calculating = false;
      });
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final payload = {
        'variant_id': widget.variant.id,
        'customer_name': _nameController.text.trim(),
        'customer_phone': _phoneController.text.trim(),
        'pickup_address': _addressController.text.trim(),
        'pickup_city': 'Tirupur',
        'pickup_pincode': _pincodeController.text.trim(),
        'pickup_slot': _pickupSlot,
        'beneficiary_type': _payoutType,
        'beneficiary_name': _nameController.text.trim(),
        'beneficiary_upi_id': _upiController.text.trim(),
        'selected_option_codes': widget.selectedOptionCodes,
      };

      final order = await _api.createSale(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Pickup Booked! Order ID: ${order.saleCode}'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );

        // Open live order tracking screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TrackOrderScreen(initialSaleCode: order.saleCode),
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_calculating) {
      return const Scaffold(
        backgroundColor: AppTheme.canvas,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryGreen),
              SizedBox(height: 12),
              Text('Calculating optimal buyback quotation...', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    if (_isRejection) {
      return Scaffold(
        appBar: AppBar(title: const Text('Evaluation Result')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cancel_outlined, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Device Not Eligible for Doorstep Buyback',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                _rejectionReason,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Questionnaire'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: const Text('Your Estimated Quote'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Device Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.lightGreen,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.phone_iphone, size: 32, color: AppTheme.primaryGreen),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.brand.name} - ${widget.model.name}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.variant.storage} Variant · Year ${widget.model.releaseYear}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Large Green Estimated Buyback Value Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Estimated Buyback Value',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.darkGreen,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₹${_estimatedPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryGreen,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '✓ Subject to physical doorstep verification',
                      style: TextStyle(fontSize: 11, color: AppTheme.darkGreen, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. Price Summary Breakdown
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Price Summary Breakdown',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    _buildPriceRow('Base Catalog Price', '₹${widget.variant.basePrice.toStringAsFixed(0)}', isPositive: true),
                    const Divider(height: 16, color: AppTheme.border),
                    if (_breakdown.isNotEmpty)
                      ..._breakdown.map((b) => _buildPriceRow(
                            b['title'] ?? 'Condition Factor',
                            '-₹${(double.tryParse(b['deduction'].toString()) ?? 0.0).toStringAsFixed(0)}',
                            isNegative: true,
                          ))
                    else
                      _buildPriceRow('Condition Deductions', '₹0', isNegative: false),
                    const Divider(height: 16, color: AppTheme.border),
                    _buildPriceRow(
                      'Net Estimated Offer',
                      '₹${_estimatedPrice.toStringAsFixed(0)}',
                      isBold: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 4. Free Doorstep Pickup Form
              const Text(
                'Schedule Free Doorstep Pickup',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Our verified agent arrives at your address with instant UPI payout.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Your Full Name *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter name' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: '10-Digit Mobile Number *',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (val) => val == null || val.trim().length < 10 ? 'Enter valid 10-digit number' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Doorstep Pickup Address *',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter address' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _upiController,
                decoration: const InputDecoration(
                  labelText: 'UPI ID for Instant Transfer (e.g. name@okhdfcbank)',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter UPI ID' : null,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _pickupSlot,
                decoration: const InputDecoration(
                  labelText: 'Preferred Time Slot',
                  prefixIcon: Icon(Icons.access_time),
                ),
                items: const [
                  DropdownMenuItem(value: 'Morning (10:00 AM - 1:00 PM)', child: Text('Morning (10 AM - 1 PM)')),
                  DropdownMenuItem(value: 'Afternoon (1:00 PM - 5:00 PM)', child: Text('Afternoon (1 PM - 5 PM)')),
                  DropdownMenuItem(value: 'Evening (5:00 PM - 8:00 PM)', child: Text('Evening (5 PM - 8 PM)')),
                ],
                onChanged: (val) => setState(() => _pickupSlot = val!),
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _submitting ? null : _submitBooking,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: AppTheme.primaryGreen,
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Proceed to Doorstep Pickup', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isPositive = false, bool isNegative = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 13 : 11,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
              color: isBold ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 15 : 12,
              fontWeight: FontWeight.w900,
              color: isNegative
                  ? Colors.red.shade700
                  : isBold
                      ? AppTheme.primaryGreen
                      : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
