import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';
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

  // Wizard Sub-steps: 0 = Category, 1 = Brand, 2 = Model & Variant
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
      var brands = await _api.getBrands(categoryId: _category?.id);
      if (brands.isEmpty) {
        // Fallback to all brands so category is never empty
        brands = await _api.getBrands();
      }
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
      setState(() {
        _seriesList = s;
        _models = m;
        if (m.isNotEmpty) {
          _selectModel(m.first);
        } else {
          _loading = false;
        }
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
        if (m.isNotEmpty) {
          _selectModel(m.first);
        } else {
          _model = null;
          _variants = [];
          _variant = null;
          _loading = false;
        }
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _selectModel(PhoneModelItem model) async {
    setState(() {
      _model = model;
      _loading = true;
    });

    try {
      var v = model.variants;
      if (v.isEmpty) {
        v = await _api.getVariants(model.id);
      }
      setState(() {
        _variants = v;
        if (v.isNotEmpty) _variant = v.first;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
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
                          ? 'Select Brand'
                          : '${_brand?.name ?? ''} Models',
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (_wizardStep > 0) {
                      setState(() => _wizardStep--);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      body: GlassBackgroundMesh(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
            : _wizardStep == 0
                ? _buildCategoryStep()
                : _wizardStep == 1
                    ? _buildBrandStep()
                    : _buildModelStep(),
      ),
      bottomNavigationBar: _wizardStep == 2 && _variant != null
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
                                const Text(
                                  'Estimated Base Value',
                                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
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
                  setState(() {
                    _category = cat;
                    _wizardStep = 1;
                  });
                  _loadBrands();
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
                      child: const Icon(Icons.phone_android, color: AppTheme.primaryGreen, size: 30),
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
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.lightGreen.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.phone_android, size: 24, color: AppTheme.primaryGreen),
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
                  padding: const EdgeInsets.all(16),
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
                      padding: const EdgeInsets.all(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryGreen : Colors.white.withValues(alpha: 0.85),
                        width: isSelected ? 2.5 : 1.5,
                      ),
                      onTap: () => _selectModel(item),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryGreen.withValues(alpha: 0.2)
                                  : AppTheme.lightGreen.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.smartphone, size: 28, color: AppTheme.primaryGreen),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Year: ${item.releaseYear}',
                            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Storage Variants Selector
        if (_model != null && _variants.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: GlassContainer(
              borderRadius: 22,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select Storage Variant for ${_model!.name}:',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _variants.map((v) {
                      final isSelected = _variant?.id == v.id;
                      return ChoiceChip(
                        label: Text('${v.storage} (₹${v.basePrice.toStringAsFixed(0)})'),
                        selected: isSelected,
                        selectedColor: AppTheme.lightGreen,
                        labelStyle: TextStyle(
                          color: isSelected ? AppTheme.darkGreen : AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _variant = v);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
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
