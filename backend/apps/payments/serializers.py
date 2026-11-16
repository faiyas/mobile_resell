from rest_framework import serializers
from .models import Payment
from apps.sales.models import PhoneSale

class PaymentRecordSerializer(serializers.Serializer):
    sale_id = serializers.CharField()
    amount = serializers.DecimalField(max_digits=10, decimal_places=2)
    payment_method = serializers.ChoiceField(choices=['GPAY', 'PHONEPE', 'PAYTM', 'BHIM', 'IMPS', 'CASH'], default='GPAY')
    utr_number = serializers.CharField(max_length=50)
    payment_proof_base64 = serializers.CharField(help_text="Base64 encoded screenshot of payment confirmation")
    admin_notes = serializers.CharField(required=False, allow_blank=True, default='')

    def validate_utr_number(self, value):
        cleaned_utr = value.strip().upper()
        if Payment.objects.filter(utr_number=cleaned_utr).exists():
            raise serializers.ValidationError(f"A payment with UTR reference '{cleaned_utr}' has already been recorded!")
        return cleaned_utr

class PaymentDetailSerializer(serializers.ModelSerializer):
    sale_code = serializers.ReadOnlyField(source='sale.sale_code')
    model_name = serializers.ReadOnlyField(source='sale.variant.model.name')
    brand_name = serializers.ReadOnlyField(source='sale.variant.model.brand.name')
    paid_by_name = serializers.ReadOnlyField(source='paid_by.full_name')

    class Meta:
        model = Payment
        fields = [
            'id', 'sale', 'sale_code', 'model_name', 'brand_name',
            'amount', 'payment_method', 'beneficiary_name',
            'beneficiary_upi_id', 'beneficiary_account_no', 'beneficiary_ifsc',
            'utr_number', 'payment_proof_base64', 'admin_notes',
            'paid_by_name', 'paid_at', 'is_verified'
        ]

class PaymentListSerializer(serializers.ModelSerializer):
    """Fast list view of payments without transmitting heavy Base64 screenshot proof"""
    sale_code = serializers.ReadOnlyField(source='sale.sale_code')
    model_name = serializers.ReadOnlyField(source='sale.variant.model.name')
    brand_name = serializers.ReadOnlyField(source='sale.variant.model.brand.name')
    paid_by_name = serializers.ReadOnlyField(source='paid_by.full_name')
    has_proof = serializers.SerializerMethodField()

    class Meta:
        model = Payment
        fields = [
            'id', 'sale', 'sale_code', 'model_name', 'brand_name',
            'amount', 'payment_method', 'beneficiary_name',
            'beneficiary_upi_id', 'beneficiary_account_no', 'beneficiary_ifsc',
            'utr_number', 'has_proof', 'admin_notes',
            'paid_by_name', 'paid_at', 'is_verified'
        ]

    def get_has_proof(self, obj):
        return bool(obj.payment_proof_base64)
