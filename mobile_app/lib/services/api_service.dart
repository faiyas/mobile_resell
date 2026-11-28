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

  static final ValueNotifier<String?> serverUnavailableNotifier = ValueNotifier<String?>(null);

  /// User-friendly error message transformer
  static String formatErrorMessage(dynamic error) {
    final str = error.toString();
    if (str.contains('FormatException') || 
        str.contains('Unexpected character') ||
        str.contains('sandbox service') ||
        str.contains('SocketException') ||
        str.contains('ClientException') ||
        str.contains('Connection refused') ||
        str.contains('502') ||
        str.contains('503')) {
      return 'Unable to reach the server. Please check your connection or contact the Admin.';
    }
    return str.replaceFirst(RegExp(r'^(Exception:\s*|Error:\s*)'), '');
  }

  /// Safe JSON decode that catches HTML/plain text server disconnect errors cleanly
  static dynamic safeDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      throw Exception('Unable to reach the server. Please check your connection or contact the Admin.');
    }
  }

  String? _token;
  UserModel? _currentUser;

  // In-Memory Fast Cache for smooth screen transitions
  List<CMSSectionModel>? _cachedCMSSections;
  List<DeviceCategoryModel>? _cachedCategories;
  final Map<String, List<BrandModel>> _cachedBrands = {};
  List<SeriesModel>? _cachedSeries;
  List<PhoneModelItem>? _cachedModels;
  List<ConditionCategoryModel>? _cachedConditions;
  Map<String, dynamic>? _cachedBusinessSettings;

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
    late http.Response res;
    try {
      res = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({'email': email.trim(), 'password': password}),
      ).timeout(const Duration(seconds: 12));
    } catch (e) {
      serverUnavailableNotifier.value = 'auth_${DateTime.now().millisecondsSinceEpoch}';
      return {'success': false, 'message': 'Server temporarily unavailable. Please contact admin.'};
    }

    if (res.statusCode >= 502 && res.statusCode <= 504) {
      serverUnavailableNotifier.value = 'auth_${DateTime.now().millisecondsSinceEpoch}';
      return {'success': false, 'message': 'Server temporarily unavailable. Please contact admin.'};
    }

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final user = UserModel.fromJson(data['user']);
      await saveAuth(data['token'], user);
      return {'success': true, 'user': user};
    } else {
      String msg = 'Invalid credentials';
      try {
        final err = jsonDecode(res.body);
        if (err is Map) {
          msg = err['detail'] ?? err['message'] ?? (err.values.isNotEmpty ? err.values.first.toString() : 'Invalid credentials');
        }
      } catch (_) {
        if (res.statusCode >= 500) {
          msg = 'Server error (${res.statusCode}). Please try again shortly.';
        } else {
          msg = 'Request failed (${res.statusCode})';
        }
      }
      throw Exception(msg);
    }
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/register/');
    late http.Response res;
    try {
      res = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 12));
    } catch (e) {
      serverUnavailableNotifier.value = 'auth_${DateTime.now().millisecondsSinceEpoch}';
      return {'success': false, 'message': 'Server temporarily unavailable. Please contact admin.'};
    }

    if (res.statusCode >= 502 && res.statusCode <= 504) {
      serverUnavailableNotifier.value = 'auth_${DateTime.now().millisecondsSinceEpoch}';
      return {'success': false, 'message': 'Server temporarily unavailable. Please contact admin.'};
    }

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

  // ================= 1B. ADMIN CUSTOMER PASSWORD OVERRIDE =================
  Future<Map<String, dynamic>> adminResetCustomerPassword({
    int? customerId,
    String? phone,
    required String newPassword,
  }) async {
    final url = Uri.parse(
      customerId != null
          ? '${ApiConfig.baseUrl}/auth/customers/$customerId/reset-password/'
          : '${ApiConfig.baseUrl}/auth/customers/reset-password/',
    );
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        'new_password': newPassword.trim(),
      }),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['detail'] ?? data['message'] ?? 'Failed to reset customer password');
    }
  }

  Future<List<Map<String, dynamic>>> getCustomers([String search = '', int? page, int? pageSize]) async {
    final queryParams = <String, String>{};
    if (search.trim().isNotEmpty) queryParams['search'] = search.trim();
    if (page != null) queryParams['page'] = '$page';
    if (pageSize != null) queryParams['page_size'] = '$pageSize';
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/customers/').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    try {
      final res = await http.get(url, headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return List<Map<String, dynamic>>.from(data);
        if (data is Map && data['results'] is List) return List<Map<String, dynamic>>.from(data['results']);
      }
    } catch (e) {
      debugPrint('Error fetching customers: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> adminResetAgentPassword({
    required int agentId,
    required String newPassword,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/agents/$agentId/');
    final res = await http.patch(
      url,
      headers: _headers,
      body: jsonEncode({'password': newPassword.trim()}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['detail'] ?? data['message'] ?? 'Failed to reset agent password');
    }
  }

  Future<Map<String, dynamic>> updateAgent(int id, Map<String, dynamic> data) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/agents/$id/');
    final res = await http.patch(
      url,
      headers: _headers,
      body: jsonEncode(data),
    );
    final json = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return json;
    } else {
      throw Exception(json['detail'] ?? json['message'] ?? 'Failed to update agent');
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

  Future<void> deleteAgent(int agentId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/agents/$agentId/');
    final res = await http.delete(url, headers: _headers);
    if (res.statusCode != 200 && res.statusCode != 204) {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Failed to delete agent');
    }
  }

  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> data) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/customers/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(data),
    );
    final json = jsonDecode(res.body);
    if (res.statusCode == 200 || res.statusCode == 201) {
      return json is Map<String, dynamic> ? json : {'data': json};
    } else {
      final msg = json is Map ? (json['detail'] ?? json['message'] ?? json.values.first) : 'Failed to create customer';
      throw Exception(msg.toString());
    }
  }

  Future<Map<String, dynamic>> updateCustomer(int customerId, Map<String, dynamic> data) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/customers/$customerId/');
    final res = await http.patch(
      url,
      headers: _headers,
      body: jsonEncode(data),
    );
    final json = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return json;
    } else {
      throw Exception(json['detail'] ?? json['message'] ?? 'Failed to update customer');
    }
  }

  Future<void> deleteCustomer(int customerId, {bool toggleOnly = false}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/customers/$customerId/${toggleOnly ? '?action=toggle' : ''}');
    final res = await http.delete(url, headers: _headers);
    if (res.statusCode != 200 && res.statusCode != 204) {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Failed to delete customer');
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

  Future<Map<String, dynamic>> getSystemSettings() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/settings/');
    try {
      final res = await http.get(url, headers: _headers);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return {};
  }

  Future<Map<String, dynamic>> updateSystemSettings(Map<String, dynamic> data) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/settings/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200 || res.statusCode == 201) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    final err = jsonDecode(res.body);
    throw Exception(err['detail'] ?? 'Failed to update settings');
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

  Future<List<PhoneModelItem>> getModels({int? brandId, int? seriesId, bool forceRefresh = false, int? page, int? pageSize, String? search, bool all = false}) async {
    if (!forceRefresh && _cachedModels != null && _cachedModels!.isNotEmpty && page == null && search == null && !all) {
      return _cachedModels!.where((m) {
        if (brandId != null && m.brandId != brandId) return false;
        if (seriesId != null && m.seriesId != seriesId) return false;
        return true;
      }).toList();
    }
    final queryParams = <String, String>{};
    if (brandId != null) queryParams['brand'] = '$brandId';
    if (seriesId != null) queryParams['series'] = '$seriesId';
    if (page != null) queryParams['page'] = '$page';
    if (pageSize != null) queryParams['page_size'] = '$pageSize';
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (all) queryParams['all'] = 'true';

    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/models/').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      final dynamic decoded = jsonDecode(res.body);
      final List list = decoded is List ? decoded : (decoded is Map && decoded['results'] is List ? decoded['results'] : []);
      final items = list.map((item) => PhoneModelItem.fromJson(Map<String, dynamic>.from(item))).toList();
      if (brandId == null && seriesId == null && page == null && search == null) _cachedModels = items;
      return items;
    }
    return [];
  }

  Future<Map<String, dynamic>> getModelsPaginated({
    int? brandId,
    int? seriesId,
    int page = 1,
    int pageSize = 10,
    String? search,
  }) async {
    final queryParams = <String, String>{};
    if (brandId != null) queryParams['brand'] = '$brandId';
    if (seriesId != null) queryParams['series'] = '$seriesId';
    queryParams['page'] = '$page';
    queryParams['page_size'] = '$pageSize';
    if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();

    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/models/').replace(
      queryParameters: queryParams,
    );
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      final dynamic decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic> && decoded.containsKey('results')) {
        final List list = decoded['results'] as List;
        final items = list.map((item) => PhoneModelItem.fromJson(Map<String, dynamic>.from(item))).toList();
        final totalCount = int.tryParse(decoded['count']?.toString() ?? '') ?? items.length;
        final totalPages = int.tryParse(decoded['total_pages']?.toString() ?? '') ?? ((totalCount / pageSize).ceil().clamp(1, 9999));
        final currentPage = int.tryParse(decoded['current_page']?.toString() ?? '') ?? page;
        return {
          'items': items,
          'total_count': totalCount,
          'total_pages': totalPages,
          'current_page': currentPage,
          'has_next': decoded['next'] != null || currentPage < totalPages,
          'has_previous': decoded['previous'] != null || currentPage > 1,
        };
      } else if (decoded is List) {
        final items = decoded.map((item) => PhoneModelItem.fromJson(Map<String, dynamic>.from(item))).toList();
        return {
          'items': items,
          'total_count': items.length,
          'total_pages': 1,
          'current_page': 1,
          'has_next': false,
          'has_previous': false,
        };
      }
    }
    return {
      'items': <PhoneModelItem>[],
      'total_count': 0,
      'total_pages': 1,
      'current_page': 1,
      'has_next': false,
      'has_previous': false,
    };
  }

  Future<List<StorageVariantModel>> getVariants(int modelId, {bool forceRefresh = false, int? page, int? pageSize}) async {
    if (!forceRefresh && _cachedModels != null && _cachedModels!.isNotEmpty && page == null) {
      for (final m in _cachedModels!) {
        if (m.id == modelId && m.variants.isNotEmpty) {
          return m.variants;
        }
      }
    }
    final queryParams = <String, String>{'model': '$modelId'};
    if (page != null) queryParams['page'] = '$page';
    if (pageSize != null) queryParams['page_size'] = '$pageSize';
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/variants/').replace(
      queryParameters: queryParams,
    );
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      final dynamic decoded = jsonDecode(res.body);
      final List list = decoded is List ? decoded : (decoded is Map && decoded['results'] is List ? decoded['results'] : []);
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

  Future<Map<String, dynamic>> calculateEstimate(
    int variantId,
    List<String> selectedOptionCodes, {
    Map<String, String>? triageAnswers,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/valuation/calculate-estimate/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        'variant_id': variantId,
        'selected_option_codes': selectedOptionCodes,
        'triage_answers': triageAnswers ?? {},
      }),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Failed to calculate estimate');
    }
  }

  Future<List<EvaluationTriageQuestionModel>> getTriageQuestions() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/valuation/triage-questions/');
    try {
      final res = await http.get(url, headers: _headers);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          return decoded.map((j) => EvaluationTriageQuestionModel.fromJson(Map<String, dynamic>.from(j))).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching triage questions: $e');
    }
    return [];
  }

  // ================= 5. SALES ORDERS & BOOKINGS =================
  Future<SaleOrderModel> createSale(Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/sales/');
    late http.Response res;
    try {
      res = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      serverUnavailableNotifier.value = 'order_${DateTime.now().millisecondsSinceEpoch}';
      throw Exception('Server temporarily unavailable. Please try again or contact admin.');
    }

    if (res.statusCode >= 502 && res.statusCode <= 504) {
      serverUnavailableNotifier.value = 'order_${DateTime.now().millisecondsSinceEpoch}';
      throw Exception('Server temporarily unavailable. Please try again or contact admin.');
    }

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

  Future<SaleOrderModel> getSaleDetail(String saleCode, {String? phone}) async {
    final cleanPhone = phone ?? _currentUser?.phone;
    final query = (cleanPhone != null && cleanPhone.trim().isNotEmpty)
        ? '?phone=${Uri.encodeComponent(cleanPhone.trim())}'
        : '';
    final url = Uri.parse('${ApiConfig.baseUrl}/sales/$saleCode/$query');
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      return SaleOrderModel.fromJson(Map<String, dynamic>.from(jsonDecode(res.body)));
    } else {
      throw Exception('Order not found');
    }
  }

  Future<List<SaleOrderModel>> getSales({String? status, bool? pool, String? search, int? page, int? pageSize}) async {
    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (pool == true) queryParams['pool'] = 'true';
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (page != null) queryParams['page'] = '$page';
    if (pageSize != null) queryParams['page_size'] = '$pageSize';

    final uri = Uri.parse('${ApiConfig.baseUrl}/sales/').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 200) {
      final dynamic raw = jsonDecode(res.body);
      final List list = raw is List ? raw : (raw is Map && raw['results'] is List ? raw['results'] : []);
      final items = <SaleOrderModel>[];
      for (final item in list) {
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

  Future<Map<String, dynamic>> markDeviceCollected(dynamic saleId, {String? cashOtp}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/sales/$saleId/mark-collected/');
    final payload = <String, dynamic>{};
    if (cashOtp != null && cashOtp.trim().isNotEmpty) {
      payload['cash_otp'] = cashOtp.trim();
    }
    try {
      final res = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(payload),
      );
      final data = safeDecode(res.body);
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(data as Map);
      } else {
        throw Exception(data['detail'] ?? 'Failed to mark device as collected');
      }
    } catch (e) {
      throw Exception(formatErrorMessage(e));
    }
  }

  Future<Map<String, dynamic>> adminApproveFinalOffer(
    dynamic saleId,
    double approvedPrice, {
    String? reason,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/sales/$saleId/approve-final-offer/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        'approved_price': approvedPrice,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      }),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Failed to update final price');
    }
  }

  Future<Map<String, dynamic>> acceptFinalOffer(dynamic saleId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/sales/$saleId/accept-offer/');
    try {
      final res = await http.post(url, headers: _headers);
      final data = safeDecode(res.body);
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(data as Map);
      } else {
        throw Exception(data['detail'] ?? 'Failed to accept offer');
      }
    } catch (e) {
      throw Exception(formatErrorMessage(e));
    }
  }

  Future<Map<String, dynamic>> rejectFinalOffer(dynamic saleId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/sales/$saleId/reject-offer/');
    try {
      final res = await http.post(url, headers: _headers);
      final data = safeDecode(res.body);
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(data as Map);
      } else {
        throw Exception(data['detail'] ?? 'Failed to reject offer');
      }
    } catch (e) {
      throw Exception(formatErrorMessage(e));
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

  Future<Map<String, dynamic>> updateSaleStatus(dynamic saleId, String newStatus, {String? reason}) async {
    if (newStatus == 'CANCELLED') {
      return cancelOrder(saleId, reason: reason);
    } else if (newStatus == 'DEVICE_COLLECTED') {
      return markDeviceCollected(saleId);
    }
    final url = Uri.parse('${ApiConfig.baseUrl}/sales/$saleId/');
    try {
      final res = await http.patch(
        url,
        headers: _headers,
        body: jsonEncode({'status': newStatus}),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else {
        return {'status': newStatus};
      }
    } catch (_) {
      return {'status': newStatus};
    }
  }

  Future<Map<String, dynamic>> recordPayout(Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/payments/record-payout/');
    try {
      final res = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(payload),
      );

      final data = safeDecode(res.body);
      if (res.statusCode == 201) {
        return Map<String, dynamic>.from(data as Map);
      } else {
        throw Exception(data['detail'] ?? 'Failed to record payout');
      }
    } catch (e) {
      throw Exception(formatErrorMessage(e));
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
      _cachedModels = null;
      return StorageVariantModel.fromJson(Map<String, dynamic>.from(jsonDecode(res.body)));
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? err.toString());
    }
  }

  Future<StorageVariantModel> updateStorageVariant(int variantId, {required double basePrice, double? mintPrice, double? minPrice}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/variants/$variantId/');
    final payload = <String, dynamic>{
      'base_price': basePrice,
    };
    if (mintPrice != null) payload['mint_price'] = mintPrice;
    if (minPrice != null) payload['min_price'] = minPrice;

    final res = await http.patch(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (res.statusCode == 200) {
      _cachedModels = null;
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

  Future<EvaluationTriageQuestionModel> createTriageQuestion(Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/valuation/triage-questions/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );
    if (res.statusCode == 201) {
      return EvaluationTriageQuestionModel.fromJson(Map<String, dynamic>.from(jsonDecode(res.body)));
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Failed to create triage question');
    }
  }

  Future<EvaluationTriageQuestionModel> updateTriageQuestion(dynamic id, Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/valuation/triage-questions/$id/');
    final res = await http.patch(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200) {
      return EvaluationTriageQuestionModel.fromJson(Map<String, dynamic>.from(jsonDecode(res.body)));
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Failed to update triage question');
    }
  }

  Future<void> deleteTriageQuestion(dynamic id, {bool permanent = true}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/valuation/triage-questions/$id/?permanent=${permanent ? "true" : "false"}');
    final res = await http.delete(url, headers: _headers);
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Failed to delete triage question');
    }
  }

  Future<Map<String, dynamic>> saveCMSSection(Map<String, dynamic> payload) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/cms/sections/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body);
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Failed to save CMS banner');
    }
  }

  /// Lightweight keep-alive health check ping
  Future<bool> pingHealth() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/health/');
      final res = await http.get(url, headers: _headers).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>>? _inflightVersions;

  Future<Map<String, dynamic>> getCatalogVersions() {
    if (_inflightVersions != null) return _inflightVersions!;
    _inflightVersions = () async {
      try {
        final url = Uri.parse('${ApiConfig.baseUrl}/catalog/versions/');
        final res = await http.get(url, headers: _headers).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
      return <String, dynamic>{};
    }();
    return _inflightVersions!.whenComplete(() => _inflightVersions = null);
  }

  Future<Map<String, dynamic>> getBusinessSettings({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedBusinessSettings != null && _cachedBusinessSettings!.isNotEmpty) {
      return _cachedBusinessSettings!;
    }
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/catalog/business-settings/');
      final res = await http.get(url, headers: _headers).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          _cachedBusinessSettings = map;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('dolly_cached_business_settings', jsonEncode(map));
          } catch (_) {}
          return map;
        }
      }
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('dolly_cached_business_settings');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _cachedBusinessSettings = Map<String, dynamic>.from(decoded);
          return _cachedBusinessSettings!;
        }
      }
    } catch (_) {}
    return {};
  }

  Future<Map<String, dynamic>> updateBusinessSettings(Map<String, dynamic> data) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/business-settings/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200 || res.statusCode == 201) {
      final decoded = Map<String, dynamic>.from(jsonDecode(res.body));
      _cachedBusinessSettings = decoded;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('dolly_cached_business_settings', jsonEncode(decoded));
      } catch (_) {}
      return decoded;
    }
    final err = jsonDecode(res.body);
    throw Exception(err['detail'] ?? 'Failed to update business settings');
  }

  Future<void> ackNotifications(List<int> ids) async {
    if (ids.isEmpty) return;
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/sales/notifications/ack/');
      await http.post(
        url,
        headers: _headers,
        body: jsonEncode({'ids': ids}),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // ================= NOTIFICATIONS ENGINE =================
  Future<Map<String, dynamic>> getNotifications({String? phone}) async {
    try {
      final p = phone ?? _currentUser?.phone ?? '';
      final query = p.isNotEmpty ? '?phone=${Uri.encodeComponent(p)}' : '';
      final url = Uri.parse('${ApiConfig.baseUrl}/sales/notifications/$query');
      final res = await http.get(url, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint('Error getting notifications: $e');
    }
    return {'unread_count': 0, 'results': []};
  }

  Future<void> markNotificationRead(int id) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/sales/notifications/$id/read/');
      await http.post(url, headers: _headers).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<void> dismissNotification(int id) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/sales/notifications/$id/dismiss/');
      await http.post(url, headers: _headers).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<void> markAllNotificationsRead() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/sales/notifications/mark-all-read/');
      await http.post(url, headers: _headers).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<void> clearAllNotifications() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/sales/notifications/clear-all/');
      await http.post(url, headers: _headers).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<Map<String, dynamic>> broadcastNotification(Map<String, dynamic> data) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/sales/notifications/');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body);
    }
    final err = jsonDecode(res.body);
    throw Exception(err['detail'] ?? 'Failed to send broadcast alert');
  }

  void clearCatalogCache() {
    _cachedCMSSections = null;
    _cachedCategories = null;
    _cachedBrands.clear();
    _cachedConditions = null;
  }
}
