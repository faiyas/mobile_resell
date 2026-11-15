from rest_framework import serializers
from .models import DeviceInspection, InspectionPhoto
from apps.sales.models import PhoneSale

class InspectionPhotoInputSerializer(serializers.Serializer):
    label = serializers.CharField(max_length=100, default='Device Photo')
    image_base64 = serializers.CharField(help_text="Base64 encoded string")

class DeviceInspectionCreateSerializer(serializers.Serializer):
    sale_id = serializers.CharField()
    switches_on = serializers.BooleanField(default=True)
    screen_working = serializers.BooleanField(default=True)
    screen_glass_broken = serializers.BooleanField(default=False)
    touch_working = serializers.BooleanField(default=True)
    camera_working = serializers.BooleanField(default=True)
    battery_healthy = serializers.BooleanField(default=True)
    body_condition = serializers.ChoiceField(choices=['FLAWLESS', 'GOOD', 'FAIR', 'HEAVY_WEAR'], default='GOOD')
    cloud_locks_removed = serializers.BooleanField(default=True)
    imei_verified = serializers.BooleanField(default=True)
    verified_imei = serializers.CharField(max_length=30)
    customer_id_verified = serializers.BooleanField(default=True)
    suggested_final_price = serializers.DecimalField(max_digits=10, decimal_places=2)
    inspector_notes = serializers.CharField(required=False, allow_blank=True)
    photos = InspectionPhotoInputSerializer(many=True, required=False, default=list)
