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
        queryset = PhoneModel.objects.filter(is_active=True)
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

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_variant_view(request):
    if request.user.role != 'ADMIN':
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)
    serializer = StorageVariantSerializer(data=request.data)
    if serializer.is_valid():
        variant = serializer.save()
        return Response(StorageVariantSerializer(variant).data, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
