import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'api_service.dart';

/// High-speed silent offline storage for customer-facing data.
/// Implements the Stale-While-Revalidate pattern:
/// 1. Instant 0ms load from mobile disk on app open (no spinner).
/// 2. Silent background sync to detect server changes and update cache delta.
class CustomerCacheService {
  static const String _keyCms = 'customer_cache_cms_sections_v2';
  static const String _keyCategories = 'customer_cache_device_categories_v2';
  static const String _keyBrands = 'customer_cache_brands_v2';
  static const String _keySyncBundle = 'customer_cache_sync_bundle_v1';
  static const String _keyLastSync = 'customer_cache_last_sync_timestamp';
  static const String _keyVersions = 'dolly_local_versions_v1';
  static final Set<int> _staleBrandIds = <int>{};

  static bool isBrandStale(int brandId) => _staleBrandIds.contains(brandId);
  static void markBrandFresh(int brandId) => _staleBrandIds.remove(brandId);

  /// Hydrates ApiService memory with cached Series, Models, Variants & Questionnaires
  static Future<void> hydrateApiFromLocalCache(ApiService api) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keySyncBundle);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final series = decoded['series'] is List
            ? (decoded['series'] as List).whereType<Map>().map((j) => SeriesModel.fromJson(Map<String, dynamic>.from(j))).toList()
            : null;
        final models = decoded['models'] is List
            ? (decoded['models'] as List).whereType<Map>().map((j) => PhoneModelItem.fromJson(Map<String, dynamic>.from(j))).toList()
            : null;
        final conditions = decoded['conditions'] is List
            ? (decoded['conditions'] as List).whereType<Map>().map((j) => ConditionCategoryModel.fromJson(Map<String, dynamic>.from(j))).toList()
            : null;
        api.hydrateOfflineBundle(series: series, models: models, conditions: conditions);
      }
    } catch (e) {
      debugPrint('Error hydrating offline bundle: $e');
    }
  }

  /// Instant synchronous/cached read of CMS Sections
  static Future<List<CMSSectionModel>> getCachedCMSSections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyCms);
      if (raw == null || raw.isEmpty) return [];
      final List decoded = jsonDecode(raw);
      return decoded.map((j) => CMSSectionModel.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error reading cached CMS: $e');
      return [];
    }
  }

  /// Instant cached read of Device Categories
  static Future<List<DeviceCategoryModel>> getCachedCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyCategories);
      if (raw == null || raw.isEmpty) return [];
      final List decoded = jsonDecode(raw);
      return decoded.map((j) => DeviceCategoryModel.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error reading cached categories: $e');
      return [];
    }
  }

  /// Instant cached read of Brands
  static Future<List<BrandModel>> getCachedBrands() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyBrands);
      if (raw == null || raw.isEmpty) return [];
      final List decoded = jsonDecode(raw);
      return decoded.map((j) => BrandModel.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error reading cached brands: $e');
      return [];
    }
  }

  /// Silently background syncs ONLY changed customer-facing data using /catalog/versions/.
  /// Returns `true` if any data changed and was updated in local storage.
  static Future<bool> syncCustomerDataSilently(ApiService api) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remoteVersions = await api.getCatalogVersions();
      Map<String, dynamic> localVersions = {};
      final rawLocalV = prefs.getString(_keyVersions);
      if (rawLocalV != null && rawLocalV.isNotEmpty) {
        try {
          localVersions = Map<String, dynamic>.from(jsonDecode(rawLocalV));
        } catch (_) {}
      }

      // Check which brands had variant/price edits
      if (remoteVersions['brand_variants'] is Map) {
        final remoteBV = Map<String, dynamic>.from(remoteVersions['brand_variants']);
        final localBV = localVersions['brand_variants'] is Map
            ? Map<String, dynamic>.from(localVersions['brand_variants'])
            : <String, dynamic>{};
        remoteBV.forEach((bKey, rVer) {
          if (localBV[bKey] != rVer) {
            final bid = int.tryParse(bKey);
            if (bid != null) _staleBrandIds.add(bid);
          }
        });
      }

      final bool needCms = (prefs.getString(_keyCms) ?? '').isEmpty ||
          remoteVersions.isEmpty ||
          remoteVersions['banners'] != localVersions['banners'];
      final bool needCats = (prefs.getString(_keyCategories) ?? '').isEmpty;
      final bool needBrands = (prefs.getString(_keyBrands) ?? '').isEmpty ||
          remoteVersions.isEmpty ||
          remoteVersions['brands'] != localVersions['brands'];
      final bool needBundle = (prefs.getString(_keySyncBundle) ?? '').isEmpty ||
          remoteVersions['triage'] != localVersions['triage'] ||
          remoteVersions['deductions'] != localVersions['deductions'] ||
          _staleBrandIds.isNotEmpty;

      final List<CMSSectionModel> freshCms = needCms ? await api.getCMSSections(forceRefresh: true) : [];
      final List<DeviceCategoryModel> freshCats = needCats ? await api.getDeviceCategories(forceRefresh: true) : [];
      final List<BrandModel> freshBrands = needBrands ? await api.getBrands(forceRefresh: true) : [];
      final String? rawBundle = needBundle ? await api.fetchSyncBundleRaw() : null;

      if (remoteVersions.isNotEmpty) {
        await prefs.setString(_keyVersions, jsonEncode(remoteVersions));
      }

      bool hasChanges = false;

      // 1. Check CMS sections
      if (freshCms.isNotEmpty) {
        final serializedCms = jsonEncode(freshCms.map((s) => {
          'id': s.id,
          'section_type': s.sectionType,
          'title': s.title,
          'subtitle': s.subtitle,
          'data_json': s.dataJson,
          'display_order': s.displayOrder,
          'is_active': s.isActive,
        }).toList());

        final oldCms = prefs.getString(_keyCms);
        if (oldCms != serializedCms) {
          await prefs.setString(_keyCms, serializedCms);
          hasChanges = true;
        }
      }

      // 2. Check Device Categories
      if (freshCats.isNotEmpty) {
        final serializedCats = jsonEncode(freshCats.map((c) => {
          'id': c.id,
          'name': c.name,
          'slug': c.slug,
          'subtitle': c.subtitle,
          'icon_name': c.iconName,
          'image_base64': c.imageBase64,
          'display_order': c.displayOrder,
          'is_active': c.isActive,
        }).toList());

        final oldCats = prefs.getString(_keyCategories);
        if (oldCats != serializedCats) {
          await prefs.setString(_keyCategories, serializedCats);
          hasChanges = true;
        }
      }

      // 3. Check Brands
      if (freshBrands.isNotEmpty) {
        final serializedBrands = jsonEncode(freshBrands.map((b) => {
          'id': b.id,
          'name': b.name,
          'slug': b.slug,
          'logo_base64': b.logoBase64,
          'category': b.categoryId,
        }).toList());

        final oldBrands = prefs.getString(_keyBrands);
        if (oldBrands != serializedBrands) {
          await prefs.setString(_keyBrands, serializedBrands);
          hasChanges = true;
        }
      }

      // 4. Check Series, Models, Variants & Questionnaires Bundle
      if (rawBundle != null && rawBundle.isNotEmpty) {
        final oldBundle = prefs.getString(_keySyncBundle);
        if (oldBundle != rawBundle) {
          await prefs.setString(_keySyncBundle, rawBundle);
          hasChanges = true;
        }
      }

      await prefs.setString(_keyLastSync, DateTime.now().toIso8601String());
      return hasChanges;
    } catch (e) {
      debugPrint('Silent sync error (offline or network blip): $e');
      return false;
    }
  }
}
