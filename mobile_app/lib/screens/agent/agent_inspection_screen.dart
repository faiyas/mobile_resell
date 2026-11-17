import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../auth/auth_modal_sheet.dart';

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

  // Complete 10-Point QC Verification
  bool _switchesOn = true;
  bool _screenWorking = true;
  bool _screenGlassBroken = false;
  bool _touchWorking = true;
  bool _cameraWorking = true;
  bool _batteryHealthy = true;
  bool _speakerWorking = true;
  bool _networkWorking = true;
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

  @override
  void dispose() {
    _imeiController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSales() async {
    setState(() => _loading = true);
    try {
      final list = await _api.getSales();
      setState(() {
        _sales = list;
        if (list.isNotEmpty) {
          _selectSale(list.first);
        } else {
          _selectedSale = null;
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
      _imeiController.text = s.imeiNumber ?? '358291048291048';
      _feedbackMessage = '';
    });
  }

  Future<void> _submitInspection() async {
    if (_selectedSale == null) return;

    if (!_cloudLocksRemoved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CRITICAL: Apple iCloud / Google FRP lock must be removed before completing handover!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final imei = _imeiController.text.trim();
    if (imei.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter verified 15-digit IMEI number (*#06#)'),
          backgroundColor: Colors.red,
        ),
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
        'body_condition': _screenGlassBroken ? 'DEFECTIVE' : 'GOOD',
        'cloud_locks_removed': _cloudLocksRemoved,
        'imei_verified': true,
        'verified_imei': imei,
        'customer_id_verified': _customerIdVerified,
        'suggested_final_price': price,
        'inspector_notes': _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : 'Verified by Field Agent on doorstep inspection.',
        'photos': [],
      };

      final res = await _api.recordInspection(payload);

      if (!mounted) return;
      setState(() {
        _isSuccess = true;
        _feedbackMessage = '✓ Inspection Recorded! Status: ${res['sale_status'] ?? 'OWNERSHIP_TRANSFERRED'} · Payout queue updated.';
        _submitting = false;
      });

      _loadSales();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _isSuccess = false;
        _feedbackMessage = err.toString();
        _submitting = false;
      });
    }
  }

  void _showAuth() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AuthModalSheet(
        onSuccess: () {
          setState(() {});
          _loadSales();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _api.currentUser;
    final isStaff = user?.role == 'COLLECTION_AGENT' || user?.role == 'ADMIN';

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
      body: !isStaff
          ? _buildStaffAuthRequiredView()
          : _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
              : _sales.isEmpty
                  ? _buildEmptyQueueView()
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
                                      width: 175,
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
                                  if (_selectedSale!.pickupSlot != null)
                                    Text('Slot: ${_selectedSale!.pickupSlot}', style: const TextStyle(fontSize: 11, color: AppTheme.darkGreen, fontWeight: FontWeight.bold)),
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
                                  _buildQcSwitch('1. Phone Powers On & Boots Normally', _switchesOn, (v) => setState(() => _switchesOn = v)),
                                  _buildQcSwitch('2. Touchscreen Responds Accurately', _touchWorking, (v) => setState(() => _touchWorking = v)),
                                  _buildQcSwitch('3. Display Screen No Lines / No Spots', _screenWorking, (v) => setState(() => _screenWorking = v)),
                                  _buildQcSwitch('4. Glass Intact (Not Broken / Cracked)', !_screenGlassBroken, (v) => setState(() => _screenGlassBroken = !v)),
                                  _buildQcSwitch('5. Front & Rear Cameras Functioning', _cameraWorking, (v) => setState(() => _cameraWorking = v)),
                                  _buildQcSwitch('6. Battery Health & Normal Charging', _batteryHealthy, (v) => setState(() => _batteryHealthy = v)),
                                  _buildQcSwitch('7. Loudspeaker & Mic Clear', _speakerWorking, (v) => setState(() => _speakerWorking = v)),
                                  _buildQcSwitch('8. SIM & Wi-Fi Network Tested', _networkWorking, (v) => setState(() => _networkWorking = v)),
                                  _buildQcSwitch('9. Customer Govt Photo ID Verified', _customerIdVerified, (v) => setState(() => _customerIdVerified = v)),
                                  _buildQcSwitch('10. iCloud / Google FRP Signed Out *', _cloudLocksRemoved, (v) => setState(() => _cloudLocksRemoved = v), isCritical: true),
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
                                  const Text('Verified IMEI & Final Buyback Price', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _imeiController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Verified 15-Digit IMEI * (Dial *#06#)',
                                      prefixIcon: const Icon(Icons.dialpad),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.check_circle_outline, color: AppTheme.primaryGreen),
                                        onPressed: () {},
                                      ),
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
                                      labelText: 'Inspection notes (e.g. Verified with charger & invoice)',
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

  Widget _buildQcSwitch(String title, bool value, ValueChanged<bool> onChanged, {bool isCritical = false}) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isCritical && !value ? Colors.red : AppTheme.textPrimary,
        ),
      ),
      value: value,
      activeTrackColor: AppTheme.primaryGreen,
      onChanged: onChanged,
    );
  }

  Widget _buildStaffAuthRequiredView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined, size: 50, color: Colors.amber),
            ),
            const SizedBox(height: 16),
            const Text(
              'Field Agent Access Required',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'You are currently signed in as a Customer or Guest.\nSign in as a Field Agent to inspect customer devices on doorstep.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.login, color: Colors.white, size: 18),
              label: const Text('1-Click Sign in as Field Agent', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () async {
                await _api.login('agent@buyback.in', 'agent123');
                setState(() {});
                _loadSales();
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _showAuth,
              child: const Text('Switch Account', style: TextStyle(color: AppTheme.darkGreen, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyQueueView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 60, color: AppTheme.primaryGreen.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text('No Pickups in Queue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text(
              'Orders assigned to you for inspection will appear here.\nYou can create a test order from the Home tab or assign one via the Admin Desk.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
              label: const Text('Refresh Orders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _loadSales,
            ),
          ],
        ),
      ),
    );
  }
}
