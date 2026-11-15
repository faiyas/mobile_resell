from decimal import Decimal
from rest_framework import serializers
from .models import ConditionCategory, ConditionOption, ModelPricingOverride
from apps.catalog.models import StorageVariant

class ConditionOptionSerializer(serializers.ModelSerializer):
    class Meta:
        model = ConditionOption
        fields = [
            'id', 'category', 'code', 'title', 'description',
            'is_defect', 'deduction_type', 'default_deduction_value',
            'display_order', 'is_active'
        ]

class ConditionCategorySerializer(serializers.ModelSerializer):
    options = serializers.SerializerMethodField()

    class Meta:
        model = ConditionCategory
        fields = ['id', 'name', 'description', 'icon_name', 'display_order', 'options']

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
