import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class SellDraftData {
  final bool isCustomDevice;
  final String? customDeviceName;
  final String? customDeviceCategory;
  final String? customDeviceSpecs;
  final double? customExpectedPrice;
  final BrandModel? brand;
  final PhoneModelItem? model;
  final StorageVariantModel? variant;
  final List<String> selectedOptionCodes;
  final Map<String, String> customStepNotes;
  final String otherDefectsNotes;
  final double estimatedPrice;
  final String savedAt;

  SellDraftData({
    this.isCustomDevice = false,
    this.customDeviceName,
    this.customDeviceCategory,
    this.customDeviceSpecs,
    this.customExpectedPrice,
    this.brand,
    this.model,
    this.variant,
    this.selectedOptionCodes = const [],
    this.customStepNotes = const {},
    this.otherDefectsNotes = '',
    this.estimatedPrice = 0.0,
    required this.savedAt,
  });

  String get deviceDisplayName {
    if (isCustomDevice && customDeviceName != null && customDeviceName!.isNotEmpty) {
      return '$customDeviceName (${customDeviceCategory ?? "Custom"})';
    }
    if (model != null && brand != null) {
      return '${brand!.name} ${model!.name}';
    }
    return 'Saved Incomplete Sell Valuation';
  }

  String get specSubtitle {
    if (isCustomDevice && customDeviceSpecs != null && customDeviceSpecs!.isNotEmpty) {
      return customDeviceSpecs!;
    }
    if (variant != null) {
      return '${variant!.storage}${variant!.ram != null && variant!.ram!.isNotEmpty ? " · ${variant!.ram} RAM" : ""}';
    }
    return 'Configured Valuation';
  }

  Map<String, dynamic> toJson() => {
    'is_custom_device': isCustomDevice,
    'custom_device_name': customDeviceName,
    'custom_device_category': customDeviceCategory,
    'custom_device_specs': customDeviceSpecs,
    'custom_expected_price': customExpectedPrice,
    'brand_id': brand?.id,
    'brand_name': brand?.name,
    'brand_slug': brand?.slug,
    'brand_logo_base64': brand?.logoBase64,
    'model_id': model?.id,
    'model_name': model?.name,
    'model_slug': model?.slug,
    'model_release_year': model?.releaseYear,
    'variant_id': variant?.id,
    'variant_storage': variant?.storage,
    'variant_ram': variant?.ram,
    'variant_base_price': variant?.basePrice,
    'variant_min_price': variant?.minPrice,
    'selected_option_codes': selectedOptionCodes,
    'custom_step_notes': customStepNotes,
    'other_defects_notes': otherDefectsNotes,
    'estimated_price': estimatedPrice,
    'saved_at': savedAt,
  };

  factory SellDraftData.fromJson(Map<String, dynamic> json) {
    BrandModel? b;
    if (json['brand_id'] != null) {
      b = BrandModel(
        id: json['brand_id'] is int ? json['brand_id'] : 0,
        name: json['brand_name']?.toString() ?? '',
        slug: json['brand_slug']?.toString() ?? '',
        logoBase64: json['brand_logo_base64']?.toString(),
      );
    }

    PhoneModelItem? m;
    if (json['model_id'] != null) {
      m = PhoneModelItem(
        id: json['model_id'] is int ? json['model_id'] : 0,
        name: json['model_name']?.toString() ?? '',
        slug: json['model_slug']?.toString() ?? '',
        releaseYear: json['model_release_year'] is int ? json['model_release_year'] : 2024,
      );
    }

    StorageVariantModel? v;
    if (json['variant_id'] != null) {
      v = StorageVariantModel(
        id: json['variant_id'] is int ? json['variant_id'] : 0,
        storage: json['variant_storage']?.toString() ?? '',
        ram: json['variant_ram']?.toString(),
        basePrice: double.tryParse(json['variant_base_price']?.toString() ?? '') ?? 0.0,
        minPrice: double.tryParse(json['variant_min_price']?.toString() ?? '') ?? 0.0,
      );
    }

    final opts = (json['selected_option_codes'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final notes = (json['custom_step_notes'] as Map<String, dynamic>?)?.map(
          (k, val) => MapEntry(k, val.toString()),
        ) ??
        {};

    return SellDraftData(
      isCustomDevice: json['is_custom_device'] == true,
      customDeviceName: json['custom_device_name']?.toString(),
      customDeviceCategory: json['custom_device_category']?.toString(),
      customDeviceSpecs: json['custom_device_specs']?.toString(),
      customExpectedPrice: double.tryParse(json['custom_expected_price']?.toString() ?? ''),
      brand: b,
      model: m,
      variant: v,
      selectedOptionCodes: opts,
      customStepNotes: notes,
      otherDefectsNotes: json['other_defects_notes']?.toString() ?? '',
      estimatedPrice: double.tryParse(json['estimated_price']?.toString() ?? '') ?? 0.0,
      savedAt: json['saved_at']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }
}

class DraftSellService {
  static const String _keyDraft = 'recell_incomplete_sell_draft_v1';

  static Future<void> saveDraft(SellDraftData draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(draft.toJson());
      await prefs.setString(_keyDraft, jsonStr);
    } catch (_) {}
  }

  static Future<SellDraftData?> getDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyDraft);
      if (jsonStr == null || jsonStr.isEmpty) return null;
      final map = jsonDecode(jsonStr);
      if (map is Map<String, dynamic>) {
        return SellDraftData.fromJson(map);
      }
    } catch (_) {}
    return null;
  }

  static Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyDraft);
    } catch (_) {}
  }
}
