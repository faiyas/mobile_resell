from django.db import models
from django.db.models import Prefetch, Q, ProtectedError
from decimal import Decimal
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from .models import ConditionCategory, ConditionOption, ModelPricingOverride, PriceHistory
from .serializers import (
    ConditionCategorySerializer, ConditionOptionSerializer, 
    EstimateCalculationSerializer, PriceHistorySerializer
)
from apps.catalog.models import StorageVariant, Brand

@api_view(['GET', 'POST'])
@permission_classes([AllowAny])
def condition_categories_view(request):
    if request.method == 'GET':
        show_all = request.GET.get('all', 'false').lower() == 'true'
        device_cat = request.GET.get('device_category')
        brand_param = request.GET.get('brand')
        
        if show_all and getattr(request.user, 'is_admin_role', False):
            categories = ConditionCategory.objects.all()
        else:
            categories = ConditionCategory.objects.filter(is_active=True)

        if device_cat:
            if str(device_cat).isdigit():
                categories = categories.filter(device_category_id=int(device_cat))
            else:
                categories = categories.filter(device_category__slug=device_cat)

        if brand_param:
            if str(brand_param).isdigit():
                categories = categories.filter(Q(brand_id=int(brand_param)) | Q(brand__isnull=True))
            else:
                categories = categories.filter(Q(brand__slug=brand_param) | Q(brand__name__iexact=brand_param) | Q(brand__isnull=True))

        categories = categories.prefetch_related(
            Prefetch('options', queryset=ConditionOption.objects.filter(is_active=True).order_by('display_order'))
        ).order_by('step_number', 'display_order')

        if not show_all:
            # Smart Deduplication for Customer Questionnaire:
            # 1. Separate brand-specific vs universal steps
            # 2. If a brand-specific step exists for a given step name, it overrides the universal step
            # 3. Discard any duplicate steps having the same normalized step name
            brand_specific = [c for c in categories if c.brand_id]
            universal = [c for c in categories if not c.brand_id]

            final_categories = []
            seen_names = set()

            # First, add brand-specific steps
            for cat in brand_specific:
                key = cat.name.strip().lower()
                if key not in seen_names:
                    seen_names.add(key)
                    final_categories.append(cat)

            # Next, add universal steps ONLY if not overridden by a brand-specific step
            for cat in universal:
                key = cat.name.strip().lower()
                if key not in seen_names:
                    seen_names.add(key)
                    final_categories.append(cat)

            final_categories.sort(key=lambda c: (c.step_number, c.display_order))
            serializer = ConditionCategorySerializer(final_categories, many=True)
            return Response(serializer.data)

        serializer = ConditionCategorySerializer(categories, many=True)
        return Response(serializer.data)
    
    elif request.method == 'POST':
        if not getattr(request.user, 'is_admin_role', False):
            return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)
        
        try:
            data = request.data.copy() if hasattr(request.data, 'copy') else dict(request.data)
            if data.get('brand') in ['', 0, '0', 'null']:
                data['brand'] = None
            if data.get('device_category') in ['', 0, '0', 'null']:
                data['device_category'] = None
            valid_fields = {'device_category', 'brand', 'step_number', 'name', 'subtitle', 'selection_type', 'pro_tip', 'icon_name', 'image_base64', 'is_mandatory', 'display_order', 'is_active'}
            sanitized_data = {k: v for k, v in data.items() if k in valid_fields}

            serializer = ConditionCategorySerializer(data=sanitized_data)
            if serializer.is_valid():
                cat = serializer.save()
                return Response(ConditionCategorySerializer(cat).data, status=status.HTTP_201_CREATED)
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            import traceback
            traceback.print_exc()
            return Response({'detail': str(e)}, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET', 'PUT', 'PATCH', 'DELETE'])
@permission_classes([AllowAny])
def condition_category_detail_view(request, pk):
    try:
        try:
            category = ConditionCategory.objects.get(pk=pk)
        except ConditionCategory.DoesNotExist:
            return Response({'detail': 'Category not found'}, status=status.HTTP_404_NOT_FOUND)

        if request.method == 'GET':
            return Response(ConditionCategorySerializer(category).data)

        if not getattr(request.user, 'is_admin_role', False):
            return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

        if request.method in ['PUT', 'PATCH']:
            data = request.data.copy() if hasattr(request.data, 'copy') else dict(request.data)
            if data.get('brand') in ['', 0, '0', 'null']:
                data['brand'] = None
            if data.get('device_category') in ['', 0, '0', 'null']:
                data['device_category'] = None
            valid_fields = {'device_category', 'brand', 'step_number', 'name', 'subtitle', 'selection_type', 'pro_tip', 'icon_name', 'image_base64', 'is_mandatory', 'display_order', 'is_active'}
            sanitized_data = {k: v for k, v in data.items() if k in valid_fields}

            serializer = ConditionCategorySerializer(category, data=sanitized_data, partial=True)
            if serializer.is_valid():
                serializer.save()
                return Response(serializer.data)
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        elif request.method == 'DELETE':
            try:
                category.delete()
            except ProtectedError:
                # Existing orders reference this category; soft-delete/deactivate to preserve order history
                category.is_active = False
                category.save()
                return Response(
                    {'detail': 'Category has historical orders referencing it; it has been deactivated from active quizzes.'},
                    status=status.HTTP_200_OK
                )
            return Response(status=status.HTTP_204_NO_CONTENT)
    except Exception as e:
        import traceback
        traceback.print_exc()
        return Response({'detail': f"Server error: {str(e)}"}, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET', 'POST'])
@permission_classes([AllowAny])
def condition_options_view(request):
    if request.method == 'GET':
        category_id = request.GET.get('category')
        show_all = request.GET.get('all', 'false').lower() == 'true'
        if show_all and getattr(request.user, 'is_admin_role', False):
            options = ConditionOption.objects.all().select_related('category')
        else:
            options = ConditionOption.objects.filter(is_active=True).select_related('category')
        
        if category_id:
            options = options.filter(category_id=category_id)
        serializer = ConditionOptionSerializer(options, many=True)
        return Response(serializer.data)

    elif request.method == 'POST':
        if not getattr(request.user, 'is_admin_role', False):
            return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)
        
        data = request.data.copy() if hasattr(request.data, 'copy') else dict(request.data)
        if not data.get('code'):
            import uuid, re
            raw_title = str(data.get('title', 'OPT')).strip()
            clean_title = re.sub(r'[^A-Za-z0-9]+', '_', raw_title).upper().strip('_')[:20]
            if not clean_title:
                clean_title = 'OPT'
            data['code'] = f"{clean_title}_{uuid.uuid4().hex[:8].upper()}"

        serializer = ConditionOptionSerializer(data=data)
        if serializer.is_valid():
            opt = serializer.save()
            return Response(ConditionOptionSerializer(opt).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET', 'PUT', 'PATCH', 'DELETE'])
@permission_classes([AllowAny])
def condition_option_detail_view(request, pk):
    try:
        option = ConditionOption.objects.get(pk=pk)
    except ConditionOption.DoesNotExist:
        return Response({'detail': 'Option not found'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        return Response(ConditionOptionSerializer(option).data)

    if not getattr(request.user, 'is_admin_role', False):
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

    if request.method in ['PUT', 'PATCH']:
        serializer = ConditionOptionSerializer(option, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    elif request.method == 'DELETE':
        try:
            option.delete()
        except ProtectedError:
            # Existing customer orders reference this option; soft-delete to preserve audit trail
            option.is_active = False
            option.save()
            return Response(
                {'detail': 'Option is referenced in historical sales records; it has been deactivated.'},
                status=status.HTTP_200_OK
            )
        return Response(status=status.HTTP_204_NO_CONTENT)

@api_view(['POST'])
@permission_classes([AllowAny])
def calculate_estimate_view(request):
    """
    Robust dynamic valuation engine.
    Calculates estimated buyback price with:
    - Base price
    - Flat and percentage deductions
    - Mutually exclusive conflict guards
    - Safety/rejection locks
    """
    serializer = EstimateCalculationSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    variant_id = serializer.validated_data['variant_id']
    selected_codes = serializer.validated_data.get('selected_option_codes', [])

    try:
        variant = StorageVariant.objects.select_related('model__brand').get(id=variant_id, is_active=True)
    except StorageVariant.DoesNotExist:
        return Response({'detail': 'Storage variant not found or inactive'}, status=status.HTTP_404_NOT_FOUND)

    base_price = variant.base_price
    min_price = variant.min_price
    phone_model = variant.model

    # Fetch selected condition options
    options = list(ConditionOption.objects.filter(code__in=selected_codes, is_active=True))
    
    # Check for safety / ownership rejections (e.g. Swollen battery, iCloud lock)
    rejection_reasons = []
    for opt in options:
        if opt.is_rejection:
            rejection_reasons.append(opt.title)

    if rejection_reasons:
        return Response({
            'brand': phone_model.brand.name,
            'model': phone_model.name,
            'variant': f"{variant.ram} / {variant.storage}" if variant.ram else variant.storage,
            'base_price': float(base_price),
            'min_price': 0.0,
            'total_deduction': float(base_price),
            'estimated_price': 0.0,
            'is_rejected': True,
            'rejection_reasons': rejection_reasons,
            'message': 'Device cannot be accepted for buyback due to safety hazards or ownership lock.',
            'currency': 'INR',
            'deductions': [],
        })

    # Fetch overrides if any for this model
    overrides = {
        mo.option_id: mo.override_deduction_value
        for mo in ModelPricingOverride.objects.filter(phone_model=phone_model)
    }

    # Group options by exclusive_group
    exclusive_groups = {}
    standalone_options = []

    for opt in options:
        if not opt.is_defect:
            continue
        if opt.exclusive_group and opt.exclusive_group.strip():
            grp = opt.exclusive_group.strip().lower()
            if grp not in exclusive_groups:
                exclusive_groups[grp] = []
            exclusive_groups[grp].append(opt)
        else:
            standalone_options.append(opt)

    deductions_breakdown = []
    total_deduction = Decimal('0.00')

    # 1. Process Standalone deductions
    for opt in standalone_options:
        if opt.id in overrides:
            amt = overrides[opt.id]
            rule_type = "Model Override (Flat)"
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

    # 2. Process Exclusive Groups (take only the maximum deduction in the group to avoid double-charging)
    for grp_name, grp_opts in exclusive_groups.items():
        highest_amt = Decimal('0.00')
        chosen_opt = None
        chosen_rule_type = ""

        for opt in grp_opts:
            if opt.id in overrides:
                amt = overrides[opt.id]
                rtype = "Model Override (Flat)"
            else:
                if opt.deduction_type == 'PERCENTAGE':
                    amt = (base_price * opt.default_deduction_value) / Decimal('100.00')
                    rtype = f"{opt.default_deduction_value}% of Base"
                else:
                    amt = opt.default_deduction_value
                    rtype = "Standard Flat"

            if amt > highest_amt or chosen_opt is None:
                highest_amt = amt
                chosen_opt = opt
                chosen_rule_type = rtype

        total_deduction += highest_amt
        deductions_breakdown.append({
            'code': chosen_opt.code,
            'title': f"{chosen_opt.title} (Exclusive Group: {grp_name})",
            'category': chosen_opt.category.name,
            'deduction_amount': float(highest_amt),
            'rule_type': f"{chosen_rule_type} [Max group rule applied]"
        })

    min_floor = min_price if (min_price and min_price > 0) else Decimal('500.00')
    estimated_price = max(base_price - total_deduction, min_floor)

    return Response({
        'brand': phone_model.brand.name,
        'model': phone_model.name,
        'variant': f"{variant.ram} / {variant.storage}" if variant.ram else variant.storage,
        'base_price': float(base_price),
        'min_price': float(min_floor),
        'total_deduction': float(total_deduction),
        'estimated_price': float(estimated_price),
        'is_rejected': False,
        'currency': 'INR',
        'deductions': deductions_breakdown,
    })

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def price_history_list_view(request):
    """Admin view of all price changes and audit log"""
    if not getattr(request.user, 'is_admin_role', False):
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)
    
    variant_id = request.GET.get('variant')
    queryset = PriceHistory.objects.all().select_related('variant__model__brand', 'changed_by')
    if variant_id:
        queryset = queryset.filter(variant_id=variant_id)
    
    serializer = PriceHistorySerializer(queryset, many=True)
    return Response(serializer.data)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def copy_questions_from_brand_view(request):
    """
    Clones all condition questions, visual Base64 illustrations, and deduction values
    from a source brand to a target brand, with optional mandatory toggle.
    Guarantees unique codes <= 50 chars and transaction atomicity with JSON responses.
    """
    if not getattr(request.user, 'is_admin_role', False):
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)
    
    source_brand_id = request.data.get('source_brand_id')
    target_brand_id = request.data.get('target_brand_id')
    mark_mandatory = request.data.get('mark_mandatory', True)
    overwrite = request.data.get('overwrite', False)
    
    if not target_brand_id:
        return Response({'detail': 'target_brand_id is required'}, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        target_brand = Brand.objects.get(id=target_brand_id)
    except Brand.DoesNotExist:
        return Response({'detail': 'Target brand not found'}, status=status.HTTP_404_NOT_FOUND)
    
    if source_brand_id:
        try:
            source_brand = Brand.objects.get(id=source_brand_id)
            source_cats = ConditionCategory.objects.filter(brand=source_brand, is_active=True).prefetch_related('options')
            if not source_cats.exists():
                # Fallback to universal questions if brand has none configured specifically
                source_cats = ConditionCategory.objects.filter(brand__isnull=True, is_active=True).prefetch_related('options')
        except Brand.DoesNotExist:
            return Response({'detail': 'Source brand not found'}, status=status.HTTP_404_NOT_FOUND)
    else:
        source_cats = ConditionCategory.objects.filter(brand__isnull=True, is_active=True).prefetch_related('options')
    
    if not source_cats.exists():
        return Response({'detail': 'No condition questions found to copy from.'}, status=status.HTTP_404_NOT_FOUND)
    
    import uuid
    from django.db import transaction
    
    brand_prefix = (target_brand.slug or target_brand.name[:6]).upper().replace('-', '_')[:8]
    
    try:
        with transaction.atomic():
            if overwrite:
                ConditionCategory.objects.filter(brand=target_brand).delete()
                
            copied_cats = 0
            copied_opts = 0
            
            for src_cat in source_cats:
                new_cat = ConditionCategory.objects.create(
                    device_category=src_cat.device_category,
                    brand=target_brand,
                    step_number=src_cat.step_number,
                    name=src_cat.name,
                    subtitle=src_cat.subtitle,
                    selection_type=src_cat.selection_type,
                    pro_tip=src_cat.pro_tip,
                    icon_name=src_cat.icon_name,
                    image_base64=src_cat.image_base64,
                    is_mandatory=mark_mandatory if mark_mandatory is not None else src_cat.is_mandatory,
                    display_order=src_cat.display_order,
                    is_active=True
                )
                copied_cats += 1
                
                for src_opt in src_cat.options.filter(is_active=True):
                    clean_code = src_opt.code.split('_', 1)[-1] if '_' in src_opt.code else src_opt.code
                    short_hash = uuid.uuid4().hex[:6].upper()
                    unique_code = f"{brand_prefix}_{clean_code[:30]}_{short_hash}"[:50]
                    
                    while ConditionOption.objects.filter(code=unique_code).exists():
                        short_hash = uuid.uuid4().hex[:6].upper()
                        unique_code = f"{brand_prefix}_{clean_code[:30]}_{short_hash}"[:50]
                    
                    ConditionOption.objects.create(
                        category=new_cat,
                        code=unique_code,
                        title=src_opt.title,
                        description=src_opt.description,
                        image_base64=src_opt.image_base64,
                        is_defect=src_opt.is_defect,
                        is_accessory_bonus=src_opt.is_accessory_bonus,
                        is_warranty=src_opt.is_warranty,
                        deduction_type=src_opt.deduction_type,
                        default_deduction_value=src_opt.default_deduction_value,
                        exclusive_group=src_opt.exclusive_group,
                        is_rejection=src_opt.is_rejection,
                        display_order=src_opt.display_order,
                        is_active=True
                    )
                    copied_opts += 1
                    
        return Response({
            'detail': f'Successfully cloned {copied_cats} question categories and {copied_opts} options to {target_brand.name}.',
            'target_brand': target_brand.name,
            'copied_categories': copied_cats,
            'copied_options': copied_opts
        }, status=status.HTTP_201_CREATED)
    except Exception as e:
        return Response({'detail': f'Failed to copy questions: {str(e)}'}, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def valuation_bulk_delete_view(request):
    """Bulk delete questionnaire steps (categories) or deduction options (Admin only)"""
    if not getattr(request.user, 'is_admin_role', False):
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

    target = str(request.data.get('target', '')).strip().lower()
    ids = request.data.get('ids', [])
    delete_all = bool(request.data.get('all', False))

    if not delete_all and (not isinstance(ids, list) or len(ids) == 0):
        return Response({'detail': 'Provide ids list or set all=true'}, status=status.HTTP_400_BAD_REQUEST)

    with transaction.atomic():
        if target == 'categories':
            qs = ConditionCategory.objects.all() if delete_all else ConditionCategory.objects.filter(id__in=ids)
            count = qs.count()
            qs.delete()  # Cascades to ConditionOption
        elif target == 'options':
            qs = ConditionOption.objects.all() if delete_all else ConditionOption.objects.filter(id__in=ids)
            count = qs.count()
            qs.delete()
        else:
            return Response({'detail': f'Unsupported target: {target}'}, status=status.HTTP_400_BAD_REQUEST)

    return Response({'deleted': count, 'target': target, 'message': f'Successfully deleted {count} {target}'})

