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
            'is_defect', 'deduction_type', 'default_deduction_value',
            'exclusive_group', 'is_rejection',
            'display_order', 'is_active'
        ]

class ConditionCategorySerializer(serializers.ModelSerializer):
    options = serializers.SerializerMethodField()

    class Meta:
        model = ConditionCategory
        fields = ['id', 'name', 'description', 'icon_name', 'display_order', 'is_active', 'options']

    def get_options(self, obj):
        active_options = obj.options.filter(is_active=True)
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
