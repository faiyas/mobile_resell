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
  bool _isEditingAddress = false;

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
              message: 'Calculating highest fair market offer...\nDolly Dynamic Valuation Engine',
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
        title: const Text('Doorstep Buyback Valuation', style: TextStyle(fontWeight: FontWeight.w900)),
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
                  // ================= 1. TOP SECTION: DOORSTEP ADDRESS & PICKUP BOOKING =================
                  if (_api.currentUser != null) ...[
                    // Saved Address Card
                    GlassContainer(
                      padding: const EdgeInsets.all(16),
                      borderRadius: BorderRadius.circular(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      _nameController.text.isNotEmpty ? _nameController.text : _api.currentUser!.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6),
                                      child: Text('|', style: TextStyle(color: Colors.grey)),
                                    ),
                                    Text(
                                      _phoneController.text.isNotEmpty ? _phoneController.text : _api.currentUser!.phone,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(() => _isEditingAddress = !_isEditingAddress),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  _isEditingAddress ? 'Done' : 'Change',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (!_isEditingAddress)
                            Text(
                              _addressController.text.isNotEmpty
                                  ? '${_addressController.text}, ${_cityController.text} ${_pincodeController.text}'
                                  : (_api.currentUser!.defaultAddress.isNotEmpty
                                      ? '${_api.currentUser!.defaultAddress}, ${_api.currentUser!.city} ${_api.currentUser!.pincode}'
                                      : 'No saved address. Tap Change to enter address.'),
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                            ),
                          if (_isEditingAddress) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _addressController,
                              maxLines: 2,
                              decoration: const InputDecoration(labelText: 'Doorstep Address *', isDense: true),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _cityController,
                                    decoration: const InputDecoration(labelText: 'City *', isDense: true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _pincodeController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    decoration: const InputDecoration(labelText: 'Pincode *', counterText: '', isDense: true),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _upiController,
                              decoration: const InputDecoration(labelText: 'UPI ID (Optional)', isDense: true),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pickup Booking Section
                    GlassContainer(
                      padding: const EdgeInsets.all(16),
                      borderRadius: BorderRadius.circular(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pickup Booking',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Choose a pickup date',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),

                          // Horizontal Scrolling Date Cards
                          SizedBox(
                            height: 82,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: 7,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (ctx, idx) {
                                final date = _getEarliestPickupDate().add(Duration(days: idx));
                                final isSelected = date.year == _pickupDate.year &&
                                    date.month == _pickupDate.month &&
                                    date.day == _pickupDate.day;
                                final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                                final days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

                                return GestureDetector(
                                  onTap: () => setState(() => _pickupDate = date),
                                  child: Container(
                                    width: 72,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF17251C) : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF17251C) : AppTheme.glassBorder,
                                        width: 1.5,
                                      ),
                                      boxShadow: isSelected
                                          ? [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))]
                                          : null,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          months[date.month - 1],
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? AppTheme.primaryGreen : AppTheme.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          date.day.toString().padLeft(2, '0'),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: isSelected ? Colors.white : AppTheme.textPrimary,
                                            height: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          days[date.weekday % 7],
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: isSelected ? Colors.grey.shade300 : AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 14),
                          const Text(
                            'Choose a pickup slot',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),

                          // Slot Selector Chips
                          Row(
                            children: [
                              _buildSlotChip('Morning (10:00 AM - 1:00 PM)', 'Morning\n10AM - 1PM'),
                              const SizedBox(width: 6),
                              _buildSlotChip('Afternoon (1:00 PM - 5:00 PM)', 'Afternoon\n1PM - 5PM'),
                              const SizedBox(width: 6),
                              _buildSlotChip('Evening (5:00 PM - 8:00 PM)', 'Evening\n5PM - 8PM'),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Book Pickup Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _submitting ? null : _submitBooking,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _submitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text(
                                      'Book Pickup',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Guest / Not Logged In View
                    GlassContainer(
                      padding: const EdgeInsets.all(20),
                      borderRadius: BorderRadius.circular(24),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: AppTheme.lightGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.local_shipping_outlined, color: AppTheme.primaryGreen, size: 28),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Doorstep Pickup & Instant Payout',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Sign in to book doorstep pickup slot and receive instant cash / UPI payout.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () {
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
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Login to Proceed / Book Pickup', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                                  SizedBox(width: 6),
                                  Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ================= 2. LOWER SECTION: SELL NOW FOR AMAZING PRICE =================
                  Center(
                    child: Text(
                      'Sell Now For Amazing price',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.grey.shade900),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // White Card with Phone image, name, price, note, and assurances
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Centered Device Image
                        SizedBox(
                          height: 90,
                          child: Builder(
                            builder: (context) {
                              if (widget.model.imageBase64 != null && widget.model.imageBase64!.trim().isNotEmpty) {
                                final bytes = ImageHelper.decodeBase64(widget.model.imageBase64);
                                if (bytes != null) {
                                  return Image.memory(bytes, fit: BoxFit.contain);
                                }
                              }
                              return const Icon(Icons.phone_iphone_rounded, size: 64, color: Colors.grey);
                            },
                          ),
                        ),
                        const SizedBox(height: 10),

                        Text(
                          '${widget.brand.name} ${widget.model.name} (${widget.variant.storage})',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Instantly Sell And Get',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹ ${_estimatedPrice.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 6),

                        // Thin readable disclaimer text
                        const Text(
                          '* Note: Final buyback price may vary during doorstep physical evaluation based on actual device inspection.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey,
                            height: 1.3,
                          ),
                        ),

                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 12),

                        // BEST PRICE Section
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'BEST PRICE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.pink.shade700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Get Value', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            Text('₹ ${_estimatedPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Get value', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            Text('₹ ${_estimatedPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // View Evaluation Summary Button
                        OutlinedButton(
                          onPressed: () => _showEvaluationSummaryModal(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('View Evaluation Summary', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                              SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Our assurance win your trust
                        const Text(
                          'Our assurance win your trust',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(child: _buildAssuranceCard(Icons.local_shipping_outlined, 'Hassle-Less\nDoorstep Free Pickup')),
                            const SizedBox(width: 8),
                            Expanded(child: _buildAssuranceCard(Icons.support_agent_rounded, 'Services\noffered across India')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _buildAssuranceCard(Icons.trending_up_rounded, 'Unbeatable\nMarket Value')),
                            const SizedBox(width: 8),
                            Expanded(child: _buildAssuranceCard(Icons.payments_outlined, 'Instant Cash\nin Hand')),
                          ],
                        ),
                      ],
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

  Widget _buildSlotChip(String slotValue, String label) {
    final isSelected = _pickupSlot == slotValue;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _pickupSlot = slotValue),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.lightGreen : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primaryGreen : AppTheme.glassBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? AppTheme.darkGreen : AppTheme.textSecondary,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssuranceCard(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.grey.shade800),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }

  void _showEvaluationSummaryModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Evaluation Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildPriceRow('Base Catalog Value (Mint)', '₹${widget.variant.basePrice.toStringAsFixed(0)}'),
            _buildPriceRow(
              'Condition Deductions',
              (widget.variant.basePrice - _estimatedPrice) > 0
                  ? '-₹${(widget.variant.basePrice - _estimatedPrice).toStringAsFixed(0)}'
                  : '₹0 (Flawless)',
              isNegative: (widget.variant.basePrice - _estimatedPrice) > 0,
            ),
            const Divider(height: 20),
            _buildPriceRow('Calculated Net Offer', '₹${_estimatedPrice.toStringAsFixed(0)}', isBold: true),
            const SizedBox(height: 12),
            const Text(
              '* Verified at doorstep by certified technician before instant payment.',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
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
