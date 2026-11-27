import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';

class AdminValuationSimulatorView extends StatefulWidget {
  final List<BrandModel> brands;

  const AdminValuationSimulatorView({super.key, required this.brands});

  @override
  State<AdminValuationSimulatorView> createState() => _AdminValuationSimulatorViewState();
}

class _AdminValuationSimulatorViewState extends State<AdminValuationSimulatorView> {
  final ApiService _api = ApiService();

  BrandModel? _selectedBrand;
  List<PhoneModelItem> _models = [];
  PhoneModelItem? _selectedModel;
  StorageVariantModel? _selectedVariant;
  bool _isLoadingModels = false;

  // Simulator toggle options
  bool _screenFlawless = true;
  bool _bodyFlawless = true;
  bool _cameraWorking = true;
  bool _batteryHealthy = true;
  bool _boxAndAccessories = true;
  bool _underWarranty = false;

  @override
  void initState() {
    super.initState();
    if (widget.brands.isNotEmpty) {
      _selectBrand(widget.brands.first);
    }
  }

  Future<void> _selectBrand(BrandModel brand) async {
    setState(() {
      _selectedBrand = brand;
      _isLoadingModels = true;
      _models = [];
      _selectedModel = null;
      _selectedVariant = null;
    });

    try {
      final res = await _api.getModels(brandId: brand.id);
      if (mounted) {
        setState(() {
          _models = res;
          _isLoadingModels = false;
          if (_models.isNotEmpty) {
            _selectedModel = _models.first;
            if (_selectedModel!.variants.isNotEmpty) {
              _selectedVariant = _selectedModel!.variants.first;
            }
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingModels = false);
    }
  }

  double _calculateSimulatedQuote() {
    if (_selectedVariant == null) return 0.0;
    double base = _selectedVariant!.basePrice;

    double deductionPct = 0.0;
    if (!_screenFlawless) deductionPct += 0.20; // 20% screen defect
    if (!_bodyFlawless) deductionPct += 0.12;   // 12% body scratches/dents
    if (!_cameraWorking) deductionPct += 0.15;  // 15% camera defect
    if (!_batteryHealthy) deductionPct += 0.10; // 10% degraded battery
    if (!_boxAndAccessories) deductionPct += 0.05; // 5% missing accessories

    if (_underWarranty) {
      deductionPct = (deductionPct - 0.05).clamp(0.0, 1.0); // 5% bonus for warranty
    }

    final calculated = base * (1.0 - deductionPct);
    return calculated < 500 ? 500 : calculated;
  }

  @override
  Widget build(BuildContext context) {
    final quotePrice = _calculateSimulatedQuote();
    final basePrice = _selectedVariant?.basePrice ?? 0.0;
    final mintPrice = _selectedVariant?.mintPrice ?? (basePrice * 1.15);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      children: [
        // Header
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'VALUATION LAB',
              style: TextStyle(
                color: AppTheme.primaryGreen,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Interactive Pricing Simulator',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Simulate real-time buyer offers and verify deduction algorithms',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Brand Selector Dropdown / Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: widget.brands.map((b) {
              final isSel = _selectedBrand?.id == b.id;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(b.name, style: TextStyle(color: isSel ? Colors.white : AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
                  selected: isSel,
                  selectedColor: AppTheme.primaryGreen,
                  backgroundColor: Colors.white,
                  onSelected: (val) {
                    if (val) _selectBrand(b);
                  },
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        // Device Model & Variant Selector
        GlassContainer(
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Target Device Model', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              if (_isLoadingModels)
                const Center(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2)))
              else if (_models.isEmpty)
                const Text('No models found for this brand', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))
              else
                DropdownButtonFormField<PhoneModelItem>(
                  value: _selectedModel,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  items: _models.map((m) => DropdownMenuItem(value: m, child: Text(m.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedModel = val;
                        _selectedVariant = val.variants.isNotEmpty ? val.variants.first : null;
                      });
                    }
                  },
                ),

              if (_selectedModel != null && _selectedModel!.variants.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Storage Capacity Variant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: _selectedModel!.variants.map((v) {
                    final isSel = _selectedVariant?.id == v.id;
                    return ChoiceChip(
                      label: Text(v.storage, style: TextStyle(color: isSel ? Colors.white : AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
                      selected: isSel,
                      selectedColor: AppTheme.primaryGreen,
                      onSelected: (val) {
                        if (val) setState(() => _selectedVariant = v);
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Live Simulated Price Result Card
        GlassContainer(
          borderRadius: BorderRadius.circular(18),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CALCULATED QUOTATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.textSecondary)),
                      const SizedBox(height: 2),
                      Text(
                        '₹${quotePrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.primaryGreen, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Base: ₹${basePrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                      Text('Mint (+15%): ₹${mintPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Condition Checkboxes (Interactive Toggles)
        GlassContainer(
          borderRadius: BorderRadius.circular(18),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hardware Condition Gates', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              _buildConditionSwitch('Screen is Flawless (No Cracks/Lines)', _screenFlawless, (val) => setState(() => _screenFlawless = val), '-20% if cracked'),
              _buildConditionSwitch('Body is Flawless (No Dents)', _bodyFlawless, (val) => setState(() => _bodyFlawless = val), '-12% if dented'),
              _buildConditionSwitch('All Cameras & Sensors Functional', _cameraWorking, (val) => setState(() => _cameraWorking = val), '-15% if faulty'),
              _buildConditionSwitch('Battery Health Good (>80%)', _batteryHealthy, (val) => setState(() => _batteryHealthy = val), '-10% if degraded'),
              _buildConditionSwitch('Original Box & Charger Available', _boxAndAccessories, (val) => setState(() => _boxAndAccessories = val), '-5% if missing'),
              _buildConditionSwitch('Device Under Official Warranty', _underWarranty, (val) => setState(() => _underWarranty = val), '+5% bonus offer'),
            ],
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildConditionSwitch(String label, bool value, Function(bool) onChanged, String impact) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                Text(impact, style: TextStyle(fontSize: 10, color: value ? Colors.grey : Colors.red.shade700, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: AppTheme.primaryGreen,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
