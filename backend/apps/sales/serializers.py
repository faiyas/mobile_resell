import datetime
from decimal import Decimal
from django.utils import timezone
from rest_framework import serializers
from .models import PhoneSale, PhoneSaleConditionAnswer
from apps.catalog.serializers import StorageVariantSerializer
from apps.valuation.models import ConditionOption
from apps.inspections.models import DeviceInspection, InspectionPhoto
from apps.payments.models import Payment

IST = datetime.timezone(datetime.timedelta(hours=5, minutes=30))

def _calculate_ist_schedule(obj):
    if not obj.pickup_date:
        return {
            'is_overdue': False,
            'schedule_status': 'UNSCHEDULED',
            'schedule_alert_message': 'No pickup date selected',
            'pickup_date_ist': None,
        }

    now_ist = timezone.now().astimezone(IST)
    slot_str = (obj.pickup_slot or '').lower()
    if 'morning' in slot_str or '1:00 pm' in slot_str or '1 pm' in slot_str:
        end_time = datetime.time(13, 0)
    elif 'afternoon' in slot_str or '5:00 pm' in slot_str or '5 pm' in slot_str:
        end_time = datetime.time(17, 0)
    elif 'evening' in slot_str or '8:00 pm' in slot_str or '8 pm' in slot_str:
        end_time = datetime.time(20, 0)
    else:
        end_time = datetime.time(18, 0)

    deadline_ist = datetime.datetime.combine(obj.pickup_date, end_time, tzinfo=IST)
    is_terminal = obj.status in ['DEVICE_COLLECTED', 'CUSTOMER_ACCEPTED', 'OWNERSHIP_TRANSFERRED', 'PAYMENT_PENDING', 'PAYMENT_COMPLETED', 'CANCELLED']

    if is_terminal:
        return {
            'is_overdue': False,
            'schedule_status': 'COMPLETED',
            'schedule_alert_message': f'Completed · {obj.pickup_date.strftime("%d %b %Y")}',
            'pickup_date_ist': obj.pickup_date.strftime('%Y-%m-%d'),
        }

    if now_ist > deadline_ist:
        diff = now_ist - deadline_ist
        if diff.days > 0:
            msg = f"Overdue by {diff.days} day(s)"
        else:
            hrs = max(1, diff.seconds // 3600)
            msg = f"Overdue by {hrs} hr(s)"
        return {
            'is_overdue': True,
            'schedule_status': 'OVERDUE',
            'schedule_alert_message': msg,
            'pickup_date_ist': obj.pickup_date.strftime('%Y-%m-%d'),
        }
    elif obj.pickup_date == now_ist.date():
        return {
            'is_overdue': False,
            'schedule_status': 'DUE_TODAY',
            'schedule_alert_message': f'Due Today: {obj.pickup_slot} (IST)',
            'pickup_date_ist': obj.pickup_date.strftime('%Y-%m-%d'),
        }
    else:
        return {
            'is_overdue': False,
            'schedule_status': 'UPCOMING',
            'schedule_alert_message': f'Scheduled: {obj.pickup_date.strftime("%d %b %Y")} (IST)',
            'pickup_date_ist': obj.pickup_date.strftime('%Y-%m-%d'),
        }

class PhoneSaleConditionAnswerSerializer(serializers.ModelSerializer):
    option_title = serializers.SerializerMethodField()
    category_name = serializers.SerializerMethodField()

    class Meta:
        model = PhoneSaleConditionAnswer
        fields = ['id', 'option', 'step_name', 'option_title', 'category_name', 'custom_text', 'deduction_applied']

    def get_option_title(self, obj):
        if obj.option:
            return obj.option.title
        return obj.step_name or "Custom Defect Note"

    def get_category_name(self, obj):
        if obj.option and obj.option.category:
            return obj.option.category.name
        return obj.step_name or "General Notes"

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

def _serialize_verified_payment(obj, context):
    """Ensure sensitive payout proof screenshot and UTR are strictly revealed to verified owner / admin only."""
    if not hasattr(obj, 'payment') or not obj.payment:
        return None
    request = context.get('request') if context else None
    if request and request.user and request.user.is_authenticated:
        u = request.user
        if getattr(u, 'is_admin_role', False) or getattr(u, 'is_agent_role', False):
            return PaymentSimpleSerializer(obj.payment).data
        if str(getattr(u, 'role', '')).upper() == 'CUSTOMER':
            is_owner = (
                obj.customer == u or
                (u.phone and obj.customer_phone == u.phone) or
                (u.email and obj.customer_email and obj.customer_email.strip().lower() == u.email.strip().lower())
            )
            if is_owner:
                return PaymentSimpleSerializer(obj.payment).data
    if request:
        phone = (request.GET.get('phone') or '').strip()[-10:]
        sale_phone = (obj.customer_phone or '').strip()[-10:]
        if phone and sale_phone and phone == sale_phone:
            return PaymentSimpleSerializer(obj.payment).data
    return None

class PhoneSaleDetailSerializer(serializers.ModelSerializer):
    variant_details = StorageVariantSerializer(source='variant', read_only=True)
    brand_name = serializers.SerializerMethodField()
    model_name = serializers.SerializerMethodField()
    storage = serializers.SerializerMethodField()
    model_image_base64 = serializers.SerializerMethodField()
    answers = PhoneSaleConditionAnswerSerializer(many=True, read_only=True)
    inspection = DeviceInspectionSerializer(read_only=True)
    payment = serializers.SerializerMethodField()
    assigned_agent_name = serializers.ReadOnlyField(source='assigned_agent.full_name')
    is_overdue = serializers.SerializerMethodField()
    schedule_status = serializers.SerializerMethodField()
    schedule_alert_message = serializers.SerializerMethodField()
    created_at_ist = serializers.SerializerMethodField()

    class Meta:
        model = PhoneSale
        fields = [
            'id', 'sale_code', 'customer', 'customer_name', 'customer_phone', 'customer_email',
            'is_custom_device', 'custom_device_name', 'custom_device_category', 'custom_device_specs', 'other_defects_notes',
            'variant', 'variant_details', 'brand_name', 'model_name', 'storage', 'model_image_base64',
            'base_price', 'estimated_price', 'final_price', 'status',
            'assigned_agent', 'assigned_agent_name',
            'pickup_address', 'pickup_city', 'pickup_pincode', 'pickup_date', 'pickup_slot',
            'beneficiary_type', 'beneficiary_name', 'beneficiary_upi_id',
            'beneficiary_account_no', 'beneficiary_ifsc',
            'imei_number', 'customer_handover_signed', 'admin_notes',
            'created_at', 'created_at_ist', 'updated_at',
            'is_overdue', 'schedule_status', 'schedule_alert_message',
            'answers', 'inspection', 'payment'
        ]

    def get_payment(self, obj):
        return _serialize_verified_payment(obj, self.context)

    def get_brand_name(self, obj):
        if obj.is_custom_device or not obj.variant:
            return obj.custom_device_category or "Others"
        return obj.variant.model.brand.name

    def get_model_name(self, obj):
        if obj.is_custom_device or not obj.variant:
            return obj.custom_device_name or "Custom Gadget"
        return obj.variant.model.name

    def get_storage(self, obj):
        if obj.is_custom_device or not obj.variant:
            return obj.custom_device_specs or "Custom Spec"
        return obj.variant.storage

    def get_model_image_base64(self, obj):
        if obj.variant and obj.variant.model:
            return obj.variant.model.image_base64
        return None

    def get_is_overdue(self, obj):
        return _calculate_ist_schedule(obj)['is_overdue']

    def get_schedule_status(self, obj):
        return _calculate_ist_schedule(obj)['schedule_status']

    def get_schedule_alert_message(self, obj):
        return _calculate_ist_schedule(obj)['schedule_alert_message']

    def get_created_at_ist(self, obj):
        if obj.created_at:
            ist_time = obj.created_at.astimezone(IST)
            return ist_time.strftime('%d %b %Y, %I:%M %p IST')
        return None

class PhoneSaleListSerializer(serializers.ModelSerializer):
    """Ultra-lightweight serializer for listing orders"""
    brand_name = serializers.SerializerMethodField()
    model_name = serializers.SerializerMethodField()
    storage = serializers.SerializerMethodField()
    ram = serializers.SerializerMethodField()
    assigned_agent_name = serializers.ReadOnlyField(source='assigned_agent.full_name')
    answers = PhoneSaleConditionAnswerSerializer(many=True, read_only=True)
    has_inspection = serializers.SerializerMethodField()
    has_payment = serializers.SerializerMethodField()
    payment = serializers.SerializerMethodField()
    is_overdue = serializers.SerializerMethodField()
    schedule_status = serializers.SerializerMethodField()
    schedule_alert_message = serializers.SerializerMethodField()
    created_at_ist = serializers.SerializerMethodField()

    class Meta:
        model = PhoneSale
        fields = [
            'id', 'sale_code', 'customer_name', 'customer_phone', 'customer_email',
            'is_custom_device', 'custom_device_name', 'custom_device_category', 'custom_device_specs', 'other_defects_notes',
            'brand_name', 'model_name', 'storage', 'ram',
            'base_price', 'estimated_price', 'final_price', 'status',
            'assigned_agent', 'assigned_agent_name',
            'pickup_address', 'pickup_city', 'pickup_pincode', 'pickup_date', 'pickup_slot',
            'beneficiary_type', 'beneficiary_name', 'beneficiary_upi_id',
            'beneficiary_account_no', 'beneficiary_ifsc',
            'imei_number', 'customer_handover_signed', 'admin_notes',
            'answers',
            'has_inspection', 'has_payment', 'payment', 'created_at', 'created_at_ist', 'updated_at',
            'is_overdue', 'schedule_status', 'schedule_alert_message'
        ]

    def get_payment(self, obj):
        return _serialize_verified_payment(obj, self.context)

    def get_brand_name(self, obj):
        if obj.is_custom_device or not obj.variant:
            return obj.custom_device_category or "Others"
        return obj.variant.model.brand.name

    def get_model_name(self, obj):
        if obj.is_custom_device or not obj.variant:
            return obj.custom_device_name or "Custom Gadget"
        return obj.variant.model.name

    def get_storage(self, obj):
        if obj.is_custom_device or not obj.variant:
            return obj.custom_device_specs or "Custom Spec"
        return obj.variant.storage

    def get_ram(self, obj):
        if obj.variant:
            return obj.variant.ram
        return None

    def get_has_inspection(self, obj):
        return hasattr(obj, 'inspection')

    def get_has_payment(self, obj):
        return hasattr(obj, 'payment')

    def get_is_overdue(self, obj):
        return _calculate_ist_schedule(obj)['is_overdue']

    def get_schedule_status(self, obj):
        return _calculate_ist_schedule(obj)['schedule_status']

    def get_schedule_alert_message(self, obj):
        return _calculate_ist_schedule(obj)['schedule_alert_message']

    def get_created_at_ist(self, obj):
        if obj.created_at:
            ist_time = obj.created_at.astimezone(IST)
            return ist_time.strftime('%d %b %Y, %I:%M %p IST')
        return None

class PhoneSaleCreateSerializer(serializers.Serializer):
    variant_id = serializers.IntegerField(required=False, allow_null=True)
    is_custom_device = serializers.BooleanField(required=False, default=False)
    custom_device_name = serializers.CharField(required=False, allow_blank=True, default='')
    custom_device_category = serializers.CharField(required=False, allow_blank=True, default='Mobile')
    custom_device_specs = serializers.CharField(required=False, allow_blank=True, default='')
    custom_expected_price = serializers.DecimalField(max_digits=10, decimal_places=2, required=False, allow_null=True)
    other_defects_notes = serializers.CharField(required=False, allow_blank=True, default='')
    custom_step_notes = serializers.DictField(required=False, default=dict)
    selected_option_codes = serializers.ListField(child=serializers.CharField(), required=False, default=list)
    customer_name = serializers.CharField(max_length=150)
    customer_phone = serializers.CharField(max_length=20)
    customer_email = serializers.EmailField(required=False, allow_blank=True)

    def validate_customer_phone(self, value):
        raw = str(value or '').strip()
        digits = ''.join(c for c in raw if c.isdigit())
        if digits.startswith('91') and len(digits) == 12:
            digits = digits[2:]
        if len(digits) < 10:
            raise serializers.ValidationError("Please provide a valid 10-digit mobile number.")
        return digits[-10:]
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
