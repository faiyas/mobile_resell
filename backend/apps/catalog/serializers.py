from rest_framework import serializers
from .models import DeviceCategory, Brand, DeviceSeries, PhoneModel, StorageVariant, CMSHomeSection

class DeviceCategorySerializer(serializers.ModelSerializer):
    brands_count = serializers.IntegerField(source='brands.count', read_only=True)

    class Meta:
        model = DeviceCategory
        fields = ['id', 'name', 'slug', 'subtitle', 'icon_name', 'image_base64', 'display_order', 'is_active', 'brands_count']

class DeviceSeriesSerializer(serializers.ModelSerializer):
    brand_name = serializers.ReadOnlyField(source='brand.name')
    models_count = serializers.IntegerField(source='models.count', read_only=True)

    class Meta:
        model = DeviceSeries
        fields = ['id', 'brand', 'brand_name', 'name', 'display_order', 'is_active', 'models_count']

class StorageVariantSerializer(serializers.ModelSerializer):
    brand_name = serializers.ReadOnlyField(source='model.brand.name')
    model_name = serializers.ReadOnlyField(source='model.name')
    model_id = serializers.ReadOnlyField(source='model.id')

    class Meta:
        model = StorageVariant
        fields = ['id', 'model', 'model_id', 'brand_name', 'model_name', 'ram', 'storage', 'base_price', 'min_price', 'is_active', 'created_at']

class PhoneModelSerializer(serializers.ModelSerializer):
    variants = StorageVariantSerializer(many=True, read_only=True)
    brand_name = serializers.ReadOnlyField(source='brand.name')
    series_name = serializers.ReadOnlyField(source='series.name')

    class Meta:
        model = PhoneModel
        fields = ['id', 'brand', 'brand_name', 'series', 'series_name', 'name', 'slug', 'image_base64', 'release_year', 'has_warranty', 'is_active', 'variants']

class BrandSerializer(serializers.ModelSerializer):
    models = serializers.SerializerMethodField()
    category_name = serializers.ReadOnlyField(source='category.name')

    class Meta:
        model = Brand
        fields = ['id', 'category', 'category_name', 'name', 'slug', 'logo_base64', 'is_active', 'display_order', 'models']

    def get_models(self, obj):
        if hasattr(obj, '_prefetched_objects_cache') and 'models' in obj._prefetched_objects_cache:
            active_models = [m for m in obj.models.all() if m.is_active]
        else:
            active_models = obj.models.filter(is_active=True)
        return PhoneModelSerializer(active_models, many=True).data

class BrandBasicSerializer(serializers.ModelSerializer):
    models_count = serializers.IntegerField(source='models.count', read_only=True)
    category_name = serializers.ReadOnlyField(source='category.name')

    class Meta:
        model = Brand
        fields = ['id', 'category', 'category_name', 'name', 'slug', 'logo_base64', 'is_active', 'display_order', 'models_count']

class CMSHomeSectionSerializer(serializers.ModelSerializer):
    class Meta:
        model = CMSHomeSection
        fields = ['id', 'section_type', 'title', 'subtitle', 'data_json', 'display_order', 'is_active', 'updated_at']
