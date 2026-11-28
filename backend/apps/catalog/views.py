from django.db.models import Prefetch
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from .models import DeviceCategory, Brand, DeviceSeries, PhoneModel, StorageVariant, CMSHomeSection, BusinessSetting
from .serializers import (
    DeviceCategorySerializer, BrandSerializer, BrandBasicSerializer, 
    DeviceSeriesSerializer, PhoneModelSerializer, StorageVariantSerializer,
    CMSHomeSectionSerializer, BusinessSettingSerializer
)

def is_admin_user(user):
    if not user or not user.is_authenticated:
        return False
    role_str = str(getattr(user, 'role', '') or '').strip().upper()
    return role_str in ['ADMIN', 'SUPER_ADMIN'] or bool(getattr(user, 'is_staff', False)) or bool(getattr(user, 'is_superuser', False))

# ================= 1. DEVICE CATEGORIES (Mobile, Tablet, Laptop, Watch, Dead Phone) =================
@api_view(['GET', 'POST'])
@permission_classes([AllowAny])
def categories_list_view(request):
    if request.method == 'GET':
        from django.db.models import Count
        show_all = request.GET.get('all', 'false').lower() == 'true'
        if show_all and is_admin_user(request.user):
            categories = DeviceCategory.objects.all()
        else:
            categories = DeviceCategory.objects.filter(is_active=True)
        categories = categories.annotate(annotated_brands_count=Count('brands'))
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
            brands = brands.select_related('category').prefetch_related(
                Prefetch('models', queryset=PhoneModel.objects.filter(is_active=True).prefetch_related('variants'))
            )
            serializer = BrandSerializer(brands, many=True)
        else:
            from django.db.models import Count
            brands = brands.select_related('category').annotate(annotated_models_count=Count('models'))
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
        from django.db.models import Max, Count
        brand_id = request.GET.get('brand')
        queryset = DeviceSeries.objects.filter(is_active=True).select_related('brand').annotate(
            max_year=Max('models__release_year'),
            annotated_models_count=Count('models'),
        ).order_by('-max_year', 'display_order', 'name')
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
        # Cascade delete all models & variants belonging to this series
        PhoneModel.objects.filter(series=series).delete()
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

        search_query = request.GET.get('search')
        if search_query:
            queryset = queryset.filter(name__icontains=search_query)

        # Pagination support (default 24 per page)
        from django.core.paginator import Paginator, EmptyPage
        page = request.GET.get('page')
        try:
            page_size = min(max(int(request.GET.get('page_size', 24)), 1), 100)
        except (ValueError, TypeError):
            page_size = 24

        show_all = request.GET.get('all', 'false').lower() == 'true'

        if not show_all and (page or not brand_id or is_admin_user(request.user)):
            page_num = int(page) if page and str(page).isdigit() else 1
            paginator = Paginator(queryset.order_by('-release_year', 'name'), page_size)
            try:
                page_obj = paginator.page(page_num)
            except EmptyPage:
                page_obj = []
            serializer = PhoneModelSerializer(page_obj, many=True)
            return Response({
                'count': paginator.count,
                'total_pages': paginator.num_pages,
                'current_page': page_num,
                'page_size': page_size,
                'has_next': page_obj.has_next() if hasattr(page_obj, 'has_next') else False,
                'has_previous': page_obj.has_previous() if hasattr(page_obj, 'has_previous') else False,
                'results': serializer.data
            })

        serializer = PhoneModelSerializer(queryset.order_by('-release_year', 'name'), many=True)
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
        brand_id = request.GET.get('brand')
        series_id = request.GET.get('series')
        show_all = request.GET.get('all', 'false').lower() == 'true'
        
        if show_all and is_admin_user(request.user):
            queryset = StorageVariant.objects.all().select_related('model__brand', 'model__series')
        else:
            queryset = StorageVariant.objects.filter(is_active=True).select_related('model__brand', 'model__series')

        if model_id:
            queryset = queryset.filter(model_id=model_id)
        if brand_id:
            queryset = queryset.filter(model__brand_id=brand_id)
        if series_id:
            queryset = queryset.filter(model__series_id=series_id)

        page = request.GET.get('page')
        page_size = int(request.GET.get('page_size', 10))
        paginate = request.GET.get('paginate', 'false').lower() == 'true'

        if paginate or (page and str(page).isdigit()):
            from django.core.paginator import Paginator, EmptyPage
            page_num = int(page) if page and str(page).isdigit() else 1
            paginator = Paginator(queryset.order_by('id'), page_size)
            try:
                page_obj = paginator.page(page_num)
            except EmptyPage:
                page_obj = []
            return Response({
                'count': paginator.count,
                'total_pages': paginator.num_pages,
                'current_page': page_num,
                'page_size': page_size,
                'results': StorageVariantSerializer(page_obj, many=True).data
            })

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
                try:
                    from apps.sales.audit import log_security_audit
                    log_security_audit(
                        user=request.user,
                        action='BASE_PRICE_CHANGED',
                        target_type='StorageVariant',
                        target_id=str(updated_variant.id),
                        details={
                            'model': str(updated_variant.model),
                            'storage': updated_variant.storage,
                            'old_price': str(old_price),
                            'new_price': str(new_price),
                            'reason': reason,
                        },
                        request=request
                    )
                except Exception:
                    pass

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
        show_all = request.GET.get('all', 'false').lower() == 'true'
        if show_all and is_admin_user(request.user):
            sections = CMSHomeSection.objects.all().order_by('display_order')
        else:
            sections = CMSHomeSection.objects.filter(is_active=True).order_by('display_order')
        return Response(CMSHomeSectionSerializer(sections, many=True).data)

    if not is_admin_user(request.user):
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

    if request.method in ['POST', 'PUT']:
        section_type = request.data.get('section_type')
        if not section_type:
            return Response({'detail': 'section_type is required'}, status=status.HTTP_400_BAD_REQUEST)

        existing = CMSHomeSection.objects.filter(section_type=section_type).first()

        data_json = request.data.get('data_json')
        if data_json is None:
            data_json = existing.data_json if existing else {}
        elif isinstance(data_json, dict) and existing and isinstance(existing.data_json, dict):
            # Preserve existing slides if not provided in update
            if 'slides' not in data_json and 'slides' in existing.data_json:
                data_json['slides'] = existing.data_json['slides']

        title = request.data.get('title')
        if title is None and existing:
            title = existing.title
        elif title is None:
            title = 'Hero Banners'

        subtitle = request.data.get('subtitle')
        if subtitle is None and existing:
            subtitle = existing.subtitle
        elif subtitle is None:
            subtitle = ''

        display_order = request.data.get('display_order')
        if display_order is None and existing:
            display_order = existing.display_order
        elif display_order is None:
            display_order = 0

        is_active = request.data.get('is_active')
        if is_active is None and existing:
            is_active = existing.is_active
        elif is_active is None:
            is_active = True

        section, _ = CMSHomeSection.objects.update_or_create(
            section_type=section_type,
            defaults={
                'title': title,
                'subtitle': subtitle,
                'data_json': data_json,
                'display_order': display_order,
                'is_active': is_active,
            }
        )
        return Response(CMSHomeSectionSerializer(section).data)

# ================= 7. SYSTEM SETTINGS =================
@api_view(['GET', 'POST', 'PUT'])
@permission_classes([AllowAny])
def system_settings_view(request):
    if request.method == 'GET':
        section, created = CMSHomeSection.objects.get_or_create(
            section_type='SYSTEM_SETTINGS',
            defaults={
                'title': 'Operations & Buyback Settings',
                'data_json': {
                    'minPayoutFloor': 500,
                    'doorstepFee': 0,
                    'inspectionWindowHours': 24,
                    'autoAssignAgents': True,
                    'whatsappAlerts': True,
                    'pincodesServed': '605001, 605002, 605003, 605004, 605005, 605006, 605007, 605008, 605009, 605010, 605014',
                    'supportPhone': '+91 99885 52211',
                    'companyName': 'Dolly Buyback Services Pvt Ltd'
                }
            }
        )
        return Response(section.data_json or {})

    if not is_admin_user(request.user):
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

    data = request.data if isinstance(request.data, dict) else {}
    existing = CMSHomeSection.objects.filter(section_type='SYSTEM_SETTINGS').first()
    old_version = ''
    if existing and isinstance(existing.data_json, dict):
        old_version = str(existing.data_json.get('latest_version', '') or '').strip()

    section, _ = CMSHomeSection.objects.update_or_create(
        section_type='SYSTEM_SETTINGS',
        defaults={
            'title': 'Operations & Buyback Settings',
            'data_json': data
        }
    )

    new_version = str(data.get('latest_version', '') or '').strip()
    if new_version and new_version != old_version:
        try:
            from apps.sales.views import create_system_notification
            release_notes = str(data.get('release_notes', '') or '').strip()
            apk_url = str(data.get('apk_download_url', '') or '').strip()
            msg = f"A new version (v{new_version.lstrip('vV')}) of Dolly is available. Tap to update now."
            if release_notes:
                msg = f"{msg}\n{release_notes}"
            create_system_notification(
                title=f"🚀 Dolly Update Available (v{new_version.lstrip('vV')})",
                message=msg,
                category='SYSTEM',
                target_audience='ALL',
                redirect_route=apk_url,
                action_type='APP_UPDATE',
            )
        except Exception as e:
            print(f"Failed to broadcast app update notification: {e}")

    return Response(section.data_json)

# ================= 7.1 BUSINESS SETTINGS (ZERO HARDCODING) =================
@api_view(['GET', 'POST', 'PUT'])
@permission_classes([AllowAny])
def business_settings_view(request):
    """Centralized database-driven business settings (contacts, working hours, links, policies)"""
    setting = BusinessSetting.objects.first()
    if not setting:
        setting = BusinessSetting.objects.create()

    if request.method == 'GET':
        return Response(BusinessSettingSerializer(setting).data)

    if not is_admin_user(request.user):
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

    serializer = BusinessSettingSerializer(setting, data=request.data, partial=True)
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# ================= 8. BULK DELETE & OFFLINE SYNC BUNDLE =================
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def catalog_bulk_delete_view(request):
    """Bulk delete brands, series (with models), models, or variants (Admin only)"""
    if not is_admin_user(request.user):
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

    target = str(request.data.get('target', '')).strip().lower()
    ids = request.data.get('ids', [])
    delete_all = bool(request.data.get('all', False))

    if not delete_all and (not isinstance(ids, list) or len(ids) == 0):
        return Response({'detail': 'Provide ids list or set all=true'}, status=status.HTTP_400_BAD_REQUEST)

    from django.db import transaction
    from apps.sales.models import PhoneSale
    with transaction.atomic():
        if target == 'brands':
            qs = Brand.objects.all() if delete_all else Brand.objects.filter(id__in=ids)
            PhoneSale.objects.filter(variant__model__brand__in=qs).update(variant=None)
            count = qs.count()
            qs.delete()  # Cascades to series, models, variants, and brand-specific condition steps
        elif target == 'series':
            qs = DeviceSeries.objects.all() if delete_all else DeviceSeries.objects.filter(id__in=ids)
            PhoneSale.objects.filter(variant__model__series__in=qs).update(variant=None)
            count = qs.count()
            PhoneModel.objects.filter(series__in=qs).delete()
            qs.delete()
        elif target == 'models':
            qs = PhoneModel.objects.all() if delete_all else PhoneModel.objects.filter(id__in=ids)
            PhoneSale.objects.filter(variant__model__in=qs).update(variant=None)
            count = qs.count()
            qs.delete()  # Cascades to variants
        elif target == 'variants':
            qs = StorageVariant.objects.all() if delete_all else StorageVariant.objects.filter(id__in=ids)
            PhoneSale.objects.filter(variant__in=qs).update(variant=None)
            count = qs.count()
            qs.delete()
        else:
            return Response({'detail': f'Unsupported target: {target}'}, status=status.HTTP_400_BAD_REQUEST)

    return Response({'deleted': count, 'target': target, 'message': f'Successfully deleted {count} {target}'})


@api_view(['GET'])
@permission_classes([AllowAny])
def catalog_sync_bundle_view(request):
    """
    Lightweight single-request offline sync bundle for mobile app background sync.
    Returns active series, models + variants (without heavy base64 images), and condition steps/options.
    """
    from django.db.models import Max
    from apps.valuation.models import ConditionCategory
    from apps.valuation.serializers import ConditionCategorySerializer

    series_qs = DeviceSeries.objects.filter(is_active=True).annotate(
        max_year=Max('models__release_year')
    ).order_by('-max_year', 'display_order', 'name').values('id', 'brand_id', 'name', 'display_order')
    models_qs = PhoneModel.objects.filter(is_active=True).prefetch_related('variants').order_by('-release_year', 'name')

    models_data = []
    for m in models_qs:
        variants_list = [
            {
                'id': v.id,
                'model': m.id,
                'ram': v.ram,
                'storage': v.storage,
                'base_price': str(v.base_price),
                'min_price': str(v.min_price),
                'is_active': v.is_active,
            }
            for v in m.variants.all() if v.is_active
        ]
        model_entry = {
            'id': m.id,
            'brand': m.brand_id,
            'series': m.series_id,
            'name': m.name,
            'slug': m.slug,
            'release_year': m.release_year,
            'has_warranty': m.has_warranty,
            'is_active': m.is_active,
            'variants': variants_list,
        }
        if m.image_base64:
            model_entry['image_base64'] = m.image_base64
        models_data.append(model_entry)

    series_data = [
        {
            'id': s['id'],
            'brand': s['brand_id'],
            'name': s['name'],
            'display_order': s['display_order'],
            'is_active': True,
        }
        for s in series_qs
    ]

    conditions_qs = ConditionCategory.objects.filter(is_active=True).prefetch_related('options').order_by('step_number', 'display_order')
    conditions_data = ConditionCategorySerializer(conditions_qs, many=True).data

    from apps.valuation.models import EvaluationTriageQuestion
    from apps.valuation.serializers import EvaluationTriageQuestionSerializer
    triage_qs = EvaluationTriageQuestion.objects.filter(is_active=True).order_by('display_order')
    triage_data = EvaluationTriageQuestionSerializer(triage_qs, many=True).data

    return Response({
        'series': series_data,
        'models': models_data,
        'conditions': conditions_data,
        'triage_questions': triage_data,
    })

# ================= 8. FAST CATALOG STATS / COUNTS (Instant 1ms response) =================
@api_view(['GET'])
@permission_classes([AllowAny])
def catalog_stats_view(request):
    """Fast endpoint returning entity counts for admin dashboard sidebar without serializing heavy models."""
    from apps.valuation.models import ConditionOption
    return Response({
        'deviceCategories': DeviceCategory.objects.count(),
        'brands': Brand.objects.count(),
        'models': PhoneModel.objects.count(),
        'variants': StorageVariant.objects.count(),
        'cms': CMSHomeSection.objects.count(),
        'options': ConditionOption.objects.count(),
    })

