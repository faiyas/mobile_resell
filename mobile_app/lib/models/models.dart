class UserModel {
  final dynamic id;
  final String email;
  final String username;
  final String fullName;
  final String phone;
  final String role; // 'CUSTOMER' | 'COLLECTION_AGENT' | 'ADMIN'
  final String defaultAddress;
  final String city;
  final String pincode;
  final String defaultUpiId;

  bool get isAdmin => role.toUpperCase() == 'ADMIN' || role.toUpperCase() == 'SUPER_ADMIN';
  bool get isAgent => role.toUpperCase() == 'COLLECTION_AGENT' || role.toUpperCase() == 'AGENT' || role.toUpperCase() == 'FIELD_AGENT';
  bool get isStaff => isAdmin || isAgent;
  bool get isCustomer => !isStaff;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.phone,
    required this.role,
    this.defaultAddress = '',
    this.city = '',
    this.pincode = '',
    this.defaultUpiId = '',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] : (int.tryParse(json['id']?.toString() ?? '') ?? json['id'] ?? 0),
      email: json['email']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? json['username']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'CUSTOMER',
      defaultAddress: json['default_address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      pincode: json['pincode']?.toString() ?? '',
      defaultUpiId: json['default_upi_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'username': username,
    'full_name': fullName,
    'phone': phone,
    'role': role,
    'default_address': defaultAddress,
    'city': city,
    'pincode': pincode,
    'default_upi_id': defaultUpiId,
  };
}

class DeviceCategoryModel {
  final int id;
  final String name;
  final String slug;
  final String subtitle;
  final String iconName;
  final String? imageBase64;
  final int displayOrder;
  final bool isActive;

  DeviceCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.subtitle = '',
    required this.iconName,
    this.imageBase64,
    this.displayOrder = 0,
    this.isActive = true,
  });

  factory DeviceCategoryModel.fromJson(Map<String, dynamic> json) {
    return DeviceCategoryModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? (json['id'] is int ? json['id'] : 0),
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      iconName: json['icon_name']?.toString() ?? 'Smartphone',
      imageBase64: json['image_base64']?.toString(),
      displayOrder: int.tryParse(json['display_order']?.toString() ?? '') ?? 0,
      isActive: json['is_active'] == null ? true : (json['is_active'] == true || json['is_active'].toString().toLowerCase() == 'true'),
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
      id: int.tryParse(json['id']?.toString() ?? '') ?? (json['id'] is int ? json['id'] : 0),
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      logoBase64: json['logo_base64']?.toString(),
      categoryId: json['category'] != null
          ? (int.tryParse(json['category']?.toString() ?? '') ?? (json['category'] is int ? json['category'] : null))
          : null,
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
      id: int.tryParse(json['id']?.toString() ?? '') ?? (json['id'] is int ? json['id'] : 0),
      name: json['name']?.toString() ?? '',
      brandId: int.tryParse(json['brand']?.toString() ?? '') ?? (json['brand'] is int ? json['brand'] : 0),
      brandName: json['brand_name']?.toString(),
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
  final bool hasWarranty;
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
    this.hasWarranty = true,
    this.variants = const [],
  });

  factory PhoneModelItem.fromJson(Map<String, dynamic> json) {
    var vList = <StorageVariantModel>[];
    if (json['variants'] != null && json['variants'] is List) {
      vList = (json['variants'] as List)
          .map((v) => StorageVariantModel.fromJson(v))
          .toList();
    }

    int? bId;
    if (json['brand'] is int) {
      bId = json['brand'];
    } else if (json['brand'] is Map) {
      bId = int.tryParse(json['brand']['id']?.toString() ?? '');
    } else if (json['brand'] != null) {
      bId = int.tryParse(json['brand'].toString());
    }

    int? sId;
    if (json['series'] is int) {
      sId = json['series'];
    } else if (json['series'] is Map) {
      sId = int.tryParse(json['series']['id']?.toString() ?? '');
    } else if (json['series'] != null) {
      sId = int.tryParse(json['series'].toString());
    }

    return PhoneModelItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? (json['id'] is int ? json['id'] : 0),
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      brandId: bId,
      brandName: json['brand_name']?.toString() ?? (json['brand'] is Map ? json['brand']['name']?.toString() : null),
      seriesId: sId,
      seriesName: json['series_name']?.toString() ?? (json['series'] is Map ? json['series']['name']?.toString() : null),
      imageBase64: json['image_base64']?.toString(),
      releaseYear: int.tryParse(json['release_year']?.toString() ?? '') ?? (json['release_year'] is int ? json['release_year'] : 2024),
      hasWarranty: json['has_warranty'] ?? true,
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
  final double mintPrice;

  StorageVariantModel({
    required this.id,
    required this.storage,
    this.ram,
    required this.basePrice,
    required this.minPrice,
    double? mintPrice,
  }) : mintPrice = mintPrice ?? (basePrice * 1.15);

  factory StorageVariantModel.fromJson(Map<String, dynamic> json) {
    final base = double.tryParse(json['base_price']?.toString() ?? '') ?? 0.0;
    final parsedMint = double.tryParse(json['mint_price']?.toString() ?? '');
    return StorageVariantModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? (json['id'] is int ? json['id'] : 0),
      storage: json['storage']?.toString() ?? '',
      ram: json['ram']?.toString(),
      basePrice: base,
      minPrice: double.tryParse(json['min_price']?.toString() ?? '') ?? 0.0,
      mintPrice: parsedMint ?? (base * 1.15),
    );
  }

  StorageVariantModel copyWith({
    int? id,
    String? storage,
    String? ram,
    double? basePrice,
    double? minPrice,
    double? mintPrice,
  }) {
    return StorageVariantModel(
      id: id ?? this.id,
      storage: storage ?? this.storage,
      ram: ram ?? this.ram,
      basePrice: basePrice ?? this.basePrice,
      minPrice: minPrice ?? this.minPrice,
      mintPrice: mintPrice ?? this.mintPrice,
    );
  }
}

class EvaluationTriageQuestionModel {
  final int id;
  final String code;
  final String questionText;
  final String subtitle;
  final bool isPowerOnGate;
  final String deductionType;
  final double deductionValueOnNo;
  final int displayOrder;
  final bool isActive;

  EvaluationTriageQuestionModel({
    required this.id,
    required this.code,
    required this.questionText,
    required this.subtitle,
    this.isPowerOnGate = false,
    this.deductionType = 'PERCENTAGE',
    this.deductionValueOnNo = 0.0,
    this.displayOrder = 1,
    this.isActive = true,
  });

  factory EvaluationTriageQuestionModel.fromJson(Map<String, dynamic> json) {
    return EvaluationTriageQuestionModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      code: json['code']?.toString() ?? '',
      questionText: json['question_text']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      isPowerOnGate: json['is_power_on_gate'] == true,
      deductionType: json['deduction_type']?.toString() ?? 'PERCENTAGE',
      deductionValueOnNo: double.tryParse(json['deduction_value_on_no']?.toString() ?? '') ?? 0.0,
      displayOrder: int.tryParse(json['display_order']?.toString() ?? '') ?? 1,
      isActive: json['is_active'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'question_text': questionText,
    'subtitle': subtitle,
    'is_power_on_gate': isPowerOnGate,
    'deduction_type': deductionType,
    'deduction_value_on_no': deductionValueOnNo,
    'display_order': displayOrder,
    'is_active': isActive,
  };
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
      id: int.tryParse(json['id']?.toString() ?? '') ?? (json['id'] is int ? json['id'] : 0),
      categoryId: int.tryParse(json['category']?.toString() ?? '') ?? (json['category'] is int ? json['category'] : 0),
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imageBase64: json['image_base64']?.toString(),
      deductionType: json['deduction_type']?.toString() ?? 'FLAT',
      defaultDeductionValue: double.tryParse(json['default_deduction_value']?.toString() ?? '') ?? 0.0,
      exclusiveGroup: json['exclusive_group']?.toString() ?? '',
      isRejection: json['is_rejection'] == true,
      isAccessoryBonus: json['is_accessory_bonus'] == true,
      isWarranty: json['is_warranty'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': categoryId,
      'code': code,
      'title': title,
      'description': description,
      'image_base64': imageBase64,
      'deduction_type': deductionType,
      'default_deduction_value': defaultDeductionValue,
      'exclusive_group': exclusiveGroup,
      'is_rejection': isRejection,
      'is_accessory_bonus': isAccessoryBonus,
      'is_warranty': isWarranty,
    };
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
  final String? imageBase64;
  final int? brand;
  final String? brandName;
  final bool isMandatory;
  final int displayOrder;
  final List<ConditionOptionModel> options;

  int? get brandId => brand;

  ConditionCategoryModel copyWith({
    int? id,
    String? name,
    String? subtitle,
    int? stepNumber,
    String? selectionType,
    String? proTip,
    String? iconName,
    String? imageBase64,
    int? brand,
    String? brandName,
    bool? isMandatory,
    int? displayOrder,
    List<ConditionOptionModel>? options,
  }) {
    return ConditionCategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      stepNumber: stepNumber ?? this.stepNumber,
      selectionType: selectionType ?? this.selectionType,
      proTip: proTip ?? this.proTip,
      iconName: iconName ?? this.iconName,
      imageBase64: imageBase64 ?? this.imageBase64,
      brand: brand ?? this.brand,
      brandName: brandName ?? this.brandName,
      isMandatory: isMandatory ?? this.isMandatory,
      displayOrder: displayOrder ?? this.displayOrder,
      options: options ?? this.options,
    );
  }

  ConditionCategoryModel({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.stepNumber,
    required this.selectionType,
    required this.proTip,
    required this.iconName,
    this.imageBase64,
    this.brand,
    this.brandName,
    this.isMandatory = true,
    required this.displayOrder,
    this.options = const [],
  });

  factory ConditionCategoryModel.fromJson(Map<String, dynamic> json) {
    var opts = <ConditionOptionModel>[];
    if (json['options'] != null && json['options'] is List) {
      for (final o in (json['options'] as List)) {
        try {
          if (o is Map) {
            opts.add(ConditionOptionModel.fromJson(Map<String, dynamic>.from(o)));
          }
        } catch (_) {}
      }
    }

    return ConditionCategoryModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? (json['id'] is int ? json['id'] : 0),
      name: json['name']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      stepNumber: int.tryParse(json['step_number']?.toString() ?? '') ?? (json['step_number'] is int ? json['step_number'] : 1),
      selectionType: json['selection_type']?.toString() ?? 'SINGLE',
      proTip: json['pro_tip']?.toString() ?? '',
      iconName: json['icon_name']?.toString() ?? 'Smartphone',
      imageBase64: json['image_base64']?.toString(),
      brand: json['brand'] is int ? json['brand'] : int.tryParse(json['brand']?.toString() ?? ''),
      brandName: json['brand_name']?.toString(),
      isMandatory: json['is_mandatory'] == true || json['is_mandatory']?.toString().toLowerCase() == 'true',
      displayOrder: int.tryParse(json['display_order']?.toString() ?? '') ?? (json['display_order'] is int ? json['display_order'] : 0),
      options: opts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'subtitle': subtitle,
      'step_number': stepNumber,
      'selection_type': selectionType,
      'pro_tip': proTip,
      'icon_name': iconName,
      'image_base64': imageBase64,
      'brand': brand,
      'brand_name': brandName,
      'is_mandatory': isMandatory,
      'display_order': displayOrder,
      'options': options.map((o) => o.toJson()).toList(),
    };
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
      id: int.tryParse(json['id']?.toString() ?? '') ?? (json['id'] is int ? json['id'] : 0),
      sectionType: json['section_type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      dataJson: json['data_json'] is Map<String, dynamic> ? json['data_json'] : {},
      displayOrder: int.tryParse(json['display_order']?.toString() ?? '') ?? (json['display_order'] is int ? json['display_order'] : 0),
      isActive: json['is_active'] == true,
    );
  }
}

class SaleConditionAnswerModel {
  final int? id;
  final String optionTitle;
  final String categoryName;
  final String? customText;
  final double deductionApplied;

  SaleConditionAnswerModel({
    this.id,
    required this.optionTitle,
    required this.categoryName,
    this.customText,
    this.deductionApplied = 0.0,
  });

  factory SaleConditionAnswerModel.fromJson(Map<String, dynamic> json) {
    return SaleConditionAnswerModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      optionTitle: json['option_title']?.toString() ?? json['step_name']?.toString() ?? '',
      categoryName: json['category_name']?.toString() ?? 'Condition',
      customText: json['custom_text']?.toString(),
      deductionApplied: double.tryParse(json['deduction_applied']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class SaleOrderModel {
  final dynamic id; // UUID string (e.g. "b569b11a-...") or int
  final String saleCode;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final bool isCustomDevice;
  final String? customDeviceName;
  final String? customDeviceCategory;
  final String? customDeviceSpecs;
  final String? otherDefectsNotes;
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
  final dynamic assignedAgent;
  final String? assignedAgentName;
  final String beneficiaryType;
  final String beneficiaryName;
  final String? beneficiaryUpiId;
  final String? imeiNumber;
  final String createdAt;
  final String? createdAtIst;
  final bool isOverdue;
  final String? scheduleStatus;
  final String? scheduleAlertMessage;
  final InspectionData? inspection;
  final PaymentData? payment;
  final List<SaleConditionAnswerModel> answers;

  SaleOrderModel({
    required this.id,
    required this.saleCode,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    this.isCustomDevice = false,
    this.customDeviceName,
    this.customDeviceCategory,
    this.customDeviceSpecs,
    this.otherDefectsNotes,
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
    this.assignedAgent,
    this.assignedAgentName,
    required this.beneficiaryType,
    required this.beneficiaryName,
    this.beneficiaryUpiId,
    this.imeiNumber,
    required this.createdAt,
    this.createdAtIst,
    this.isOverdue = false,
    this.scheduleStatus,
    this.scheduleAlertMessage,
    this.inspection,
    this.payment,
    this.answers = const [],
  });

  factory SaleOrderModel.fromJson(Map<String, dynamic> json) {
    final bool isCust = json['is_custom_device'] == true;
    final String cName = json['custom_device_name']?.toString() ?? '';
    final String cCat = json['custom_device_category']?.toString() ?? '';
    final String cSpec = json['custom_device_specs']?.toString() ?? '';

    final bName = isCust && cCat.isNotEmpty ? cCat : (json['brand_name']?.toString() ?? '');
    final mName = isCust && cName.isNotEmpty ? cName : (json['model_name']?.toString() ?? '');
    final sName = isCust && cSpec.isNotEmpty ? cSpec : (json['storage']?.toString() ??
        (json['variant_details'] != null && json['variant_details'] is Map ? json['variant_details']['storage']?.toString() : null) ?? '');

    InspectionData? insp;
    if (json['inspection'] != null && json['inspection'] is Map) {
      try {
        insp = InspectionData.fromJson(Map<String, dynamic>.from(json['inspection'] as Map));
      } catch (_) {}
    }

    PaymentData? pay;
    if (json['payment'] != null && json['payment'] is Map) {
      try {
        pay = PaymentData.fromJson(Map<String, dynamic>.from(json['payment'] as Map));
      } catch (_) {}
    }

    var ansList = <SaleConditionAnswerModel>[];
    if (json['answers'] != null && json['answers'] is List) {
      ansList = (json['answers'] as List)
          .map((a) => SaleConditionAnswerModel.fromJson(Map<String, dynamic>.from(a as Map)))
          .toList();
    }

    return SaleOrderModel(
      id: json['id']?.toString() ?? '',
      saleCode: json['sale_code']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      customerPhone: json['customer_phone']?.toString() ?? '',
      customerEmail: json['customer_email']?.toString(),
      isCustomDevice: isCust,
      customDeviceName: cName,
      customDeviceCategory: cCat,
      customDeviceSpecs: cSpec,
      otherDefectsNotes: json['other_defects_notes']?.toString(),
      brandName: bName.isNotEmpty ? bName : 'Others',
      modelName: mName.isNotEmpty ? mName : 'Custom Device',
      storage: sName.isNotEmpty ? sName : 'Standard',
      basePrice: double.tryParse(json['base_price']?.toString() ?? '') ?? 0.0,
      estimatedPrice: double.tryParse(json['estimated_price']?.toString() ?? '') ?? 0.0,
      finalPrice: json['final_price'] != null ? double.tryParse(json['final_price'].toString()) : null,
      status: json['status']?.toString() ?? 'SUBMITTED',
      pickupAddress: json['pickup_address']?.toString() ?? '',
      pickupCity: json['pickup_city']?.toString() ?? 'City',
      pickupPincode: json['pickup_pincode']?.toString() ?? '',
      pickupDate: json['pickup_date']?.toString(),
      pickupSlot: json['pickup_slot']?.toString(),
      assignedAgent: json['assigned_agent'],
      assignedAgentName: json['assigned_agent_name']?.toString(),
      beneficiaryType: json['beneficiary_type']?.toString() ?? 'UPI',
      beneficiaryName: json['beneficiary_name']?.toString() ?? '',
      beneficiaryUpiId: json['beneficiary_upi_id']?.toString(),
      imeiNumber: json['imei_number']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      createdAtIst: json['created_at_ist']?.toString(),
      isOverdue: json['is_overdue'] == true,
      scheduleStatus: json['schedule_status']?.toString(),
      scheduleAlertMessage: json['schedule_alert_message']?.toString(),
      inspection: insp,
      payment: pay,
      answers: ansList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sale_code': saleCode,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'is_custom_device': isCustomDevice,
      'custom_device_name': customDeviceName,
      'custom_device_category': customDeviceCategory,
      'custom_device_specs': customDeviceSpecs,
      'other_defects_notes': otherDefectsNotes,
      'brand_name': brandName,
      'model_name': modelName,
      'storage': storage,
      'base_price': basePrice,
      'estimated_price': estimatedPrice,
      'final_price': finalPrice,
      'status': status,
      'pickup_address': pickupAddress,
      'pickup_city': pickupCity,
      'pickup_pincode': pickupPincode,
      'pickup_date': pickupDate,
      'pickup_slot': pickupSlot,
      'assigned_agent': assignedAgent,
      'assigned_agent_name': assignedAgentName,
      'beneficiary_type': beneficiaryType,
      'beneficiary_name': beneficiaryName,
      'beneficiary_upi_id': beneficiaryUpiId,
      'imei_number': imeiNumber,
      'created_at': createdAt,
      'created_at_ist': createdAtIst,
      'is_overdue': isOverdue,
      'schedule_status': scheduleStatus,
      'schedule_alert_message': scheduleAlertMessage,
      'inspection': inspection?.toJson(),
      'payment': payment?.toJson(),
    };
  }
}

class InspectionPhotoData {
  final int? id;
  final String label;
  final String imageBase64;

  InspectionPhotoData({this.id, required this.label, required this.imageBase64});

  factory InspectionPhotoData.fromJson(Map<String, dynamic> json) {
    return InspectionPhotoData(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      label: json['label']?.toString() ?? 'Inspection Photo',
      imageBase64: json['image_base64']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'image_base64': imageBase64,
    };
  }
}

class InspectionData {
  final int? id;
  final String? inspectorName;
  final String? verifiedImei;
  final double? suggestedFinalPrice;
  final String? inspectorNotes;
  final List<InspectionPhotoData> photos;

  InspectionData({
    this.id,
    this.inspectorName,
    this.verifiedImei,
    this.suggestedFinalPrice,
    this.inspectorNotes,
    this.photos = const [],
  });

  factory InspectionData.fromJson(Map<String, dynamic> json) {
    var pList = <InspectionPhotoData>[];
    if (json['photos'] != null && json['photos'] is List) {
      for (final p in (json['photos'] as List)) {
        try {
          if (p is Map) {
            pList.add(InspectionPhotoData.fromJson(Map<String, dynamic>.from(p)));
          }
        } catch (_) {}
      }
    }
    return InspectionData(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      inspectorName: json['inspector_name']?.toString(),
      verifiedImei: json['verified_imei']?.toString(),
      suggestedFinalPrice: json['suggested_final_price'] != null
          ? double.tryParse(json['suggested_final_price'].toString())
          : null,
      inspectorNotes: json['inspector_notes']?.toString(),
      photos: pList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'inspector_name': inspectorName,
      'verified_imei': verifiedImei,
      'suggested_final_price': suggestedFinalPrice,
      'inspector_notes': inspectorNotes,
      'photos': photos.map((p) => p.toJson()).toList(),
    };
  }
}

class PaymentData {
  final int? id;
  final double amount;
  final String paymentMethod;
  final String utrNumber;
  final String paymentProofBase64;
  final String? beneficiaryUpiId;
  final String? adminNotes;
  final String? paidByName;
  final String? paidAt;

  PaymentData({
    this.id,
    required this.amount,
    required this.paymentMethod,
    required this.utrNumber,
    required this.paymentProofBase64,
    this.beneficiaryUpiId,
    this.adminNotes,
    this.paidByName,
    this.paidAt,
  });

  factory PaymentData.fromJson(Map<String, dynamic> json) {
    return PaymentData(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0.0,
      paymentMethod: json['payment_method']?.toString() ?? 'UPI',
      utrNumber: json['utr_number']?.toString() ?? '',
      paymentProofBase64: json['payment_proof_base64']?.toString() ?? '',
      beneficiaryUpiId: json['beneficiary_upi_id']?.toString(),
      adminNotes: json['admin_notes']?.toString(),
      paidByName: json['paid_by_name']?.toString(),
      paidAt: json['paid_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'payment_method': paymentMethod,
      'utr_number': utrNumber,
      'payment_proof_base64': paymentProofBase64,
      'beneficiary_upi_id': beneficiaryUpiId,
      'admin_notes': adminNotes,
      'paid_by_name': paidByName,
      'paid_at': paidAt,
    };
  }
}

class AgentUserModel {
  final int id;
  final String email;
  final String fullName;
  final String phone;

  AgentUserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
  });

  factory AgentUserModel.fromJson(Map<String, dynamic> json) {
    return AgentUserModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? (json['id'] is int ? json['id'] : 0),
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
    };
  }
}

class PaymentSummaryModel {
  final int totalCount;
  final double totalDisbursed;
  final List<dynamic> payments;

  PaymentSummaryModel({
    required this.totalCount,
    required this.totalDisbursed,
    required this.payments,
  });

  factory PaymentSummaryModel.fromJson(Map<String, dynamic> json) {
    return PaymentSummaryModel(
      totalCount: int.tryParse(json['total_count']?.toString() ?? '') ??
          (json['total_count'] is int ? json['total_count'] : 0),
      totalDisbursed: double.tryParse(json['total_disbursed']?.toString() ?? '') ?? 0.0,
      payments: json['payments'] is List ? json['payments'] : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_count': totalCount,
      'total_disbursed': totalDisbursed,
      'payments': payments,
    };
  }
}
