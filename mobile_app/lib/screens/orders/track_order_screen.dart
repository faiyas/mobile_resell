import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';

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
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: const Text('Track Your Order'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar for Sale Code
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Enter Order ID (e.g. XP2610008753)...',
                      prefixIcon: Icon(Icons.search, color: AppTheme.primaryGreen),
                    ),
                    onSubmitted: _lookupOrder,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _lookupOrder(_searchController.text),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  child: const Text('Track'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppTheme.primaryGreen)))
            else if (_error.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_error, style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
              )
            else if (_order != null)
              _buildOrderTimelineCard(_order!)
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('No order selected. Enter an Order ID to track.'),
                ),
              ),

            // Recent Orders List (if multiple exist)
            if (_myOrders.length > 1) ...[
              const SizedBox(height: 24),
              const Text(
                'Recent Orders',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              ..._myOrders.map((o) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        '${o.brandName} ${o.modelName}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                      subtitle: Text(
                        '${o.saleCode} · ₹${o.estimatedPrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () {
                        setState(() {
                          _order = o;
                          _searchController.text = o.saleCode;
                        });
                      },
                    ),
                  )),
            ],

            const SizedBox(height: 30),
          ],
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
        // 1. Order Code Card with Copy
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('REQUEST ID', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.textSecondary, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(order.saleCode, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.primaryGreen),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: order.saleCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Order ID copied to clipboard'), duration: Duration(seconds: 1)),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Timeline Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTimelineStep(
                title: 'Request Submitted',
                subtitle: 'Order recorded in 1103 RECELL desk',
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
                    ? 'Assigned to ${order.assignedAgentName}'
                    : 'Awaiting field agent assignment',
                isCompleted: currentStage >= 3,
                isCurrent: currentStage == 3,
              ),
              _buildTimelineStep(
                title: 'Device Collected',
                subtitle: 'Physical inspection & IMEI verification at home',
                isCompleted: currentStage >= 4,
                isCurrent: currentStage == 4,
              ),
              _buildTimelineStep(
                title: 'Final Price & Instant Payment',
                subtitle: currentStage == 5 ? 'Transferred via UPI · Payout Completed' : 'Transferred before agent departs',
                isCompleted: currentStage >= 5,
                isCurrent: currentStage == 5,
                isLast: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 3. Order Details Summary
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
              const Text('Device & Payout Details', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              const Divider(height: 16, color: AppTheme.border),
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
        OutlinedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Support concierge: support@buyback.in / +91 9876543210')),
            );
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            side: const BorderSide(color: AppTheme.primaryGreen),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.headset_mic_outlined, size: 18, color: AppTheme.primaryGreen),
              SizedBox(width: 8),
              Text(
                'Need Help? Contact Concierge Support',
                style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
              ),
            ],
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
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? AppTheme.primaryGreen : Colors.white,
                border: Border.all(
                  color: isCompleted ? AppTheme.primaryGreen : AppTheme.border,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 38,
                color: isCompleted ? AppTheme.primaryGreen : AppTheme.border,
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
