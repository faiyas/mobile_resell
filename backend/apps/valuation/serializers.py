from decimal import Decimal
from rest_framework import serializers
from .models import ConditionCategory, ConditionOption, ModelPricingOverride, PriceHistory
from apps.catalog.models import StorageVariant

class ConditionOptionSerializer(serializers.ModelSerializer):
    category_name = serializers.ReadOnlyField(source='category.name')

    class Meta:
        model = ConditionOption
        fields = [
            'id', 'category', 'category_name', 'code', 'title', 'description',
            'image_base64',
            'is_defect', 'is_accessory_bonus', 'is_warranty',
            'deduction_type', 'default_deduction_value',
            'exclusive_group', 'is_rejection',
            'display_order', 'is_active'
        ]

class ConditionCategorySerializer(serializers.ModelSerializer):
    options = serializers.SerializerMethodField()
    device_category_name = serializers.ReadOnlyField(source='device_category.name')

    class Meta:
        model = ConditionCategory
        fields = [
            'id', 'device_category', 'device_category_name', 'step_number',
            'name', 'subtitle', 'selection_type', 'pro_tip',
            'icon_name', 'display_order', 'is_active', 'options'
        ]

    def get_options(self, obj):
        active_options = obj.options.filter(is_active=True).order_by('display_order')
        return ConditionOptionSerializer(active_options, many=True).data

class EstimateCalculationSerializer(serializers.Serializer):
    variant_id = serializers.IntegerField()
    selected_option_codes = serializers.ListField(
        child=serializers.CharField(),
        required=False,
        default=list
    )

class PriceHistorySerializer(serializers.ModelSerializer):
    variant_spec = serializers.SerializerMethodField()
    changed_by_name = serializers.ReadOnlyField(source='changed_by.full_name')

    class Meta:
        model = PriceHistory
        fields = [
            'id', 'variant', 'variant_spec', 'old_base_price', 'new_base_price',
            'changed_by', 'changed_by_name', 'reason', 'created_at'
        ]

    def get_variant_spec(self, obj):
        return f"{obj.variant.model.brand.name} {obj.variant.model.name} ({obj.variant.storage})"
