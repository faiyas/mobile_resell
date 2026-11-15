from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.db import transaction
from django.shortcuts import get_object_or_404
from .models import DeviceInspection, InspectionPhoto
from .serializers import DeviceInspectionCreateSerializer
from apps.sales.models import PhoneSale
from apps.sales.serializers import DeviceInspectionSerializer

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def record_inspection_view(request):
    """
    Staff / Collection Agent records physical device inspection,
    attaches Base64 photos, verifies IMEI and cloud locks.
    """
    if request.user.role not in ['ADMIN', 'COLLECTION_AGENT']:
        return Response({'detail': 'Staff access required'}, status=status.HTTP_403_FORBIDDEN)

    serializer = DeviceInspectionCreateSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    data = serializer.validated_data
    sale_id = data['sale_id']
    sale = get_object_or_404(PhoneSale, id=sale_id)

    with transaction.atomic():
        # Check if already inspected, update or create
        inspection, created = DeviceInspection.objects.update_or_create(
            sale=sale,
            defaults={
                'inspected_by': request.user,
                'switches_on': data['switches_on'],
                'screen_working': data['screen_working'],
                'screen_glass_broken': data['screen_glass_broken'],
                'touch_working': data['touch_working'],
                'camera_working': data['camera_working'],
                'battery_healthy': data['battery_healthy'],
                'body_condition': data['body_condition'],
                'cloud_locks_removed': data['cloud_locks_removed'],
                'imei_verified': data['imei_verified'],
                'verified_imei': data['verified_imei'],
                'customer_id_verified': data['customer_id_verified'],
                'suggested_final_price': data['suggested_final_price'],
                'inspector_notes': data.get('inspector_notes', ''),
            }
        )

        # Save Base64 photos
        photos_data = data.get('photos', [])
        for photo_item in photos_data:
            InspectionPhoto.objects.create(
                inspection=inspection,
                label=photo_item.get('label', 'Device Photo'),
                image_base64=photo_item['image_base64']
            )

        # Update sale
        sale.imei_number = data['verified_imei']
        sale.final_price = data['suggested_final_price']
        
        # If suggested price == estimated price, advance smoothly, otherwise notify customer
        if sale.suggested_final_price_matches_estimate():
            sale.status = 'OWNERSHIP_TRANSFERRED'
        else:
            sale.status = 'FINAL_OFFER_SENT'
        
        sale.save()

    return Response({
        'message': 'Inspection successfully recorded',
        'inspection': DeviceInspectionSerializer(inspection).data,
        'sale_status': sale.status
    }, status=status.HTTP_201_CREATED)

# Helper method on PhoneSale to compare prices cleanly
def suggested_final_price_matches_estimate(self):
    return self.final_price is not None and self.final_price == self.estimated_price

PhoneSale.suggested_final_price_matches_estimate = suggested_final_price_matches_estimate
