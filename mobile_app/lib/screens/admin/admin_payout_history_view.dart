import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../utils/image_helper.dart';
import '../../widgets/glass_container.dart';

class AdminPayoutHistoryView extends StatefulWidget {
  final List<SaleOrderModel> orders;
  final VoidCallback onRefresh;

  const AdminPayoutHistoryView({
    super.key,
    required this.orders,
    required this.onRefresh,
  });

  @override
  State<AdminPayoutHistoryView> createState() => _AdminPayoutHistoryViewState();
}

class _AdminPayoutHistoryViewState extends State<AdminPayoutHistoryView> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    // Only completed payment orders
    final paidOrders = widget.orders.where((o) => o.status == 'PAYMENT_COMPLETED').toList();
    final totalDisbursed = paidOrders.fold<double>(0.0, (sum, o) => sum + (o.finalPrice ?? o.estimatedPrice));

    final filtered = paidOrders.where((o) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return o.saleCode.toLowerCase().contains(q) ||
          o.customerName.toLowerCase().contains(q) ||
          o.customerPhone.contains(q) ||
          o.beneficiaryName.toLowerCase().contains(q) ||
          (o.beneficiaryUpiId?.toLowerCase().contains(q) ?? false);
    }).toList();

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      color: AppTheme.primaryGreen,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          // Header Summary Card
          GlassContainer(
            borderRadius: BorderRadius.circular(18),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.verified_rounded, color: AppTheme.primaryGreen, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL DISBURSED (LIFETIME)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${totalDisbursed.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryGreen,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${paidOrders.length} Completed Payouts via UPI / IMPS',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryGreen),
                  onPressed: widget.onRefresh,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Search Box
          GlassContainer(
            borderRadius: BorderRadius.circular(14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: 'Search by TXN code, customer, or UPI...',
                hintStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppTheme.primaryGreen),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),

          const SizedBox(height: 14),

          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: const [
                    Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.textSecondary),
                    SizedBox(height: 10),
                    Text('No disbursed payout records found', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ...filtered.map((order) {
              final price = order.finalPrice ?? order.estimatedPrice;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassContainer(
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Code, Paid badge, and Amount
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                order.saleCode,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.textPrimary),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 10, color: Colors.green.shade700),
                                    const SizedBox(width: 3),
                                    Text(
                                      'PAID',
                                      style: TextStyle(color: Colors.green.shade800, fontSize: 9, fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '₹${price.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.primaryGreen),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Device & Customer Details
                      Text(
                        '${order.brandName} ${order.modelName} (${order.storage})',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 13, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            order.customerName.isNotEmpty ? order.customerName : 'Customer',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.payment_rounded, size: 13, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              order.beneficiaryUpiId != null ? 'UPI: ${order.beneficiaryUpiId}' : 'Bank IMPS',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Action - View Receipt Modal Button
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(120, 34),
                            side: BorderSide(color: AppTheme.primaryGreen.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.receipt_outlined, size: 14, color: AppTheme.primaryGreen),
                          label: const Text(
                            'View Digital Receipt',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                          ),
                          onPressed: () => _showDigitalReceipt(context, order),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showDigitalReceipt(BuildContext context, SaleOrderModel order) {
    final price = order.finalPrice ?? order.estimatedPrice;
    final proofBytes = ImageHelper.decodeBase64(order.payment?.paymentProofBase64);
    final utr = order.payment?.utrNumber ?? '';
    final payMethod = order.payment?.paymentMethod ?? (order.beneficiaryType == 'CASH' ? 'CASH' : (order.beneficiaryUpiId != null ? 'UPI' : 'Bank IMPS'));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        contentPadding: const EdgeInsets.all(20),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, color: AppTheme.primaryGreen, size: 36),
              ),
              const SizedBox(height: 10),
              const Text(
                'PAYMENT RECEIPT',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.primaryGreen, letterSpacing: 1.0),
              ),
              const SizedBox(height: 2),
              const Text(
                'Dolly Buyback India Pvt Ltd',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Order Details List
              _buildReceiptRow('Transaction Ref', order.saleCode),
              _buildReceiptRow('Beneficiary', order.beneficiaryName.isNotEmpty ? order.beneficiaryName : order.customerName),
              _buildReceiptRow('Payout Mode', payMethod),
              if (utr.isNotEmpty)
                _buildReceiptRow('UTR / Ref No.', utr),
              if (order.beneficiaryUpiId != null && order.beneficiaryUpiId!.isNotEmpty)
                _buildReceiptRow('UPI VPA', order.beneficiaryUpiId!),
              _buildReceiptRow('Device', '${order.brandName} ${order.modelName}'),
              if (order.imeiNumber != null && order.imeiNumber!.isNotEmpty)
                _buildReceiptRow('Verified IMEI', order.imeiNumber!),

              if (proofBytes != null) ...[
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Payment Proof Screenshot', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textSecondary)),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: ctx,
                      builder: (imgCtx) => Dialog(
                        backgroundColor: Colors.black,
                        insetPadding: const EdgeInsets.all(12),
                        child: Stack(
                          children: [
                            InteractiveViewer(child: Image.memory(proofBytes, fit: BoxFit.contain)),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white),
                                onPressed: () => Navigator.pop(imgCtx),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(proofBytes, height: 150, width: double.infinity, fit: BoxFit.cover, gaplessPlayback: true),
                  ),
                ),
              ],

              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Total Amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Amount Disbursed:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                  Text(
                    '₹${price.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.primaryGreen),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close Receipt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}
