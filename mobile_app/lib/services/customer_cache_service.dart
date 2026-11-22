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
  static const String _keyLastSync = 'customer_cache_last_sync_timestamp';

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

  /// Silently background syncs fresh customer-facing data from the backend.
  /// Returns `true` if any data changed and was updated in local storage.
  static Future<bool> syncCustomerDataSilently(ApiService api) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Parallel fetch from API
      final results = await Future.wait([
        api.getCMSSections(),
        api.getDeviceCategories(),
        api.getBrands(),
      ]);

      final freshCms = results[0] as List<CMSSectionModel>;
      final freshCats = results[1] as List<DeviceCategoryModel>;
      final freshBrands = results[2] as List<BrandModel>;

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

      await prefs.setString(_keyLastSync, DateTime.now().toIso8601String());
      return hasChanges;
    } catch (e) {
      debugPrint('Silent sync error (offline or network blip): $e');
      return false;
    }
  }
}
