import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/brand_logo.dart';
import '../../utils/image_helper.dart';
import '../../utils/time_helper.dart';
import '../splash_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _isLoading = true;
  List<SaleOrderModel> _sales = [];
  PaymentSummaryModel _paymentSummary = PaymentSummaryModel(totalCount: 0, totalDisbursed: 0.0, payments: []);
  List<AgentUserModel> _agents = [];
  List<ConditionCategoryModel> _conditionCategories = [];
  List<BrandModel> _pricingBrands = [];
  int? _selectedPricingBrandId;
  String _searchQuery = '';
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAdminData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    setState(() => _isLoading = true);

    // 1. Fetch Sales Orders independently from DB
    try {
      final sales = await _api.getSales();
      if (mounted) {
        setState(() => _sales = sales);
      }
    } catch (e) {
      debugPrint('AdminDashboard: Sales loading error: $e');
    }

    // 2. Fetch Payments Summary independently from DB
    try {
      final summary = await _api.getPaymentsSummary();
      if (mounted) {
        setState(() => _paymentSummary = summary);
      }
    } catch (e) {
      debugPrint('AdminDashboard: Payments loading error: $e');
    }

    // 3. Fetch Agents independently from DB
    try {
      final agents = await _api.getAgents();
      if (mounted) {
        setState(() => _agents = agents);
      }
    } catch (e) {
      debugPrint('AdminDashboard: Agents loading error: $e');
    }

    // 4. Fetch Condition Categories independently from DB
    try {
      final conditions = await _api.getConditionCategories(forceRefresh: true);
      if (mounted) {
        setState(() => _conditionCategories = conditions);
      }
    } catch (e) {
      debugPrint('AdminDashboard: Conditions loading error: $e');
    }

    // 5. Fetch Brands for Pricing Filter
    try {
      final bList = await _api.getBrands();
      if (mounted) {
        setState(() => _pricingBrands = bList);
      }
    } catch (e) {
      debugPrint('AdminDashboard: Brands loading error: $e');
    }

    if (mounted) {
      if (_paymentSummary.totalCount == 0 && _sales.isNotEmpty) {
        final paidSales = _sales.where((s) => s.status == 'PAYMENT_COMPLETED').toList();
        final disbursed = paidSales.fold<double>(0.0, (sum, s) => sum + (s.finalPrice ?? s.estimatedPrice));
        if (paidSales.isNotEmpty) {
          _paymentSummary = PaymentSummaryModel(
            totalCount: paidSales.length,
            totalDisbursed: disbursed,
            payments: [],
          );
        }
      }
      setState(() => _isLoading = false);
    }
  }

  int get _pendingPickupsCount => _sales.where((s) => ['SUBMITTED', 'PICKUP_SCHEDULED', 'PICKED_UP', 'INSPECTION_PENDING'].contains(s.status)).length;
  int get _awaitingPayoutCount => _sales.where((s) => ['OWNERSHIP_TRANSFERRED', 'CUSTOMER_ACCEPTED'].contains(s.status)).length;

  List<SaleOrderModel> get _payoutQueue =>
      _sales.where((s) => ['OWNERSHIP_TRANSFERRED', 'CUSTOMER_ACCEPTED'].contains(s.status)).toList();

  DateTimeRange? _selectedDateRange;
  String _datePeriodFilter = 'ALL'; // 'ALL', 'TODAY', 'WEEK', 'MONTH'

  List<SaleOrderModel> get _filteredSales {
    final now = DateTime.now();
    return _sales.where((s) {
      final matchesStatus = _statusFilter == 'ALL' ? true : s.status == _statusFilter;
      final matchesQuery = _searchQuery.isEmpty
          ? true
          : s.saleCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              s.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              s.customerPhone.contains(_searchQuery);

      if (!matchesStatus || !matchesQuery) return false;

      // Period / Date filters
      if (_selectedDateRange != null && s.createdAt != null) {
        final orderDate = DateTime.tryParse(s.createdAt!);
        if (orderDate != null) {
          final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
          final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
          if (orderDate.isBefore(start) || orderDate.isAfter(end)) return false;
        }
      } else if (_datePeriodFilter == 'TODAY' && s.createdAt != null) {
        final orderDate = DateTime.tryParse(s.createdAt!);
        if (orderDate != null && (orderDate.year != now.year || orderDate.month != now.month || orderDate.day != now.day)) {
          return false;
        }
      } else if (_datePeriodFilter == 'WEEK' && s.createdAt != null) {
        final orderDate = DateTime.tryParse(s.createdAt!);
        if (orderDate != null && now.difference(orderDate).inDays > 7) {
          return false;
        }
      } else if (_datePeriodFilter == 'MONTH' && s.createdAt != null) {
        final orderDate = DateTime.tryParse(s.createdAt!);
        if (orderDate != null && (orderDate.year != now.year || orderDate.month != now.month)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _showCreateAgentDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: 'agent123');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          padding: const EdgeInsets.all(22),
          borderRadius: BorderRadius.circular(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primaryGreen, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Create Field Agent Account', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('Only Admins can issue credentials for collection agents.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Agent Full Name *',
                    hintText: 'e.g. Ramesh Kumar',
                    prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.primaryGreen),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Agent Mobile Number *',
                    hintText: 'e.g. 9876543210',
                    prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.primaryGreen),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Agent Email Address *',
                    hintText: 'e.g. ramesh@buyback.in',
                    prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primaryGreen),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Initial Password *',
                    hintText: 'e.g. agent123',
                    prefixIcon: Icon(Icons.lock_outline_rounded, color: AppTheme.primaryGreen),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          final phone = phoneCtrl.text.trim();
                          final email = emailCtrl.text.trim();
                          final pass = passCtrl.text;

                          if (name.isEmpty || email.isEmpty || phone.isEmpty || pass.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Please fill all fields')),
                            );
                            return;
                          }

                          Navigator.pop(ctx);
                          try {
                            await _api.register({
                              'full_name': name,
                              'phone': phone,
                              'email': email,
                              'password': pass,
                              'role': 'COLLECTION_AGENT',
                            });
                            _loadAdminData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✓ Collection Agent $name created successfully!'),
                                backgroundColor: AppTheme.primaryGreen,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to create agent: $e')),
                            );
                          }
                        },
                        child: const Text('Create Agent'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAssignAgentDialog(SaleOrderModel order) {
    if (_agents.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            padding: const EdgeInsets.all(22),
            borderRadius: BorderRadius.circular(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.group_off_rounded, size: 40, color: AppTheme.textSecondary),
                const SizedBox(height: 12),
                const Text('No Collection Agents Found', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Create an agent account first to assign doorstep pickup requests.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showCreateAgentDialog();
                  },
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: const Text('Create Agent Account'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    int selectedAgentId = _agents.first.id;
    String selectedSlot = order.pickupSlot ?? 'Morning (10:00 AM - 1:00 PM)';
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowStr = '${tomorrow.year.toString().padLeft(4, '0')}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
    
    // Earliest dispatch is tomorrow
    String initialDate = tomorrowStr;
    if (order.pickupDate != null && order.pickupDate!.trim().isNotEmpty) {
      if (order.pickupDate!.trim().compareTo(tomorrowStr) >= 0) {
        initialDate = order.pickupDate!.trim();
      }
    }
    final dateController = TextEditingController(text: initialDate);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: GlassContainer(
            padding: const EdgeInsets.all(24),
            borderRadius: BorderRadius.circular(28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.person_add_rounded, color: AppTheme.primaryGreen, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Assign Field Agent', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                            Text(order.saleCode, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text('Select Pickup Specialist:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: selectedAgentId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.85),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: _agents.map((a) {
                      return DropdownMenuItem<int>(
                        value: a.id,
                        child: Text('${a.fullName} (${a.phone})', style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedAgentId = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pickup Date (YYYY-MM-DD):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('From Tomorrow', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.darkGreen)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: dateController,
                    readOnly: true,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.tryParse(dateController.text) ?? tomorrow,
                        firstDate: tomorrow,
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                      );
                      if (picked != null) {
                        final formatted = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                        setDialogState(() => dateController.text = formatted);
                      }
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.85),
                      prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.primaryGreen),
                      suffixIcon: const Icon(Icons.touch_app_rounded, size: 16, color: AppTheme.primaryGreen),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Time Slot:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedSlot,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.85),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Morning (10:00 AM - 1:00 PM)', child: Text('Morning (10:00 AM - 1:00 PM)', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Afternoon (1:00 PM - 4:00 PM)', child: Text('Afternoon (1:00 PM - 4:00 PM)', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Evening (4:00 PM - 7:00 PM)', child: Text('Evening (4:00 PM - 7:00 PM)', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedSlot = val);
                    },
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            await _api.assignPickup(order.id, {
                              'agent_id': selectedAgentId,
                              'pickup_date': dateController.text.trim(),
                              'pickup_slot': selectedSlot,
                            });
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✓ Agent successfully assigned to ${order.saleCode}'),
                                backgroundColor: AppTheme.primaryGreen,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            _loadAdminData();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
                            );
                          }
                        },
                        child: const Text('Confirm Assignment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleShiftToTomorrow(SaleOrderModel order) async {
    try {
      await _api.shiftPickupToNextDay(order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Pickup for ${order.saleCode} shifted to tomorrow morning!'),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadAdminData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showRecordPayoutDialog(SaleOrderModel order) {
    final utrController = TextEditingController();
    final double amount = order.finalPrice ?? order.estimatedPrice;
    String? paymentProofBase64;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: GlassContainer(
            padding: const EdgeInsets.all(24),
            borderRadius: BorderRadius.circular(28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.currency_rupee_rounded, color: AppTheme.primaryGreen, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Release Instant Payout', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                            Text('${order.saleCode} · ₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('Beneficiary: ${order.customerName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  Text('Device: ${order.brandName} ${order.modelName} (${order.storage})', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  if (order.otherDefectsNotes != null && order.otherDefectsNotes!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Custom Notes: ${order.otherDefectsNotes}', style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
                    ),
                  Text('Payout Mode: ${order.beneficiaryType}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  if (order.beneficiaryUpiId != null)
                    Text('UPI ID: ${order.beneficiaryUpiId}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.darkGreen)),
                  if (order.inspection != null && order.inspection!.photos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Doorstep QC Proof (4 Photos):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        Text('IMEI: ${order.inspection!.verifiedImei ?? order.imeiNumber ?? "Verified"}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.darkGreen)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 65,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: order.inspection!.photos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, pIdx) {
                          final p = order.inspection!.photos[pIdx];
                          final bytes = ImageHelper.decodeBase64(p.imageBase64);
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              children: [
                                if (bytes != null)
                                  Image.memory(bytes, width: 65, height: 65, fit: BoxFit.cover)
                                else
                                  Container(width: 65, height: 65, color: Colors.grey.shade200, child: const Icon(Icons.image, size: 20)),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    color: Colors.black.withOpacity(0.65),
                                    padding: const EdgeInsets.symmetric(vertical: 1),
                                    child: Text(p.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: utrController,
                    decoration: InputDecoration(
                      labelText: 'Bank / UPI UTR Reference Number *',
                      hintText: 'e.g. 429184920194',
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.85),
                      prefixIcon: const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryGreen),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Payment Proof Confirmation Screenshot:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.lightGreen,
                          foregroundColor: AppTheme.darkGreen,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.photo_library_rounded, size: 16, color: AppTheme.primaryGreen),
                        label: const Text('Pick Receipt (Gallery)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final b64 = await ImageHelper.pickImageAsBase64();
                          if (b64 != null) {
                            setDlgState(() => paymentProofBase64 = b64);
                          }
                        },
                      ),
                      if (paymentProofBase64 != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Colors.red),
                          onPressed: () => setDlgState(() => paymentProofBase64 = null),
                        ),
                      ],
                    ],
                  ),
                  if (paymentProofBase64 != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 70,
                      width: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(ImageHelper.decodeBase64(paymentProofBase64)!, fit: BoxFit.cover),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                        onPressed: () async {
                          final utr = utrController.text.trim();
                          if (utr.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter UTR reference number'), behavior: SnackBarBehavior.floating),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          try {
                            String method = order.beneficiaryType.toUpperCase();
                            if (!['GPAY', 'PHONEPE', 'PAYTM', 'BHIM', 'IMPS', 'CASH'].contains(method)) {
                              method = 'GPAY';
                            }
                            await _api.recordPayment(order.id, {
                              'amount': amount,
                              'payment_method': method,
                              'utr_number': utr,
                              'payment_proof_base64': paymentProofBase64 ??
                                  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
                              'admin_notes': 'Disbursed via Dolly Admin Desk',
                            });
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✓ Payout of ₹${amount.toStringAsFixed(0)} recorded successfully!'),
                                backgroundColor: AppTheme.primaryGreen,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            _loadAdminData();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
                            );
                          }
                        },
                        child: const Text('Confirm Disbursal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showInspectionPhotosDialog(SaleOrderModel order) {
    final photos = order.inspection?.photos ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(20),
            height: MediaQuery.of(ctx).size.height * 0.78,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.96),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(10))),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Agent Inspection Photos: ${order.saleCode}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                Text(
                  'Inspector: ${order.inspection?.inspectorName ?? 'Field Agent'} · IMEI: ${order.inspection?.verifiedImei ?? 'Verified'}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: photos.isEmpty
                      ? const Center(child: Text('No inspection photos uploaded for this order.'))
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: photos.length,
                          itemBuilder: (ctx, idx) {
                            final p = photos[idx];
                            final bytes = ImageHelper.decodeBase64(p.imageBase64);
                            return GlassContainer(
                              padding: const EdgeInsets.all(8),
                              borderRadius: BorderRadius.circular(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: bytes != null
                                          ? Image.memory(bytes, width: double.infinity, fit: BoxFit.cover)
                                          : const Center(child: Icon(Icons.broken_image)),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    p.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out from Central Admin Desk?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _api.logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Dolly · Admin Desk', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryGreen),
            tooltip: 'Refresh Desk',
            onPressed: _loadAdminData,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Log Out',
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: GlassBackgroundMesh(
        child: SafeArea(
          child: _isLoading
              ? const RecellBrandLoader(message: 'Loading Dolly Central Admin metrics...')
              : RefreshIndicator(
                  color: AppTheme.primaryGreen,
                  onRefresh: _loadAdminData,
                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Executive Header Glass Banner
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF0BAA4B), Color(0xFF06612A)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryGreen.withOpacity(0.25),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 28),
                                    ),
                                    const SizedBox(width: 14),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Dolly Central Control',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 17,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Payout Approvals · Field Dispatch · Pricing Rules',
                                            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // 4 Executive Frosted KPI Cards
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildKpiCard('Total Orders', '${_sales.length}', Icons.smartphone_rounded, AppTheme.primaryGreen),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildKpiCard('Pending Pickups', '$_pendingPickupsCount', Icons.motorcycle_rounded, Colors.orange),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildKpiCard('Awaiting Payout', '$_awaitingPayoutCount', Icons.payments_rounded, const Color(0xFF059669)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildKpiCard(
                                      'Total Disbursed',
                                      '₹${_paymentSummary.totalDisbursed.toStringAsFixed(0)}',
                                      Icons.account_balance_rounded,
                                      Colors.purple,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Frosted Glass Tab Bar
                              GlassContainer(
                                padding: const EdgeInsets.all(4),
                                borderRadius: BorderRadius.circular(18),
                                child: TabBar(
                                  controller: _tabController,
                                  labelColor: AppTheme.primaryGreen,
                                  unselectedLabelColor: AppTheme.textSecondary,
                                  indicatorColor: AppTheme.primaryGreen,
                                  indicatorWeight: 3,
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                  tabs: [
                                    Tab(text: 'Payouts (${_payoutQueue.length})'),
                                    Tab(text: 'Orders (${_sales.length})'),
                                    const Tab(text: 'Pricing & Rules'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    body: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPayoutsTab(),
                        _buildOrdersTab(),
                        _buildPricingTab(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: BorderRadius.circular(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutsTab() {
    if (_payoutQueue.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassContainer(
            padding: const EdgeInsets.all(28),
            borderRadius: BorderRadius.circular(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 54, color: AppTheme.primaryGreen.withOpacity(0.6)),
                const SizedBox(height: 12),
                const Text('No Payouts Pending', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                const Text(
                  'Orders inspected and accepted by customers will appear here for instant UPI/Bank release.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: _payoutQueue.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = _payoutQueue[index];
        final amount = order.finalPrice ?? order.estimatedPrice;

        return GlassContainer(
          padding: const EdgeInsets.all(18),
          borderRadius: BorderRadius.circular(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                    ),
                    child: Text(
                      order.saleCode,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppTheme.primaryGreen),
                    ),
                  ),
                  Text(
                    '₹${amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.primaryGreen),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${order.brandName} ${order.modelName} (${order.storage})',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Customer: ${order.customerName} · ${order.customerPhone}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              if (order.beneficiaryUpiId != null && order.beneficiaryUpiId!.isNotEmpty)
                Text(
                  'UPI: ${order.beneficiaryUpiId}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
              const SizedBox(height: 12),
              if (order.inspection != null && order.inspection!.photos.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.darkGreen,
                      side: BorderSide(color: AppTheme.primaryGreen.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.photo_library_rounded, size: 16, color: AppTheme.primaryGreen),
                    label: Text(
                      'Verify Agent Inspection Photos (${order.inspection!.photos.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    onPressed: () => _showInspectionPhotosDialog(order),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'Authorize & Release Payout',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  onPressed: () => _showRecordPayoutDialog(order),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrdersTab() {
    return Column(
      children: [
        // Search & Filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            borderRadius: BorderRadius.circular(16),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: 'Search order ID, phone, customer...',
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppTheme.primaryGreen),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
            ),
          ),
        ),
        // Filter Chips & Agent Creation Action
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              ActionChip(
                avatar: const Icon(Icons.person_add_rounded, size: 14, color: Colors.white),
                label: const Text('+ Add Field Agent', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                backgroundColor: AppTheme.primaryGreen,
                onPressed: _showCreateAgentDialog,
              ),
              const SizedBox(width: 8),
              _buildFilterChip('ALL', 'All Orders'),
              _buildFilterChip('SUBMITTED', 'Submitted'),
              _buildFilterChip('PICKUP_SCHEDULED', 'Scheduled'),
              _buildFilterChip('OWNERSHIP_TRANSFERRED', 'Awaiting Payout'),
              _buildFilterChip('PAYMENT_COMPLETED', 'Completed'),
            ],
          ),
        ),
        // Date / Period Filter Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              ActionChip(
                avatar: Icon(Icons.calendar_today_rounded, size: 12, color: _selectedDateRange != null ? Colors.white : AppTheme.darkGreen),
                label: Text(
                  _selectedDateRange != null
                      ? '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}'
                      : 'Pick Dates',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _selectedDateRange != null ? Colors.white : AppTheme.darkGreen,
                  ),
                ),
                backgroundColor: _selectedDateRange != null ? AppTheme.primaryGreen : AppTheme.lightGreen,
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2025),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                    initialDateRange: _selectedDateRange,
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDateRange = picked;
                      _datePeriodFilter = 'CUSTOM';
                    });
                  }
                },
              ),
              const SizedBox(width: 6),
              ...['ALL', 'TODAY', 'WEEK', 'MONTH'].map((p) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(
                    p == 'ALL' ? 'All Time' : p == 'TODAY' ? 'Today' : p == 'WEEK' ? 'This Week' : 'This Month',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  selected: _datePeriodFilter == p && _selectedDateRange == null,
                  selectedColor: AppTheme.primaryGreen.withOpacity(0.2),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _datePeriodFilter = p;
                        _selectedDateRange = null;
                      });
                    }
                  },
                ),
              )),
              if (_selectedDateRange != null || _datePeriodFilter != 'ALL')
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                  tooltip: 'Reset Date Filter',
                  onPressed: () => setState(() {
                    _selectedDateRange = null;
                    _datePeriodFilter = 'ALL';
                  }),
                ),
            ],
          ),
        ),
        Expanded(
          child: _filteredSales.isEmpty
              ? const Center(child: Text('No matching orders found', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  itemCount: _filteredSales.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final order = _filteredSales[index];
                    return GlassContainer(
                      padding: const EdgeInsets.all(16),
                      borderRadius: BorderRadius.circular(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(order.saleCode, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.textPrimary)),
                              _buildStatusBadge(order.status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${order.brandName} ${order.modelName} (${order.storage})',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${order.customerName} · ${order.customerPhone}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                          if (order.pickupSlot != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  order.isOverdue ? Icons.alarm_off_rounded : Icons.access_time_rounded,
                                  size: 13,
                                  color: order.isOverdue ? Colors.red : Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${order.pickupDate ?? "Scheduled"} · ${order.pickupSlot} (IST)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: order.isOverdue ? Colors.red : AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                                if (order.isOverdue)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                                    child: const Text('OVERDUE', style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.w900)),
                                  ),
                              ],
                            ),
                          ],
                          if (order.answers.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 5,
                              runSpacing: 4,
                              children: order.answers.map((a) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blueGrey.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.blueGrey.shade200),
                                  ),
                                  child: Text(
                                    '${a.categoryName}: ${a.optionTitle}',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                          if (order.otherDefectsNotes != null && order.otherDefectsNotes!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: Text(
                                'Customer Note: ${order.otherDefectsNotes}',
                                style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Est: ₹${order.estimatedPrice.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryGreen),
                              ),
                              Text(
                                order.assignedAgentName != null ? 'Agent: ${order.assignedAgentName}' : 'No Agent Assigned',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: order.assignedAgentName != null ? AppTheme.darkGreen : Colors.orange.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: AppTheme.primaryGreen.withOpacity(0.6)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: AppTheme.primaryGreen),
                                  label: const Text('Assign Agent', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                                  onPressed: () => _showAssignAgentDialog(order),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => _handleShiftToTomorrow(order),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.amber.shade600.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.forward_rounded, size: 14, color: Colors.amber.shade900),
                                      const SizedBox(width: 4),
                                      Text('Next Day', style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _statusFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppTheme.textPrimary)),
        selected: isSelected,
        selectedColor: AppTheme.primaryGreen,
        backgroundColor: Colors.white.withOpacity(0.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? AppTheme.primaryGreen : AppTheme.glassBorder)),
        onSelected: (val) => setState(() => _statusFilter = key),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'PAYMENT_COMPLETED':
        color = Colors.green;
        break;
      case 'OWNERSHIP_TRANSFERRED':
      case 'CUSTOMER_ACCEPTED':
        color = Colors.teal;
        break;
      case 'PICKUP_SCHEDULED':
        color = Colors.blue;
        break;
      case 'CANCELLED':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900),
      ),
    );
  }

  void _editConditionOption(ConditionOptionModel opt) {
    final titleController = TextEditingController(text: opt.title);
    final valController = TextEditingController(text: opt.defaultDeductionValue.toStringAsFixed(0));
    final imgController = TextEditingController(text: opt.imageBase64 ?? '');
    String deductionType = opt.deductionType;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: GlassContainer(
            padding: const EdgeInsets.all(22),
            borderRadius: BorderRadius.circular(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.tune_rounded, color: AppTheme.primaryGreen, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Edit Defect & Reference Photo', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Defect / Option Title *'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: valController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Deduction Amount *',
                      prefixIcon: Icon(Icons.currency_rupee, color: AppTheme.primaryGreen),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Flat (₹)'),
                        selected: deductionType == 'FLAT',
                        onSelected: (v) => setDlgState(() => deductionType = 'FLAT'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Percentage (%)'),
                        selected: deductionType == 'PERCENTAGE',
                        onSelected: (v) => setDlgState(() => deductionType = 'PERCENTAGE'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Defect Reference Image Guide (Base64 / URL):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: imgController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'data:image/png;base64,...',
                      prefixIcon: Icon(Icons.add_photo_alternate_rounded, color: AppTheme.primaryGreen),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.lightGreen,
                          foregroundColor: AppTheme.darkGreen,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.photo_library_rounded, size: 16, color: AppTheme.primaryGreen),
                        label: const Text('Pick Photo (JPG/PNG)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final b64 = await ImageHelper.pickImageAsBase64();
                          if (b64 != null) {
                            setDlgState(() => imgController.text = b64);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      if (imgController.text.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          label: const Text('Clear', style: TextStyle(color: Colors.red, fontSize: 11)),
                          onPressed: () => setDlgState(() => imgController.text = ''),
                        ),
                    ],
                  ),
                  if (imgController.text.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Builder(builder: (ctx) {
                      final bytes = ImageHelper.decodeBase64(imgController.text);
                      if (bytes != null) {
                        return Container(
                          height: 70,
                          width: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.4)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(bytes, fit: BoxFit.cover),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Delete Option',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Delete Option', style: TextStyle(fontWeight: FontWeight.bold)),
                              content: Text('Delete "${opt.title}" option permanently?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            Navigator.pop(ctx);
                            try {
                              await _api.deleteConditionOption(opt.id);
                              _loadAdminData();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('✓ Option "${opt.title}" deleted!'), backgroundColor: AppTheme.primaryGreen),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                          onPressed: () async {
                            final val = double.tryParse(valController.text.trim()) ?? opt.defaultDeductionValue;
                            final img = imgController.text.trim();
                            Navigator.pop(ctx);
                            try {
                              final title = titleController.text.trim();
                              await _api.updateConditionOption(opt.id, {
                                'title': title.isNotEmpty ? title : opt.title,
                                'default_deduction_value': val,
                                'deduction_type': deductionType,
                                'image_base64': img,
                              });
                              _loadAdminData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('✓ Defect rule & image updated successfully!')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to update: $e')),
                              );
                            }
                          },
                          child: const Text('Save Rule'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogQuickBtn(String title, IconData icon, VoidCallback onTap, {bool isPrimary = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary ? AppTheme.primaryGreen : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isPrimary ? Colors.white : AppTheme.primaryGreen,
            ),
            const SizedBox(width: 5),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: isPrimary ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= 1. CATEGORIES MANAGEMENT (ADD / DELETE / IMAGE) =================
  void _showCategoryManager() async {
    List<DeviceCategoryModel> categories = [];
    try {
      categories = await _api.getDeviceCategories(forceRefresh: true);
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(ctx).size.height * 0.82,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.96),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.category_rounded, color: AppTheme.primaryGreen),
                          SizedBox(width: 8),
                          Text('Categories Control', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => _showAddCategoryDialog(onAdded: () async {
                          final updated = await _api.getDeviceCategories(forceRefresh: true);
                          setSheetState(() => categories = updated);
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Manage categories and upload Base64 images directly from device photo gallery.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: categories.isEmpty
                        ? const Center(child: Text('No categories found', style: TextStyle(color: AppTheme.textSecondary)))
                        : ListView.separated(
                            itemCount: categories.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, idx) {
                              final c = categories[idx];
                              final bytes = ImageHelper.decodeBase64(c.imageBase64);
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                leading: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppTheme.lightGreen,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
                                  ),
                                  alignment: Alignment.center,
                                  child: bytes != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.memory(bytes, width: 38, height: 38, fit: BoxFit.contain),
                                        )
                                      : const Icon(Icons.devices_rounded, size: 22, color: AppTheme.primaryGreen),
                                ),
                                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text(
                                  c.imageBase64 != null && c.imageBase64!.isNotEmpty ? 'Photo active' : 'No photo',
                                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.add_a_photo_outlined, size: 20, color: AppTheme.primaryGreen),
                                      tooltip: 'Pick Image (Gallery)',
                                      onPressed: () async {
                                        final b64 = await ImageHelper.pickImageAsBase64();
                                        if (b64 != null) {
                                          await _api.updateDeviceCategory(c.id, {'image_base64': b64});
                                          final updated = await _api.getDeviceCategories(forceRefresh: true);
                                          setSheetState(() => categories = updated);
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('✓ ${c.name} image updated!'), backgroundColor: AppTheme.primaryGreen),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      tooltip: 'Delete Category',
                                      onPressed: () => _confirmDeleteCategory(c, onDeleted: () async {
                                        final updated = await _api.getDeviceCategories(forceRefresh: true);
                                        setSheetState(() => categories = updated);
                                      }),
                                    ),
                                  ],
                                ),
                              );
                            },
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

  void _showAddCategoryDialog({required VoidCallback onAdded}) {
    final nameCtrl = TextEditingController();
    final subCtrl = TextEditingController();
    String? selectedBase64;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            padding: const EdgeInsets.all(22),
            borderRadius: BorderRadius.circular(22),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add New Category', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Category Name *', hintText: 'e.g. Smartwatch, Laptop'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: subCtrl,
                    decoration: const InputDecoration(labelText: 'Subtitle', hintText: 'e.g. Sell smart wearables'),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.lightGreen,
                          foregroundColor: AppTheme.darkGreen,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.photo_library_rounded, size: 16, color: AppTheme.primaryGreen),
                        label: const Text('Pick Image (Gallery)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final b64 = await ImageHelper.pickImageAsBase64();
                          if (b64 != null) {
                            setDlgState(() => selectedBase64 = b64);
                          }
                        },
                      ),
                      if (selectedBase64 != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Colors.red),
                          onPressed: () => setDlgState(() => selectedBase64 = null),
                        ),
                      ],
                    ],
                  ),
                  if (selectedBase64 != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(ImageHelper.decodeBase64(selectedBase64)!, fit: BoxFit.contain),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;
                            Navigator.pop(dlgCtx);
                            try {
                              await _api.createDeviceCategory({
                                'name': name,
                                'subtitle': subCtrl.text.trim(),
                                'image_base64': selectedBase64 ?? '',
                              });
                              onAdded();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('✓ Category "$name" created!'), backgroundColor: AppTheme.primaryGreen),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                              }
                            }
                          },
                          child: const Text('Create'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteCategory(DeviceCategoryModel cat, {required VoidCallback onDeleted}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${cat.name}"?'),
        content: const Text('Are you sure you want to delete this category? Devices linked to this category may be affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteDeviceCategory(cat.id);
                onDeleted();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Deleted category ${cat.name}')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ================= 2. BRANDS MANAGEMENT (ADD / DELETE / LOGO) =================
  void _showBrandManager() async {
    List<BrandModel> brands = [];
    List<DeviceCategoryModel> categories = [];
    try {
      brands = await _api.getBrands(forceRefresh: true);
      categories = await _api.getDeviceCategories();
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(ctx).size.height * 0.82,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.96),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_rounded, color: AppTheme.primaryGreen),
                          SizedBox(width: 8),
                          Text('Brands Control', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Brand', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => _showAddBrandDialog(categories: categories, onAdded: () async {
                          final updated = await _api.getBrands(forceRefresh: true);
                          setSheetState(() => brands = updated);
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Add new device brands and upload logos from phone gallery directly.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: brands.isEmpty
                        ? const Center(child: Text('No brands found', style: TextStyle(color: AppTheme.textSecondary)))
                        : ListView.separated(
                            itemCount: brands.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, idx) {
                              final b = brands[idx];
                              final bytes = ImageHelper.decodeBase64(b.logoBase64);
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                leading: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppTheme.lightGreen,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
                                  ),
                                  alignment: Alignment.center,
                                  child: bytes != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.memory(bytes, width: 38, height: 38, fit: BoxFit.contain),
                                        )
                                      : const Icon(Icons.phone_android_rounded, size: 22, color: AppTheme.primaryGreen),
                                ),
                                title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text(
                                  b.logoBase64 != null && b.logoBase64!.isNotEmpty ? 'Logo uploaded' : 'Default icon',
                                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.add_a_photo_outlined, size: 20, color: AppTheme.primaryGreen),
                                      tooltip: 'Pick Logo (Gallery)',
                                      onPressed: () async {
                                        final b64 = await ImageHelper.pickImageAsBase64();
                                        if (b64 != null) {
                                          await _api.updateBrand(b.id, {'logo_base64': b64});
                                          final updated = await _api.getBrands(forceRefresh: true);
                                          setSheetState(() => brands = updated);
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('✓ ${b.name} logo updated!'), backgroundColor: AppTheme.primaryGreen),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      tooltip: 'Delete Brand',
                                      onPressed: () => _confirmDeleteBrand(b, onDeleted: () async {
                                        final updated = await _api.getBrands(forceRefresh: true);
                                        setSheetState(() => brands = updated);
                                      }),
                                    ),
                                  ],
                                ),
                              );
                            },
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

  void _showAddBrandDialog({required List<DeviceCategoryModel> categories, required VoidCallback onAdded}) {
    final nameCtrl = TextEditingController();
    int? selectedCatId = categories.isNotEmpty ? categories.first.id : null;
    String? selectedLogoBase64;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            padding: const EdgeInsets.all(22),
            borderRadius: BorderRadius.circular(22),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add New Brand', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Brand Name *', hintText: 'e.g. Apple, Google, Xiaomi'),
                  ),
                  const SizedBox(height: 10),
                  if (categories.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: selectedCatId,
                      decoration: const InputDecoration(labelText: 'Device Category'),
                      items: categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                      onChanged: (v) => setDlgState(() => selectedCatId = v),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.lightGreen,
                          foregroundColor: AppTheme.darkGreen,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.photo_library_rounded, size: 16, color: AppTheme.primaryGreen),
                        label: const Text('Pick Logo (Gallery)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final b64 = await ImageHelper.pickImageAsBase64();
                          if (b64 != null) {
                            setDlgState(() => selectedLogoBase64 = b64);
                          }
                        },
                      ),
                      if (selectedLogoBase64 != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Colors.red),
                          onPressed: () => setDlgState(() => selectedLogoBase64 = null),
                        ),
                      ],
                    ],
                  ),
                  if (selectedLogoBase64 != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(ImageHelper.decodeBase64(selectedLogoBase64)!, fit: BoxFit.contain),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;
                            Navigator.pop(dlgCtx);
                            try {
                              await _api.createBrand({
                                'name': name,
                                if (selectedCatId != null) 'category': selectedCatId,
                                'logo_base64': selectedLogoBase64 ?? '',
                              });
                              onAdded();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('✓ Brand "$name" added!'), backgroundColor: AppTheme.primaryGreen),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                              }
                            }
                          },
                          child: const Text('Create'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteBrand(BrandModel brand, {required VoidCallback onDeleted}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${brand.name}"?'),
        content: const Text('Are you sure you want to delete this brand? Models under this brand will also be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteBrand(brand.id);
                onDeleted();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted brand ${brand.name}')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ================= 3. MODELS MANAGEMENT (ADD / DELETE / PHOTO) =================
  void _showModelManager() async {
    List<BrandModel> brands = [];
    List<PhoneModelItem> models = [];
    int? filterBrandId;

    try {
      brands = await _api.getBrands();
      models = await _api.getModels();
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final displayModels = filterBrandId != null
              ? models.where((m) => m.brandId == filterBrandId).toList()
              : models;

          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(20),
                height: MediaQuery.of(ctx).size.height * 0.85,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(10))),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.phone_android_rounded, color: AppTheme.primaryGreen),
                            SizedBox(width: 8),
                            Text('Phone Models Control', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Model', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => _showAddPhoneModelDialog(brands: brands, onAdded: () async {
                            final updated = await _api.getModels();
                            setSheetState(() => models = updated);
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (brands.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('All Brands'),
                              selected: filterBrandId == null,
                              onSelected: (_) => setSheetState(() => filterBrandId = null),
                            ),
                            const SizedBox(width: 6),
                            ...brands.map((b) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(b.name),
                                    selected: filterBrandId == b.id,
                                    onSelected: (sel) => setSheetState(() => filterBrandId = sel ? b.id : null),
                                  ),
                                )),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: displayModels.isEmpty
                          ? const Center(child: Text('No models found', style: TextStyle(color: AppTheme.textSecondary)))
                          : ListView.separated(
                              itemCount: displayModels.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, idx) {
                                final m = displayModels[idx];
                                final bytes = ImageHelper.decodeBase64(m.imageBase64);
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                  leading: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: AppTheme.lightGreen,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
                                    ),
                                    alignment: Alignment.center,
                                    child: bytes != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: Image.memory(bytes, width: 38, height: 38, fit: BoxFit.contain),
                                          )
                                        : const Icon(Icons.smartphone_rounded, size: 22, color: AppTheme.primaryGreen),
                                  ),
                                  title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  subtitle: Text(
                                    '${m.brandName ?? ''} · ${m.variants.length} Variants',
                                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.add_a_photo_outlined, size: 20, color: AppTheme.primaryGreen),
                                        tooltip: 'Pick Photo (Gallery)',
                                        onPressed: () async {
                                          final b64 = await ImageHelper.pickImageAsBase64();
                                          if (b64 != null) {
                                            await _api.updatePhoneModel(m.id, {'image_base64': b64});
                                            final updated = await _api.getModels();
                                            setSheetState(() => models = updated);
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('✓ ${m.name} picture updated!'), backgroundColor: AppTheme.primaryGreen),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                        tooltip: 'Delete Model',
                                        onPressed: () => _confirmDeletePhoneModel(m, onDeleted: () async {
                                          final updated = await _api.getModels();
                                          setSheetState(() => models = updated);
                                        }),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddPhoneModelDialog({required List<BrandModel> brands, required VoidCallback onAdded}) {
    if (brands.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a brand first')));
      return;
    }

    final nameCtrl = TextEditingController();
    final yearCtrl = TextEditingController(text: DateTime.now().year.toString());
    int selectedBrandId = brands.first.id;
    int? selectedSeriesId;
    bool hasWarranty = true;
    List<SeriesModel> brandSeries = [];
    bool loadedSeries = false;
    String? selectedPhotoBase64;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            padding: const EdgeInsets.all(22),
            borderRadius: BorderRadius.circular(22),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Phone Model', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 14),
                  Builder(builder: (ctx) {
                    if (!loadedSeries) {
                      loadedSeries = true;
                      _api.getSeries(brandId: selectedBrandId).then((s) {
                        setDlgState(() => brandSeries = s);
                      });
                    }
                    return const SizedBox.shrink();
                  }),
                  DropdownButtonFormField<int>(
                    value: selectedBrandId,
                    decoration: const InputDecoration(labelText: 'Brand *'),
                    items: brands.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                    onChanged: (v) {
                      setDlgState(() {
                        selectedBrandId = v!;
                        selectedSeriesId = null;
                      });
                      _api.getSeries(brandId: v).then((s) {
                        setDlgState(() => brandSeries = s);
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    value: selectedSeriesId,
                    decoration: const InputDecoration(labelText: 'Series (Optional)'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('No Series (Standalone)')),
                      ...brandSeries.map((s) => DropdownMenuItem<int?>(value: s.id, child: Text(s.name))),
                    ],
                    onChanged: (v) => setDlgState(() => selectedSeriesId = v),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Warranty Eligible', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Disable for old models without warranty claim options', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    value: hasWarranty,
                    onChanged: (v) => setDlgState(() => hasWarranty = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Model Name *', hintText: 'e.g. iPhone 15 Pro, S24 Ultra'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: yearCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Release Year', hintText: 'e.g. 2024'),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.lightGreen,
                          foregroundColor: AppTheme.darkGreen,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.photo_library_rounded, size: 16, color: AppTheme.primaryGreen),
                        label: const Text('Pick Photo (Gallery)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final b64 = await ImageHelper.pickImageAsBase64();
                          if (b64 != null) {
                            setDlgState(() => selectedPhotoBase64 = b64);
                          }
                        },
                      ),
                      if (selectedPhotoBase64 != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Colors.red),
                          onPressed: () => setDlgState(() => selectedPhotoBase64 = null),
                        ),
                      ],
                    ],
                  ),
                  if (selectedPhotoBase64 != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(ImageHelper.decodeBase64(selectedPhotoBase64)!, fit: BoxFit.contain),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;
                            Navigator.pop(dlgCtx);
                            try {
                              await _api.createPhoneModel({
                                'brand': selectedBrandId,
                                if (selectedSeriesId != null) 'series': selectedSeriesId,
                                'name': name,
                                'release_year': int.tryParse(yearCtrl.text.trim()) ?? DateTime.now().year,
                                'has_warranty': hasWarranty,
                                'image_base64': selectedPhotoBase64 ?? '',
                              });
                              onAdded();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('✓ Model "$name" created!'), backgroundColor: AppTheme.primaryGreen),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                              }
                            }
                          },
                          child: const Text('Create'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeletePhoneModel(PhoneModelItem model, {required VoidCallback onDeleted}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${model.name}"?'),
        content: const Text('Are you sure you want to delete this phone model? All storage variants will also be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deletePhoneModel(model.id);
                onDeleted();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted model ${model.name}')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ================= 4. VARIANTS & BASE PRICE MANAGEMENT =================
  void _showVariantManager() async {
    List<BrandModel> brands = [];
    List<PhoneModelItem> models = [];
    List<StorageVariantModel> variants = [];
    int? selectedModelId;

    try {
      brands = await _api.getBrands();
      models = await _api.getModels();
      if (models.isNotEmpty) {
        selectedModelId = models.first.id;
        variants = await _api.getVariants(selectedModelId);
      }
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(ctx).size.height * 0.85,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.96),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.storage_rounded, color: AppTheme.primaryGreen),
                          SizedBox(width: 8),
                          Text('Variants & Base Prices', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        ],
                      ),
                      if (models.isNotEmpty)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Variant', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => _showAddVariantDialog(
                            models: models,
                            initialModelId: selectedModelId,
                            onAdded: () async {
                              if (selectedModelId != null) {
                                final updated = await _api.getVariants(selectedModelId!);
                                setSheetState(() => variants = updated);
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (models.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: selectedModelId,
                      decoration: const InputDecoration(labelText: 'Select Phone Model'),
                      items: models.map((m) => DropdownMenuItem(value: m.id, child: Text('${m.brandName ?? ''} ${m.name}'))).toList(),
                      onChanged: (v) async {
                        selectedModelId = v;
                        if (v != null) {
                          final vList = await _api.getVariants(v);
                          setSheetState(() => variants = vList);
                        }
                      },
                    ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: variants.isEmpty
                        ? const Center(child: Text('No storage variants found for this model', style: TextStyle(color: AppTheme.textSecondary)))
                        : ListView.separated(
                            itemCount: variants.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, idx) {
                              final v = variants[idx];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                leading: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(color: AppTheme.lightGreen, borderRadius: BorderRadius.circular(12)),
                                  child: const Icon(Icons.sd_storage_rounded, color: AppTheme.primaryGreen, size: 22),
                                ),
                                title: Text(v.ram != null && v.ram!.isNotEmpty ? '${v.ram} / ${v.storage}' : v.storage, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text('Base Buyback: ₹${v.basePrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AppTheme.darkGreen, fontWeight: FontWeight.w700)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      tooltip: 'Delete Variant',
                                      onPressed: () => _confirmDeleteVariant(v, onDeleted: () async {
                                        if (selectedModelId != null) {
                                          final updated = await _api.getVariants(selectedModelId!);
                                          setSheetState(() => variants = updated);
                                        }
                                      }),
                                    ),
                                  ],
                                ),
                              );
                            },
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

  void _showAddVariantDialog({required List<PhoneModelItem> models, int? initialModelId, required VoidCallback onAdded}) {
    int selectedModelId = initialModelId ?? models.first.id;
    final ramCtrl = TextEditingController(text: '8GB');
    final storageCtrl = TextEditingController(text: '128GB');
    final priceCtrl = TextEditingController(text: '15000');

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            padding: const EdgeInsets.all(22),
            borderRadius: BorderRadius.circular(22),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Storage Variant', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    value: selectedModelId,
                    decoration: const InputDecoration(labelText: 'Model *'),
                    items: models.map((m) => DropdownMenuItem(value: m.id, child: Text('${m.brandName ?? ''} ${m.name}'))).toList(),
                    onChanged: (v) => setDlgState(() => selectedModelId = v!),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ramCtrl,
                          decoration: const InputDecoration(labelText: 'RAM', hintText: 'e.g. 6GB, 8GB'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: storageCtrl,
                          decoration: const InputDecoration(labelText: 'Storage *', hintText: 'e.g. 128GB'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Base Buyback Price (₹) *', hintText: 'e.g. 25000'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                          onPressed: () async {
                            final storage = storageCtrl.text.trim();
                            final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                            if (storage.isEmpty || price <= 0) return;
                            Navigator.pop(dlgCtx);
                            try {
                              await _api.createVariant({
                                'model': selectedModelId,
                                'ram': ramCtrl.text.trim(),
                                'storage': storage,
                                'base_price': price,
                              });
                              onAdded();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('✓ Storage variant added!'), backgroundColor: AppTheme.primaryGreen),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                              }
                            }
                          },
                          child: const Text('Create'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteVariant(StorageVariantModel variant, {required VoidCallback onDeleted}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Variant "${variant.storage}"?'),
        content: const Text('Are you sure you want to delete this storage variant?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteVariant(variant.id);
                onDeleted();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Variant deleted')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCopyQuestionsModal() async {
    List<BrandModel> brands = [];
    try {
      brands = await _api.getBrands();
    } catch (_) {}

    if (!mounted || brands.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No brands available to copy questions.')),
      );
      return;
    }

    int? selectedSourceBrandId;
    int? selectedTargetBrandId = brands.first.id;
    bool markMandatory = true;
    bool isCloning = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            padding: const EdgeInsets.all(22),
            borderRadius: BorderRadius.circular(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.copy_all_rounded, color: AppTheme.primaryGreen, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Copy Questions from Brand',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Clone all diagnostic steps, condition options, Base64 illustrations, and deduction rules from one brand to another.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  const Text('Source Brand (Copy From):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: selectedSourceBrandId,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('🌐 Universal / All Brands Questions'),
                          ),
                          ...brands.map((b) => DropdownMenuItem<int?>(
                                value: b.id,
                                child: Text(b.name),
                              )),
                        ],
                        onChanged: (val) => setDlgState(() => selectedSourceBrandId = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Target Brand (Clone To):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedTargetBrandId,
                        isExpanded: true,
                        items: brands.map((b) => DropdownMenuItem<int>(
                              value: b.id,
                              child: Text(b.name),
                            )).toList(),
                        onChanged: (val) => setDlgState(() => selectedTargetBrandId = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Switch.adaptive(
                        value: markMandatory,
                        activeColor: AppTheme.primaryGreen,
                        onChanged: (val) => setDlgState(() => markMandatory = val),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Mark Copied Questions as Mandatory',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: isCloning
                        ? null
                        : () async {
                            if (selectedTargetBrandId == null) return;
                            setDlgState(() => isCloning = true);
                            try {
                              final res = await _api.copyQuestionsFromBrand(
                                sourceBrandId: selectedSourceBrandId,
                                targetBrandId: selectedTargetBrandId!,
                                markMandatory: markMandatory,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppTheme.primaryGreen,
                                  content: Text(res['detail'] ?? 'Questions copied successfully!'),
                                ),
                              );
                              _loadAdminData();
                            } catch (e) {
                              setDlgState(() => isCloning = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error copying questions: $e')),
                              );
                            }
                          },
                    child: isCloning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.copy_all_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Clone Questions Now', style: TextStyle(fontWeight: FontWeight.w900)),
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

  void _confirmDeleteConditionCategory(ConditionCategoryModel cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Condition Step', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Are you sure you want to delete "${cat.name}" and all attached defect options?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteConditionCategory(cat.id);
                _loadAdminData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✓ Step "${cat.name}" deleted successfully!'), backgroundColor: AppTheme.primaryGreen),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSeriesManager() async {
    List<BrandModel> brands = [];
    List<SeriesModel> series = [];
    int? filterBrandId;

    try {
      brands = await _api.getBrands();
      series = await _api.getSeries();
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final displaySeries = filterBrandId != null
              ? series.where((s) => s.brandId == filterBrandId).toList()
              : series;

          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(20),
                height: MediaQuery.of(ctx).size.height * 0.85,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(10))),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.view_carousel_rounded, color: AppTheme.primaryGreen),
                            SizedBox(width: 8),
                            Text('Device Series Control', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Series', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => _showAddSeriesDialog(
                            brands: brands,
                            initialBrandId: filterBrandId,
                            onAdded: () async {
                              final updated = await _api.getSeries(brandId: filterBrandId);
                              setSheetState(() => series = updated);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (brands.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('All Brands'),
                              selected: filterBrandId == null,
                              onSelected: (_) async {
                                final s = await _api.getSeries();
                                setSheetState(() {
                                  filterBrandId = null;
                                  series = s;
                                });
                              },
                            ),
                            const SizedBox(width: 6),
                            ...brands.map((b) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(b.name),
                                    selected: filterBrandId == b.id,
                                    onSelected: (sel) async {
                                      final newId = sel ? b.id : null;
                                      final s = await _api.getSeries(brandId: newId);
                                      setSheetState(() {
                                        filterBrandId = newId;
                                        series = s;
                                      });
                                    },
                                  ),
                                )),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: displaySeries.isEmpty
                          ? const Center(child: Text('No series found for this brand', style: TextStyle(color: AppTheme.textSecondary)))
                          : ListView.separated(
                              itemCount: displaySeries.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, idx) {
                                final s = displaySeries[idx];
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppTheme.border.withOpacity(0.6)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryGreen.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.layers_rounded, color: AppTheme.primaryGreen, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(s.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.textPrimary)),
                                            if (s.brandName != null) ...[
                                              const SizedBox(height: 2),
                                              Text('Brand: ${s.brandName}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                            ],
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                        tooltip: 'Delete Series',
                                        onPressed: () async {
                                          final conf = await showDialog<bool>(
                                            context: context,
                                            builder: (c) => AlertDialog(
                                              title: const Text('Delete Series', style: TextStyle(fontWeight: FontWeight.bold)),
                                              content: Text('Delete series "${s.name}"?'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                  onPressed: () => Navigator.pop(c, true),
                                                  child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (conf == true) {
                                            try {
                                              await _api.deleteSeries(s.id);
                                              final updated = await _api.getSeries(brandId: filterBrandId);
                                              setSheetState(() => series = updated);
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('✓ Series "${s.name}" deleted!'), backgroundColor: AppTheme.primaryGreen),
                                                );
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                                              }
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddSeriesDialog({required List<BrandModel> brands, int? initialBrandId, required VoidCallback onAdded}) {
    if (brands.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a brand first')));
      return;
    }

    final nameCtrl = TextEditingController();
    final orderCtrl = TextEditingController(text: '0');
    int selectedBrandId = initialBrandId ?? brands.first.id;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            padding: const EdgeInsets.all(22),
            borderRadius: BorderRadius.circular(22),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Device Series', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    value: selectedBrandId,
                    decoration: const InputDecoration(labelText: 'Brand *'),
                    items: brands.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                    onChanged: (v) => setDlgState(() => selectedBrandId = v!),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Series Name *', hintText: 'e.g. iPhone 16 Series, Galaxy S24 Series'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: orderCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Display Order', hintText: '0'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;
                            Navigator.pop(dlgCtx);
                            try {
                              await _api.createSeries({
                                'brand': selectedBrandId,
                                'name': name,
                                'display_order': int.tryParse(orderCtrl.text.trim()) ?? 0,
                              });
                              onAdded();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('✓ Series "$name" created!'), backgroundColor: AppTheme.primaryGreen),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                              }
                            }
                          },
                          child: const Text('Create'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddConditionCategoryModal({ConditionCategoryModel? categoryToEdit}) {
    final nameCtrl = TextEditingController(text: categoryToEdit?.name ?? '');
    final subtitleCtrl = TextEditingController(text: categoryToEdit?.subtitle ?? '');
    final stepNumCtrl = TextEditingController(text: (categoryToEdit?.stepNumber ?? (_conditionCategories.length + 1)).toString());
    int? selectedBrandId = categoryToEdit?.brandId;
    String selectionType = categoryToEdit?.selectionType ?? 'SINGLE';
    bool isMandatory = categoryToEdit?.isMandatory ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: GlassContainer(
            padding: const EdgeInsets.all(22),
            borderRadius: BorderRadius.circular(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: Icon(categoryToEdit == null ? Icons.add_circle_outline_rounded : Icons.edit_rounded, color: AppTheme.primaryGreen, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(categoryToEdit == null ? 'Add Questionnaire Step' : 'Edit Questionnaire Step', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Step Title *', hintText: 'e.g. Screen & Touchscreen'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: subtitleCtrl,
                    decoration: const InputDecoration(labelText: 'Subtitle (Optional)', hintText: 'e.g. Tell us about display glass'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: stepNumCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Step Number *'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    value: selectedBrandId,
                    decoration: const InputDecoration(labelText: 'Brand Assignment'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Universal (All Brands)')),
                      ..._pricingBrands.map((b) => DropdownMenuItem<int?>(value: b.id, child: Text(b.name))),
                    ],
                    onChanged: (v) => setDlgState(() => selectedBrandId = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Single Choice'),
                        selected: selectionType == 'SINGLE',
                        onSelected: (v) => setDlgState(() => selectionType = 'SINGLE'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Multiple Choice'),
                        selected: selectionType == 'MULTI',
                        onSelected: (v) => setDlgState(() => selectionType = 'MULTI'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mandatory Step', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Customer must answer before continuing', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    value: isMandatory,
                    onChanged: (v) => setDlgState(() => isMandatory = v),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;
                            final stepNum = int.tryParse(stepNumCtrl.text.trim()) ?? 1;
                            Navigator.pop(ctx);
                            try {
                              final payload = {
                                'name': name,
                                'subtitle': subtitleCtrl.text.trim(),
                                'step_number': stepNum,
                                'selection_type': selectionType,
                                'is_mandatory': isMandatory,
                                if (selectedBrandId != null) 'brand': selectedBrandId,
                              };
                              if (categoryToEdit != null) {
                                await _api.updateConditionCategory(categoryToEdit.id, payload);
                              } else {
                                await _api.createConditionCategory(payload);
                              }
                              _loadAdminData();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('✓ Step "$name" ${categoryToEdit == null ? "created" : "updated"}!'), backgroundColor: AppTheme.primaryGreen),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                              }
                            }
                          },
                          child: Text(categoryToEdit == null ? 'Create Step' : 'Update Step'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddConditionOptionModal(ConditionCategoryModel cat) {
    final titleCtrl = TextEditingController();
    final valCtrl = TextEditingController(text: '500');
    final imgCtrl = TextEditingController();
    String deductionType = 'FLAT';
    bool isRejection = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: GlassContainer(
            padding: const EdgeInsets.all(22),
            borderRadius: BorderRadius.circular(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryGreen, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Add Option to ${cat.name}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Option / Defect Title *', hintText: 'e.g. Broken back glass'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: valCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Deduction Amount *', prefixIcon: Icon(Icons.currency_rupee, color: AppTheme.primaryGreen)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Flat (₹)'),
                        selected: deductionType == 'FLAT',
                        onSelected: (v) => setDlgState(() => deductionType = 'FLAT'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Percentage (%)'),
                        selected: deductionType == 'PERCENTAGE',
                        onSelected: (v) => setDlgState(() => deductionType = 'PERCENTAGE'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reject Device If Selected', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Instantly marks device ineligible for buyback', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    value: isRejection,
                    onChanged: (v) => setDlgState(() => isRejection = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.lightGreen,
                          foregroundColor: AppTheme.darkGreen,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.photo_library_rounded, size: 16, color: AppTheme.primaryGreen),
                        label: const Text('Pick Photo (JPG/PNG)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final b64 = await ImageHelper.pickImageAsBase64();
                          if (b64 != null) {
                            setDlgState(() => imgCtrl.text = b64);
                          }
                        },
                      ),
                      if (imgCtrl.text.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => setDlgState(() => imgCtrl.text = ''),
                          child: const Text('Clear', style: TextStyle(color: Colors.red, fontSize: 11)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                          onPressed: () async {
                            final title = titleCtrl.text.trim();
                            if (title.isEmpty) return;
                            final val = double.tryParse(valCtrl.text.trim()) ?? 0.0;
                            Navigator.pop(ctx);
                            try {
                              await _api.createConditionOption({
                                'category': cat.id,
                                'title': title,
                                'default_deduction_value': val,
                                'deduction_type': deductionType,
                                'is_rejection': isRejection,
                                'image_base64': imgCtrl.text.trim(),
                              });
                              _loadAdminData();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('✓ Option "$title" added!'), backgroundColor: AppTheme.primaryGreen),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                              }
                            }
                          },
                          child: const Text('Add Option'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPricingTab() {
    final filteredCategories = _conditionCategories.where((c) {
      if (_selectedPricingBrandId == null) return true;
      if (_selectedPricingBrandId == -1) return c.brand == null;
      return c.brand == _selectedPricingBrandId || c.brand == null;
    }).toList();

    return Column(
      children: [
        // Quick Action Bar for Catalog Suite
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCatalogQuickBtn('+ Add Step', Icons.add_circle_outline_rounded, _showAddConditionCategoryModal, isPrimary: true),
                const SizedBox(width: 8),
                _buildCatalogQuickBtn('Copy from Brand', Icons.copy_all_rounded, _showCopyQuestionsModal),
                const SizedBox(width: 8),
                _buildCatalogQuickBtn('Categories', Icons.category_rounded, _showCategoryManager),
                const SizedBox(width: 8),
                _buildCatalogQuickBtn('Brands', Icons.verified_rounded, _showBrandManager),
                const SizedBox(width: 8),
                _buildCatalogQuickBtn('Series', Icons.view_carousel_rounded, _showSeriesManager),
                const SizedBox(width: 8),
                _buildCatalogQuickBtn('Models', Icons.phone_android_rounded, _showModelManager),
                const SizedBox(width: 8),
                _buildCatalogQuickBtn('Variants & Prices', Icons.storage_rounded, _showVariantManager),
              ],
            ),
          ),
        ),

        // Brand Questionnaire Mapping Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: Text('All (${_conditionCategories.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  selected: _selectedPricingBrandId == null,
                  selectedColor: AppTheme.primaryGreen.withOpacity(0.2),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedPricingBrandId = null);
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: Text('🌐 Universal (${_conditionCategories.where((c) => c.brand == null).length})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  selected: _selectedPricingBrandId == -1,
                  selectedColor: AppTheme.primaryGreen.withOpacity(0.2),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedPricingBrandId = -1);
                  },
                ),
                const SizedBox(width: 6),
                ..._pricingBrands.map((b) {
                  final brandCount = _conditionCategories.where((c) => c.brand == b.id || c.brand == null).length;
                  final exclusiveCount = _conditionCategories.where((c) => c.brand == b.id).length;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        '${b.name} ($brandCount${exclusiveCount > 0 ? ' • $exclusiveCount exclusive' : ''})',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      selected: _selectedPricingBrandId == b.id,
                      selectedColor: AppTheme.primaryGreen.withOpacity(0.2),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedPricingBrandId = b.id);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        filteredCategories.isEmpty
            ? Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.rule_folder_outlined, size: 48, color: AppTheme.textSecondary),
                        const SizedBox(height: 12),
                        const Text(
                          'No condition rules matched for this filter',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap below to reload rules from cloud or restore standard defect categories.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                          label: const Text('Reload Pricing & Defect Rules', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: _loadAdminData,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
              final cat = filteredCategories[index];
              return GlassContainer(
                padding: const EdgeInsets.all(16),
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Step ${index + 1}: ${cat.name}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary),
                          ),
                        ),
                        Row(
                          children: [
                            if (cat.brandName != null && cat.brandName!.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Text(cat.brandName!, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                              ),
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: cat.isMandatory ? AppTheme.primaryGreen.withOpacity(0.12) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                cat.isMandatory ? 'Mandatory' : 'Optional',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: cat.isMandatory ? AppTheme.primaryGreen : Colors.grey.shade700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('${cat.options.length} options', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.primaryGreen)),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryGreen),
                              tooltip: 'Edit Question Step',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _showAddConditionCategoryModal(categoryToEdit: cat),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              tooltip: 'Delete Question Step',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _confirmDeleteConditionCategory(cat),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: cat.options.map((opt) {
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _editConditionOption(opt),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.glassBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${opt.title}: -₹${opt.defaultDeductionValue.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.edit, size: 12, color: AppTheme.primaryGreen),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
