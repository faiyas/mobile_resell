from django.db.models import Prefetch
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from .models import DeviceCategory, Brand, DeviceSeries, PhoneModel, StorageVariant, CMSHomeSection
from .serializers import (
    DeviceCategorySerializer, BrandSerializer, BrandBasicSerializer, 
    DeviceSeriesSerializer, PhoneModelSerializer, StorageVariantSerializer,
    CMSHomeSectionSerializer
)

def is_admin_user(user):
    return user and user.is_authenticated and (user.role in ['ADMIN', 'SUPER_ADMIN'] or user.is_staff or user.is_superuser)

# ================= 1. DEVICE CATEGORIES (Mobile, Tablet, Laptop, Watch, Dead Phone) =================
@api_view(['GET', 'POST'])
@permission_classes([AllowAny])
def categories_list_view(request):
    if request.method == 'GET':
        show_all = request.GET.get('all', 'false').lower() == 'true'
        if show_all and is_admin_user(request.user):
            categories = DeviceCategory.objects.all()
        else:
            categories = DeviceCategory.objects.filter(is_active=True)
        return Response(DeviceCategorySerializer(categories, many=True).data)

    elif request.method == 'POST':
        if not is_admin_user(request.user):
            return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)
        serializer = DeviceCategorySerializer(data=request.data)
        if serializer.is_valid():
            cat = serializer.save()
            return Response(DeviceCategorySerializer(cat).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET', 'PUT', 'DELETE'])
@permission_classes([AllowAny])
def category_detail_view(request, pk):
    try:
        category = DeviceCategory.objects.get(pk=pk)
    except DeviceCategory.DoesNotExist:
        return Response({'detail': 'Category not found'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        return Response(DeviceCategorySerializer(category).data)

    if not is_admin_user(request.user):
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

    if request.method == 'PUT':
        serializer = DeviceCategorySerializer(category, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    elif request.method == 'DELETE':
        category.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

# ================= 2. BRANDS =================
@api_view(['GET', 'POST'])
@permission_classes([AllowAny])
def brands_list_view(request):
    if request.method == 'GET':
        include_models = request.GET.get('include_models', 'false').lower() == 'true'
        show_all = request.GET.get('all', 'false').lower() == 'true'
        category_id = request.GET.get('category')
        
        if show_all and is_admin_user(request.user):
            brands = Brand.objects.all()
        else:
            brands = Brand.objects.filter(is_active=True)

        if category_id:
            brands = brands.filter(category_id=category_id)

        if include_models:
            brands = brands.prefetch_related(
                Prefetch('models', queryset=PhoneModel.objects.filter(is_active=True).prefetch_related('variants'))
            )
            serializer = BrandSerializer(brands, many=True)
        else:
            serializer = BrandBasicSerializer(brands, many=True)
        return Response(serializer.data)

    elif request.method == 'POST':
        if not is_admin_user(request.user):
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

    if not is_admin_user(request.user):
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

# ================= 3. SERIES =================
@api_view(['GET', 'POST'])
@permission_classes([AllowAny])
def series_list_view(request):
    if request.method == 'GET':
        brand_id = request.GET.get('brand')
        queryset = DeviceSeries.objects.filter(is_active=True)
        if brand_id:
            queryset = queryset.filter(brand_id=brand_id)
        return Response(DeviceSeriesSerializer(queryset, many=True).data)

    elif request.method == 'POST':
        if not is_admin_user(request.user):
            return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)
        serializer = DeviceSeriesSerializer(data=request.data)
        if serializer.is_valid():
            series = serializer.save()
            return Response(DeviceSeriesSerializer(series).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET', 'PUT', 'DELETE'])
@permission_classes([AllowAny])
def series_detail_view(request, pk):
    try:
        series = DeviceSeries.objects.get(pk=pk)
    except DeviceSeries.DoesNotExist:
        return Response({'detail': 'Series not found'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        return Response(DeviceSeriesSerializer(series).data)

    if not is_admin_user(request.user):
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

    if request.method == 'PUT':
        serializer = DeviceSeriesSerializer(series, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    elif request.method == 'DELETE':
        series.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

# ================= 4. MODELS =================
@api_view(['GET', 'POST'])
@permission_classes([AllowAny])
def models_list_view(request):
    if request.method == 'GET':
        brand_id = request.GET.get('brand')
        series_id = request.GET.get('series')
        show_all = request.GET.get('all', 'false').lower() == 'true'
        if show_all and is_admin_user(request.user):
            queryset = PhoneModel.objects.all().select_related('brand', 'series').prefetch_related('variants')
        else:
            queryset = PhoneModel.objects.filter(is_active=True).select_related('brand', 'series').prefetch_related('variants')

        if brand_id:
            queryset = queryset.filter(brand_id=brand_id)
        if series_id:
            queryset = queryset.filter(series_id=series_id)

        serializer = PhoneModelSerializer(queryset, many=True)
        return Response(serializer.data)

    elif request.method == 'POST':
        if not is_admin_user(request.user):
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

    if not is_admin_user(request.user):
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

# ================= 5. STORAGE VARIANTS & BASE PRICES =================
@api_view(['GET', 'POST'])
@permission_classes([AllowAny])
def variants_list_create_view(request):
    if request.method == 'GET':
        model_id = request.GET.get('model')
        show_all = request.GET.get('all', 'false').lower() == 'true'
        
        if show_all and is_admin_user(request.user):
            queryset = StorageVariant.objects.all().select_related('model__brand')
        else:
            queryset = StorageVariant.objects.filter(is_active=True).select_related('model__brand')

        if model_id:
            queryset = queryset.filter(model_id=model_id)

        serializer = StorageVariantSerializer(queryset, many=True)
        return Response(serializer.data)

    elif request.method == 'POST':
        if not is_admin_user(request.user):
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

    if not is_admin_user(request.user):
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

    if request.method in ['PUT', 'PATCH']:
        old_price = variant.base_price
        serializer = StorageVariantSerializer(variant, data=request.data, partial=True)
        if serializer.is_valid():
            updated_variant = serializer.save()
            new_price = updated_variant.base_price

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

# ================= 6. DYNAMIC CMS HOMEPAGE BUILDER =================
@api_view(['GET', 'POST', 'PUT'])
@permission_classes([AllowAny])
def cms_sections_view(request):
    if request.method == 'GET':
        sections = CMSHomeSection.objects.filter(is_active=True).order_by('display_order')
        return Response(CMSHomeSectionSerializer(sections, many=True).data)

    if not is_admin_user(request.user):
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

    if request.method in ['POST', 'PUT']:
        section_type = request.data.get('section_type')
        section, _ = CMSHomeSection.objects.update_or_create(
            section_type=section_type,
            defaults={
                'title': request.data.get('title', ''),
                'subtitle': request.data.get('subtitle', ''),
                'data_json': request.data.get('data_json', {}),
                'display_order': request.data.get('display_order', 0),
                'is_active': request.data.get('is_active', True),
            }
        )
        return Response(CMSHomeSectionSerializer(section).data)
