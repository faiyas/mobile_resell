from decimal import Decimal
from rest_framework import serializers
from .models import PhoneSale, PhoneSaleConditionAnswer
from apps.catalog.serializers import StorageVariantSerializer
from apps.valuation.models import ConditionOption
from apps.inspections.models import DeviceInspection, InspectionPhoto
from apps.payments.models import Payment

class PhoneSaleConditionAnswerSerializer(serializers.ModelSerializer):
    option_title = serializers.ReadOnlyField(source='option.title')
    category_name = serializers.ReadOnlyField(source='option.category.name')

    class Meta:
        model = PhoneSaleConditionAnswer
        fields = ['id', 'option', 'option_title', 'category_name', 'deduction_applied']

class InspectionPhotoSerializer(serializers.ModelSerializer):
    class Meta:
        model = InspectionPhoto
        fields = ['id', 'label', 'image_base64', 'created_at']

class DeviceInspectionSerializer(serializers.ModelSerializer):
    photos = InspectionPhotoSerializer(many=True, read_only=True)
    inspector_name = serializers.ReadOnlyField(source='inspected_by.full_name')

    class Meta:
        model = DeviceInspection
        fields = [
            'id', 'inspector_name', 'switches_on', 'screen_working',
            'screen_glass_broken', 'touch_working', 'camera_working',
            'battery_healthy', 'body_condition', 'cloud_locks_removed',
            'imei_verified', 'verified_imei', 'customer_id_verified',
            'suggested_final_price', 'inspector_notes', 'created_at', 'photos'
        ]

class PaymentSimpleSerializer(serializers.ModelSerializer):
    paid_by_name = serializers.ReadOnlyField(source='paid_by.full_name')

    class Meta:
        model = Payment
        fields = [
            'id', 'amount', 'payment_method', 'beneficiary_name',
            'beneficiary_upi_id', 'beneficiary_account_no', 'beneficiary_ifsc',
            'utr_number', 'payment_proof_base64', 'admin_notes', 'paid_by_name', 'paid_at'
        ]

class PhoneSaleDetailSerializer(serializers.ModelSerializer):
    variant_details = StorageVariantSerializer(source='variant', read_only=True)
    brand_name = serializers.ReadOnlyField(source='variant.model.brand.name')
    model_name = serializers.ReadOnlyField(source='variant.model.name')
    model_image_base64 = serializers.ReadOnlyField(source='variant.model.image_base64')
    answers = PhoneSaleConditionAnswerSerializer(many=True, read_only=True)
    inspection = DeviceInspectionSerializer(read_only=True)
    payment = PaymentSimpleSerializer(read_only=True)
    assigned_agent_name = serializers.ReadOnlyField(source='assigned_agent.full_name')

    class Meta:
        model = PhoneSale
        fields = [
            'id', 'sale_code', 'customer', 'customer_name', 'customer_phone', 'customer_email',
            'variant', 'variant_details', 'brand_name', 'model_name', 'model_image_base64',
            'base_price', 'estimated_price', 'final_price', 'status',
            'assigned_agent', 'assigned_agent_name',
            'pickup_address', 'pickup_city', 'pickup_pincode', 'pickup_date', 'pickup_slot',
            'beneficiary_type', 'beneficiary_name', 'beneficiary_upi_id',
            'beneficiary_account_no', 'beneficiary_ifsc',
            'imei_number', 'customer_handover_signed', 'admin_notes',
            'created_at', 'updated_at', 'answers', 'inspection', 'payment'
        ]

class PhoneSaleCreateSerializer(serializers.Serializer):
    variant_id = serializers.IntegerField()
    selected_option_codes = serializers.ListField(child=serializers.CharField(), required=False, default=list)
    customer_name = serializers.CharField(max_length=150)
    customer_phone = serializers.CharField(max_length=20)
    customer_email = serializers.EmailField(required=False, allow_blank=True)
    pickup_address = serializers.CharField()
    pickup_city = serializers.CharField(max_length=100, default='City')
    pickup_pincode = serializers.CharField(max_length=10)
    pickup_date = serializers.DateField(required=False, allow_null=True)
    pickup_slot = serializers.CharField(max_length=50, default='Morning (10:00 AM - 1:00 PM)')
    beneficiary_type = serializers.ChoiceField(choices=['UPI', 'BANK'], default='UPI')
    beneficiary_name = serializers.CharField(max_length=150)
    beneficiary_upi_id = serializers.CharField(max_length=100, required=False, allow_blank=True)
    beneficiary_account_no = serializers.CharField(max_length=50, required=False, allow_blank=True)
    beneficiary_ifsc = serializers.CharField(max_length=20, required=False, allow_blank=True)
