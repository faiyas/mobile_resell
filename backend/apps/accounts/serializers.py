from rest_framework import serializers
from .models import User

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = [
            'id', 'email', 'phone', 'full_name', 'role',
            'default_address', 'city', 'pincode', 'default_upi_id',
            'is_staff', 'is_superuser', 'created_at'
        ]
        read_only_fields = ['id', 'email', 'role', 'is_staff', 'is_superuser', 'created_at']

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)
    phone = serializers.CharField(required=True)

    class Meta:
        model = User
        fields = ['id', 'email', 'password', 'phone', 'full_name', 'role']

    def validate_email(self, value):
        email = value.strip().lower()
        if User.objects.filter(email__iexact=email).exists():
            raise serializers.ValidationError("An account with this email address already exists. Please sign in.")
        return email

    def validate_phone(self, value):
        raw_phone = value.strip()
        # Keep only digits
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

        user = User.objects.create_user(
            email=validated_data['email'],
            password=validated_data['password'],
            phone=validated_data['phone'],
            full_name=validated_data.get('full_name', ''),
            role=role,
            is_staff=(role == 'ADMIN')
        )
        return user

class LoginSerializer(serializers.Serializer):
    email = serializers.CharField(help_text="Email address or 10-digit mobile number")
    password = serializers.CharField()
