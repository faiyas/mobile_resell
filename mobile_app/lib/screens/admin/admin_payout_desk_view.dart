import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../utils/image_helper.dart';
import '../../widgets/glass_container.dart';

class AdminPayoutDeskView extends StatefulWidget {
  final List<SaleOrderModel> orders;
  final VoidCallback onRefresh;
  final Future<void> Function(SaleOrderModel, String utr, {String? proofBase64}) onConfirmPayout;

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
    String? proofBase64;
    final photos = order.inspection?.photos ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
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
                const SizedBox(height: 14),

                if (photos.isNotEmpty) ...[
                  Text(
                    'Inspection Proof (${photos.length} Photos · IMEI: ${order.inspection?.verifiedImei ?? order.imeiNumber ?? "Verified"})',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 68,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, idx) {
                        final bytes = ImageHelper.decodeBase64(photos[idx].imageBase64);
                        if (bytes == null) return const SizedBox.shrink();
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(bytes, width: 68, height: 68, fit: BoxFit.cover, gaplessPlayback: true),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

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
                  const Text('Bank 12-Digit Reference (UTR Number) *', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
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
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment Screenshot Proof', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      if (proofBase64 != null)
                        TextButton(
                          onPressed: () => setModalState(() => proofBase64 = null),
                          child: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      final source = await ImageHelper.showImageSourceDialog(ctx);
                      if (source == null) return;
                      final b64 = await ImageHelper.pickImageAsBase64(
                        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
                        maxWidth: 1000,
                        maxHeight: 1000,
                        imageQuality: 80,
                      );
                      if (b64 != null && ctx.mounted) {
                        setModalState(() => proofBase64 = b64);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: proofBase64 != null ? 150 : 76,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: proofBase64 != null ? AppTheme.primaryGreen : Colors.grey.shade300),
                      ),
                      child: proofBase64 != null && ImageHelper.decodeBase64(proofBase64) != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.memory(ImageHelper.decodeBase64(proofBase64)!, fit: BoxFit.contain, gaplessPlayback: true),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined, color: AppTheme.primaryGreen, size: 26),
                                SizedBox(height: 4),
                                Text('Tap to Upload Payment Screenshot (Optional)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                              ],
                            ),
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
                      widget.onConfirmPayout(order, code, proofBase64: proofBase64);
                    },
                    child: Text(isCash ? 'Verify OTP & Complete Payout' : 'Confirm Payment & Mark Paid', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
