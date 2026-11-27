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
  List<SaleOrderModel> get _payoutOrders {
    return widget.orders.where((o) => ['OWNERSHIP_TRANSFERRED', 'CUSTOMER_ACCEPTED', 'READY_FOR_PAYOUT'].contains(o.status)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub-header indicator
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.currency_rupee_rounded, size: 16, color: AppTheme.primaryGreen),
                    const SizedBox(width: 4),
                    Text(
                      'Ready for Payout (${_payoutOrders.length})',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.primaryGreen),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Instant Disbursement Queue',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
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
                        'No orders awaiting payment!',
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

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(order.beneficiaryType == 'CASH' ? Icons.payments_rounded : Icons.qr_code_rounded, size: 18),
                label: Text(
                  order.beneficiaryType == 'CASH' ? 'Verify Cash Handover OTP' : 'Authorize Payout & Enter UTR',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _showPayoutActionModal(order, amount),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayoutActionModal(SaleOrderModel order, double amount) {
    final utrController = TextEditingController();
    final otpController = TextEditingController();
    final isCash = order.beneficiaryType == 'CASH';

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
            Text('Amount to ${isCash ? "Handover in Cash" : "Transfer"}: ₹${amount.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.darkGreen, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 16),

            if (isCash) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.shade300)),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cash on Pickup: Ask customer for the 4-digit verification OTP shown on their tracking screen after handing over the cash.',
                        style: TextStyle(fontSize: 11, color: Colors.brown, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Customer Cash Handover OTP *', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: InputDecoration(
                  hintText: 'e.g. 7492',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            ] else ...[
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
            ],
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
                  final code = isCash ? otpController.text.trim() : utrController.text.trim();
                  if (code.isEmpty) return;
                  Navigator.pop(ctx);
                  widget.onConfirmPayout(order, code);
                },
                child: Text(isCash ? 'Verify OTP & Complete Payout' : 'Confirm Payment & Mark Paid', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
