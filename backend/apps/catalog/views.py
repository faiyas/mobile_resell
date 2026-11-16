from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from .models import Brand, PhoneModel, StorageVariant
from .serializers import BrandSerializer, BrandBasicSerializer, PhoneModelSerializer, StorageVariantSerializer

@api_view(['GET', 'POST'])
@permission_classes([AllowAny])
def brands_list_view(request):
    if request.method == 'GET':
        include_models = request.GET.get('include_models', 'false').lower() == 'true'
        show_all = request.GET.get('all', 'false').lower() == 'true'
        if show_all and request.user.is_authenticated and request.user.role == 'ADMIN':
            brands = Brand.objects.all()
        else:
            brands = Brand.objects.filter(is_active=True)

        if include_models:
            serializer = BrandSerializer(brands, many=True)
        else:
            serializer = BrandBasicSerializer(brands, many=True)
        return Response(serializer.data)

    elif request.method == 'POST':
        # Admin can add brands with Base64 logos
        if not request.user.is_authenticated or request.user.role != 'ADMIN':
            return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)
        serializer = BrandBasicSerializer(data=request.data)
        if serializer.is_valid():
            brand = serializer.save()
            return Response(BrandBasicSerializer(brand).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET', 'PUT', 'DELETE'])
@permission_classes([AllowAny])
def brand_detail_view(request, pk):
    try:
        brand = Brand.objects.get(pk=pk)
    except Brand.DoesNotExist:
        return Response({'detail': 'Brand not found'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        serializer = BrandSerializer(brand)
        return Response(serializer.data)

    if not request.user.is_authenticated or request.user.role != 'ADMIN':
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

    if request.method == 'PUT':
        serializer = BrandBasicSerializer(brand, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    elif request.method == 'DELETE':
        brand.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

@api_view(['GET', 'POST'])
@permission_classes([AllowAny])
def models_list_view(request):
    if request.method == 'GET':
        brand_id = request.GET.get('brand')
        show_all = request.GET.get('all', 'false').lower() == 'true'
        if show_all and request.user.is_authenticated and request.user.role == 'ADMIN':
            queryset = PhoneModel.objects.all().select_related('brand')
        else:
            queryset = PhoneModel.objects.filter(is_active=True).select_related('brand')

        if brand_id:
            queryset = queryset.filter(brand_id=brand_id)
        serializer = PhoneModelSerializer(queryset, many=True)
        return Response(serializer.data)

    elif request.method == 'POST':
        if not request.user.is_authenticated or request.user.role != 'ADMIN':
            return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)
        serializer = PhoneModelSerializer(data=request.data)
        if serializer.is_valid():
            model_obj = serializer.save()
            return Response(PhoneModelSerializer(model_obj).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET', 'PUT', 'DELETE'])
@permission_classes([AllowAny])
def model_detail_view(request, pk):
    try:
        phone_model = PhoneModel.objects.get(pk=pk)
    except PhoneModel.DoesNotExist:
        return Response({'detail': 'Phone model not found'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        serializer = PhoneModelSerializer(phone_model)
        return Response(serializer.data)

    if not request.user.is_authenticated or request.user.role != 'ADMIN':
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

    if request.method == 'PUT':
        serializer = PhoneModelSerializer(phone_model, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    elif request.method == 'DELETE':
        phone_model.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

@api_view(['GET', 'POST'])
@permission_classes([AllowAny])
def variants_list_create_view(request):
    if request.method == 'GET':
        model_id = request.GET.get('model')
        show_all = request.GET.get('all', 'false').lower() == 'true'
        
        if show_all and request.user.is_authenticated and request.user.role == 'ADMIN':
            queryset = StorageVariant.objects.all().select_related('model__brand')
        else:
            queryset = StorageVariant.objects.filter(is_active=True).select_related('model__brand')

        if model_id:
            queryset = queryset.filter(model_id=model_id)

        serializer = StorageVariantSerializer(queryset, many=True)
        return Response(serializer.data)

    elif request.method == 'POST':
        if not request.user.is_authenticated or request.user.role != 'ADMIN':
            return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)
        serializer = StorageVariantSerializer(data=request.data)
        if serializer.is_valid():
            variant = serializer.save()
            return Response(StorageVariantSerializer(variant).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET', 'PUT', 'PATCH', 'DELETE'])
@permission_classes([AllowAny])
def variant_detail_view(request, pk):
    try:
        variant = StorageVariant.objects.select_related('model__brand').get(pk=pk)
    except StorageVariant.DoesNotExist:
        return Response({'detail': 'Storage variant not found'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        serializer = StorageVariantSerializer(variant)
        return Response(serializer.data)

    if not request.user.is_authenticated or request.user.role != 'ADMIN':
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

    if request.method in ['PUT', 'PATCH']:
        old_price = variant.base_price
        serializer = StorageVariantSerializer(variant, data=request.data, partial=True)
        if serializer.is_valid():
            updated_variant = serializer.save()
            new_price = updated_variant.base_price

            # If base_price changed, record in PriceHistory
            if old_price != new_price:
                from apps.valuation.models import PriceHistory
                reason = request.data.get('change_reason', 'Admin base price update')
                PriceHistory.objects.create(
                    variant=updated_variant,
                    old_base_price=old_price,
                    new_base_price=new_price,
                    changed_by=request.user,
                    reason=reason
                )

            return Response(StorageVariantSerializer(updated_variant).data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    elif request.method == 'DELETE':
        variant.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
