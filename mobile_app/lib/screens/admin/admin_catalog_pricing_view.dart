import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';
import '../../utils/image_helper.dart';

class AdminCatalogPricingView extends StatefulWidget {
  final List<BrandModel> brands;
  final VoidCallback onRefresh;

  const AdminCatalogPricingView({
    super.key,
    required this.brands,
    required this.onRefresh,
  });

  @override
  State<AdminCatalogPricingView> createState() => _AdminCatalogPricingViewState();
}

class _AdminCatalogPricingViewState extends State<AdminCatalogPricingView> {
  final ApiService _api = ApiService();
  BrandModel? _selectedBrand;
  List<PhoneModelItem> _models = [];
  bool _isLoadingModels = false;
  String _searchQuery = '';

  Future<void> _loadModels(BrandModel brand) async {
    setState(() {
      _selectedBrand = brand;
      _isLoadingModels = true;
      _models = [];
    });
    try {
      final res = await _api.getModels(brandId: brand.id);
      if (mounted) {
        setState(() {
          _models = res;
          _isLoadingModels = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingModels = false);
    }
  }

  void _showVariantPriceModal(PhoneModelItem model, StorageVariantModel variant) {
    final baseController = TextEditingController(text: variant.basePrice.toStringAsFixed(0));
    final mintController = TextEditingController(text: variant.mintPrice.toStringAsFixed(0));
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 14),
              Text('${model.name} (${variant.storage})', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const Text('Manage Buyback Offer Prices', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              const Text('Base Buyback Price (₹)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: baseController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.currency_rupee, color: AppTheme.primaryGreen, size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                onChanged: (val) {
                  final b = double.tryParse(val) ?? 0.0;
                  if (b > 0) {
                    setMState(() => mintController.text = (b * 1.15).toStringAsFixed(0));
                  }
                },
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Mint Price (Top Flawless Offer) (₹)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  TextButton(
                    onPressed: () {
                      final b = double.tryParse(baseController.text) ?? 0.0;
                      if (b > 0) setMState(() => mintController.text = (b * 1.15).toStringAsFixed(0));
                    },
                    child: const Text('+15% Auto', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: mintController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
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
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newBase = double.tryParse(baseController.text) ?? 0.0;
                          final newMint = double.tryParse(mintController.text) ?? 0.0;
                          if (newBase <= 0) return;

                          setMState(() => isSaving = true);
                          try {
                            await _api.updateStorageVariant(variant.id, basePrice: newBase, mintPrice: newMint);
                            if (mounted && _selectedBrand != null) {
                              _loadModels(_selectedBrand!);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            setMState(() => isSaving = false);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save & Update Live Price', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Brand selector horizontal list
        Container(
          color: Colors.white,
          height: 54,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: widget.brands.length,
            itemBuilder: (ctx, idx) {
              final b = widget.brands[idx];
              final isSel = _selectedBrand?.id == b.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(b.name),
                  selected: isSel,
                  selectedColor: AppTheme.lightGreen,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                    color: isSel ? AppTheme.darkGreen : AppTheme.textSecondary,
                  ),
                  onSelected: (_) => _loadModels(b),
                ),
              );
            },
          ),
        ),

        // Search bar
        if (_selectedBrand != null)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            color: Colors.white,
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search ${_selectedBrand!.name} models...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),

        // Models list with expandable variants
        Expanded(
          child: _selectedBrand == null
              ? const Center(child: Text('Select a brand above to manage pricing', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)))
              : _isLoadingModels
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                  : _models.isEmpty
                      ? const Center(child: Text('No models configured for this brand'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: _models.where((m) => m.name.toLowerCase().contains(_searchQuery.toLowerCase())).length,
                          itemBuilder: (ctx, idx) {
                            final filtered = _models.where((m) => m.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                            final m = filtered[idx];
                            return _buildModelItem(m);
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildModelItem(PhoneModelItem model) {
    final imgBytes = ImageHelper.decodeBase64(model.imageBase64);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        borderRadius: 18,
        padding: const EdgeInsets.all(12),
        child: ExpansionTile(
          shape: const Border(),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
            child: imgBytes != null ? ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.memory(imgBytes, fit: BoxFit.contain)) : const Icon(Icons.phone_android, size: 24, color: AppTheme.primaryGreen),
          ),
          title: Text(model.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          subtitle: Text('${model.variants.length} storage variants configured', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          children: [
            const Divider(),
            ...model.variants.map((v) => ListTile(
                  dense: true,
                  title: Text(v.storage, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  subtitle: Text('Base: ₹${v.basePrice.toStringAsFixed(0)} · Mint: ₹${v.mintPrice.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.darkGreen, fontWeight: FontWeight.w700)),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_note, color: AppTheme.primaryGreen, size: 22),
                    tooltip: 'Edit Price',
                    onPressed: () => _showVariantPriceModal(model, v),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
