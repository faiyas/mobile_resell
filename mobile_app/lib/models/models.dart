class UserModel {
  final int id;
  final String email;
  final String username;
  final String fullName;
  final String phone;
  final String role; // 'CUSTOMER' | 'COLLECTION_AGENT' | 'ADMIN'

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.phone,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      fullName: json['full_name'] ?? json['username'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'CUSTOMER',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'username': username,
    'full_name': fullName,
    'phone': phone,
    'role': role,
  };
}

class DeviceCategoryModel {
  final int id;
  final String name;
  final String slug;
  final String iconName;
  final String? imageBase64;

  DeviceCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.iconName,
    this.imageBase64,
  });

  factory DeviceCategoryModel.fromJson(Map<String, dynamic> json) {
    return DeviceCategoryModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      iconName: json['icon_name'] ?? 'Smartphone',
      imageBase64: json['image_base64'],
    );
  }
}

class BrandModel {
  final int id;
  final String name;
  final String slug;
  final String? logoBase64;
  final int? categoryId;

  BrandModel({
    required this.id,
    required this.name,
    required this.slug,
    this.logoBase64,
    this.categoryId,
  });

  factory BrandModel.fromJson(Map<String, dynamic> json) {
    return BrandModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      logoBase64: json['logo_base64'],
      categoryId: json['category'],
    );
  }
}

class SeriesModel {
  final int id;
  final String name;
  final int brandId;
  final String? brandName;

  SeriesModel({
    required this.id,
    required this.name,
    required this.brandId,
    this.brandName,
  });

  factory SeriesModel.fromJson(Map<String, dynamic> json) {
    return SeriesModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      brandId: json['brand'] ?? 0,
      brandName: json['brand_name'],
    );
  }
}

class PhoneModelItem {
  final int id;
  final String name;
  final String slug;
  final int? brandId;
  final String? brandName;
  final int? seriesId;
  final String? seriesName;
  final String? imageBase64;
  final int releaseYear;
  final List<StorageVariantModel> variants;

  PhoneModelItem({
    required this.id,
    required this.name,
    required this.slug,
    this.brandId,
    this.brandName,
    this.seriesId,
    this.seriesName,
    this.imageBase64,
    required this.releaseYear,
    this.variants = const [],
  });

  factory PhoneModelItem.fromJson(Map<String, dynamic> json) {
    var vList = <StorageVariantModel>[];
    if (json['variants'] != null) {
      vList = (json['variants'] as List)
          .map((v) => StorageVariantModel.fromJson(v))
          .toList();
    }

    return PhoneModelItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      brandId: json['brand'] is int ? json['brand'] : json['brand']?['id'],
      brandName: json['brand_name'] ?? (json['brand'] is Map ? json['brand']['name'] : null),
      seriesId: json['series'] is int ? json['series'] : json['series']?['id'],
      seriesName: json['series_name'] ?? (json['series'] is Map ? json['series']['name'] : null),
      imageBase64: json['image_base64'],
      releaseYear: json['release_year'] ?? 2024,
      variants: vList,
    );
  }
}

class StorageVariantModel {
  final int id;
  final String storage;
  final String? ram;
  final double basePrice;
  final double minPrice;

  StorageVariantModel({
    required this.id,
    required this.storage,
    this.ram,
    required this.basePrice,
    required this.minPrice,
  });

  factory StorageVariantModel.fromJson(Map<String, dynamic> json) {
    return StorageVariantModel(
      id: json['id'] ?? 0,
      storage: json['storage'] ?? '',
      ram: json['ram'],
      basePrice: double.tryParse(json['base_price'].toString()) ?? 0.0,
      minPrice: double.tryParse(json['min_price'].toString()) ?? 0.0,
    );
  }
}

class ConditionOptionModel {
  final int id;
  final int categoryId;
  final String code;
  final String title;
  final String description;
  final String? imageBase64;
  final String deductionType; // 'FLAT' | 'PERCENTAGE'
  final double defaultDeductionValue;
  final String exclusiveGroup;
  final bool isRejection;
  final bool isAccessoryBonus;
  final bool isWarranty;

  ConditionOptionModel({
    required this.id,
    required this.categoryId,
    required this.code,
    required this.title,
    required this.description,
    this.imageBase64,
    required this.deductionType,
    required this.defaultDeductionValue,
    required this.exclusiveGroup,
    required this.isRejection,
    required this.isAccessoryBonus,
    required this.isWarranty,
  });

  factory ConditionOptionModel.fromJson(Map<String, dynamic> json) {
    return ConditionOptionModel(
      id: json['id'] ?? 0,
      categoryId: json['category'] ?? 0,
      code: json['code'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageBase64: json['image_base64'],
      deductionType: json['deduction_type'] ?? 'FLAT',
      defaultDeductionValue: double.tryParse(json['default_deduction_value'].toString()) ?? 0.0,
      exclusiveGroup: json['exclusive_group'] ?? '',
      isRejection: json['is_rejection'] ?? false,
      isAccessoryBonus: json['is_accessory_bonus'] ?? false,
      isWarranty: json['is_warranty'] ?? false,
    );
  }
}

class ConditionCategoryModel {
  final int id;
  final String name;
  final String subtitle;
  final int stepNumber;
  final String selectionType; // 'SINGLE' | 'MULTIPLE' | 'ACCESSORY' | 'WARRANTY'
  final String proTip;
  final String iconName;
  final int displayOrder;
  final List<ConditionOptionModel> options;

  ConditionCategoryModel({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.stepNumber,
    required this.selectionType,
    required this.proTip,
    required this.iconName,
    required this.displayOrder,
    this.options = const [],
  });

  factory ConditionCategoryModel.fromJson(Map<String, dynamic> json) {
    var opts = <ConditionOptionModel>[];
    if (json['options'] != null) {
      opts = (json['options'] as List)
          .map((o) => ConditionOptionModel.fromJson(o))
          .toList();
    }

    return ConditionCategoryModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      subtitle: json['subtitle'] ?? '',
      stepNumber: json['step_number'] ?? 1,
      selectionType: json['selection_type'] ?? 'SINGLE',
      proTip: json['pro_tip'] ?? '',
      iconName: json['icon_name'] ?? 'Smartphone',
      displayOrder: json['display_order'] ?? 0,
      options: opts,
    );
  }
}

class CMSSectionModel {
  final int id;
  final String sectionType;
  final String title;
  final String subtitle;
  final Map<String, dynamic> dataJson;
  final int displayOrder;
  final bool isActive;

  CMSSectionModel({
    required this.id,
    required this.sectionType,
    required this.title,
    required this.subtitle,
    required this.dataJson,
    required this.displayOrder,
    required this.isActive,
  });

  factory CMSSectionModel.fromJson(Map<String, dynamic> json) {
    return CMSSectionModel(
      id: json['id'] ?? 0,
      sectionType: json['section_type'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      dataJson: json['data_json'] is Map<String, dynamic> ? json['data_json'] : {},
      displayOrder: json['display_order'] ?? 0,
      isActive: json['is_active'] ?? true,
    );
  }
}

class SaleOrderModel {
  final int id;
  final String saleCode;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final String brandName;
  final String modelName;
  final String storage;
  final double basePrice;
  final double estimatedPrice;
  final double? finalPrice;
  final String status;
  final String pickupAddress;
  final String pickupCity;
  final String pickupPincode;
  final String? pickupDate;
  final String? pickupSlot;
  final String? assignedAgentName;
  final String beneficiaryType;
  final String beneficiaryName;
  final String? beneficiaryUpiId;
  final String? imeiNumber;
  final String createdAt;

  SaleOrderModel({
    required this.id,
    required this.saleCode,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    required this.brandName,
    required this.modelName,
    required this.storage,
    required this.basePrice,
    required this.estimatedPrice,
    this.finalPrice,
    required this.status,
    required this.pickupAddress,
    required this.pickupCity,
    required this.pickupPincode,
    this.pickupDate,
    this.pickupSlot,
    this.assignedAgentName,
    required this.beneficiaryType,
    required this.beneficiaryName,
    this.beneficiaryUpiId,
    this.imeiNumber,
    required this.createdAt,
  });

  factory SaleOrderModel.fromJson(Map<String, dynamic> json) {
    return SaleOrderModel(
      id: json['id'] ?? 0,
      saleCode: json['sale_code'] ?? '',
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      customerEmail: json['customer_email'],
      brandName: json['brand_name'] ?? '',
      modelName: json['model_name'] ?? '',
      storage: json['storage'] ?? '',
      basePrice: double.tryParse(json['base_price'].toString()) ?? 0.0,
      estimatedPrice: double.tryParse(json['estimated_price'].toString()) ?? 0.0,
      finalPrice: json['final_price'] != null ? double.tryParse(json['final_price'].toString()) : null,
      status: json['status'] ?? 'SUBMITTED',
      pickupAddress: json['pickup_address'] ?? '',
      pickupCity: json['pickup_city'] ?? 'City',
      pickupPincode: json['pickup_pincode'] ?? '',
      pickupDate: json['pickup_date'],
      pickupSlot: json['pickup_slot'],
      assignedAgentName: json['assigned_agent_name'],
      beneficiaryType: json['beneficiary_type'] ?? 'UPI',
      beneficiaryName: json['beneficiary_name'] ?? '',
      beneficiaryUpiId: json['beneficiary_upi_id'],
      imeiNumber: json['imei_number'],
      createdAt: json['created_at'] ?? '',
    );
  }
}
