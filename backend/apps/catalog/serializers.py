from rest_framework import serializers
from .models import Brand, PhoneModel, StorageVariant

class StorageVariantSerializer(serializers.ModelSerializer):
    class Meta:
        model = StorageVariant
        fields = ['id', 'model', 'ram', 'storage', 'base_price', 'min_price', 'is_active']

class PhoneModelSerializer(serializers.ModelSerializer):
    variants = StorageVariantSerializer(many=True, read_only=True)
    brand_name = serializers.ReadOnlyField(source='brand.name')

    class Meta:
        model = PhoneModel
        fields = ['id', 'brand', 'brand_name', 'name', 'slug', 'image_base64', 'release_year', 'is_active', 'variants']

class BrandSerializer(serializers.ModelSerializer):
    models = serializers.SerializerMethodField()

    class Meta:
        model = Brand
        fields = ['id', 'name', 'slug', 'logo_base64', 'is_active', 'display_order', 'models']

    def get_models(self, obj):
        active_models = obj.models.filter(is_active=True)
        return PhoneModelSerializer(active_models, many=True).data

class BrandBasicSerializer(serializers.ModelSerializer):
    models_count = serializers.IntegerField(source='models.count', read_only=True)
    class Meta:
        model = Brand
        fields = ['id', 'name', 'slug', 'logo_base64', 'is_active', 'display_order', 'models_count']
