import 'dart:convert';
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('current_user');
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

  // ================= 1. AUTHENTICATION =================
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/accounts/login/');
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
    final url = Uri.parse('${ApiConfig.baseUrl}/accounts/register/');
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
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Registration failed');
    }
  }

  // ================= 2. DYNAMIC CMS SECTIONS =================
  Future<List<CMSSectionModel>> getCMSSections() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/cms/sections/');
    try {
      final res = await http.get(url, headers: _headers);
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((item) => CMSSectionModel.fromJson(item)).toList();
      }
    } catch (e) {
      // Fallback local defaults if backend is spinning up
    }
    return [];
  }

  // ================= 3. CATALOG & DEVICES =================
  Future<List<DeviceCategoryModel>> getDeviceCategories() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/categories/');
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((item) => DeviceCategoryModel.fromJson(item)).toList();
    }
    return [];
  }

  Future<List<BrandModel>> getBrands({int? categoryId}) async {
    var endpoint = '${ApiConfig.baseUrl}/catalog/brands/?include_models=false';
    if (categoryId != null) {
      endpoint += '&category=$categoryId';
    }
    final url = Uri.parse(endpoint);
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((item) => BrandModel.fromJson(item)).toList();
    }
    return [];
  }

  Future<List<SeriesModel>> getSeries({int? brandId}) async {
    var endpoint = '${ApiConfig.baseUrl}/catalog/series/';
    if (brandId != null) {
      endpoint += '?brand=$brandId';
    }
    final url = Uri.parse(endpoint);
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((item) => SeriesModel.fromJson(item)).toList();
    }
    return [];
  }

  Future<List<PhoneModelItem>> getModels({int? brandId, int? seriesId}) async {
    var endpoint = '${ApiConfig.baseUrl}/catalog/models/?';
    if (brandId != null) endpoint += 'brand=$brandId&';
    if (seriesId != null) endpoint += 'series=$seriesId&';
    final url = Uri.parse(endpoint);
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((item) => PhoneModelItem.fromJson(item)).toList();
    }
    return [];
  }

  Future<List<StorageVariantModel>> getVariants(int modelId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/catalog/variants/?model=$modelId');
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((item) => StorageVariantModel.fromJson(item)).toList();
    }
    return [];
  }

  // ================= 4. DYNAMIC 11-STEP QUESTIONNAIRE =================
  Future<List<ConditionCategoryModel>> getConditionCategories() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/valuation/conditions/');
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((item) => ConditionCategoryModel.fromJson(item)).toList();
    }
    return [];
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
      return SaleOrderModel.fromJson(jsonDecode(res.body));
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Failed to book pickup');
    }
  }

  Future<SaleOrderModel> getSaleDetail(String saleCode) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/sales/$saleCode/');
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      return SaleOrderModel.fromJson(jsonDecode(res.body));
    } else {
      throw Exception('Order not found');
    }
  }

  Future<List<SaleOrderModel>> getSales() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/sales/');
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((item) => SaleOrderModel.fromJson(item)).toList();
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

  // ================= 7. ADMIN ASSIGNMENT =================
  Future<Map<String, dynamic>> assignPickup(int saleId, Map<String, dynamic> payload) async {
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
}
