from decimal import Decimal
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from django.db import transaction
from django.shortcuts import get_object_or_404
from .models import PhoneSale, PhoneSaleConditionAnswer
from .serializers import PhoneSaleDetailSerializer, PhoneSaleListSerializer, PhoneSaleCreateSerializer
from apps.catalog.models import StorageVariant
from apps.valuation.models import ConditionOption, ModelPricingOverride
from apps.accounts.models import User

@api_view(['GET', 'POST'])
@permission_classes([AllowAny])
def sales_list_create_view(request):
    if request.method == 'GET':
        user = request.user
        queryset = PhoneSale.objects.all().select_related('variant__model__brand', 'assigned_agent')

        # Role-based filtering
        if not user.is_authenticated:
            # Guest lookup by phone or sale_code
            phone = request.GET.get('phone')
            sale_code = request.GET.get('sale_code')
            if not phone and not sale_code:
                return Response({'detail': 'Authentication or phone/sale_code query required'}, status=status.HTTP_401_UNAUTHORIZED)
            if phone:
                queryset = queryset.filter(customer_phone=phone)
            if sale_code:
                queryset = queryset.filter(sale_code=sale_code)
        elif user.role == 'CUSTOMER':
            queryset = queryset.filter(customer=user) | queryset.filter(customer_phone=user.phone)
        elif user.role == 'COLLECTION_AGENT':
            # Collection agent sees assigned tasks OR unassigned bookings needing pickup
            queryset = queryset.filter(assigned_agent=user) | queryset.filter(assigned_agent__isnull=True, status__in=['SUBMITTED', 'PICKUP_SCHEDULED'])
        # ADMIN sees all

        status_filter = request.GET.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)

        is_full = request.GET.get('full', 'false').lower() == 'true'
        if is_full:
            serializer = PhoneSaleDetailSerializer(queryset, many=True)
        else:
            serializer = PhoneSaleListSerializer(queryset, many=True)
        return Response(serializer.data)

    elif request.method == 'POST':
        serializer = PhoneSaleCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        data = serializer.validated_data
        variant_id = data.get('variant_id')
        is_custom = data.get('is_custom_device', False) or (variant_id is None or variant_id == 0)
        selected_codes = data.get('selected_option_codes', [])
        custom_notes = data.get('other_defects_notes', '')
        custom_step_notes = data.get('custom_step_notes', {})

        variant = None
        if variant_id:
            try:
                variant = StorageVariant.objects.select_related('model__brand').get(id=variant_id, is_active=True)
            except StorageVariant.DoesNotExist:
                if not is_custom:
                    return Response({'detail': 'Variant not found'}, status=status.HTTP_404_NOT_FOUND)

        if variant:
            base_price = variant.base_price
            min_price = variant.min_price
            phone_model = variant.model
            overrides = {
                mo.option_id: mo.override_deduction_value
                for mo in ModelPricingOverride.objects.filter(phone_model=phone_model)
            }
        else:
            is_custom = True
            base_price = data.get('custom_expected_price') or Decimal('8000.00')
            min_price = Decimal('500.00')
            overrides = {}

        # Calculate exact price per valuation engine rules
        options = ConditionOption.objects.filter(code__in=selected_codes, is_active=True)
        total_deduction = Decimal('0.00')
        answers_to_create = []

        for opt in options:
            if not opt.is_defect:
                continue
            if opt.id in overrides:
                amt = overrides[opt.id]
            else:
                if opt.deduction_type == 'PERCENTAGE':
                    amt = (base_price * opt.default_deduction_value) / Decimal('100.00')
                else:
                    amt = opt.default_deduction_value
            total_deduction += amt
            answers_to_create.append((opt, amt, ''))

        estimated_price = max(base_price - total_deduction, min_price)

        with transaction.atomic():
            customer_user = request.user if request.user.is_authenticated else None
            sale = PhoneSale.objects.create(
                customer=customer_user,
                customer_name=data['customer_name'],
                customer_phone=data['customer_phone'],
                customer_email=data.get('customer_email', ''),
                variant=variant,
                is_custom_device=is_custom,
                custom_device_name=data.get('custom_device_name', '') or ('Custom Device' if is_custom else ''),
                custom_device_category=data.get('custom_device_category', 'Others') if is_custom else '',
                custom_device_specs=data.get('custom_device_specs', '') if is_custom else '',
                other_defects_notes=custom_notes,
                base_price=base_price,
                estimated_price=estimated_price,
                status='SUBMITTED',
                pickup_address=data['pickup_address'],
                pickup_city=data.get('pickup_city', 'City'),
                pickup_pincode=data['pickup_pincode'],
                pickup_date=data.get('pickup_date'),
                pickup_slot=data.get('pickup_slot', 'Morning (10:00 AM - 1:00 PM)'),
                beneficiary_type=data.get('beneficiary_type', 'UPI'),
                beneficiary_name=data['beneficiary_name'],
                beneficiary_upi_id=data.get('beneficiary_upi_id', ''),
                beneficiary_account_no=data.get('beneficiary_account_no', ''),
                beneficiary_ifsc=data.get('beneficiary_ifsc', ''),
            )

            for opt, amt, custom_t in answers_to_create:
                PhoneSaleConditionAnswer.objects.create(
                    sale=sale,
                    option=opt,
                    step_name=opt.category.name if opt.category else '',
                    custom_text=custom_t,
                    deduction_applied=amt
                )

            # Record per-step custom free-text notes
            if isinstance(custom_step_notes, dict):
                for step_name, note in custom_step_notes.items():
                    if note and str(note).strip():
                        PhoneSaleConditionAnswer.objects.create(
                            sale=sale,
                            option=None,
                            step_name=str(step_name).strip(),
                            custom_text=str(note).strip(),
                            deduction_applied=Decimal('0.00')
                        )

        return Response(PhoneSaleDetailSerializer(sale).data, status=status.HTTP_201_CREATED)

@api_view(['GET'])
@permission_classes([AllowAny])
def sale_detail_view(request, pk):
    try:
        # pk can be UUID or sale_code
        if len(str(pk)) == 36:
            sale = PhoneSale.objects.get(id=pk)
        else:
            sale = PhoneSale.objects.get(sale_code=pk)
    except PhoneSale.DoesNotExist:
        return Response({'detail': 'Sale not found'}, status=status.HTTP_404_NOT_FOUND)

    serializer = PhoneSaleDetailSerializer(sale)
    return Response(serializer.data)

@api_view(['POST'])
@permission_classes([AllowAny])
def accept_final_offer_view(request, pk):
    """Customer accepts the revised final offer after inspection"""
    sale = get_object_or_404(PhoneSale, id=pk)
    if sale.status != 'FINAL_OFFER_SENT':
        return Response({'detail': f'Cannot accept offer in state: {sale.status}'}, status=status.HTTP_400_BAD_REQUEST)

    sale.status = 'CUSTOMER_ACCEPTED'
    sale.save()
    return Response({'message': 'Offer accepted successfully', 'status': sale.status, 'sale': PhoneSaleDetailSerializer(sale).data})

@api_view(['POST'])
@permission_classes([AllowAny])
def reject_final_offer_view(request, pk):
    """Customer rejects revised offer (phone returned)"""
    sale = get_object_or_404(PhoneSale, id=pk)
    sale.status = 'CUSTOMER_REJECTED'
    sale.save()
    return Response({'message': 'Offer rejected. Device return will be initiated.', 'status': sale.status})

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def assign_pickup_view(request, pk):
    """Admin or Collection Agent schedules pickup and assigns agent"""
    if request.user.role not in ['ADMIN', 'COLLECTION_AGENT']:
        return Response({'detail': 'Staff access required'}, status=status.HTTP_403_FORBIDDEN)

    sale = get_object_or_404(PhoneSale, id=pk)
    agent_id = request.data.get('agent_id')
    pickup_date = request.data.get('pickup_date')
    pickup_slot = request.data.get('pickup_slot')

    if request.user.role == 'COLLECTION_AGENT':
        sale.assigned_agent = request.user
    elif agent_id:
        agent = get_object_or_404(User, id=agent_id, role='COLLECTION_AGENT')
        sale.assigned_agent = agent

    if pickup_date:
        sale.pickup_date = pickup_date
    if pickup_slot:
        sale.pickup_slot = pickup_slot

    sale.status = 'PICKUP_SCHEDULED'
    sale.save()
    return Response({'message': 'Pickup scheduled successfully', 'sale': PhoneSaleDetailSerializer(sale).data})

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def transfer_ownership_view(request, pk):
    """Agent/Admin records IMEI and physical device handover"""
    if request.user.role not in ['ADMIN', 'COLLECTION_AGENT']:
        return Response({'detail': 'Staff access required'}, status=status.HTTP_403_FORBIDDEN)

    sale = get_object_or_404(PhoneSale, id=pk)
    imei = request.data.get('imei')
    if not imei:
        return Response({'detail': 'Valid IMEI is required'}, status=status.HTTP_400_BAD_REQUEST)

    sale.imei_number = imei
    sale.customer_handover_signed = True
    sale.status = 'OWNERSHIP_TRANSFERRED'
    sale.save()
    return Response({'message': 'Ownership successfully transferred to company', 'sale': PhoneSaleDetailSerializer(sale).data})

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def admin_approve_final_offer_view(request, pk):
    """Admin reviews inspection and sets approved final price"""
    if request.user.role != 'ADMIN':
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

    sale = get_object_or_404(PhoneSale, id=pk)
    approved_price = request.data.get('approved_price')
    if not approved_price:
        return Response({'detail': 'Approved price is required'}, status=status.HTTP_400_BAD_REQUEST)

    sale.final_price = Decimal(str(approved_price))
    
    # If final price == estimated price, can move directly to accepted or final offer sent
    if sale.final_price == sale.estimated_price:
        sale.status = 'OWNERSHIP_TRANSFERRED'
    else:
        sale.status = 'FINAL_OFFER_SENT'
    
    sale.save()
    return Response({'message': 'Final offer updated', 'sale': PhoneSaleDetailSerializer(sale).data})
