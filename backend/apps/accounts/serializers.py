from django.db import models
from rest_framework import serializers
from .models import User

class UserSerializer(serializers.ModelSerializer):
    orders_count = serializers.SerializerMethodField(read_only=True)
    total_sales_value = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = User
        fields = [
            'id', 'email', 'phone', 'full_name', 'role',
            'default_address', 'city', 'pincode', 'default_upi_id',
            'is_active', 'is_staff', 'is_superuser', 'created_at',
            'orders_count', 'total_sales_value'
        ]
        read_only_fields = ['id', 'created_at']

    def get_orders_count(self, obj):
        try:
            from apps.sales.models import SaleOrder
            return SaleOrder.objects.filter(models.Q(customer=obj) | models.Q(customer_phone=obj.phone)).count()
        except Exception:
            return 0

    def get_total_sales_value(self, obj):
        try:
            from apps.sales.models import SaleOrder
            from django.db.models import Sum
            res = SaleOrder.objects.filter(
                models.Q(customer=obj) | models.Q(customer_phone=obj.phone),
                status__in=['OWNERSHIP_TRANSFERRED', 'PAYMENT_COMPLETED']
            ).aggregate(Sum('final_price'))['final_price__sum']
            return float(res or 0)
        except Exception:
            return 0.0

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)
    phone = serializers.CharField(required=True)
    email = serializers.EmailField(required=False, allow_blank=True, allow_null=True)

    class Meta:
        model = User
        fields = ['id', 'email', 'password', 'phone', 'full_name', 'role']

    def validate_email(self, value):
        if not value or not str(value).strip():
            return ''
        email = str(value).strip().lower()
        # If user with same email exists, raise error
        if User.objects.filter(email__iexact=email).exists():
            raise serializers.ValidationError("An account with this email address already exists. Please sign in.")
        return email

    def validate_phone(self, value):
        raw_phone = str(value or '').strip()
        clean_phone = ''.join(c for c in raw_phone if c.isdigit())
        if clean_phone.startswith('91') and len(clean_phone) == 12:
            clean_phone = clean_phone[2:]
        elif clean_phone.startswith('0') and len(clean_phone) == 11:
            clean_phone = clean_phone[1:]

        if not clean_phone or len(clean_phone) != 10:
            raise serializers.ValidationError("Please enter a valid 10-digit Indian mobile number.")

        if User.objects.filter(phone=clean_phone).exists():
            raise serializers.ValidationError("An account with this mobile number already exists. Please sign in.")
        return clean_phone

    def create(self, validated_data):
        is_admin = self.context.get('is_admin', False)
        requested_role = validated_data.get('role', 'CUSTOMER')
        if is_admin and requested_role in ['COLLECTION_AGENT', 'ADMIN']:
            role = requested_role
        else:
            role = 'CUSTOMER'

        clean_phone = validated_data.get('phone', '')
        email = validated_data.get('email')
        if not email or not str(email).strip():
            # Auto-assign domain email based on phone if omitted
            prefix = 'agent' if role == 'COLLECTION_AGENT' else 'user'
            email = f"{prefix}_{clean_phone}@dollybuyback.com"

        user = User.objects.create_user(
            email=email,
            password=validated_data['password'],
            phone=clean_phone,
            full_name=validated_data.get('full_name', ''),
            role=role,
            is_staff=(role == 'ADMIN')
        )
        return user

class LoginSerializer(serializers.Serializer):
    email = serializers.CharField(help_text="Email address or 10-digit mobile number")
    password = serializers.CharField()
