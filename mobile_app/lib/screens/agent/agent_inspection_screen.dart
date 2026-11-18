import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';
import '../auth/auth_modal_sheet.dart';
import '../../utils/contact_launcher.dart';
import '../../utils/image_helper.dart';

class AgentInspectionScreen extends StatefulWidget {
  final SaleOrderModel? initialSale;

  const AgentInspectionScreen({super.key, this.initialSale});

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
  final Map<String, String> _capturedPhotos = {};

  void _capturePhotoForSlot(String label) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.96),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 16),
                Text('Capture $label Photo', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                const Text('Snap physical proof for Super Admin verification & payout approval.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppTheme.lightGreen, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryGreen),
                  ),
                  title: const Text('Take Live Camera Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Open device camera and take real photo', style: TextStyle(fontSize: 11)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final b64 = await ImageHelper.pickImageAsBase64(source: ImageSource.camera);
                    if (b64 != null) {
                      setState(() {
                        _capturedPhotos[label] = b64;
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('✓ $label camera photo captured!'), backgroundColor: AppTheme.primaryGreen),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppTheme.lightGreen, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryGreen),
                  ),
                  title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Select JPG/PNG photo from phone gallery', style: TextStyle(fontSize: 11)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final b64 = await ImageHelper.pickImageAsBase64(source: ImageSource.gallery);
                    if (b64 != null) {
                      setState(() {
                        _capturedPhotos[label] = b64;
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('✓ $label photo selected from gallery!'), backgroundColor: AppTheme.primaryGreen),
                        );
                      }
                    }
                  },
                ),
                if (_capturedPhotos.containsKey(label))
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    ),
                    title: const Text('Remove Photo', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _capturedPhotos.remove(label);
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSlot(String label, IconData icon) {
    final hasPhoto = _capturedPhotos.containsKey(label);
    final photoBytes = hasPhoto ? ImageHelper.decodeBase64(_capturedPhotos[label]) : null;

    return InkWell(
      onTap: () => _capturePhotoForSlot(label),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: hasPhoto ? AppTheme.primaryGreen.withOpacity(0.08) : Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasPhoto ? AppTheme.primaryGreen : AppTheme.glassBorder,
            width: hasPhoto ? 1.8 : 1,
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: photoBytes != null
            ? Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(photoBytes, fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    left: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle),
                      child: const Icon(Icons.check, size: 12, color: Colors.white),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 26,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap to Snap',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialSale != null) {
      _selectedSale = widget.initialSale;
      _selectSale(widget.initialSale!);
    }
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
      if (mounted) {
        setState(() {
          _sales = list;
          if (widget.initialSale != null && _selectedSale != null) {
            final matching = list.where((s) => s.id == _selectedSale!.id).firstOrNull;
            if (matching != null) {
              _selectSale(matching);
            }
          } else if (list.isNotEmpty) {
            _selectSale(list.first);
          } else {
            _selectedSale = null;
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
        SnackBar(
          content: const Text('CRITICAL: Apple iCloud / Google FRP lock must be removed before completing handover!'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final imei = _imeiController.text.trim();
    if (imei.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter verified 15-digit IMEI number (*#06#)'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
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
        'photos': _capturedPhotos.entries.map((e) => {
          'label': e.key,
          'image_base64': e.value,
        }).toList(),
      };

      final res = await _api.recordInspection(payload);

      if (!mounted) return;
      setState(() {
        _isSuccess = true;
        _feedbackMessage = '✓ Inspection Recorded! Status: ${res['sale_status'] ?? 'OWNERSHIP_TRANSFERRED'} · Ready for Payout.';
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
        title: const Text('1103 RECELL · Agent Desk', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_rounded, color: AppTheme.primaryGreen),
            tooltip: 'Dispatch & Admin Help',
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
                              Text('Field Agent Hotline & Dispatch', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ListTile(
                            leading: const Icon(Icons.phone_rounded, color: AppTheme.primaryGreen),
                            title: const Text('+91 90252 32453', style: TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: const Text('Direct Admin / Field Coordinator Line'),
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
                            subtitle: const Text('Escalation & Support Desk'),
                            onTap: () => ContactLauncher.sendEmail(context, subject: 'Agent Field Operations Support'),
                            trailing: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD97706),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.mail_outline_rounded, size: 12),
                              label: const Text('Mail', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              onPressed: () => ContactLauncher.sendEmail(context, subject: 'Agent Field Operations Support'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryGreen),
            onPressed: _loadSales,
          ),
        ],
      ),
      body: GlassBackgroundMesh(
        child: SafeArea(
          child: !isStaff
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
                                'Assigned Doorstep Pickups',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.textPrimary),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 96,
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
                                        borderRadius: BorderRadius.circular(18),
                                        child: GlassContainer(
                                          width: 185,
                                          padding: const EdgeInsets.all(12),
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(
                                            color: isSelected ? AppTheme.primaryGreen : AppTheme.glassBorder,
                                            width: isSelected ? 2 : 1,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: AppTheme.primaryGreen.withOpacity(0.25),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  )
                                                ]
                                              : null,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(s.saleCode, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppTheme.textSecondary)),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${s.brandName} ${s.modelName}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '₹${(s.finalPrice ?? s.estimatedPrice).toStringAsFixed(0)}',
                                                style: const TextStyle(fontSize: 13, color: AppTheme.primaryGreen, fontWeight: FontWeight.w900),
                                              ),
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
                                // Customer & Device Details Glass Card
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
                                            child: Text(
                                              '${_selectedSale!.brandName} ${_selectedSale!.modelName}',
                                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textPrimary),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryGreen.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                                            ),
                                            child: Text(
                                              _selectedSale!.status.replaceAll('_', ' '),
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.primaryGreen),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      _buildInfoRow(Icons.person_rounded, 'Customer', '${_selectedSale!.customerName} (${_selectedSale!.customerPhone})'),
                                      _buildInfoRow(Icons.location_on_rounded, 'Address', '${_selectedSale!.pickupAddress}, ${_selectedSale!.pickupCity}'),
                                      if (_selectedSale!.pickupSlot != null)
                                        _buildInfoRow(Icons.access_time_rounded, 'Time Slot', _selectedSale!.pickupSlot!),
                                    ],
                                  ),
                                ),

                                // Customer Reported Other Defects Alert
                                if (_selectedSale!.otherDefectsNotes != null && _selectedSale!.otherDefectsNotes!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  GlassContainer(
                                    padding: const EdgeInsets.all(14),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: Colors.amber.shade300, width: 1.5),
                                    color: Colors.amber.shade50.withOpacity(0.85),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.report_problem_rounded, color: Colors.amber.shade900, size: 18),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Customer Reported Other Defects & Notes:',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber.shade900),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _selectedSale!.otherDefectsNotes!,
                                          style: TextStyle(fontSize: 12, color: Colors.amber.shade900, height: 1.3),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 16),

                                // 10-Point QC Checks Frosted Glass Card
                                GlassContainer(
                                  padding: const EdgeInsets.all(18),
                                  borderRadius: BorderRadius.circular(22),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.checklist_rtl_rounded, color: AppTheme.primaryGreen, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            '10-Point Physical Verification',
                                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary),
                                          ),
                                        ],
                                      ),
                                      Divider(height: 18, color: AppTheme.border.withOpacity(0.6)),
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

                                // 📸 Doorstep Physical Inspection Photos Card
                                GlassContainer(
                                  padding: const EdgeInsets.all(18),
                                  borderRadius: BorderRadius.circular(22),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(Icons.camera_alt_rounded, color: AppTheme.primaryGreen, size: 20),
                                              SizedBox(width: 8),
                                              Text(
                                                'Physical Device Photos (Proof)',
                                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryGreen.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${_capturedPhotos.length}/4 Taken',
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.primaryGreen),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Snap live photos of front screen, back glass, frame, and IMEI for Super Admin payout release.',
                                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                      ),
                                      const SizedBox(height: 14),

                                      // 4 Slots Grid
                                      GridView.count(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                        childAspectRatio: 1.35,
                                        children: [
                                          _buildPhotoSlot('Front Screen', Icons.screenshot_rounded),
                                          _buildPhotoSlot('Rear Panel', Icons.phone_android_rounded),
                                          _buildPhotoSlot('Side Frame', Icons.view_sidebar_rounded),
                                          _buildPhotoSlot('IMEI & *#06#', Icons.qr_code_scanner_rounded),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // IMEI & Final Pricing Frosted Card
                                GlassContainer(
                                  padding: const EdgeInsets.all(18),
                                  borderRadius: BorderRadius.circular(22),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.verified_user_outlined, color: AppTheme.primaryGreen, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Verified IMEI & Final Buyback Price',
                                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      TextField(
                                        controller: _imeiController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Verified 15-Digit IMEI * (Dial *#06#)',
                                          prefixIcon: const Icon(Icons.dialpad_rounded, color: AppTheme.primaryGreen),
                                          filled: true,
                                          fillColor: Colors.white.withOpacity(0.85),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _priceController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Recommended Final Buyback Price (₹) *',
                                          prefixIcon: const Icon(Icons.currency_rupee_rounded, color: AppTheme.primaryGreen),
                                          filled: true,
                                          fillColor: Colors.white.withOpacity(0.85),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _notesController,
                                        decoration: InputDecoration(
                                          labelText: 'Inspection notes (e.g. Verified with charger & invoice)',
                                          prefixIcon: const Icon(Icons.note_alt_outlined, color: AppTheme.primaryGreen),
                                          filled: true,
                                          fillColor: Colors.white.withOpacity(0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                if (_feedbackMessage.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  GlassContainer(
                                    padding: const EdgeInsets.all(14),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: _isSuccess ? AppTheme.primaryGreen : Colors.red),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                          color: _isSuccess ? AppTheme.primaryGreen : Colors.red,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
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
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 20),

                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryGreen.withOpacity(0.35),
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _submitting ? null : _submitInspection,
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(54),
                                      backgroundColor: AppTheme.primaryGreen,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    ),
                                    child: _submitting
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                          )
                                        : const Text(
                                            'Confirm Inspection & Submit Final Offer',
                                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 30),
                              ],
                            ],
                          ),
                        ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryGreen),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          ),
        ],
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
      activeColor: AppTheme.primaryGreen,
      activeTrackColor: AppTheme.primaryGreen.withOpacity(0.4),
      onChanged: onChanged,
    );
  }

  Widget _buildStaffAuthRequiredView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassContainer(
          padding: const EdgeInsets.all(28),
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined, size: 48, color: AppTheme.primaryGreen),
              ),
              const SizedBox(height: 16),
              const Text(
                'Field Agent Access Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'You are currently signed in as a Customer or Guest.\nSign in as a Field Agent to inspect customer devices on doorstep.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.login_rounded, color: Colors.white, size: 18),
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
      ),
    );
  }

  Widget _buildEmptyQueueView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassContainer(
          padding: const EdgeInsets.all(28),
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, size: 54, color: AppTheme.primaryGreen.withOpacity(0.6)),
              const SizedBox(height: 16),
              const Text('No Pickups in Queue', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                'Orders assigned to you for inspection will appear here.\nYou can create a test order from the Home tab or assign one via the Admin Desk.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                label: const Text('Refresh Orders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: _loadSales,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
