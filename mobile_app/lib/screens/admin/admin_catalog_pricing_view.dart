import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final ImagePicker _picker = ImagePicker();

  BrandModel? _selectedBrand;
  List<PhoneModelItem> _models = [];
  bool _isLoadingModels = false;
  String _searchQuery = '';

  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  bool _hasNext = false;
  bool _hasPrevious = false;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    if (widget.brands.isNotEmpty) {
      _selectedBrand = widget.brands.first;
      _loadModels(widget.brands.first, page: 1);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadModels(BrandModel brand, {int page = 1, String? search}) async {
    setState(() {
      _selectedBrand = brand;
      _isLoadingModels = true;
      _currentPage = page;
    });
    try {
      final q = search ?? (_searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null);
      final res = await _api.getModelsPaginated(
        brandId: brand.id,
        page: page,
        pageSize: 10,
        search: q,
      );
      if (mounted) {
        setState(() {
          _models = res['items'] as List<PhoneModelItem>;
          _totalCount = res['total_count'] as int;
          _totalPages = res['total_pages'] as int;
          _currentPage = res['current_page'] as int;
          _hasNext = res['has_next'] as bool;
          _hasPrevious = res['has_previous'] as bool;
          _isLoadingModels = false;
        });
        if (_scrollController.hasClients) {
          _scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingModels = false);
    }
  }

  // ================= 1. BRAND CRUD =================
  void _showBrandModal([BrandModel? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String? base64Img = existing?.logoBase64;
    int? catId = existing?.categoryId ?? 1;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 14),
              Text(existing == null ? 'Add New Brand' : 'Edit Brand: ${existing.name}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const Text('Device catalog brand settings', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              const Text('Brand Name', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Apple, Samsung, OnePlus',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              // Logo Picker
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                    child: base64Img != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.memory(ImageHelper.decodeBase64(base64Img)!, fit: BoxFit.contain))
                        : const Icon(Icons.image, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87),
                    icon: const Icon(Icons.upload, size: 16),
                    label: Text(base64Img != null ? 'Change Logo' : 'Pick Logo', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final xfile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 400);
                      if (xfile != null) {
                        final bytes = await xfile.readAsBytes();
                        setM(() => base64Img = base64Encode(bytes));
                      }
                    },
                  ),
                  if (base64Img != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      tooltip: 'Remove Logo',
                      onPressed: () => setM(() => base64Img = null),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          setM(() => isSaving = true);
                          try {
                            if (existing == null) {
                              await _api.createBrand({
                                'name': name,
                                'slug': name.toLowerCase().replaceAll(' ', '-'),
                                'category': catId,
                                if (base64Img != null) 'logo_base64': base64Img,
                              });
                            } else {
                              await _api.updateBrand(existing.id, {
                                'name': name,
                                if (base64Img != null) 'logo_base64': base64Img,
                              });
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            widget.onRefresh();
                          } catch (e) {
                            setM(() => isSaving = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(existing == null ? 'Create Brand' : 'Save Changes', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteBrand(BrandModel brand) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${brand.name}?'),
        content: const Text('This will remove the brand and hide all associated models. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteBrand(brand.id);
                widget.onRefresh();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ================= 2. CATEGORY CRUD =================
  void _showCategoryModal() {
    final nameCtrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 14),
              const Text('Add Device Category', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const Text('e.g. Mobile, Tablet, Laptop, Smartwatch', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              const Text('Category Name', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Smartwatch, Dead Phone',
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
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          setM(() => isSaving = true);
                          try {
                            await _api.createDeviceCategory({
                              'name': name,
                              'slug': name.toLowerCase().replaceAll(' ', '-'),
                              'icon_name': 'devices',
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                            widget.onRefresh();
                          } catch (e) {
                            setM(() => isSaving = false);
                            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Add Category', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ================= 3. SERIES CRUD =================
  void _showSeriesModal() {
    if (_selectedBrand == null) return;
    final nameCtrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 14),
              Text('Add Series for ${_selectedBrand!.name}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const Text('e.g. Galaxy S Series, iPhone Pro, Redmi Note', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              const Text('Series Name', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Galaxy S Series, Nord Series',
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
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          setM(() => isSaving = true);
                          try {
                            await _api.createSeries({
                              'name': name,
                              'brand': _selectedBrand!.id,
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (_selectedBrand != null) _loadModels(_selectedBrand!, page: _currentPage);
                          } catch (e) {
                            setM(() => isSaving = false);
                            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Add Series', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ================= 4. MODEL CRUD =================
  void _showModelModal([PhoneModelItem? existing]) {
    if (_selectedBrand == null) return;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final yearCtrl = TextEditingController(text: (existing?.releaseYear ?? DateTime.now().year).toString());
    String? base64Img = existing?.imageBase64;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 14),
              Text(existing == null ? 'Add Model for ${_selectedBrand!.name}' : 'Edit Model: ${existing.name}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const SizedBox(height: 16),
              const Text('Model Name', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. iPhone 15 Pro Max, Galaxy S24 Ultra',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Release Year', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: yearCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '2024',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                    child: base64Img != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.memory(ImageHelper.decodeBase64(base64Img)!, fit: BoxFit.contain))
                        : const Icon(Icons.phone_android, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87),
                    icon: const Icon(Icons.upload, size: 16),
                    label: Text(base64Img != null ? 'Change Picture' : 'Pick Picture', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final xfile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 600);
                      if (xfile != null) {
                        final bytes = await xfile.readAsBytes();
                        setM(() => base64Img = base64Encode(bytes));
                      }
                    },
                  ),
                  if (base64Img != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      tooltip: 'Remove Picture',
                      onPressed: () => setM(() => base64Img = null),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          final yr = int.tryParse(yearCtrl.text) ?? DateTime.now().year;
                          setM(() => isSaving = true);
                          try {
                            if (existing == null) {
                              await _api.createPhoneModel({
                                'name': name,
                                'brand': _selectedBrand!.id,
                                'release_year': yr,
                                if (base64Img != null) 'image_base64': base64Img,
                              });
                            } else {
                              await _api.updatePhoneModel(existing.id, {
                                'name': name,
                                'release_year': yr,
                                if (base64Img != null) 'image_base64': base64Img,
                              });
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (_selectedBrand != null) _loadModels(_selectedBrand!, page: _currentPage);
                          } catch (e) {
                            setM(() => isSaving = false);
                            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(existing == null ? 'Create Model' : 'Save Changes', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteModel(PhoneModelItem model) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${model.name}?'),
        content: const Text('This will delete the model and all its storage variants. Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deletePhoneModel(model.id);
                if (_selectedBrand != null) _loadModels(_selectedBrand!);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ================= 5. VARIANT CRUD =================
  void _showAddVariantModal(PhoneModelItem model) {
    final storageCtrl = TextEditingController(text: '128GB');
    final ramCtrl = TextEditingController(text: '8GB');
    final baseCtrl = TextEditingController(text: '15000');
    final mintCtrl = TextEditingController(text: '17250');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 14),
              Text('Add Storage Variant · ${model.name}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: storageCtrl,
                      decoration: InputDecoration(
                        labelText: 'Storage (e.g. 128GB, 256GB)',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: ramCtrl,
                      decoration: InputDecoration(
                        labelText: 'RAM (e.g. 8GB)',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: baseCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Base Buyback Price (₹)',
                  prefixIcon: const Icon(Icons.currency_rupee, color: AppTheme.primaryGreen),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onChanged: (val) {
                  final b = double.tryParse(val) ?? 0.0;
                  if (b > 0) setM(() => mintCtrl.text = (b * 1.15).toStringAsFixed(0));
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mintCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Mint Price (Flawless) (₹)',
                  prefixIcon: const Icon(Icons.star, color: Colors.amber),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final storage = storageCtrl.text.trim();
                          final base = double.tryParse(baseCtrl.text) ?? 0.0;
                          final mint = double.tryParse(mintCtrl.text) ?? (base * 1.15);
                          if (storage.isEmpty || base <= 0) return;
                          setM(() => isSaving = true);
                          try {
                            await _api.createVariant({
                              'model': model.id,
                              'storage': storage,
                              'ram': ramCtrl.text.trim(),
                              'base_price': base,
                              'mint_price': mint,
                              'min_price': (base * 0.40).round(),
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (_selectedBrand != null) _loadModels(_selectedBrand!, page: _currentPage);
                          } catch (e) {
                            setM(() => isSaving = false);
                            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Add Storage Variant', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${model.name} (${variant.storage})', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                        const Text('Manage Buyback Offer Prices', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete Variant',
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await _api.deleteVariant(variant.id);
                        if (_selectedBrand != null) _loadModels(_selectedBrand!);
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                  ),
                ],
              ),
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
                              _loadModels(_selectedBrand!, page: _currentPage);
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
        // Top Quick Actions bar for Categories, Series, Brands
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.add_circle, size: 16, color: AppTheme.primaryGreen),
                        label: const Text('+ Brand', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        onPressed: () => _showBrandModal(),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.category, size: 16, color: Colors.blue),
                        label: const Text('+ Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        onPressed: _showCategoryModal,
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.layers, size: 16, color: Colors.purple),
                        label: const Text('+ Series', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        onPressed: _showSeriesModal,
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.phone_iphone, size: 16, color: Colors.teal),
                        label: const Text('+ Model', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        onPressed: () => _showModelModal(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Brand selector horizontal list with Edit / Delete actions
        Container(
          color: Colors.white,
          height: 52,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            itemCount: widget.brands.length,
            itemBuilder: (ctx, idx) {
              final b = widget.brands[idx];
              final isSel = _selectedBrand?.id == b.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(b.name),
                      if (isSel) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _showBrandModal(b),
                          child: const Icon(Icons.edit, size: 12, color: AppTheme.darkGreen),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _confirmDeleteBrand(b),
                          child: const Icon(Icons.close, size: 12, color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                  selected: isSel,
                  selectedColor: AppTheme.lightGreen,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                    color: isSel ? AppTheme.darkGreen : AppTheme.textSecondary,
                  ),
                  onSelected: (_) {
                    _searchCtrl.clear();
                    _searchQuery = '';
                    _loadModels(b, page: 1);
                  },
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
              controller: _searchCtrl,
              onChanged: (val) {
                setState(() => _searchQuery = val);
                _debounceTimer?.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                  if (_selectedBrand != null) {
                    _loadModels(_selectedBrand!, page: 1, search: val);
                  }
                });
              },
              decoration: InputDecoration(
                hintText: 'Search ${_selectedBrand!.name} models...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                          if (_selectedBrand != null) {
                            _loadModels(_selectedBrand!, page: 1, search: '');
                          }
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),

        // Models list with expandable variants and Add Variant button
        Expanded(
          child: _selectedBrand == null
              ? const Center(child: Text('Select a brand above to manage pricing', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)))
              : _isLoadingModels
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                  : _models.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('No models configured for ${_selectedBrand!.name}'),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add First Model'),
                                onPressed: () => _showModelModal(),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                          itemCount: _models.length + (_totalPages > 1 ? 1 : 0),
                          itemBuilder: (ctx, idx) {
                            if (idx == _models.length) {
                              return _buildPaginationBar();
                            }
                            final m = _models[idx];
                            return _buildModelItem(m);
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildPaginationBar() {
    if (_totalPages <= 1) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Button
          ElevatedButton.icon(
            onPressed: (_hasPrevious && !_isLoadingModels && _selectedBrand != null)
                ? () => _loadModels(_selectedBrand!, page: _currentPage - 1)
                : null,
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 12),
            label: const Text('Previous', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.lightGreen,
              foregroundColor: AppTheme.darkGreen,
              disabledBackgroundColor: Colors.grey.shade100,
              disabledForegroundColor: Colors.grey.shade400,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),

          // Page info
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Page $_currentPage of $_totalPages',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppTheme.textPrimary),
              ),
              Text(
                '$_totalCount Models Total',
                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),

          // Next Button
          ElevatedButton.icon(
            onPressed: (_hasNext && !_isLoadingModels && _selectedBrand != null)
                ? () => _loadModels(_selectedBrand!, page: _currentPage + 1)
                : null,
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
            label: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade100,
              disabledForegroundColor: Colors.grey.shade400,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
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
          title: Row(
            children: [
              Expanded(child: Text(model.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
              IconButton(
                icon: const Icon(Icons.edit, size: 18, color: AppTheme.textSecondary),
                onPressed: () => _showModelModal(model),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                onPressed: () => _confirmDeleteModel(model),
              ),
            ],
          ),
          subtitle: Text('${model.variants.length} storage variants · Release ${model.releaseYear}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryGreen,
                    side: const BorderSide(color: AppTheme.primaryGreen),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Storage Variant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _showAddVariantModal(model),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
