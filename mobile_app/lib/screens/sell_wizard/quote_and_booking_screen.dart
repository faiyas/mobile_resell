import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/draft_sell_service.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/brand_logo.dart';
import '../../utils/image_helper.dart';
import '../auth/auth_modal_sheet.dart';
import '../orders/track_order_screen.dart';

class QuoteAndBookingScreen extends StatefulWidget {
  final BrandModel brand;
  final PhoneModelItem model;
  final StorageVariantModel variant;
  final List<String> selectedOptionCodes;
  final bool isCustomDevice;
  final String? customDeviceName;
  final String? customDeviceCategory;
  final String? customDeviceSpecs;
  final double? customExpectedPrice;
  final String? otherDefectsNotes;
  final Map<String, String>? customStepNotes;

  const QuoteAndBookingScreen({
    super.key,
    required this.brand,
    required this.model,
    required this.variant,
    required this.selectedOptionCodes,
    this.isCustomDevice = false,
    this.customDeviceName,
    this.customDeviceCategory,
    this.customDeviceSpecs,
    this.customExpectedPrice,
    this.otherDefectsNotes,
    this.customStepNotes,
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
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _upiController = TextEditingController();

  String _payoutType = 'UPI';
  String _pickupSlot = 'Morning (10:00 AM - 1:00 PM)';
  late DateTime _pickupDate;
  bool _pincodeLoading = false;
  Map<String, dynamic>? _pincodeInfo;

  static DateTime _getEarliestPickupDate() {
    final now = DateTime.now();
    // 8:00 PM (20:00) cutoff rule:
    final leadDays = now.hour >= 20 ? 2 : 1;
    return now.add(Duration(days: leadDays));
  }

  void _verifyPincode(String pin) async {
    final clean = pin.trim().replaceAll(RegExp(r'\D'), '');
    if (clean.length != 6) {
      if (mounted) setState(() => _pincodeInfo = null);
      return;
    }
    setState(() => _pincodeLoading = true);
    final res = await _api.lookupPincode(clean);
    if (!mounted) return;
    setState(() {
      _pincodeLoading = false;
      _pincodeInfo = res;
      if (res != null && res['city'] != null) {
        _cityController.text = res['city'].toString();
      }
    });
  }

  String _formatPickupDate(DateTime dt) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final isTomorrow = dt.year == tomorrow.year && dt.month == tomorrow.month && dt.day == tomorrow.day;
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = days[dt.weekday - 1];
    final mName = months[dt.month - 1];
    if (isTomorrow) {
      return 'Tomorrow ($dayName, ${dt.day} $mName)';
    }
    return '$dayName, ${dt.day} $mName ${dt.year}';
  }

  @override
  void initState() {
    super.initState();
    _pickupDate = _getEarliestPickupDate();
    _prefillFromUser();
    _fetchCalculation();
    if (_pincodeController.text.trim().length == 6) {
      _verifyPincode(_pincodeController.text);
    }
  }

  void _prefillFromUser() {
    final user = _api.currentUser;
    if (user != null) {
      if (_nameController.text.isEmpty && user.fullName.isNotEmpty) _nameController.text = user.fullName;
      if (_phoneController.text.isEmpty && user.phone.isNotEmpty) _phoneController.text = user.phone;
      if (_addressController.text.isEmpty && user.defaultAddress.isNotEmpty) _addressController.text = user.defaultAddress;
      if (_cityController.text.isEmpty && user.city.isNotEmpty) _cityController.text = user.city;
      if (_pincodeController.text.isEmpty && user.pincode.isNotEmpty) _pincodeController.text = user.pincode;
      if (_upiController.text.isEmpty && user.defaultUpiId.isNotEmpty) _upiController.text = user.defaultUpiId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _upiController.dispose();
    super.dispose();
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
      _saveDraft(est);
    } catch (e) {
      // Fallback
      setState(() {
        _estimatedPrice = widget.variant.basePrice;
        _calculating = false;
      });
      _saveDraft(widget.variant.basePrice);
    }
  }

  void _saveDraft(double est) {
    DraftSellService.saveDraft(
      SellDraftData(
        isCustomDevice: widget.isCustomDevice,
        customDeviceName: widget.customDeviceName,
        customDeviceCategory: widget.customDeviceCategory,
        customDeviceSpecs: widget.customDeviceSpecs,
        customExpectedPrice: widget.customExpectedPrice,
        brand: widget.brand,
        model: widget.model,
        variant: widget.variant,
        selectedOptionCodes: widget.selectedOptionCodes,
        customStepNotes: widget.customStepNotes ?? {},
        otherDefectsNotes: widget.otherDefectsNotes ?? '',
        estimatedPrice: est,
        savedAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if user is authenticated (End-of-Funnel Login)
    if (_api.currentUser == null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => AuthModalSheet(
          onSuccess: () {
            setState(() {
              _prefillFromUser();
            });
            _proceedWithBooking();
          },
        ),
      );
      return;
    }

    _proceedWithBooking();
  }

  Future<void> _proceedWithBooking() async {
    setState(() => _submitting = true);
    try {
      final cityVal = _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : 'Doorstep Pickup';
      final dateStr = '${_pickupDate.year.toString().padLeft(4, '0')}-${_pickupDate.month.toString().padLeft(2, '0')}-${_pickupDate.day.toString().padLeft(2, '0')}';
      final payload = {
        'variant_id': widget.variant.id,
        'customer_name': _nameController.text.trim(),
        'customer_phone': _phoneController.text.trim(),
        'pickup_address': _addressController.text.trim(),
        'pickup_city': cityVal,
        'pickup_pincode': _pincodeController.text.trim(),
        'pickup_date': dateStr,
        'pickup_slot': _pickupSlot,
        'beneficiary_type': _payoutType,
        'beneficiary_name': _nameController.text.trim(),
        'beneficiary_upi_id': _upiController.text.trim(),
        'selected_option_codes': widget.selectedOptionCodes,
        'is_custom_device': widget.isCustomDevice,
        'custom_device_name': widget.customDeviceName ?? (widget.isCustomDevice ? widget.model.name : ''),
        'custom_device_category': widget.customDeviceCategory ?? (widget.isCustomDevice ? widget.brand.name : 'Others'),
        'custom_device_specs': widget.customDeviceSpecs ?? widget.variant.storage,
        'custom_expected_price': widget.customExpectedPrice ?? widget.variant.basePrice,
        'other_defects_notes': widget.otherDefectsNotes ?? '',
        'custom_step_notes': widget.customStepNotes ?? {},
      };

      final order = await _api.createSale(payload);

      // Auto-save doorstep details & UPI ID to DB so user is NEVER asked again
      if (_api.currentUser != null) {
        try {
          await _api.updateProfile({
            'full_name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'default_address': _addressController.text.trim(),
            'city': cityVal,
            'pincode': _pincodeController.text.trim(),
            'default_upi_id': _upiController.text.trim(),
          });
        } catch (_) {}
      }

      // Successfully booked: clear incomplete local draft
      await DraftSellService.clearDraft();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Free Doorstep Pickup Confirmed! ID: ${order.saleCode}'),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          SnackBar(
            content: Text(err.toString()),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
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
        body: GlassBackgroundMesh(
          child: Center(
            child: RecellBrandLoader(
              message: 'Calculating highest fair market offer...\n1103 Dynamic Valuation Engine',
            ),
          ),
        ),
      );
    }

    if (_isRejection) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.white.withOpacity(0.65),
          elevation: 0,
          title: const Text('Evaluation Result'),
        ),
        body: GlassBackgroundMesh(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GlassContainer(
                padding: const EdgeInsets.all(28),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cancel_outlined, size: 48, color: Colors.red),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Device Ineligible for Doorstep Buyback',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _rejectionReason,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Back to Questionnaire', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.70),
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.glassBorder.withOpacity(0.5))),
              ),
            ),
          ),
        ),
        title: const Text('Your Estimated Quote', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: GlassBackgroundMesh(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Device Info Frosted Glass Card
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(22),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE8F8ED), Color(0xFFD1FAE5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
                          ),
                          child: Builder(
                            builder: (context) {
                              if (widget.model.imageBase64 != null && widget.model.imageBase64!.trim().isNotEmpty) {
                                final bytes = ImageHelper.decodeBase64(widget.model.imageBase64);
                                if (bytes != null) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.memory(bytes, width: 32, height: 32, fit: BoxFit.contain),
                                  );
                                }
                              }
                              return const Icon(Icons.phone_iphone_rounded, size: 28, color: AppTheme.primaryGreen);
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.brand.name} ${widget.model.name}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textPrimary),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${widget.variant.storage} Storage Variant · Year ${widget.model.releaseYear}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. High-Impact Emerald Frosted Buyback Value Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0BAA4B), Color(0xFF06612A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: const Text(
                            'ESTIMATED BUYBACK OFFER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '₹${_estimatedPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified_rounded, size: 16, color: Colors.green.shade200),
                            const SizedBox(width: 6),
                            const Text(
                              'Instant UPI Payout · Free Doorstep Pickup',
                              style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 3. Itemized Price Summary Frosted Card
                  GlassContainer(
                    padding: const EdgeInsets.all(18),
                    borderRadius: BorderRadius.circular(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.receipt_long_rounded, size: 18, color: AppTheme.primaryGreen),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Price Summary Breakdown',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildPriceRow('Base Catalog Value (Mint)', '₹${widget.variant.basePrice.toStringAsFixed(0)}', isPositive: true),
                        Divider(height: 18, color: AppTheme.border.withOpacity(0.6)),
                        _buildPriceRow(
                          'Condition Deductions (Calculated)',
                          (widget.variant.basePrice - _estimatedPrice) > 0
                              ? '-₹${(widget.variant.basePrice - _estimatedPrice).toStringAsFixed(0)}'
                              : '₹0 (Flawless)',
                          isNegative: (widget.variant.basePrice - _estimatedPrice) > 0,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.lightGreen.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.verified_user_outlined, size: 16, color: AppTheme.primaryGreen),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Field Agent will perform doorstep physical verification and confirm final valuation before payout.',
                                  style: TextStyle(fontSize: 10, color: AppTheme.darkGreen, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 18, color: AppTheme.border.withOpacity(0.6)),
                        _buildPriceRow(
                          'Net Doorstep Payout',
                          '₹${_estimatedPrice.toStringAsFixed(0)}',
                          isBold: true,
                        ),
                      ],
                    ),
                  ),

                  // Custom Other Defects Noted
                  if ((widget.otherDefectsNotes != null && widget.otherDefectsNotes!.isNotEmpty) ||
                      (widget.customStepNotes != null && widget.customStepNotes!.isNotEmpty)) ...[
                    const SizedBox(height: 14),
                    GlassContainer(
                      padding: const EdgeInsets.all(14),
                      borderRadius: BorderRadius.circular(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.edit_note_rounded, color: AppTheme.primaryGreen, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Other Defects & Notes Reported:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (widget.customStepNotes != null)
                            ...widget.customStepNotes!.entries.map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('• ${e.key}: "${e.value}"', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              ),
                            ),
                          if (widget.otherDefectsNotes != null && widget.otherDefectsNotes!.isNotEmpty && widget.customStepNotes?.isEmpty != false)
                            Text(widget.otherDefectsNotes!, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // 4. Doorstep Pickup & Instant Payout Form
                  const Text(
                    'Schedule Free Doorstep Pickup',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Our verified agent arrives at your door, checks device, and transfers cash/UPI instantly.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),

                  GlassContainer(
                    padding: const EdgeInsets.all(18),
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      children: [
                        if (_api.currentUser != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Logged in as ${_api.currentUser!.fullName.isNotEmpty ? _api.currentUser!.fullName : _api.currentUser!.email}. Saved profile details applied!',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          InkWell(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (ctx) => AuthModalSheet(
                                  onSuccess: () {
                                    setState(() {
                                      _prefillFromUser();
                                    });
                                  },
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.amber.shade400),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.lock_person_rounded, color: Colors.amber.shade900, size: 20),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Sign In / Register to auto-fill saved address & track orders.',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                                    ),
                                  ),
                                  Text(
                                    'Sign In →',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.amber.shade900),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Your Full Name *',
                            prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.primaryGreen),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.85),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your full name' : null,
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: '10-Digit Mobile Number *',
                            prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.primaryGreen),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.85),
                          ),
                          validator: (val) => val == null || val.trim().length < 10 ? 'Enter valid 10-digit number' : null,
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _addressController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Doorstep Pickup Address *',
                            prefixIcon: const Icon(Icons.location_on_outlined, color: AppTheme.primaryGreen),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.85),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Please enter complete address' : null,
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _cityController,
                                decoration: InputDecoration(
                                  labelText: 'City *',
                                  prefixIcon: const Icon(Icons.location_city_rounded, color: AppTheme.primaryGreen),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.85),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Enter city' : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _pincodeController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                onChanged: (val) {
                                  if (val.trim().length == 6) {
                                    _verifyPincode(val);
                                  } else if (_pincodeInfo != null) {
                                    setState(() => _pincodeInfo = null);
                                  }
                                },
                                decoration: InputDecoration(
                                  labelText: 'Pincode *',
                                  counterText: '',
                                  prefixIcon: const Icon(Icons.pin_drop_outlined, color: AppTheme.primaryGreen),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.85),
                                ),
                                validator: (val) => val == null || val.trim().length < 6 ? 'Enter 6-digit pincode' : null,
                              ),
                            ),
                          ],
                        ),

                        if (_pincodeLoading) ...[
                          const SizedBox(height: 6),
                          const Row(
                            children: [
                              SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen)),
                              SizedBox(width: 8),
                              Text('Verifying postal coverage...', style: TextStyle(fontSize: 11, color: AppTheme.darkGreen, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ] else if (_pincodeInfo != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '✓ Verified: ${_pincodeInfo!['city']}, ${_pincodeInfo!['state']} · Doorstep Service Active',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.darkGreen),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _upiController,
                          decoration: InputDecoration(
                            labelText: 'UPI ID for Instant Transfer (e.g. name@okhdfcbank)',
                            prefixIcon: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primaryGreen),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.85),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Please enter UPI ID' : null,
                        ),
                        const SizedBox(height: 12),

                        // Doorstep Pickup Date Selector (Restricted to Tomorrow Onwards / Cutoff Aware)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.glassBorder),
                          ),
                          child: InkWell(
                            onTap: () async {
                              final earliest = _getEarliestPickupDate();
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _pickupDate.isBefore(earliest) ? earliest : _pickupDate,
                                firstDate: earliest,
                                lastDate: DateTime.now().add(const Duration(days: 30)),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: AppTheme.primaryGreen,
                                        onPrimary: Colors.white,
                                        onSurface: AppTheme.textPrimary,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() => _pickupDate = picked);
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.event_available_rounded, color: AppTheme.primaryGreen, size: 20),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Doorstep Pickup Date',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryGreen.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        DateTime.now().hour >= 20 ? '+2 Days Lead' : 'From Tomorrow',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.darkGreen),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatPickupDate(_pickupDate),
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                                    ),
                                    const Text(
                                      'Change 📅',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateTime.now().hour >= 20
                                      ? '⚡ Booked after 8:00 PM: Earliest doorstep pickup is Day After Tomorrow.'
                                      : '⚡ Same-day slots are closed. Earliest doorstep pickup is tomorrow.',
                                  style: const TextStyle(fontSize: 10, color: AppTheme.darkGreen, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          value: _pickupSlot,
                          decoration: InputDecoration(
                            labelText: 'Preferred Time Slot',
                            prefixIcon: const Icon(Icons.access_time_rounded, color: AppTheme.primaryGreen),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.85),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Morning (10:00 AM - 1:00 PM)', child: Text('Morning (10 AM - 1 PM)')),
                            DropdownMenuItem(value: 'Afternoon (1:00 PM - 5:00 PM)', child: Text('Afternoon (1 PM - 5 PM)')),
                            DropdownMenuItem(value: 'Evening (5:00 PM - 8:00 PM)', child: Text('Evening (5 PM - 8 PM)')),
                          ],
                          onChanged: (val) => setState(() => _pickupSlot = val!),
                        ),
                        const SizedBox(height: 14),

                        // Payout Mode Toggle
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _payoutType = 'UPI'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _payoutType == 'UPI' ? AppTheme.primaryGreen.withOpacity(0.15) : Colors.white.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _payoutType == 'UPI' ? AppTheme.primaryGreen : AppTheme.glassBorder,
                                      width: _payoutType == 'UPI' ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.bolt_rounded, size: 18, color: _payoutType == 'UPI' ? AppTheme.primaryGreen : AppTheme.textSecondary),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Instant UPI',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: _payoutType == 'UPI' ? AppTheme.primaryGreen : AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _payoutType = 'BANK'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _payoutType == 'BANK' ? AppTheme.primaryGreen.withOpacity(0.15) : Colors.white.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _payoutType == 'BANK' ? AppTheme.primaryGreen : AppTheme.glassBorder,
                                      width: _payoutType == 'BANK' ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.account_balance_rounded, size: 18, color: _payoutType == 'BANK' ? AppTheme.primaryGreen : AppTheme.textSecondary),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Bank IMPS',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: _payoutType == 'BANK' ? AppTheme.primaryGreen : AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Primary Glass Glow CTA Button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submitBooking,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        backgroundColor: AppTheme.primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Confirm Free Doorstep Pickup',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isPositive = false, bool isNegative = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
              color: isBold ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 16 : 13,
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
