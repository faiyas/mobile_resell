import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';

class AgentInspectionScreen extends StatefulWidget {
  const AgentInspectionScreen({super.key});

  @override
  State<AgentInspectionScreen> createState() => _AgentInspectionScreenState();
}

class _AgentInspectionScreenState extends State<AgentInspectionScreen> {
  final ApiService _api = ApiService();

  List<SaleOrderModel> _sales = [];
  SaleOrderModel? _selectedSale;
  bool _loading = false;
  bool _submitting = false;

  // Inspection Checklist
  bool _switchesOn = true;
  bool _screenWorking = true;
  bool _screenGlassBroken = false;
  bool _touchWorking = true;
  bool _cameraWorking = true;
  bool _batteryHealthy = true;
  String _bodyCondition = 'GOOD';
  bool _cloudLocksRemoved = true;
  bool _customerIdVerified = true;

  final _imeiController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  String _feedbackMessage = '';
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _loading = true);
    try {
      final list = await _api.getSales();
      setState(() {
        _sales = list;
        if (list.isNotEmpty) {
          _selectSale(list.first);
        }
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _selectSale(SaleOrderModel s) {
    setState(() {
      _selectedSale = s;
      _priceController.text = (s.finalPrice ?? s.estimatedPrice).toStringAsFixed(0);
      _imeiController.text = s.imeiNumber ?? '';
      _feedbackMessage = '';
    });
  }

  Future<void> _submitInspection() async {
    if (_selectedSale == null) return;

    if (!_cloudLocksRemoved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CRITICAL: iCloud/FRP lock must be removed!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_imeiController.text.trim().length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter verified 15-digit IMEI number (*#06#)'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _feedbackMessage = '';
    });

    try {
      final price = double.tryParse(_priceController.text.trim()) ?? _selectedSale!.estimatedPrice;
      final payload = {
        'sale_id': _selectedSale!.id,
        'switches_on': _switchesOn,
        'screen_working': _screenWorking,
        'screen_glass_broken': _screenGlassBroken,
        'touch_working': _touchWorking,
        'camera_working': _cameraWorking,
        'battery_healthy': _batteryHealthy,
        'body_condition': _bodyCondition,
        'cloud_locks_removed': _cloudLocksRemoved,
        'imei_verified': true,
        'verified_imei': _imeiController.text.trim(),
        'customer_id_verified': _customerIdVerified,
        'suggested_final_price': price,
        'inspector_notes': _notesController.text.trim(),
        'photos': [],
      };

      final res = await _api.recordInspection(payload);

      setState(() {
        _isSuccess = true;
        _feedbackMessage = '✓ Inspection Recorded! Status: ${res['sale_status'] ?? 'OWNERSHIP_TRANSFERRED'} · Payout queue updated.';
        _submitting = false;
      });

      _loadSales();
    } catch (err) {
      setState(() {
        _isSuccess = false;
        _feedbackMessage = err.toString();
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: const Text('1103 RECELL · Field Agent Desk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSales,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Assigned Queue Horizontal Scroll
                  const Text(
                    'Assigned Pickups Queue',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 88,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _sales.length,
                      itemBuilder: (context, idx) {
                        final s = _sales[idx];
                        final isSelected = _selectedSale?.id == s.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: InkWell(
                            onTap: () => _selectSale(s),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 170,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.lightGreen : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? AppTheme.primaryGreen : AppTheme.border,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(s.saleCode, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                                  Text('${s.brandName} ${s.modelName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  Text('₹${(s.finalPrice ?? s.estimatedPrice).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AppTheme.primaryGreen, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (_selectedSale != null) ...[
                    // Customer & Device Details
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_selectedSale!.brandName} ${_selectedSale!.modelName}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.lightGreen,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _selectedSale!.status,
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.darkGreen),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Customer: ${_selectedSale!.customerName} (${_selectedSale!.customerPhone})', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          Text('Address: ${_selectedSale!.pickupAddress}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 10-Point QC Checks
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
                          const Text('10-Point Physical Verification', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                          const Divider(height: 16, color: AppTheme.border),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Phone Powers On & Boots', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            value: _switchesOn,
                            activeTrackColor: AppTheme.primaryGreen,
                            onChanged: (v) => setState(() => _switchesOn = v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Touchscreen Responds Accurately', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            value: _touchWorking,
                            activeTrackColor: AppTheme.primaryGreen,
                            onChanged: (v) => setState(() => _touchWorking = v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Front & Rear Cameras Functioning', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            value: _cameraWorking,
                            activeTrackColor: AppTheme.primaryGreen,
                            onChanged: (v) => setState(() => _cameraWorking = v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Apple iCloud / Google FRP Signed Out *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                            value: _cloudLocksRemoved,
                            activeTrackColor: AppTheme.primaryGreen,
                            onChanged: (v) => setState(() => _cloudLocksRemoved = v),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // IMEI & Final Pricing
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
                          const Text('Verified IMEI & Recommended Price', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _imeiController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Verified 15-Digit IMEI * (Dial *#06#)',
                              prefixIcon: Icon(Icons.dialpad),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Recommended Final Buyback Price (₹) *',
                              prefixIcon: Icon(Icons.currency_rupee),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: 'Inspection notes (e.g. Minor hairline scratch on bezel)',
                              prefixIcon: Icon(Icons.note_alt_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_feedbackMessage.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _isSuccess ? AppTheme.lightGreen : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _isSuccess ? AppTheme.primaryGreen : Colors.red),
                        ),
                        child: Text(
                          _feedbackMessage,
                          style: TextStyle(
                            color: _isSuccess ? AppTheme.darkGreen : Colors.red.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: _submitting ? null : _submitInspection,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: AppTheme.primaryGreen,
                      ),
                      child: _submitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Confirm Inspection & Submit Final Offer',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                            ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ],
              ),
            ),
    );
  }
}
