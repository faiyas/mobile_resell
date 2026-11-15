from decimal import Decimal
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from .models import ConditionCategory, ConditionOption, ModelPricingOverride
from .serializers import ConditionCategorySerializer, ConditionOptionSerializer, EstimateCalculationSerializer
from apps.catalog.models import StorageVariant

@api_view(['GET', 'POST'])
@permission_classes([AllowAny])
def condition_categories_view(request):
    if request.method == 'GET':
        categories = ConditionCategory.objects.filter(is_active=True)
        serializer = ConditionCategorySerializer(categories, many=True)
        return Response(serializer.data)
    
    elif request.method == 'POST':
        if not request.user.is_authenticated or request.user.role != 'ADMIN':
            return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)
        serializer = ConditionCategorySerializer(data=request.data)
        if serializer.is_valid():
            cat = serializer.save()
            return Response(ConditionCategorySerializer(cat).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['POST'])
@permission_classes([AllowAny])
def calculate_estimate_view(request):
    """
    Core dynamic valuation engine.
    Calculates estimated buyback price from base price and chosen defects/answers.
    """
    serializer = EstimateCalculationSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    variant_id = serializer.validated_data['variant_id']
    selected_codes = serializer.validated_data.get('selected_option_codes', [])

    try:
        variant = StorageVariant.objects.select_related('model__brand').get(id=variant_id, is_active=True)
    except StorageVariant.DoesNotExist:
        return Response({'detail': 'Storage variant not found'}, status=status.HTTP_404_NOT_FOUND)

    base_price = variant.base_price
    min_price = variant.min_price
    phone_model = variant.model

    # Fetch selected condition options
    options = ConditionOption.objects.filter(code__in=selected_codes, is_active=True)
    
    # Fetch overrides if any for this model
    overrides = {
        mo.option_id: mo.override_deduction_value
        for mo in ModelPricingOverride.objects.filter(phone_model=phone_model)
    }

    deductions_breakdown = []
    total_deduction = Decimal('0.00')

    for opt in options:
        if not opt.is_defect:
            continue

        if opt.id in overrides:
            amt = overrides[opt.id]
            rule_type = "Model Override"
        else:
            if opt.deduction_type == 'PERCENTAGE':
                amt = (base_price * opt.default_deduction_value) / Decimal('100.00')
                rule_type = f"{opt.default_deduction_value}% of Base"
            else:
                amt = opt.default_deduction_value
                rule_type = "Standard Flat"

        total_deduction += amt
        deductions_breakdown.append({
            'code': opt.code,
            'title': opt.title,
            'category': opt.category.name,
            'deduction_amount': float(amt),
            'rule_type': rule_type
        })

    estimated_price = max(base_price - total_deduction, min_price)

    return Response({
        'brand': phone_model.brand.name,
        'model': phone_model.name,
        'variant': f"{variant.ram} / {variant.storage}" if variant.ram else variant.storage,
        'base_price': float(base_price),
        'min_price': float(min_price),
        'total_deduction': float(total_deduction),
        'estimated_price': float(estimated_price),
        'currency': 'INR',
        'deductions': deductions_breakdown,
    })

@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def update_condition_option_view(request, pk):
    """Admin updates deduction price for a question option"""
    if request.user.role != 'ADMIN':
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)
    
    try:
        option = ConditionOption.objects.get(pk=pk)
    except ConditionOption.DoesNotExist:
        return Response({'detail': 'Option not found'}, status=status.HTTP_404_NOT_FOUND)

    serializer = ConditionOptionSerializer(option, data=request.data, partial=True)
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
