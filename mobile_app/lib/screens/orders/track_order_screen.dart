import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';
import '../auth/auth_modal_sheet.dart';
import '../sell_wizard/category_selection_screen.dart';
import '../../utils/contact_launcher.dart';
import '../../utils/image_helper.dart';
import '../../widgets/brand_logo.dart';

class TrackOrderScreen extends StatefulWidget {
  final String? initialSaleCode;

  const TrackOrderScreen({super.key, this.initialSaleCode});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  final ApiService _api = ApiService();
  final _searchController = TextEditingController();

  SaleOrderModel? _order;
  List<SaleOrderModel> _myOrders = [];
  bool _loading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialSaleCode != null && widget.initialSaleCode!.isNotEmpty) {
      _searchController.text = widget.initialSaleCode!;
      _lookupOrder(widget.initialSaleCode!);
    } else {
      _loadRecentOrders();
    }
  }

  Future<void> _acceptOffer(SaleOrderModel order) async {
    setState(() => _loading = true);
    try {
      await _api.acceptFinalOffer(order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Final buyback offer accepted! Please hand over device to agent.'),
          backgroundColor: AppTheme.primaryGreen,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _lookupOrder(order.saleCode);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _rejectOffer(SaleOrderModel order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline Buyback Offer?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('If declined, the device inspection will be closed and the agent will return the phone to you immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Decline Offer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await _api.rejectFinalOffer(order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offer declined. Device return initiated.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _lookupOrder(order.saleCode);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _cancelOrder(SaleOrderModel order) async {
    String selectedReason = 'Changed my mind';
    final reasons = [
      'Changed my mind',
      'Price didn\'t match expectation',
      'Decided to keep or gift device',
      'Device repaired or sold elsewhere',
      'Wrong details entered',
      'Other',
    ];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.cancel_outlined, color: Colors.red, size: 22),
              SizedBox(width: 8),
              Text('Cancel Sell Order?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to cancel the doorstep pickup for your ${order.brandName} ${order.modelName}?',
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 14),
              const Text('Reason for cancellation:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.grey.shade50,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedReason,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                    items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDlgState(() => selectedReason = val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Order'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await _api.cancelOrder(order.id, reason: selectedReason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Selling order has been cancelled successfully.'),
          backgroundColor: Colors.black87,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _lookupOrder(order.saleCode);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel order: $e'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentOrders() async {
    final user = _api.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    try {
      final list = await _api.getSales();
      if (mounted) {
        setState(() {
          _myOrders = list;
          if (list.isNotEmpty) {
            _order = list.first;
            _searchController.text = _order!.saleCode;
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _lookupOrder(String code) async {
    if (code.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final o = await _api.getSaleDetail(code.trim());
      if (mounted) {
        setState(() {
          _order = o;
          _loading = false;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = 'Order not found for code: $code';
          _loading = false;
        });
      }
    }
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
        title: const Text('Track Order Status', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.headset_mic_rounded, color: AppTheme.primaryGreen),
            tooltip: 'Support Help Desk',
            onPressed: () => ContactLauncher.callHotline(context),
          ),
        ],
      ),
      body: GlassBackgroundMesh(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Frosted Search Bar for Sale Code
                GlassContainer(
                  padding: const EdgeInsets.all(8),
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Enter Order ID (e.g. XP2610008753)...',
                            hintStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withOpacity(0.8)),
                            prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryGreen),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onSubmitted: _lookupOrder,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _lookupOrder(_searchController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Track', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: RecellBrandLoader(message: 'Tracking real-time order status...'),
                  )
                else if (_error.isNotEmpty)
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.red.withOpacity(0.4)),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_error, style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  )
                else if (_order != null)
                  _buildOrderTimelineCard(_order!)
                else if (_api.currentUser == null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: GlassContainer(
                        padding: const EdgeInsets.all(26),
                        borderRadius: BorderRadius.circular(24),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.lock_person_rounded, size: 42, color: AppTheme.primaryGreen),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Track Your Personal Orders',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Doorstep pickup timelines, QC verification, and instant UPI receipts are linked to your account.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (ctx) => AuthModalSheet(
                                    onSuccess: () {
                                      setState(() {});
                                      _loadRecentOrders();
                                    },
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.login_rounded, size: 18),
                              label: const Text('Sign In or Register', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Have a pickup receipt slip? Enter the Order ID in the search bar above.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: GlassContainer(
                        padding: const EdgeInsets.all(26),
                        borderRadius: BorderRadius.circular(24),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.lightGreen,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.receipt_long_outlined, size: 40, color: AppTheme.primaryGreen),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Active Orders for ${_api.currentUser?.fullName ?? "You"}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'You haven\'t placed any device sell orders yet. Sell your old phone, tablet, or dead device today for instant doorstep cash!',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CategorySelectionScreen()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.sell_outlined, size: 18),
                              label: const Text('Sell a Device Now', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Recent Orders List (if multiple exist)
                if (_myOrders.length > 1) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Your Recent Bookings',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  ..._myOrders.map(
                    (o) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassContainer(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.phone_iphone_rounded, color: AppTheme.primaryGreen, size: 20),
                          ),
                          title: Text(
                            '${o.brandName} ${o.modelName}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.textPrimary),
                          ),
                          subtitle: Text(
                            '${o.saleCode} · ₹${o.estimatedPrice.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.primaryGreen),
                          onTap: () {
                            setState(() {
                              _order = o;
                              _searchController.text = o.saleCode;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderTimelineCard(SaleOrderModel order) {
    // Stage Calculation for 6-Milestone Lifecycle
    int currentStage = 1;
    if (order.status == 'PICKUP_SCHEDULED') currentStage = 2;
    if (order.status == 'FINAL_OFFER_SENT') currentStage = 3;
    if (order.status == 'CUSTOMER_ACCEPTED') currentStage = 4;
    if (order.status == 'OWNERSHIP_TRANSFERRED') currentStage = 5;
    if (order.status == 'PAYMENT_COMPLETED') currentStage = 6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Order Code Frosted Glass Header
        GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          borderRadius: BorderRadius.circular(22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DOLLY ORDER ID',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.textSecondary, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    order.saleCode,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: 0.5),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: order.status == 'CANCELLED' ? Colors.red.withOpacity(0.12) : AppTheme.primaryGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: order.status == 'CANCELLED' ? Colors.red.withOpacity(0.4) : AppTheme.primaryGreen.withOpacity(0.3)),
                    ),
                    child: Text(
                      order.status.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: order.status == 'CANCELLED' ? Colors.red : AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.primaryGreen),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: order.saleCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Order ID copied to clipboard'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Action Banners based on customer approval stage
        if (order.status == 'CANCELLED') ...[
          GlassContainer(
            padding: const EdgeInsets.all(18),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.red.withOpacity(0.4), width: 1.5),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.cancel_rounded, color: Colors.red, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Selling Order Cancelled', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.red)),
                      SizedBox(height: 2),
                      Text('This doorstep buyback request was cancelled. No device inspection or collection will take place.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ] else if (order.status == 'FINAL_OFFER_SENT') ...[
          GlassContainer(
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.amber.shade600, width: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.rate_review_rounded, color: Colors.amber.shade900, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ACTION REQUIRED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.amber, letterSpacing: 0.8)),
                          Text('Review Final Buyback Offer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Doorstep inspection is completed for your ${order.brandName} ${order.modelName}. Please review the final price below:',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                if (order.imeiNumber != null && order.imeiNumber!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Verified IMEI: ${order.imeiNumber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.darkGreen)),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Final Agreed Payout:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                      Text(
                        '₹${(order.finalPrice ?? order.estimatedPrice).toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppTheme.primaryGreen),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _rejectOffer(order),
                        child: const Text('Decline', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _acceptOffer(order),
                        child: const Text('Accept Offer ✓', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ] else if (order.status == 'CUSTOMER_ACCEPTED') ...[
          GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: BorderRadius.circular(20),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Offer Accepted (₹${(order.finalPrice ?? order.estimatedPrice).toStringAsFixed(0)})', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.darkGreen)),
                      const SizedBox(height: 2),
                      Text('Please hand over the physical device to agent ${order.assignedAgentName ?? "Specialist"}.', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ] else if (order.status == 'OWNERSHIP_TRANSFERRED') ...[
          GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: BorderRadius.circular(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pickup Completed & In Custody', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.darkGreen)),
                      const SizedBox(height: 2),
                      Text('Device safely handed over to ${order.assignedAgentName ?? "Agent"}. Super Admin payout is being processed.', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 2. Timeline Card
        GlassContainer(
          padding: const EdgeInsets.all(22),
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Live 6-Stage Pickup & Payout Progress',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 18),
              _buildTimelineStep(
                title: '1. Request Submitted',
                subtitle: 'Order recorded in Dolly operations desk',
                isCompleted: currentStage >= 1,
                isCurrent: currentStage == 1,
              ),
              _buildTimelineStep(
                title: '2. Pickup Scheduled',
                subtitle: order.assignedAgentName != null
                    ? 'Assigned to Agent ${order.assignedAgentName}'
                    : 'Awaiting field agent assignment',
                isCompleted: currentStage >= 2,
                isCurrent: currentStage == 2,
              ),
              _buildTimelineStep(
                title: '3. Doorstep QC Inspected',
                subtitle: currentStage >= 3 ? 'Inspection completed by agent · Final offer sent' : '10-point physical inspection & IMEI verification',
                isCompleted: currentStage >= 3,
                isCurrent: currentStage == 3,
              ),
              _buildTimelineStep(
                title: '4. Offer Confirmed by Customer',
                subtitle: currentStage >= 4 ? 'You accepted the final offer amount' : 'Customer reviews & confirms final buyback price',
                isCompleted: currentStage >= 4,
                isCurrent: currentStage == 4,
              ),
              _buildTimelineStep(
                title: '5. Pickup Completed (Device Collected)',
                subtitle: currentStage >= 5 ? 'Physical device handed over to agent' : 'Agent verifies customer agreement and collects phone',
                isCompleted: currentStage >= 5,
                isCurrent: currentStage == 5,
              ),
              _buildTimelineStep(
                title: '6. Payout Disbursed',
                subtitle: currentStage >= 6 ? 'Transferred via UPI · Payout Completed' : 'Super Admin releases instant payment',
                isCompleted: currentStage >= 6,
                isCurrent: currentStage == 6,
                isLast: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 3. Order Details Summary Card
        GlassContainer(
          padding: const EdgeInsets.all(18),
          borderRadius: BorderRadius.circular(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Device & Payout Details', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.textPrimary)),
              Divider(height: 16, color: AppTheme.border.withOpacity(0.6)),
              _buildDetailRow('Device', '${order.brandName} ${order.modelName} (${order.storage})'),
              _buildDetailRow('Quoted Value', '₹${order.estimatedPrice.toStringAsFixed(0)}'),
              if (order.finalPrice != null)
                _buildDetailRow('Final Agreed Price', '₹${order.finalPrice!.toStringAsFixed(0)}'),
              if (order.pickupSlot != null)
                _buildDetailRow('Scheduled Pickup', '${order.pickupDate ?? "Scheduled"} · ${order.pickupSlot!} (IST)'),
              if (order.createdAtIst != null)
                _buildDetailRow('Booked On', order.createdAtIst!),
              _buildDetailRow('Pickup Address', '${order.pickupAddress}, ${order.pickupCity} - ${order.pickupPincode}'),
              _buildDetailRow('Payout Method', '${order.beneficiaryType}: ${order.beneficiaryUpiId ?? 'Direct Account'}'),
            ],
          ),
        ),

        // 4. Official Payment Proof & Confirmation Card (If Paid)
        if (order.payment != null || order.status == 'PAYMENT_COMPLETED') ...[
          const SizedBox(height: 16),
          GlassContainer(
            padding: const EdgeInsets.all(18),
            borderRadius: BorderRadius.circular(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppTheme.lightGreen, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.verified_user_rounded, color: AppTheme.primaryGreen, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment Transferred & Verified',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.textPrimary),
                          ),
                          Text(
                            order.payment?.utrNumber != null && order.payment!.utrNumber.isNotEmpty
                                ? 'Bank UTR: ${order.payment!.utrNumber}'
                                : 'Instant Disbursal Confirmed',
                            style: const TextStyle(fontSize: 11, color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (order.payment != null && order.payment!.paymentProofBase64.isNotEmpty) ...[
                  Builder(builder: (ctx) {
                    final bytes = ImageHelper.decodeBase64(order.payment!.paymentProofBase64);
                    if (bytes != null) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 14),
                          const Text(
                            'Official Bank / UPI Payout Confirmation Receipt:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.memory(bytes, width: double.infinity, fit: BoxFit.contain),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                ],
              ],
            ),
          ),
        ],

        // 5. Agent Handover Inspection Photos (If captured)
        if (order.inspection != null && order.inspection!.photos.isNotEmpty) ...[
          const SizedBox(height: 16),
          GlassContainer(
            padding: const EdgeInsets.all(18),
            borderRadius: BorderRadius.circular(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.camera_alt_outlined, size: 18, color: AppTheme.primaryGreen),
                    const SizedBox(width: 8),
                    Text(
                      'Doorstep Inspection Photos (${order.inspection!.photos.length})',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: order.inspection!.photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (ctx, idx) {
                      final p = order.inspection!.photos[idx];
                      final bytes = ImageHelper.decodeBase64(p.imageBase64);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 65,
                            height: 65,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: bytes != null
                                  ? Image.memory(bytes, fit: BoxFit.cover)
                                  : const Icon(Icons.image, color: AppTheme.textSecondary),
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 65,
                            child: Text(
                              p.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Concierge Support Button
        GlassContainer(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          borderRadius: BorderRadius.circular(16),
          child: OutlinedButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (ctx) => ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      color: Colors.white.withOpacity(0.96),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(10))),
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              Icon(Icons.headset_mic_rounded, color: AppTheme.primaryGreen),
                              SizedBox(width: 8),
                              Text('Dolly Order Concierge', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ListTile(
                            leading: const Icon(Icons.phone_rounded, color: AppTheme.primaryGreen),
                            title: const Text('+91 90252 32453', style: TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: const Text('Direct Pickup Support & Dispute Line'),
                            onTap: () => ContactLauncher.callHotline(context),
                            trailing: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.phone_forwarded_rounded, size: 12),
                              label: const Text('Call', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              onPressed: () => ContactLauncher.callHotline(context),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.email_outlined, color: Color(0xFFD97706)),
                            title: const Text('aiothamizha@gmail.com', style: TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: const Text('Official Support Desk'),
                            onTap: () => ContactLauncher.sendEmail(context, subject: 'Order ${order.saleCode} Support Request'),
                            trailing: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD97706),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.mail_outline_rounded, size: 12),
                              label: const Text('Mail', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              onPressed: () => ContactLauncher.sendEmail(context, subject: 'Order ${order.saleCode} Support Request'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: BorderSide(color: AppTheme.primaryGreen.withOpacity(0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.headset_mic_outlined, size: 18, color: AppTheme.primaryGreen),
                SizedBox(width: 8),
                Text(
                  'Need Help? Contact Dolly Support',
                  style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
        ),

        // Cancel Order Action Button (Visible if order is pending/scheduled/inspected)
        if (['SUBMITTED', 'PICKUP_SCHEDULED', 'INSPECTION_PENDING', 'FINAL_OFFER_SENT'].contains(order.status)) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: Colors.red.shade300, width: 1.2),
                backgroundColor: Colors.red.withOpacity(0.04),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
              label: const Text(
                'Cancel This Selling Order',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () => _cancelOrder(order),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isCurrent,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? AppTheme.primaryGreen : Colors.white.withOpacity(0.8),
                border: Border.all(
                  color: isCompleted ? AppTheme.primaryGreen : AppTheme.glassBorder,
                  width: 2,
                ),
                boxShadow: isCompleted
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 38,
                color: isCompleted ? AppTheme.primaryGreen.withOpacity(0.8) : AppTheme.border.withOpacity(0.7),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: isCompleted ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              if (!isLast) const SizedBox(height: 18),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}
