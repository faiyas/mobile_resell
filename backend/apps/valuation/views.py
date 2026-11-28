from django.db import models, transaction
from django.db.models import Prefetch, Q, ProtectedError
from decimal import Decimal
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from .models import ConditionCategory, ConditionOption, ModelPricingOverride, PriceHistory, EvaluationTriageQuestion
from .serializers import (
    ConditionCategorySerializer, ConditionOptionSerializer, 
    EstimateCalculationSerializer, PriceHistorySerializer,
    EvaluationTriageQuestionSerializer
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

def get_operational_pricing_rules():
    """Reads minPayoutFloor and doorstepFee from SYSTEM_SETTINGS CMS section."""
    min_floor = Decimal('500.00')
    doorstep_fee = Decimal('0.00')
    try:
        from apps.catalog.models import CmsSection
        sec = CmsSection.objects.filter(section_type='SYSTEM_SETTINGS', is_active=True).first()
        if sec and isinstance(sec.data_json, dict):
            raw_floor = sec.data_json.get('minPayoutFloor')
            if raw_floor is not None and str(raw_floor).strip() != '':
                min_floor = max(Decimal(str(raw_floor)), Decimal('0.00'))
            raw_fee = sec.data_json.get('doorstepFee')
            if raw_fee is not None and str(raw_fee).strip() != '':
                doorstep_fee = max(Decimal(str(raw_fee)), Decimal('0.00'))
    except Exception:
        pass
    return min_floor, doorstep_fee


def evaluate_device_quote(base_price: Decimal, min_price: Decimal, selected_codes: list, triage_answers: dict, overrides: dict):
    """
    Shared DB-driven valuation engine used by both estimate preview and order creation:
    - Cascading triage dynamic gating (disables_question_codes)
    - Component-based exclusive_group deduplication (max deduction per group)
    - ModelPricingOverride priority over default option deductions
    - Accessory bonuses (is_accessory_bonus=True, never exceeding base_price)
    - Operational minPayoutFloor & doorstepFee from SYSTEM_SETTINGS
    """
    config_floor, doorstep_fee = get_operational_pricing_rules()
    options = list(ConditionOption.objects.filter(code__in=selected_codes, is_active=True).select_related('category'))

    rejection_reasons = [opt.title for opt in options if opt.is_rejection]
    if rejection_reasons:
        return {
            'is_rejected': True,
            'rejection_reasons': rejection_reasons,
            'min_floor': Decimal('0.00'),
            'doorstep_fee': doorstep_fee,
            'total_deduction': base_price,
            'total_bonus': Decimal('0.00'),
            'gross_offer': Decimal('0.00'),
            'estimated_price': Decimal('0.00'),
            'deductions': [],
            'answer_records': [],
        }

    grouped_items = {}
    standalone_items = []
    deductions_breakdown = []
    answer_records = []
    total_deduction = Decimal('0.00')

    # 1. Triage Questions (in display order, respecting cascading disables_question_codes)
    triage_questions = list(EvaluationTriageQuestion.objects.filter(is_active=True).order_by('display_order'))
    disabled_codes = set()

    for tq in triage_questions:
        if tq.code in disabled_codes:
            continue
        ans = str((triage_answers or {}).get(tq.code, '')).strip().upper()
        if ans == 'NO':
            if tq.disables_question_codes and isinstance(tq.disables_question_codes, list):
                for dc in tq.disables_question_codes:
                    disabled_codes.add(str(dc).strip())

            if tq.deduction_type == 'PERCENTAGE':
                amt = (base_price * tq.deduction_value_on_no) / Decimal('100.00')
                rtype = f"{tq.deduction_value_on_no}% of Base"
            else:
                amt = tq.deduction_value_on_no
                rtype = f"Flat ₹{tq.deduction_value_on_no}"

            standalone_items.append({
                'opt': None,
                'code': tq.code,
                'title': f"{tq.question_text} (Answered No)",
                'category': "Initial Health Check",
                'amt': amt,
                'rule_type': rtype,
                'note': f"{tq.question_text}: NO",
            })

    # 2. Condition Options (Defects + Accessory Bonuses)
    bonus_options = []
    for opt in options:
        if opt.is_accessory_bonus:
            bonus_options.append(opt)
            continue
        if not opt.is_defect:
            continue

        if opt.id in overrides:
            override_val = overrides[opt.id]
            if opt.deduction_type == 'PERCENTAGE':
                amt = (base_price * override_val) / Decimal('100.00')
                rule_type = f"Model Override ({override_val}% of Base)"
            else:
                amt = override_val
                rule_type = f"Model Override (Flat ₹{override_val})"
        else:
            if opt.deduction_type == 'PERCENTAGE':
                amt = (base_price * opt.default_deduction_value) / Decimal('100.00')
                rule_type = f"{opt.default_deduction_value}% of Base"
            else:
                amt = opt.default_deduction_value
                rule_type = f"Standard Flat ₹{opt.default_deduction_value}"

        item = {
            'opt': opt,
            'code': opt.code,
            'title': opt.title,
            'category': opt.category.name,
            'amt': amt,
            'rule_type': rule_type,
            'note': '',
        }
        if opt.exclusive_group and opt.exclusive_group.strip():
            grp = opt.exclusive_group.strip().lower()
            grouped_items.setdefault(grp, []).append(item)
        else:
            standalone_items.append(item)

    for item in standalone_items:
        total_deduction += item['amt']
        deductions_breakdown.append({
            'code': item['code'],
            'title': item['title'],
            'category': item['category'],
            'deduction_amount': float(item['amt']),
            'rule_type': item['rule_type'],
        })
        answer_records.append((item['opt'], item['amt'], item['note']))

    for grp_name, grp_items in grouped_items.items():
        chosen = max(grp_items, key=lambda x: x['amt'])
        total_deduction += chosen['amt']
        deductions_breakdown.append({
            'code': chosen['code'],
            'title': f"{chosen['title']} ({grp_name.replace('_', ' ').title()})",
            'category': chosen['category'],
            'deduction_amount': float(chosen['amt']),
            'rule_type': f"{chosen['rule_type']} [Max group rule applied]",
        })
        answer_records.append((chosen['opt'], chosen['amt'], chosen['note']))

    # 3. Accessory Bonuses (read from ConditionOption DB values)
    total_bonus = Decimal('0.00')
    for bopt in bonus_options:
        if bopt.deduction_type == 'PERCENTAGE':
            b_amt = (base_price * bopt.default_deduction_value) / Decimal('100.00')
        else:
            b_amt = bopt.default_deduction_value
        total_bonus += b_amt
        answer_records.append((bopt, Decimal('0.00'), f"Accessory Bonus: +₹{b_amt:.0f}"))

    min_floor = max(min_price or Decimal('0.00'), config_floor)
    base_offer = max(base_price - total_deduction, min_floor)
    gross_offer = min(base_offer + total_bonus, base_price)
    estimated_price = max(gross_offer - doorstep_fee, Decimal('0.00'))

    return {
        'is_rejected': False,
        'rejection_reasons': [],
        'min_floor': min_floor,
        'doorstep_fee': doorstep_fee,
        'total_deduction': total_deduction,
        'total_bonus': total_bonus,
        'gross_offer': gross_offer,
        'estimated_price': estimated_price,
        'deductions': deductions_breakdown,
        'answer_records': answer_records,
    }


@api_view(['POST'])
@permission_classes([AllowAny])
def calculate_estimate_view(request):
    """
    Calculates dynamic valuation quote based on:
    - Base variant price & min floor
    - Cascading triage health-check questions
    - Price-tier percentages & component-grouped deductions
    - Capped accessory bonuses & doorstep fee
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
    phone_model = variant.model
    overrides = {
        mo.option_id: mo.override_deduction_value
        for mo in ModelPricingOverride.objects.filter(phone_model=phone_model)
    }
    triage_answers = serializer.validated_data.get('triage_answers', {})
    result = evaluate_device_quote(base_price, variant.min_price, selected_codes, triage_answers, overrides)

    if result['is_rejected']:
        return Response({
            'brand': phone_model.brand.name,
            'model': phone_model.name,
            'variant': f"{variant.ram} / {variant.storage}" if variant.ram else variant.storage,
            'base_price': float(base_price),
            'min_price': 0.0,
            'total_deduction': float(base_price),
            'estimated_price': 0.0,
            'is_rejected': True,
            'rejection_reasons': result['rejection_reasons'],
            'message': 'Device cannot be accepted for buyback due to safety hazards or ownership lock.',
            'currency': 'INR',
            'deductions': [],
        })

    return Response({
        'brand': phone_model.brand.name,
        'model': phone_model.name,
        'variant': f"{variant.ram} / {variant.storage}" if variant.ram else variant.storage,
        'variant_id': variant.id,
        'base_price': float(base_price),
        'mint_price': float(base_price),
        'min_price': float(result['min_floor']),
        'doorstep_fee': float(result['doorstep_fee']),
        'accessory_bonus': float(result['total_bonus']),
        'gross_estimated_price': float(result['gross_offer']),
        'total_deduction': float(result['total_deduction']),
        'estimated_price': float(result['estimated_price']),
        'is_rejected': False,
        'is_dead_device': False,
        'currency': 'INR',
        'deductions': result['deductions'],
    })

# ================= 6. INITIAL HEALTH CHECK TRIAGE QUESTIONS =================
@api_view(['GET', 'POST'])
@permission_classes([AllowAny])
def triage_questions_view(request):
    """List or create Initial Health Check Yes/No questions"""
    if request.method == 'GET':
        include_all = request.GET.get('all', 'false').lower() == 'true'
        questions = EvaluationTriageQuestion.objects.all() if include_all else EvaluationTriageQuestion.objects.filter(is_active=True)
        return Response(EvaluationTriageQuestionSerializer(questions.order_by('display_order'), many=True).data)

    if not getattr(request.user, 'is_admin_role', False):
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

    serializer = EvaluationTriageQuestionSerializer(data=request.data)
    if serializer.is_valid():
        q = serializer.save()
        return Response(EvaluationTriageQuestionSerializer(q).data, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET', 'PUT', 'PATCH', 'DELETE'])
@permission_classes([AllowAny])
def triage_question_detail_view(request, pk):
    try:
        q = EvaluationTriageQuestion.objects.get(pk=pk)
    except EvaluationTriageQuestion.DoesNotExist:
        return Response({'detail': 'Question not found'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        return Response(EvaluationTriageQuestionSerializer(q).data)

    if not getattr(request.user, 'is_admin_role', False):
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

    if request.method in ['PUT', 'PATCH']:
        serializer = EvaluationTriageQuestionSerializer(q, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    elif request.method == 'DELETE':
        permanent = request.GET.get('permanent', 'false').lower() == 'true'
        if permanent:
            q.delete()
        else:
            q.is_active = not q.is_active  # Toggle active status or deactivate
            q.save()
        return Response(status=status.HTTP_204_NO_CONTENT)

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

    from apps.sales.models import PhoneSaleConditionAnswer

    with transaction.atomic():
        if target == 'categories':
            qs = ConditionCategory.objects.all() if delete_all else ConditionCategory.objects.filter(id__in=ids)
            opt_ids = list(ConditionOption.objects.filter(category__in=qs).values_list('id', flat=True))
            if opt_ids:
                PhoneSaleConditionAnswer.objects.filter(option_id__in=opt_ids).update(option=None)
            count = qs.count()
            ConditionOption.objects.filter(category__in=qs).delete()
            qs.delete()
        elif target == 'options':
            qs = ConditionOption.objects.all() if delete_all else ConditionOption.objects.filter(id__in=ids)
            PhoneSaleConditionAnswer.objects.filter(option__in=qs).update(option=None)
            count = qs.count()
            qs.delete()
        else:
            return Response({'detail': f'Unsupported target: {target}'}, status=status.HTTP_400_BAD_REQUEST)

    return Response({'deleted': count, 'target': target, 'message': f'Successfully deleted {count} {target}'})

