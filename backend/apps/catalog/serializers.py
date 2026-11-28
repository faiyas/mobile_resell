from rest_framework import serializers
from .models import DeviceCategory, Brand, DeviceSeries, PhoneModel, StorageVariant, CMSHomeSection, BusinessSetting

def _normalize_base64_data_uri(val, mime='image/jpeg'):
    """
    Ensures a base64 string is formatted as an RFC 2397 Data URI.
    If already prefixed with data: or is an http/https URL, preserves it.
    Otherwise prepends data:<mime>;base64, so browsers can render it directly.
    """
    if not val or not isinstance(val, str):
        return val
    s = val.strip()
    if not s:
        return s
    if s.startswith('data:') or s.startswith('http://') or s.startswith('https://'):
        return s
    return f"data:{mime};base64,{s}"

class DeviceCategorySerializer(serializers.ModelSerializer):
    brands_count = serializers.SerializerMethodField()

    class Meta:
        model = DeviceCategory
        fields = ['id', 'name', 'slug', 'subtitle', 'icon_name', 'image_base64', 'display_order', 'is_active', 'brands_count']

    def to_representation(self, instance):
        data = super().to_representation(instance)
        if data.get('image_base64'):
            data['image_base64'] = _normalize_base64_data_uri(data['image_base64'], 'image/png')
        return data

    def validate_image_base64(self, value):
        return _normalize_base64_data_uri(value, 'image/png')

    def get_brands_count(self, obj):
        val = getattr(obj, 'annotated_brands_count', None)
        return val if val is not None else obj.brands.count()

class DeviceSeriesSerializer(serializers.ModelSerializer):
    brand_name = serializers.ReadOnlyField(source='brand.name')
    models_count = serializers.SerializerMethodField()

    class Meta:
        model = DeviceSeries
        fields = ['id', 'brand', 'brand_name', 'name', 'display_order', 'is_active', 'models_count']

    def get_models_count(self, obj):
        val = getattr(obj, 'annotated_models_count', None)
        return val if val is not None else obj.models.count()

class StorageVariantSerializer(serializers.ModelSerializer):
    brand_name = serializers.ReadOnlyField(source='model.brand.name')
    brand_id = serializers.ReadOnlyField(source='model.brand.id')
    series_name = serializers.ReadOnlyField(source='model.series.name')
    series_id = serializers.ReadOnlyField(source='model.series.id')
    model_name = serializers.ReadOnlyField(source='model.name')
    model_id = serializers.ReadOnlyField(source='model.id')

    class Meta:
        model = StorageVariant
        fields = ['id', 'model', 'model_id', 'brand_id', 'brand_name', 'series_id', 'series_name', 'model_name', 'ram', 'storage', 'base_price', 'min_price', 'is_active', 'created_at']

class PhoneModelSerializer(serializers.ModelSerializer):
    variants = StorageVariantSerializer(many=True, read_only=True)
    brand_name = serializers.ReadOnlyField(source='brand.name')
    series_name = serializers.ReadOnlyField(source='series.name')

    class Meta:
        model = PhoneModel
        fields = ['id', 'brand', 'brand_name', 'series', 'series_name', 'name', 'slug', 'image_base64', 'release_year', 'has_warranty', 'is_active', 'variants']

    def to_representation(self, instance):
        data = super().to_representation(instance)
        if data.get('image_base64'):
            data['image_base64'] = _normalize_base64_data_uri(data['image_base64'], 'image/jpeg')
        return data

    def validate_image_base64(self, value):
        return _normalize_base64_data_uri(value, 'image/jpeg')

class BrandSerializer(serializers.ModelSerializer):
    models = serializers.SerializerMethodField()
    category_name = serializers.ReadOnlyField(source='category.name')

    class Meta:
        model = Brand
        fields = ['id', 'category', 'category_name', 'name', 'slug', 'logo_base64', 'is_active', 'display_order', 'models']

    def to_representation(self, instance):
        data = super().to_representation(instance)
        if data.get('logo_base64'):
            data['logo_base64'] = _normalize_base64_data_uri(data['logo_base64'], 'image/png')
        return data

    def validate_logo_base64(self, value):
        return _normalize_base64_data_uri(value, 'image/png')

    def get_models(self, obj):
        if hasattr(obj, '_prefetched_objects_cache') and 'models' in obj._prefetched_objects_cache:
            active_models = [m for m in obj.models.all() if m.is_active]
        else:
            active_models = obj.models.filter(is_active=True)
        return PhoneModelSerializer(active_models, many=True).data

class BrandBasicSerializer(serializers.ModelSerializer):
    models_count = serializers.SerializerMethodField()
    category_name = serializers.ReadOnlyField(source='category.name')

    class Meta:
        model = Brand
        fields = ['id', 'category', 'category_name', 'name', 'slug', 'logo_base64', 'is_active', 'display_order', 'models_count']

    def to_representation(self, instance):
        data = super().to_representation(instance)
        if data.get('logo_base64'):
            data['logo_base64'] = _normalize_base64_data_uri(data['logo_base64'], 'image/png')
        return data

    def validate_logo_base64(self, value):
        return _normalize_base64_data_uri(value, 'image/png')

    def get_models_count(self, obj):
        val = getattr(obj, 'annotated_models_count', None)
        return val if val is not None else obj.models.count()


class CMSHomeSectionSerializer(serializers.ModelSerializer):
    class Meta:
        model = CMSHomeSection
        fields = ['id', 'section_type', 'title', 'subtitle', 'data_json', 'display_order', 'is_active', 'updated_at']

class BusinessSettingSerializer(serializers.ModelSerializer):
    class Meta:
        model = BusinessSetting
        fields = [
            'id', 'company_name', 'business_logo', 'customer_helpline', 'agent_helpline',
            'whatsapp_number', 'support_email', 'office_address', 'google_maps_url',
            'website_url', 'privacy_policy_url', 'terms_url',
            'working_hours', 'instagram_url', 'facebook_url', 'youtube_url',
            'terms_and_conditions', 'privacy_policy_text', 'updated_at'
        ]
