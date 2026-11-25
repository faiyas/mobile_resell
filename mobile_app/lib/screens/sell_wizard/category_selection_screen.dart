import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/brand_logo.dart';
import '../../utils/image_helper.dart';
import 'questionnaire_screen.dart';

class CategorySelectionScreen extends StatefulWidget {
  final DeviceCategoryModel? selectedCategory;
  final int? initialBrandId;

  const CategorySelectionScreen({
    super.key,
    this.selectedCategory,
    this.initialBrandId,
  });

  @override
  State<CategorySelectionScreen> createState() => _CategorySelectionScreenState();
}

class _CategorySelectionScreenState extends State<CategorySelectionScreen> {
  final ApiService _api = ApiService();

  // Wizard Sub-steps: 0 = Category, 1 = Brand, 2 = Model, 3 = Storage Variant
  int _wizardStep = 0;

  DeviceCategoryModel? _category;
  BrandModel? _brand;
  SeriesModel? _series;
  PhoneModelItem? _model;
  StorageVariantModel? _variant;

  List<DeviceCategoryModel> _categories = [];
  List<BrandModel> _brands = [];
  List<SeriesModel> _seriesList = [];
  List<PhoneModelItem> _models = [];
  List<StorageVariantModel> _variants = [];

  bool _loading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _category = widget.selectedCategory;
    if (_category != null) {
      _wizardStep = 1;
      _loadBrands();
    } else {
      _loadCategories();
    }
  }

  Future<void> _loadCategories() async {
    setState(() => _loading = true);
    try {
      final cats = await _api.getDeviceCategories();
      setState(() {
        _categories = cats;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadBrands() async {
    setState(() => _loading = true);
    try {
      final brands = await _api.getBrands(categoryId: _category?.id, forceRefresh: true);
      setState(() {
        _brands = brands;
        _loading = false;
      });

      if (widget.initialBrandId != null && brands.isNotEmpty) {
        final found = brands.firstWhere(
          (b) => b.id == widget.initialBrandId,
          orElse: () => brands.first,
        );
        _selectBrand(found);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _selectBrand(BrandModel brand) async {
    setState(() {
      _brand = brand;
      _wizardStep = 2;
      _series = null;
      _model = null;
      _variant = null;
      _loading = true;
    });

    try {
      final s = await _api.getSeries(brandId: brand.id);
      final m = await _api.getModels(brandId: brand.id);

      // Sort series chips so the latest generations appear first
      final maxYearBySeries = <int, int>{};
      for (final modelItem in m) {
        final sid = modelItem.seriesId;
        if (sid != null) {
          final prev = maxYearBySeries[sid] ?? 0;
          if (modelItem.releaseYear > prev) {
            maxYearBySeries[sid] = modelItem.releaseYear;
          }
        }
      }
      int extractSeriesNum(String name) {
        final match = RegExp(r'(\d+)').firstMatch(name);
        return match != null ? (int.tryParse(match.group(1)!) ?? 0) : 0;
      }
      final sortedSeries = List<SeriesModel>.from(s)
        ..sort((a, b) {
          final yearCmp = (maxYearBySeries[b.id] ?? 0).compareTo(maxYearBySeries[a.id] ?? 0);
          if (yearCmp != 0) return yearCmp;
          final numCmp = extractSeriesNum(b.name).compareTo(extractSeriesNum(a.name));
          if (numCmp != 0) return numCmp;
          return a.name.compareTo(b.name);
        });

      setState(() {
        _seriesList = sortedSeries;
        _models = m;
        _model = null;
        _variant = null;
        _variants = [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _selectSeries(SeriesModel? series) async {
    setState(() {
      _series = series;
      _loading = true;
    });
    try {
      final m = await _api.getModels(
        brandId: _brand!.id,
        seriesId: series?.id,
      );
      setState(() {
        _models = m;
        _model = null;
        _variant = null;
        _variants = [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _selectModel(PhoneModelItem model) async {
    setState(() {
      _model = model;
      _variant = null;
      _loading = true;
    });

    try {
      var v = model.variants;
      if (v.isEmpty) {
        v = await _api.getVariants(model.id);
      }
      if (!mounted) return;
      setState(() {
        _variants = v;
        _variant = v.length == 1 ? v.first : null;
        _wizardStep = 3;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleBack() {
    if (_wizardStep == 3) {
      setState(() {
        _variant = null;
        _wizardStep = 2;
      });
    } else if (_wizardStep == 2) {
      setState(() {
        _model = null;
        _wizardStep = 1;
      });
    } else if (_wizardStep == 1) {
      if (widget.selectedCategory != null) {
        Navigator.pop(context);
      } else {
        setState(() {
          _brand = null;
          _wizardStep = 0;
        });
      }
    } else {
      Navigator.pop(context);
    }
  }

  void _showCustomDeviceModal({String? initialCategory}) {
    final nameCtrl = TextEditingController();
    final brandCtrl = TextEditingController(text: initialCategory ?? 'Others');
    final specsCtrl = TextEditingController(text: '128GB');
    final priceCtrl = TextEditingController(text: '10000');
    String selectedCat = initialCategory ?? 'Others';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: AppTheme.glassBorder, width: 1.5),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Row(
                      children: [
                        Icon(Icons.devices_other_rounded, color: AppTheme.primaryGreen),
                        SizedBox(width: 10),
                        Text('Sell Other Gadget / Custom Device', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Enter device information to receive an instant buyback offer.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    const SizedBox(height: 16),

                    const Text('Select Category:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    Row(
                      children: ['Mobile', 'Tablet', 'Dead Phone', 'Others'].map((cat) {
                        final isSel = selectedCat == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(cat, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? Colors.white : AppTheme.textPrimary)),
                            selected: isSel,
                            selectedColor: AppTheme.primaryGreen,
                            backgroundColor: Colors.white,
                            side: BorderSide(color: isSel ? AppTheme.primaryGreen : AppTheme.border),
                            onSelected: (val) {
                              if (val) {
                                setModalState(() {
                                  selectedCat = cat;
                                  brandCtrl.text = cat;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Device & Model Name *',
                        hintText: 'e.g. Apple iPad Mini 4, Sony Xperia 1, PS5...',
                        prefixIcon: Icon(Icons.phone_android, color: AppTheme.primaryGreen),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: specsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Storage & RAM / Condition *',
                        hintText: 'e.g. 64GB WiFi, 8GB/128GB, Dead Battery...',
                        prefixIcon: Icon(Icons.memory, color: AppTheme.primaryGreen),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Estimated Value / Expected Price (₹) *',
                        hintText: 'e.g. 8000',
                        prefixIcon: Icon(Icons.currency_rupee, color: AppTheme.primaryGreen),
                      ),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter device name')));
                          return;
                        }
                        final price = double.tryParse(priceCtrl.text.trim()) ?? 8000.0;
                        Navigator.pop(ctx);

                        final virtualBrand = BrandModel(id: 0, name: selectedCat, slug: selectedCat.toLowerCase());
                        final virtualModel = PhoneModelItem(id: 0, name: name, slug: name.toLowerCase(), releaseYear: 2024);
                        final virtualVariant = StorageVariantModel(id: 0, storage: specsCtrl.text.trim(), basePrice: price, minPrice: 500.0);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuestionnaireScreen(
                              brand: virtualBrand,
                              model: virtualModel,
                              variant: virtualVariant,
                              isCustomDevice: true,
                              customDeviceName: name,
                              customDeviceCategory: selectedCat,
                              customDeviceSpecs: specsCtrl.text.trim(),
                              customExpectedPrice: price,
                            ),
                          ),
                        );
                      },
                      child: const Text('Continue to Condition Inspection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _proceedToQuestionnaire() {
    if (_variant == null || _model == null || _brand == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionnaireScreen(
          category: _category,
          brand: _brand!,
          model: _model!,
          variant: _variant!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      extendBody: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 1.5,
                  ),
                ),
              ),
              child: AppBar(
                backgroundColor: Colors.transparent,
                title: Text(
                  _wizardStep == 0
                      ? 'Select Category'
                      : _wizardStep == 1
                          ? 'Select ${_category?.name ?? "Brand"}'
                          : _wizardStep == 2
                              ? '${_brand?.name ?? ''} Models'
                              : 'Select Storage Variant',
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _handleBack,
                ),
              ),
            ),
          ),
        ),
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleBack();
        },
        child: GlassBackgroundMesh(
          child: _loading
              ? const RecellBrandLoader(message: 'Fetching guaranteed buyback catalog...')
              : _wizardStep == 0
                  ? _buildCategoryStep()
                  : _wizardStep == 1
                      ? _buildBrandStep()
                      : _wizardStep == 2
                          ? _buildModelStep()
                          : _buildVariantStep(),
        ),
      ),
      bottomNavigationBar: _wizardStep == 3 && _variant != null
          ? Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Estimated Base Value · ${_variant!.storage}',
                                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '₹${_variant!.basePrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.darkGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _proceedToQuestionnaire,
                            child: const Row(
                              children: [
                                Text('Continue to Inspection'),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward_rounded, size: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildCategoryStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sell Your Device',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose a device category to calculate its highest buyback quotation.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 18),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: _categories.length,
            itemBuilder: (context, idx) {
              final cat = _categories[idx];
              return GlassContainer(
                borderRadius: 22,
                padding: const EdgeInsets.all(16),
                onTap: () {
                  final isOther = cat.name.toLowerCase().contains('other') || cat.slug.toLowerCase().contains('other');
                  if (isOther) {
                    _showCustomDeviceModal(initialCategory: 'Others');
                  } else {
                    setState(() {
                      _category = cat;
                      _wizardStep = 1;
                    });
                    _loadBrands();
                  }
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.lightGreen.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: _buildCategoryIcon(cat),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      cat.name,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tap to proceed',
                      style: TextStyle(fontSize: 11, color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 18),

          // Custom "Sell Any Other Device" Glass Banner
          GlassContainer(
            borderRadius: 20,
            padding: const EdgeInsets.all(16),
            onTap: () => _showCustomDeviceModal(initialCategory: 'Others'),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryGreen, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Can\'t find your device?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.textPrimary)),
                      SizedBox(height: 2),
                      Text('Sell Tablet, Dead Phone, Watch or custom device with instant offer', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.primaryGreen),
              ],
            ),
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildBrandStep() {
    final filtered = _brands.where((b) => b.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: GlassContainer(
            borderRadius: 18,
            padding: EdgeInsets.zero,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search brand (e.g. Apple, Samsung, OnePlus)...',
                prefixIcon: Icon(Icons.search, color: AppTheme.primaryGreen),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GlassContainer(
                      padding: const EdgeInsets.all(24),
                      borderRadius: BorderRadius.circular(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.lightGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.devices_other_rounded, size: 36, color: AppTheme.primaryGreen),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No ${_category?.name ?? "device"} brands found',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Get an instant doorstep valuation for your ${_category?.name ?? "device"} using custom specs.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                            label: Text('Sell Custom ${_category?.name ?? "Device"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () => _showCustomDeviceModal(initialCategory: _category?.name),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: filtered.length,
            itemBuilder: (context, idx) {
              final brand = filtered[idx];
              return GlassContainer(
                borderRadius: 20,
                padding: const EdgeInsets.all(10),
                onTap: () => _selectBrand(brand),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withOpacity(0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(child: _buildBrandLogo(brand)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      brand.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBrandLogo(BrandModel brand) {
    if (brand.logoBase64 != null && brand.logoBase64!.trim().isNotEmpty) {
      try {
        final clean = brand.logoBase64!.contains(',')
            ? brand.logoBase64!.split(',').last
            : brand.logoBase64!;
        final bytes = base64Decode(clean);
        return Image.memory(
          bytes,
          width: 32,
          height: 32,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _getBrandEmblem(brand.name),
        );
      } catch (_) {
        return _getBrandEmblem(brand.name);
      }
    }
    return _getBrandEmblem(brand.name);
  }

  Widget _getBrandEmblem(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('apple')) {
      return const Icon(Icons.apple, size: 28, color: Colors.black87);
    } else if (lower.contains('samsung')) {
      return const Text(
        'SAMSUNG',
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF1428A0), letterSpacing: 0.5),
      );
    } else if (lower.contains('oneplus')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFFEB0029), borderRadius: BorderRadius.circular(4)),
        child: const Text('1+', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
      );
    } else if (lower.contains('google')) {
      return const Text('G', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF4285F4)));
    } else if (lower.contains('xiaomi')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFFFF6700), borderRadius: BorderRadius.circular(4)),
        child: const Text('mi', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
      );
    } else if (lower.contains('nothing')) {
      return const Text('NOTHING', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 1.0));
    } else {
      return Text(
        name.length > 5 ? name.substring(0, 5).toUpperCase() : name.toUpperCase(),
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.darkGreen),
      );
    }
  }

  Widget _buildCategoryIcon(DeviceCategoryModel cat) {
    if (cat.imageBase64 != null && cat.imageBase64!.trim().isNotEmpty) {
      final bytes = ImageHelper.decodeBase64(cat.imageBase64);
      if (bytes != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            bytes,
            width: 32,
            height: 32,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _getCategoryFallbackIcon(cat.name),
          ),
        );
      }
    }
    return _getCategoryFallbackIcon(cat.name);
  }

  Widget _getCategoryFallbackIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('tablet') || lower.contains('ipad')) {
      return const Icon(Icons.tablet_mac_rounded, color: AppTheme.primaryGreen, size: 30);
    } else if (lower.contains('gaming') || lower.contains('console')) {
      return const Icon(Icons.sports_esports_rounded, color: AppTheme.primaryGreen, size: 30);
    } else if (lower.contains('laptop') || lower.contains('macbook')) {
      return const Icon(Icons.laptop_mac_rounded, color: AppTheme.primaryGreen, size: 30);
    } else if (lower.contains('watch')) {
      return const Icon(Icons.watch_rounded, color: AppTheme.primaryGreen, size: 30);
    }
    return const Icon(Icons.phone_android, color: AppTheme.primaryGreen, size: 30);
  }

  Widget _buildModelImageArea(PhoneModelItem item, bool isSelected) {
    if (item.imageBase64 != null && item.imageBase64!.trim().isNotEmpty) {
      final bytes = ImageHelper.decodeBase64(item.imageBase64);
      if (bytes != null) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.all(8),
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              color: isSelected
                  ? AppTheme.primaryGreen.withValues(alpha: 0.16)
                  : AppTheme.lightGreen.withValues(alpha: 0.65),
              alignment: Alignment.center,
              child: const Icon(Icons.smartphone_rounded, size: 48, color: AppTheme.primaryGreen),
            ),
          ),
        );
      }
    }
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: isSelected
          ? AppTheme.primaryGreen.withValues(alpha: 0.16)
          : AppTheme.lightGreen.withValues(alpha: 0.65),
      alignment: Alignment.center,
      child: const Icon(Icons.smartphone_rounded, size: 48, color: AppTheme.primaryGreen),
    );
  }

  Widget _buildVariantStep() {
    final modelImgBytes = ImageHelper.decodeBase64(_model?.imageBase64);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: modelImgBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.memory(modelImgBytes, fit: BoxFit.contain),
                      )
                    : const Icon(Icons.phone_iphone_rounded, size: 32, color: AppTheme.primaryGreen),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_brand?.name ?? ''} ${_model?.name ?? ''}'.trim(),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Choose your device storage variant below to continue to condition questions.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Available Storage Variants',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        if (_variants.isEmpty)
          GlassContainer(
            borderRadius: 22,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.sd_storage_outlined, size: 36, color: AppTheme.textSecondary),
                const SizedBox(height: 10),
                const Text(
                  'No storage variants configured for this model yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _wizardStep = 2),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Choose Another Model'),
                ),
              ],
            ),
          )
        else
          ..._variants.map((v) {
            final isSelected = _variant?.id == v.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() => _variant = v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.lightGreen : Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryGreen : AppTheme.border,
                      width: isSelected ? 2.2 : 1.2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.14),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryGreen
                              : AppTheme.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.sd_storage_rounded,
                          color: isSelected ? Colors.white : AppTheme.primaryGreen,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.ram != null && v.ram!.isNotEmpty
                                  ? '${v.storage} · ${v.ram} RAM'
                                  : v.storage,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Base Buyback Value: ₹${v.basePrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.darkGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen, size: 24)
                      else
                        const Icon(Icons.radio_button_unchecked_rounded, color: AppTheme.border, size: 22),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildModelStep() {
    return Column(
      children: [
        // Series Pills (e.g. All, iPhone 11 Series, iPhone 12 Series)
        if (_seriesList.isNotEmpty)
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildSeriesPill(null, 'All'),
                ..._seriesList.map((s) => _buildSeriesPill(s, s.name)),
              ],
            ),
          ),

        // Models Grid
        Expanded(
          child: _models.isEmpty
              ? const Center(child: Text('No models available for this selection'))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: _models.length,
                  itemBuilder: (context, idx) {
                    final item = _models[idx];
                    final isSelected = _model?.id == item.id;

                    return GlassContainer(
                      borderRadius: 20,
                      padding: EdgeInsets.zero,
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryGreen : Colors.white.withValues(alpha: 0.85),
                        width: isSelected ? 2.5 : 1.5,
                      ),
                      onTap: () => _selectModel(item),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _buildModelImageArea(item, isSelected),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              color: Colors.white.withValues(alpha: 0.92),
                              child: Text(
                                item.name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSeriesPill(SeriesModel? s, String label) {
    final isSelected = (s == null && _series == null) || (_series?.id == s?.id);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.lightGreen,
        checkmarkColor: AppTheme.primaryGreen,
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.darkGreen : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          fontSize: 11,
        ),
        onSelected: (_) => _selectSeries(s),
      ),
    );
  }
}
