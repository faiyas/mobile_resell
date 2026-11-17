import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentOrders() async {
    setState(() => _loading = true);
    try {
      final list = await _api.getSales();
      setState(() {
        _myOrders = list;
        if (list.isNotEmpty && _order == null) {
          _order = list.first;
          _searchController.text = _order!.saleCode;
        }
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
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
      setState(() {
        _order = o;
        _loading = false;
      });
    } catch (err) {
      setState(() {
        _error = 'Order not found for code: $code';
        _loading = false;
      });
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
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                    ),
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
                else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: GlassContainer(
                        padding: const EdgeInsets.all(24),
                        borderRadius: BorderRadius.circular(20),
                        child: const Column(
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 40, color: AppTheme.textSecondary),
                            SizedBox(height: 12),
                            Text(
                              'No order selected. Enter an Order ID to track.',
                              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary, fontSize: 13),
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

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderTimelineCard(SaleOrderModel order) {
    // Stage Calculation
    int currentStage = 1;
    if (order.status == 'PICKUP_SCHEDULED') currentStage = 3;
    if (order.status == 'FINAL_OFFER_SENT' || order.status == 'OWNERSHIP_TRANSFERRED') currentStage = 4;
    if (order.status == 'PAYMENT_COMPLETED') currentStage = 5;

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
                    '1103 RECELL ORDER ID',
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
                      color: AppTheme.primaryGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                    ),
                    child: Text(
                      order.status.replaceAll('_', ' '),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.primaryGreen),
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

        // 2. Timeline Card
        GlassContainer(
          padding: const EdgeInsets.all(22),
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Live Pickup & Payout Progress',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 18),
              _buildTimelineStep(
                title: 'Request Submitted',
                subtitle: 'Order recorded in 1103 RECELL operations desk',
                isCompleted: currentStage >= 1,
                isCurrent: currentStage == 1,
              ),
              _buildTimelineStep(
                title: 'Quote Generated',
                subtitle: '₹${order.estimatedPrice.toStringAsFixed(0)} instant valuation locked',
                isCompleted: currentStage >= 2,
                isCurrent: currentStage == 2,
              ),
              _buildTimelineStep(
                title: 'Pickup Scheduled',
                subtitle: order.assignedAgentName != null
                    ? 'Assigned to Agent ${order.assignedAgentName}'
                    : 'Awaiting field agent assignment',
                isCompleted: currentStage >= 3,
                isCurrent: currentStage == 3,
              ),
              _buildTimelineStep(
                title: 'Device Collected',
                subtitle: 'Physical doorstep inspection & IMEI verification',
                isCompleted: currentStage >= 4,
                isCurrent: currentStage == 4,
              ),
              _buildTimelineStep(
                title: 'Final Price & Instant Payment',
                subtitle: currentStage == 5 ? 'Transferred via UPI · Payout Completed' : 'Transferred via UPI before agent leaves',
                isCompleted: currentStage >= 5,
                isCurrent: currentStage == 5,
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
              _buildDetailRow('Pickup Address', '${order.pickupAddress}, ${order.pickupCity} - ${order.pickupPincode}'),
              _buildDetailRow('Payout Method', '${order.beneficiaryType}: ${order.beneficiaryUpiId ?? 'Direct Account'}'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Concierge Support Button
        GlassContainer(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          borderRadius: BorderRadius.circular(16),
          child: OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Support concierge: support@1103recell.in / +91 9876543210'),
                  behavior: SnackBarBehavior.floating,
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
                  'Need Help? Contact 1103 RECELL Concierge',
                  style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
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
