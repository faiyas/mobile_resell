import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/models.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;
  UserModel? _currentUser;

  // In-Memory Fast Cache for smooth screen transitions
  List<CMSSectionModel>? _cachedCMSSections;
  List<DeviceCategoryModel>? _cachedCategories;
  final Map<String, List<BrandModel>> _cachedBrands = {};
  List<SeriesModel>? _cachedSeries;
  List<PhoneModelItem>? _cachedModels;
  List<ConditionCategoryModel>? _cachedConditions;

  void hydrateOfflineBundle({
    List<SeriesModel>? series,
    List<PhoneModelItem>? models,
    List<ConditionCategoryModel>? conditions,
  }) {
    if (series != null && series.isNotEmpty) _cachedSeries = series;
    if (models != null && models.isNotEmpty) _cachedModels = models;
    if (conditions != null && conditions.isNotEmpty) _cachedConditions = conditions;
  }

  Future<String?> fetchSyncBundleRaw() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/sync-bundle/');
    try {
      final res = await http.get(url, headers: _headers);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          if (decoded['series'] is List) {
            _cachedSeries = (decoded['series'] as List)
                .whereType<Map>()
                .map((item) => SeriesModel.fromJson(Map<String, dynamic>.from(item)))
                .toList();
          }
          if (decoded['models'] is List) {
            _cachedModels = (decoded['models'] as List)
                .whereType<Map>()
                .map((item) => PhoneModelItem.fromJson(Map<String, dynamic>.from(item)))
                .toList();
          }
          if (decoded['conditions'] is List) {
            _cachedConditions = (decoded['conditions'] as List)
                .whereType<Map>()
                .map((item) => ConditionCategoryModel.fromJson(Map<String, dynamic>.from(item)))
                .toList();
          }
        }
        return res.body;
      }
    } catch (e) {
      debugPrint('Error fetching sync bundle: $e');
    }
    return null;
  }

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final userJson = prefs.getString('current_user');
    if (userJson != null) {
      try {
        _currentUser = UserModel.fromJson(jsonDecode(userJson));
      } catch (_) {}
    }
  }

  Future<void> saveAuth(String token, UserModel user) async {
    _token = token;
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('current_user', jsonEncode(user.toJson()));
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    _cachedCMSSections = null;
    _cachedCategories = null;
    _cachedBrands.clear();
    _cachedConditions = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('current_user');
  }

  /// Permanently deletes the user account and erases personal data (App Store & Google Play compliance)
  Future<void> deleteAccount() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/delete-account/');
    try {
      await http.post(url, headers: _headers);
    } catch (_) {}
    await logout();
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // ================= 1. AUTHENTICATION & PROFILE =================
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/login/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final user = UserModel.fromJson(data['user']);
      await saveAuth(data['token'], user);
      return {'success': true, 'user': user};
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Invalid credentials');
    }
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/register/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (res.statusCode == 201) {
      final data = jsonDecode(res.body);
      final user = UserModel.fromJson(data['user']);
      await saveAuth(data['token'], user);
      return {'success': true, 'user': user};
    } else {
      try {
        final err = jsonDecode(res.body);
        if (err is Map) {
          if (err['detail'] != null) throw Exception(err['detail']);
          if (err['message'] != null) throw Exception(err['message']);
          final firstVal = err.values.isNotEmpty ? err.values.first : null;
          if (firstVal is List && firstVal.isNotEmpty) throw Exception(firstVal.first.toString());
          if (firstVal != null) throw Exception(firstVal.toString());
        }
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) rethrow;
      }
      throw Exception('Registration failed. Please check your details.');
    }
  }

  Future<Map<String, dynamic>> createAgent(Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/agents/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (res.statusCode == 201) {
      final data = jsonDecode(res.body);
      return data;
    } else {
      try {
        final err = jsonDecode(res.body);
        if (err is Map) {
          if (err['detail'] != null) throw Exception(err['detail']);
          if (err['message'] != null) throw Exception(err['message']);
          final firstVal = err.values.isNotEmpty ? err.values.first : null;
          if (firstVal is List && firstVal.isNotEmpty) throw Exception(firstVal.first.toString());
          if (firstVal != null) throw Exception(firstVal.toString());
        }
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) rethrow;
      }
      throw Exception('Failed to create agent account.');
    }
  }

  Future<UserModel> getProfile() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/me/');
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final user = UserModel.fromJson(data['user']);
      _currentUser = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', jsonEncode(user.toJson()));
      return user;
    } else {
      throw Exception('Failed to load profile');
    }
  }

  Future<UserModel> updateProfile(Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/me/');
    final res = await http.put(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final user = UserModel.fromJson(data['user']);
      _currentUser = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', jsonEncode(user.toJson()));
      return user;
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Failed to update profile');
    }
  }

  Future<void> changePassword({required String oldPassword, required String newPassword}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/change-password/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        'old_password': oldPassword,
        'new_password': newPassword,
      }),
    );
    if (res.statusCode != 200) {
      try {
        final err = jsonDecode(res.body);
        throw Exception(err['detail'] ?? 'Failed to change password');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('Failed to change password: ${res.statusCode}');
      }
    }
  }

  // ================= 2. DYNAMIC CMS SECTIONS =================
  Future<List<CMSSectionModel>> getCMSSections({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCMSSections != null && _cachedCMSSections!.isNotEmpty) {
      return _cachedCMSSections!;
    }
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/cms/sections/');
    try {
      final res = await http.get(url, headers: _headers);
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _cachedCMSSections = list.map((item) => CMSSectionModel.fromJson(Map<String, dynamic>.from(item))).toList();
        return _cachedCMSSections!;
      }
    } catch (_) {}
    return _cachedCMSSections ?? [];
  }

  // ================= 3. CATALOG & DEVICES =================
  Future<List<DeviceCategoryModel>> getDeviceCategories({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCategories != null && _cachedCategories!.isNotEmpty) {
      return _cachedCategories!;
    }
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/categories/');
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      _cachedCategories = list.map((item) => DeviceCategoryModel.fromJson(Map<String, dynamic>.from(item))).toList();
      return _cachedCategories!;
    }
    return _cachedCategories ?? [];
  }

  Future<List<BrandModel>> getBrands({int? categoryId, bool forceRefresh = false}) async {
    final cacheKey = categoryId?.toString() ?? 'all';
    if (!forceRefresh && _cachedBrands.containsKey(cacheKey) && _cachedBrands[cacheKey]!.isNotEmpty) {
      return _cachedBrands[cacheKey]!;
    }
    var endpoint = '${ApiConfig.baseUrl}/catalog/brands/?include_models=false';
    if (categoryId != null) {
      endpoint += '&category=$categoryId';
    }
    final url = Uri.parse(endpoint);
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      final brands = list.map((item) => BrandModel.fromJson(Map<String, dynamic>.from(item))).toList();
      _cachedBrands[cacheKey] = brands;
      return brands;
    }
    return _cachedBrands[cacheKey] ?? [];
  }

  Future<List<SeriesModel>> getSeries({int? brandId, bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedSeries != null && _cachedSeries!.isNotEmpty) {
      if (brandId == null) return _cachedSeries!;
      return _cachedSeries!.where((s) => s.brandId == brandId).toList();
    }
    var endpoint = '${ApiConfig.baseUrl}/catalog/series/';
    if (brandId != null) {
      endpoint += '?brand=$brandId';
    }
    final url = Uri.parse(endpoint);
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      final items = list.map((item) => SeriesModel.fromJson(Map<String, dynamic>.from(item))).toList();
      if (brandId == null) _cachedSeries = items;
      return items;
    }
    return [];
  }

  Future<List<PhoneModelItem>> getModels({int? brandId, int? seriesId, bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedModels != null && _cachedModels!.isNotEmpty) {
      return _cachedModels!.where((m) {
        if (brandId != null && m.brandId != brandId) return false;
        if (seriesId != null && m.seriesId != seriesId) return false;
        return true;
      }).toList();
    }
    var endpoint = '${ApiConfig.baseUrl}/catalog/models/?';
    if (brandId != null) endpoint += 'brand=$brandId&';
    if (seriesId != null) endpoint += 'series=$seriesId&';
    final url = Uri.parse(endpoint);
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      final items = list.map((item) => PhoneModelItem.fromJson(Map<String, dynamic>.from(item))).toList();
      if (brandId == null && seriesId == null) _cachedModels = items;
      return items;
    }
    return [];
  }

  Future<List<StorageVariantModel>> getVariants(int modelId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedModels != null && _cachedModels!.isNotEmpty) {
      for (final m in _cachedModels!) {
        if (m.id == modelId && m.variants.isNotEmpty) {
          return m.variants;
        }
      }
    }
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/variants/?model=$modelId');
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((item) => StorageVariantModel.fromJson(Map<String, dynamic>.from(item))).toList();
    }
    return [];
  }

  // ================= 4. DYNAMIC QUESTIONNAIRE =================
  Future<List<ConditionCategoryModel>> getConditionCategories({int? brandId, bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedConditions != null && _cachedConditions!.isNotEmpty) {
      if (brandId == null) return _cachedConditions!;
      return _cachedConditions!.where((c) => c.brand == null || c.brand == brandId).toList();
    }
    final query = brandId != null ? '?brand=$brandId' : '';
    final url = Uri.parse('${ApiConfig.baseUrl}/valuation/conditions/$query');
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      final dynamic raw = jsonDecode(res.body);
      if (raw is List) {
        final items = <ConditionCategoryModel>[];
        for (final item in raw) {
          try {
            if (item is Map) {
              items.add(ConditionCategoryModel.fromJson(Map<String, dynamic>.from(item)));
            }
          } catch (e) {
            debugPrint('Error parsing condition category: $e');
          }
        }
        if (brandId == null) {
          _cachedConditions = items;
        }
        return items;
      }
    }
    return (brandId == null ? _cachedConditions : null) ?? [];
  }

  Future<Map<String, dynamic>> copyQuestionsFromBrand({
    int? sourceBrandId,
    required int targetBrandId,
    bool markMandatory = true,
    bool overwrite = true,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/valuation/conditions/copy-from-brand/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        'source_brand_id': sourceBrandId,
        'target_brand_id': targetBrandId,
        'mark_mandatory': markMandatory,
        'overwrite': overwrite,
      }),
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      try {
        final err = jsonDecode(res.body);
        throw err['detail'] ?? 'Failed to copy questions from brand';
      } catch (e) {
        if (e is String) rethrow;
        throw 'Server response error (${res.statusCode})';
      }
    }
  }

  Future<Map<String, dynamic>> calculateEstimate(int variantId, List<String> selectedOptionCodes) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/valuation/calculate-estimate/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        'variant_id': variantId,
        'selected_option_codes': selectedOptionCodes,
      }),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Failed to calculate estimate');
    }
  }

  // ================= 5. SALES ORDERS & BOOKINGS =================
  Future<SaleOrderModel> createSale(Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/sales/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (res.statusCode == 201) {
      return SaleOrderModel.fromJson(Map<String, dynamic>.from(jsonDecode(res.body)));
    } else {
      try {
        final err = jsonDecode(res.body);
        if (err is Map) {
          if (err['detail'] != null) throw Exception(err['detail']);
          if (err['message'] != null) throw Exception(err['message']);
          final errorMessages = <String>[];
          err.forEach((key, val) {
            String label = key.replaceAll('_', ' ');
            label = label.isEmpty ? '' : label[0].toUpperCase() + label.substring(1);
            if (val is List && val.isNotEmpty) {
              errorMessages.add('$label: ${val.first}');
            } else if (val != null) {
              errorMessages.add('$label: $val');
            }
          });
          if (errorMessages.isNotEmpty) {
            throw Exception(errorMessages.join('\n'));
          }
        }
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) rethrow;
      }
      throw Exception('Failed to book pickup. Please verify your address and booking details.');
    }
  }

  Future<SaleOrderModel> getSaleDetail(String saleCode) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/sales/$saleCode/');
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      return SaleOrderModel.fromJson(Map<String, dynamic>.from(jsonDecode(res.body)));
    } else {
      throw Exception('Order not found');
    }
  }

  Future<List<SaleOrderModel>> getSales() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/sales/');
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      final dynamic raw = jsonDecode(res.body);
      if (raw is List) {
        final items = <SaleOrderModel>[];
        for (final item in raw) {
          try {
            if (item is Map) {
              items.add(SaleOrderModel.fromJson(Map<String, dynamic>.from(item)));
            }
          } catch (e) {
            debugPrint('Error parsing sale order: $e');
          }
        }
        return items;
      }
    }
    return [];
  }

  // ================= 6. FIELD AGENT INSPECTION =================
  Future<Map<String, dynamic>> recordInspection(Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/inspections/record/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (res.statusCode == 201) {
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Inspection failed');
    }
  }

  // ================= 7. ADMIN ASSIGNMENT & PAYOUTS =================
  Future<List<AgentUserModel>> getAgents() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/agents/');
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      final dynamic raw = jsonDecode(res.body);
      if (raw is List) {
        final items = <AgentUserModel>[];
        for (final item in raw) {
          try {
            if (item is Map) {
              items.add(AgentUserModel.fromJson(Map<String, dynamic>.from(item)));
            }
          } catch (e) {
            debugPrint('Error parsing agent: $e');
          }
        }
        return items;
      }
    }
    return [];
  }

  Future<PaymentSummaryModel> getPaymentsSummary() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/payments/');
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      final dynamic raw = jsonDecode(res.body);
      if (raw is Map) {
        return PaymentSummaryModel.fromJson(Map<String, dynamic>.from(raw));
      }
    }
    return PaymentSummaryModel(totalCount: 0, totalDisbursed: 0.0, payments: []);
  }

  Future<Map<String, dynamic>> assignPickup(dynamic saleId, Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/sales/$saleId/assign-pickup/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Failed to assign pickup');
    }
  }

  Future<Map<String, dynamic>> shiftPickupToNextDay(dynamic saleId, [Map<String, dynamic>? payload]) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/sales/$saleId/shift-next-day/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(payload ?? {}),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Failed to shift pickup');
    }
  }

  Future<Map<String, dynamic>?> lookupPincode(String pincode) async {
    final clean = pincode.trim().replaceAll(RegExp(r'\D'), '');
    if (clean.length != 6) return null;
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/sales/pincode-lookup/?pincode=$clean');
      final res = await http.get(url, headers: _headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> markDeviceCollected(dynamic saleId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/sales/$saleId/mark-collected/');
    final res = await http.post(url, headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Failed to mark device as collected');
    }
  }

  Future<Map<String, dynamic>> acceptFinalOffer(dynamic saleId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/sales/$saleId/accept-offer/');
    final res = await http.post(url, headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Failed to accept offer');
    }
  }

  Future<Map<String, dynamic>> rejectFinalOffer(dynamic saleId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/sales/$saleId/reject-offer/');
    final res = await http.post(url, headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Failed to reject offer');
    }
  }

  Future<Map<String, dynamic>> cancelOrder(dynamic saleId, {String? reason}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/sales/$saleId/cancel/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({'reason': reason ?? 'Cancelled by customer'}),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Failed to cancel order');
    }
  }

  Future<Map<String, dynamic>> recordPayout(Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/payments/record-payout/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (res.statusCode == 201) {
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Failed to record payout');
    }
  }

  Future<Map<String, dynamic>> recordPayment(dynamic saleId, Map<String, dynamic> payload) {
    final Map<String, dynamic> p = Map<String, dynamic>.from(payload);
    p['sale_id'] = saleId.toString();
    return recordPayout(p);
  }

  Future<Map<String, dynamic>> updateConditionOption(dynamic optionId, Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/valuation/options/$optionId/');
    final res = await http.patch(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (res.statusCode == 200) {
      _cachedConditions = null;
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? err.toString());
    }
  }

  Future<Map<String, dynamic>> createConditionOption(Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/valuation/options/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (res.statusCode == 201) {
      _cachedConditions = null;
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? err.toString());
    }
  }

  Future<Map<String, dynamic>> createConditionCategory(Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/valuation/conditions/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (res.statusCode == 201) {
      _cachedConditions = null;
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? err.toString());
    }
  }

  Future<Map<String, dynamic>> updateConditionCategory(dynamic categoryId, Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/valuation/conditions/$categoryId/');
    final res = await http.put(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (res.statusCode == 200) {
      _cachedConditions = null;
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? err.toString());
    }
  }

  Future<Map<String, dynamic>> createSeries(Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/series/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (res.statusCode == 201) {
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? err.toString());
    }
  }

  Future<Map<String, dynamic>> updateSeries(dynamic seriesId, Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/series/$seriesId/');
    final res = await http.put(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? err.toString());
    }
  }

  Future<void> deleteSeries(dynamic seriesId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/series/$seriesId/');
    final res = await http.delete(url, headers: _headers);
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception('Failed to delete series');
    }
  }

  Future<Map<String, dynamic>> updateBrand(dynamic brandId, Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/brands/$brandId/');
    final res = await http.put(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (res.statusCode == 200) {
      _cachedBrands.clear();
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Failed to update brand logo');
    }
  }

  Future<Map<String, dynamic>> updateDeviceCategory(dynamic categoryId, Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/categories/$categoryId/');
    final res = await http.put(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (res.statusCode == 200) {
      _cachedCategories = null;
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Failed to update category image');
    }
  }

  // ================= CATALOG CRUD FOR ADMIN =================
  Future<DeviceCategoryModel> createDeviceCategory(Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/categories/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (res.statusCode == 201) {
      _cachedCategories = null;
      return DeviceCategoryModel.fromJson(Map<String, dynamic>.from(jsonDecode(res.body)));
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? err.toString());
    }
  }

  Future<void> deleteDeviceCategory(dynamic categoryId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/categories/$categoryId/');
    final res = await http.delete(url, headers: _headers);
    if (res.statusCode == 204 || res.statusCode == 200) {
      _cachedCategories = null;
    } else {
      throw Exception('Failed to delete category');
    }
  }

  Future<BrandModel> createBrand(Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/brands/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (res.statusCode == 201) {
      _cachedBrands.clear();
      return BrandModel.fromJson(Map<String, dynamic>.from(jsonDecode(res.body)));
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? err.toString());
    }
  }

  Future<void> deleteBrand(dynamic brandId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/brands/$brandId/');
    final res = await http.delete(url, headers: _headers);
    if (res.statusCode == 204 || res.statusCode == 200) {
      _cachedBrands.clear();
    } else {
      throw Exception('Failed to delete brand');
    }
  }

  Future<PhoneModelItem> createPhoneModel(Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/models/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (res.statusCode == 201) {
      return PhoneModelItem.fromJson(Map<String, dynamic>.from(jsonDecode(res.body)));
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? err.toString());
    }
  }

  Future<PhoneModelItem> updatePhoneModel(dynamic modelId, Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/models/$modelId/');
    final res = await http.put(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (res.statusCode == 200) {
      return PhoneModelItem.fromJson(Map<String, dynamic>.from(jsonDecode(res.body)));
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? err.toString());
    }
  }

  Future<void> deletePhoneModel(dynamic modelId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/models/$modelId/');
    final res = await http.delete(url, headers: _headers);
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception('Failed to delete model');
    }
  }

  Future<StorageVariantModel> createVariant(Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/variants/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (res.statusCode == 201) {
      return StorageVariantModel.fromJson(Map<String, dynamic>.from(jsonDecode(res.body)));
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? err.toString());
    }
  }

  Future<void> deleteVariant(dynamic variantId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/variants/$variantId/');
    final res = await http.delete(url, headers: _headers);
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception('Failed to delete variant');
    }
  }

  Future<void> deleteConditionCategory(dynamic categoryId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/valuation/conditions/$categoryId/');
    final res = await http.delete(url, headers: _headers);
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception('Failed to delete condition category');
    }
    _cachedConditions = null;
  }

  Future<void> deleteConditionOption(dynamic optionId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/valuation/options/$optionId/');
    final res = await http.delete(url, headers: _headers);
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception('Failed to delete condition option');
    }
    _cachedConditions = null;
  }

  /// Lightweight keep-alive health check ping
  Future<void> pingHealth() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/health/');
      await http.get(url, headers: _headers).timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  void clearCatalogCache() {
    _cachedCMSSections = null;
    _cachedCategories = null;
    _cachedBrands.clear();
    _cachedConditions = null;
  }
}
