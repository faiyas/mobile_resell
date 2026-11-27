import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../widgets/glass_container.dart';

class AdminPayoutDeskView extends StatefulWidget {
  final List<SaleOrderModel> orders;
  final VoidCallback onRefresh;
  final Function(SaleOrderModel, String utr) onConfirmPayout;

  const AdminPayoutDeskView({
    super.key,
    required this.orders,
    required this.onRefresh,
    required this.onConfirmPayout,
  });

  @override
  State<AdminPayoutDeskView> createState() => _AdminPayoutDeskViewState();
}

class _AdminPayoutDeskViewState extends State<AdminPayoutDeskView> {
  String _tab = 'READY'; // 'READY' or 'PAID'

  List<SaleOrderModel> get _payoutOrders {
    if (_tab == 'READY') {
      return widget.orders.where((o) => o.status == 'READY_FOR_PAYOUT').toList();
    }
    return widget.orders.where((o) => o.status == 'PAID' || o.status == 'COMPLETED').toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab selector
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.pending_actions_rounded, size: 18),
                  label: Text('Ready for Payout (${widget.orders.where((o) => o.status == 'READY_FOR_PAYOUT').length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _tab == 'READY' ? AppTheme.primaryGreen : Colors.grey.shade100,
                    foregroundColor: _tab == 'READY' ? Colors.white : AppTheme.textPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _tab = 'READY'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: Text('Paid History (${widget.orders.where((o) => o.status == 'PAID' || o.status == 'COMPLETED').length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _tab == 'PAID' ? AppTheme.primaryGreen : Colors.grey.shade100,
                    foregroundColor: _tab == 'PAID' ? Colors.white : AppTheme.textPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _tab = 'PAID'),
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: _payoutOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payments_outlined, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text(
                        _tab == 'READY' ? 'No orders awaiting payment!' : 'No payment history yet',
                        style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => widget.onRefresh(),
                  color: AppTheme.primaryGreen,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: _payoutOrders.length,
                    itemBuilder: (ctx, idx) => _buildPayoutCard(_payoutOrders[idx]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPayoutCard(SaleOrderModel order) {
    final amount = order.finalPrice ?? order.estimatedPrice;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        borderRadius: 20,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(order.saleCode.isNotEmpty ? order.saleCode : '#${order.id}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                Text(
                  '₹${amount.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.darkGreen),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${order.brandName} ${order.modelName} (${order.storage})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const Divider(height: 18),

            // Beneficiary details
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Beneficiary: ${order.beneficiaryName.isNotEmpty ? order.beneficiaryName : order.customerName} (${order.beneficiaryUpiId ?? order.customerPhone})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (_tab == 'READY')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_rounded, size: 18),
                  label: const Text('Authorize Payout & Enter UTR', style: TextStyle(fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _showPayoutActionModal(order, amount),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: AppTheme.darkGreen),
                    SizedBox(width: 6),
                    Text('Disbursed & Closed', style: TextStyle(color: AppTheme.darkGreen, fontWeight: FontWeight.bold, fontSize: 11)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showPayoutActionModal(SaleOrderModel order, double amount) {
    final utrController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 16),
            Text('Payout Desk · ${order.saleCode.isNotEmpty ? order.saleCode : '#${order.id}'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 4),
            Text('Amount to Transfer: ₹${amount.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.darkGreen, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 16),

            // UTR input
            const Text('Bank 12-Digit Reference (UTR Number)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: utrController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'e.g. 432198765432',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  final utr = utrController.text.trim();
                  if (utr.isEmpty) return;
                  Navigator.pop(ctx);
                  widget.onConfirmPayout(order, utr);
                },
                child: const Text('Confirm Payment & Mark Paid', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
