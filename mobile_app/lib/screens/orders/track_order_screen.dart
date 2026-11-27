import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';
import '../auth/auth_modal_sheet.dart';
import '../sell_wizard/category_selection_screen.dart';
import '../home_screen.dart';
import '../../utils/contact_launcher.dart';
import '../../utils/image_helper.dart';
import '../../widgets/brand_logo.dart';

class TrackOrderScreen extends StatefulWidget {
  final String? initialSaleCode;
  final bool isFromBooking;

  const TrackOrderScreen({
    super.key,
    this.initialSaleCode,
    this.isFromBooking = false,
  });

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
  String _activeFilter = 'ALL';

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

  void _goToHomeScreen() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _showPaymentProofViewer(Uint8List bytes, String utr, String upiId) {
    showDialog(
      context: context,
      builder: (zCtx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 5.0,
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(zCtx),
                  ),
                ),
              ),
              Positioned(
                bottom: 14,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Verified Payout Receipt',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                      if (upiId.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'UPI: $upiId',
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                          ),
                        ),
                      if (utr.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Bank Ref / UTR: $utr',
                            style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.cancel_rounded, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 8),
              const Text('Cancel Selling Order?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to cancel the doorstep pickup for your ${order.brandName} ${order.modelName}?',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),
              const Text('Reason for cancellation (optional):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
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

  Future<void> _adminCancelOrder(SaleOrderModel order) async {
    String selectedReason = 'Customer requested cancellation';
    final adminReasons = [
      'Customer requested cancellation',
      'Customer unreachable / Invalid phone',
      'Out of operational service area',
      'Device mismatch / Fake details entered',
      'Duplicate order booking',
      'Other operational reason',
    ];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 8),
              const Text('Admin Cancel Order', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cancel order ${order.saleCode.isNotEmpty ? order.saleCode : "#${order.id}"} (${order.brandName} ${order.modelName})?',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),
              const Text('Administrative Cancellation Reason:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedReason,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                    items: adminReasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
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
              child: const Text('Back'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm Admin Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await _api.cancelOrder(order.id, reason: '[ADMIN] $selectedReason');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Order ${order.saleCode} cancelled by Admin ($selectedReason).'),
          backgroundColor: AppTheme.darkGreen,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _lookupOrder(order.saleCode);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Admin cancel error: $e'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
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
          // If exactly 1 order, open it directly; if multiple, start in Amazon-style list view!
          if (list.length == 1) {
            _order = list.first;
            _searchController.text = _order!.saleCode;
          } else {
            _order = null;
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _lookupOrder(String code) async {
    if (code.trim().isEmpty) {
      if (_myOrders.isNotEmpty) {
        setState(() => _order = null);
      }
      return;
    }
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

  List<SaleOrderModel> get _filteredOrders {
    if (_activeFilter == 'SCHEDULED') {
      return _myOrders.where((o) => ['SUBMITTED', 'PICKUP_SCHEDULED'].contains(o.status)).toList();
    }
    if (_activeFilter == 'INSPECTION') {
      return _myOrders.where((o) => ['INSPECTION_PENDING', 'FINAL_OFFER_SENT', 'CUSTOMER_ACCEPTED'].contains(o.status)).toList();
    }
    if (_activeFilter == 'PAID') {
      return _myOrders.where((o) => ['OWNERSHIP_TRANSFERRED', 'PAYMENT_COMPLETED'].contains(o.status)).toList();
    }
    if (_activeFilter == 'CANCELLED') {
      return _myOrders.where((o) => o.status == 'CANCELLED').toList();
    }
    return _myOrders;
  }

  @override
  Widget build(BuildContext context) {
    final hasMultipleOrders = _myOrders.length > 1;
    final isDetailView = _order != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.80),
        elevation: 0,
        leading: widget.isFromBooking
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
                tooltip: 'Back to Home',
                onPressed: _goToHomeScreen,
              )
            : (isDetailView && hasMultipleOrders
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
                    tooltip: 'All Orders',
                    onPressed: () => setState(() => _order = null),
                  )
                : null),
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
        title: Text(
          isDetailView ? 'Order Details' : 'Your Orders',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.headset_mic_rounded, color: AppTheme.primaryGreen),
            tooltip: 'Support Help Desk',
            onPressed: () => ContactLauncher.callHotline(context),
          ),
        ],
      ),
      body: PopScope(
        canPop: !widget.isFromBooking,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (widget.isFromBooking) {
            _goToHomeScreen();
          }
        },
        child: GlassBackgroundMesh(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Search Bar (Amazon style)
                GlassContainer(
                  padding: const EdgeInsets.all(6),
                  borderRadius: BorderRadius.circular(18),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search by Order ID (e.g. PHN-2026-22245B)...',
                            hintStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withOpacity(0.8)),
                            prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryGreen, size: 20),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          onSubmitted: _lookupOrder,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _lookupOrder(_searchController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Search', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

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
                // VIEW B: SINGLE ORDER DETAILS VIEW (AMAZON STYLE)
                else if (_order != null) ...[
                  if (hasMultipleOrders) ...[
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryGreen,
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: Text('Back to All Orders (${_myOrders.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () => setState(() => _order = null),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _buildAmazonOrderDetailView(_order!),
                ]
                // VIEW A: MULTIPLE ORDERS LIST VIEW (AMAZON STYLE)
                else if (_myOrders.isNotEmpty)
                  _buildAmazonOrdersListView()
                // GUEST / SIGN-IN PROMPT
                else if (_api.currentUser == null)
                  _buildGuestSignInView()
                // NO ORDERS
                else
                  _buildEmptyOrdersView(),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  // =========================================================
  // VIEW A: AMAZON-STYLE "YOUR ORDERS" LIST SCREEN
  // =========================================================
  Widget _buildAmazonOrdersListView() {
    final orders = _filteredOrders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('ALL', 'All (${_myOrders.length})'),
              _buildFilterChip('SCHEDULED', 'Scheduled'),
              _buildFilterChip('INSPECTION', 'QC / Inspection'),
              _buildFilterChip('PAID', 'Completed'),
              _buildFilterChip('CANCELLED', 'Cancelled'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (orders.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: GlassContainer(
                padding: const EdgeInsets.all(24),
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 36, color: AppTheme.primaryGreen),
                    const SizedBox(height: 10),
                    const Text('No orders in this category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('Tap "All" to view your full buyback history.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ),
          )
        else
          ...orders.map((o) {
            final isPaid = o.status == 'PAYMENT_COMPLETED';
            final isCancelled = o.status == 'CANCELLED';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() {
                    _order = o;
                    _searchController.text = o.saleCode;
                  });
                  _lookupOrder(o.saleCode);
                },
                child: GlassContainer(
                  padding: EdgeInsets.zero,
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      // Amazon Top Card Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100.withOpacity(0.8),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('ORDER PLACED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                                Text(o.pickupDate ?? 'Recent', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                              ],
                            ),
                            Row(
                              children: [
                                Text('#${o.saleCode}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, fontFamily: 'monospace', color: AppTheme.textPrimary)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isCancelled ? Colors.red.withOpacity(0.12) : isPaid ? AppTheme.primaryGreen.withOpacity(0.15) : Colors.amber.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    o.status.replaceAll('_', ' '),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: isCancelled ? Colors.red : isPaid ? AppTheme.primaryGreen : Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Card Content
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: AppTheme.lightGreen,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                              ),
                              child: const Icon(Icons.phone_iphone_rounded, color: AppTheme.primaryGreen, size: 28),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${o.brandName} ${o.modelName}',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Slot: ${o.pickupDate ?? "Today"} · ${o.pickupSlot ?? "Morning"}',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹${(o.finalPrice ?? o.estimatedPrice).toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.primaryGreen),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, size: 22, color: AppTheme.primaryGreen),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _activeFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.white : AppTheme.textPrimary,
        ),
        selectedColor: AppTheme.primaryGreen,
        backgroundColor: Colors.white.withOpacity(0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade300)),
        onSelected: (_) => setState(() => _activeFilter = key),
      ),
    );
  }

  Widget _buildPayoutProofCard(SaleOrderModel order) {
    final pay = order.payment;
    final upiId = (order.beneficiaryUpiId != null && order.beneficiaryUpiId!.isNotEmpty)
        ? order.beneficiaryUpiId!
        : (pay?.beneficiaryUpiId ?? '');
    final utr = pay?.utrNumber ?? '';
    final amount = pay?.amount != null && pay!.amount > 0
        ? pay.amount
        : (order.finalPrice ?? order.estimatedPrice);
    final proofBase64 = pay?.paymentProofBase64;
    final bytes = (proofBase64 != null && proofBase64.isNotEmpty)
        ? ImageHelper.decodeBase64(proofBase64)
        : null;

    return GlassContainer(
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppTheme.primaryGreen, width: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, color: AppTheme.primaryGreen, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Disbursed Successfully',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Instant buyback payment credited',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: Colors.grey.shade300),
          const SizedBox(height: 12),

          // UPI ID Row
          if (upiId.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, size: 18, color: AppTheme.primaryGreen),
                  const SizedBox(width: 8),
                  const Text('Paid to UPI ID:', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      upiId,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, fontFamily: 'monospace'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: upiId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('UPI ID copied to clipboard'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.copy_rounded, size: 16, color: AppTheme.primaryGreen),
                    ),
                  ),
                ],
              ),
            ),

          // UTR / Reference Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_rounded, size: 18, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                const Text('Transaction ID / UTR:', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    utr.isNotEmpty ? utr : 'Processing via Banking Gateway',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: utr.isNotEmpty ? AppTheme.textPrimary : Colors.grey.shade600,
                      fontFamily: utr.isNotEmpty ? 'monospace' : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (utr.isNotEmpty)
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: utr));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transaction ID copied to clipboard'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.copy_rounded, size: 16, color: AppTheme.primaryGreen),
                    ),
                  ),
              ],
            ),
          ),

          // Payout Proof Image Preview
          if (bytes != null && bytes.length > 200) ...[
            const Text(
              'Official Bank Transfer Proof',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showPaymentProofViewer(bytes, utr, upiId),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 180,
                      width: double.infinity,
                      color: Colors.black,
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.1),
                            Colors.black.withOpacity(0.65),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in_rounded, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Tap to View & Pinch to Zoom',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined, color: AppTheme.primaryGreen, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Disbursed to Beneficiary',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.darkGreen),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Doorstep collection verified. Funds sent directly to $upiId.',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================
  // VIEW B: AMAZON-STYLE ORDER DETAILS & TIMELINE
  // =========================================================
  Widget _buildAmazonOrderDetailView(SaleOrderModel order) {
    int currentStage = 1;
    if (order.status == 'PICKUP_SCHEDULED') currentStage = 2;
    if (order.status == 'FINAL_OFFER_SENT') currentStage = 3;
    if (order.status == 'CUSTOMER_ACCEPTED') currentStage = 4;
    if (order.status == 'OWNERSHIP_TRANSFERRED') currentStage = 5;
    if (order.status == 'PAYMENT_COMPLETED') currentStage = 6;

    final isPaid = order.status == 'PAYMENT_COMPLETED' || order.status == 'PAID' || order.payment != null;
    final isCancelled = order.status == 'CANCELLED';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Amazon Hero Status Card (Screenshot 2 style)
        GlassContainer(
          padding: const EdgeInsets.all(18),
          borderRadius: BorderRadius.circular(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPaid ? 'Payment Disbursed' : isCancelled ? 'Order Cancelled' : 'Doorstep Pickup Scheduled',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: isPaid ? AppTheme.primaryGreen : isCancelled ? Colors.red : AppTheme.darkGreen,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isPaid
                              ? 'Paid ₹${(order.payment?.amount ?? order.finalPrice ?? order.estimatedPrice).toStringAsFixed(0)}'
                              : '${order.pickupDate ?? "Today"} · ${order.pickupSlot ?? "Morning"}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.lightGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.phone_iphone_rounded, color: AppTheme.primaryGreen, size: 26),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Pickup address: ${order.pickupAddress}, ${order.pickupCity}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Payout Proof & Bank Confirmation Card
        if (isPaid || order.payment != null) ...[
          _buildPayoutProofCard(order),
          const SizedBox(height: 14),
        ],

        // Action Banners: Review final offer / Cancelled
        if (order.status == 'FINAL_OFFER_SENT') ...[
          GlassContainer(
            padding: const EdgeInsets.all(18),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.amber.shade600, width: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Physical Inspection Completed', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  'Our agent inspected your ${order.brandName} ${order.modelName} and offered a final payout of:',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 10),
                Text(
                  '₹${(order.finalPrice ?? order.estimatedPrice).toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primaryGreen),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                        onPressed: () => _rejectOffer(order),
                        child: const Text('Decline', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                        onPressed: () => _acceptOffer(order),
                        child: const Text('Accept Offer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // In-App Cash Handover OTP Card (ONLY for Cash on Pickup / COD orders)
        if (['CUSTOMER_ACCEPTED', 'OWNERSHIP_TRANSFERRED', 'PAYMENT_PENDING'].contains(order.status) &&
            order.beneficiaryType == 'CASH' &&
            order.cashHandoverOtp != null &&
            order.cashHandoverOtp!.isNotEmpty) ...[
          GlassContainer(
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.primaryGreen, width: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.payments_rounded, color: AppTheme.primaryGreen, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Text('Cash Handover Verification', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.textPrimary)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Collect ₹${(order.finalPrice ?? order.estimatedPrice).toStringAsFixed(0)} in cash from the agent. Once you have counted and received the cash, share this 4-digit OTP with the agent:',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                  ),
                  child: Text(
                    order.cashHandoverOtp ?? '----',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 8, color: AppTheme.primaryGreen, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 13, color: AppTheme.textSecondary),
                    SizedBox(width: 4),
                    Text('Do not share this code before receiving physical cash', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ] else if (['CUSTOMER_ACCEPTED', 'OWNERSHIP_TRANSFERRED', 'PAYMENT_PENDING'].contains(order.status) &&
            order.beneficiaryType != 'CASH') ...[
          // Online Transfer / Admin Payout Desk Card (UPI / Bank Transfer)
          GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: BorderRadius.circular(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.account_balance_wallet_rounded, color: Colors.blue.shade700, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.beneficiaryType == 'BANK' ? 'Direct Bank Transfer (IMPS/NEFT)' : 'Instant UPI Transfer',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Doorstep physical check verified. Super Admin payout desk will release ₹${(order.finalPrice ?? order.estimatedPrice).toStringAsFixed(0)} directly to your registered ${order.beneficiaryType == "BANK" ? "bank account" : "UPI ID"}.',
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // 2. Amazon Stepper Timeline (Screenshot 3 style)
        GlassContainer(
          padding: const EdgeInsets.all(20),
          borderRadius: BorderRadius.circular(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.local_shipping_outlined, color: AppTheme.primaryGreen, size: 20),
                  SizedBox(width: 8),
                  Text('Pickup & Verification Journey', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.textPrimary)),
                ],
              ),
              const SizedBox(height: 16),
              _buildTimelineStep(
                title: '1. Request Submitted',
                subtitle: 'Order recorded in Dolly operations system',
                isCompleted: currentStage >= 1,
                isCurrent: currentStage == 1,
              ),
              _buildTimelineStep(
                title: '2. Pickup Scheduled',
                subtitle: order.assignedAgentName != null ? 'Assigned to specialist ${order.assignedAgentName}' : 'Awaiting specialist assignment',
                isCompleted: currentStage >= 2,
                isCurrent: currentStage == 2,
              ),
              _buildTimelineStep(
                title: '3. Doorstep Inspection',
                subtitle: currentStage >= 3 ? 'Inspection completed by field specialist' : 'Physical condition & IMEI check at doorstep',
                isCompleted: currentStage >= 3,
                isCurrent: currentStage == 3,
              ),
              _buildTimelineStep(
                title: '4. Offer Confirmed',
                subtitle: currentStage >= 4 ? 'Final buyback price approved' : 'Customer confirms final payout value',
                isCompleted: currentStage >= 4,
                isCurrent: currentStage == 4,
              ),
              _buildTimelineStep(
                title: '5. Device Handover',
                subtitle: currentStage >= 5 ? 'Physical device collected' : 'Agent collects device and issues receipt',
                isCompleted: currentStage >= 5,
                isCurrent: currentStage == 5,
              ),
              _buildTimelineStep(
                title: '6. Payout Disbursed',
                subtitle: currentStage >= 6 ? 'Instant payment transferred via UPI' : 'Funds credited directly to your bank account',
                isCompleted: currentStage >= 6,
                isCurrent: currentStage == 6,
                isLast: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 3. Amazon "Order Summary" Card (Screenshot 2 style)
        GlassContainer(
          padding: const EdgeInsets.all(18),
          borderRadius: BorderRadius.circular(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Order Summary', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              Text('Order number #${order.saleCode}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontFamily: 'monospace')),
              Divider(height: 18, color: Colors.grey.shade300),
              _buildDetailRow('Device Subtotal', '₹${order.estimatedPrice.toStringAsFixed(0)}'),
              if (order.finalPrice != null && order.finalPrice != order.estimatedPrice)
                _buildDetailRow('QC Adjustments', '-₹${(order.estimatedPrice - order.finalPrice!).toStringAsFixed(0)}'),
              _buildDetailRow('Doorstep Pickup Fee', 'FREE'),
              Divider(height: 18, color: Colors.grey.shade300),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Grand Total Payout:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary)),
                  Text(
                    '₹${(order.finalPrice ?? order.estimatedPrice).toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.primaryGreen),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Payout To: ${order.beneficiaryType}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                    Text(order.beneficiaryUpiId ?? 'Bank IMPS', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 4. Cancel Order Button (Role-aware: Admin vs Customer)
        if (['SUBMITTED', 'PICKUP_SCHEDULED', 'INSPECTION_PENDING', 'FINAL_OFFER_SENT'].contains(order.status)) ...[
          const SizedBox(height: 14),
          if (_api.currentUser?.isAdmin == true) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: BorderSide(color: Colors.red.shade400, width: 1.2),
                  backgroundColor: Colors.red.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.admin_panel_settings_rounded, size: 18, color: Colors.red),
                label: const Text(
                  'Admin Cancel Order',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () => _adminCancelOrder(order),
              ),
            ),
          ] else ...[
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
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? AppTheme.primaryGreen : Colors.white,
                border: Border.all(
                  color: isCompleted ? AppTheme.primaryGreen : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isCompleted ? AppTheme.primaryGreen : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isCompleted ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              ),
              if (!isLast) const SizedBox(height: 14),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildGuestSignInView() {
    return Center(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyOrdersView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: GlassContainer(
          padding: const EdgeInsets.all(26),
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppTheme.lightGreen, shape: BoxShape.circle),
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
                icon: const Icon(Icons.phone_iphone_rounded, size: 18),
                label: const Text('Sell A Device Now', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
