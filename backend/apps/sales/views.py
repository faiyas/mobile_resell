import datetime
from decimal import Decimal
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from django.db import transaction
from django.shortcuts import get_object_or_404
from .models import PhoneSale, PhoneSaleConditionAnswer
from .serializers import PhoneSaleDetailSerializer, PhoneSaleListSerializer, PhoneSaleCreateSerializer
from .pincode_helper import resolve_pincode
from apps.catalog.models import StorageVariant
from apps.valuation.models import ConditionOption, ModelPricingOverride
from apps.accounts.models import User

IST = datetime.timezone(datetime.timedelta(hours=5, minutes=30))

def _auto_shift_overdue_pickups():
    """Automatically shifts uncollected/missed pickups from past dates to tomorrow morning queue."""
    try:
        now_ist = timezone.now().astimezone(IST)
        today_ist = now_ist.date()
        tomorrow_ist = today_ist + datetime.timedelta(days=1)

        overdue_orders = PhoneSale.objects.filter(
            status__in=['SUBMITTED', 'PICKUP_SCHEDULED'],
            pickup_date__lt=today_ist
        )
        for s in overdue_orders:
            orig = s.pickup_date.strftime('%d %b %Y') if s.pickup_date else 'Past Date'
            s.pickup_date = tomorrow_ist
            s.pickup_slot = 'Morning (10:00 AM - 1:00 PM)'
            note = f"[Auto-Shift] Missed pickup on {orig}. Shifted to {tomorrow_ist.strftime('%d %b %Y')} (Morning Slot)."
            if note not in (s.admin_notes or ''):
                s.admin_notes = (s.admin_notes + '\n' + note).strip() if s.admin_notes else note
            s.save(update_fields=['pickup_date', 'pickup_slot', 'admin_notes'])
    except Exception:
        pass

@api_view(['GET', 'POST'])
@permission_classes([AllowAny])
def sales_list_create_view(request):
    if request.method == 'GET':
        _auto_shift_overdue_pickups()
        user = request.user
        queryset = PhoneSale.objects.all().select_related(
            'variant__model__brand', 'assigned_agent', 'payment'
        ).prefetch_related('inspection__photos')

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
        elif getattr(user, 'is_admin_role', False):
            pass # Super Admin sees all orders across the business
        elif getattr(user, 'is_agent_role', False):
            # Collection agent view: default is their own assigned queue & history.
            # If agent specifically queries unassigned pool: ?pool=true
            if request.GET.get('pool', 'false').lower() == 'true':
                queryset = queryset.filter(assigned_agent__isnull=True, status__in=['SUBMITTED', 'PICKUP_SCHEDULED'])
            else:
                queryset = queryset.filter(assigned_agent=user)
        elif str(getattr(user, 'role', '')).upper() == 'CUSTOMER':
            q = queryset.filter(customer=user)
            if user.phone:
                q = q | queryset.filter(customer_phone=user.phone)
            if user.email:
                q = q | queryset.filter(customer_email__iexact=user.email)
            queryset = q.distinct()
        else:
            queryset = queryset.none()

        status_filter = request.GET.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)

        search_query = request.GET.get('search')
        if search_query:
            from django.db.models import Q
            queryset = queryset.filter(
                Q(sale_code__icontains=search_query) |
                Q(customer_name__icontains=search_query) |
                Q(customer_phone__icontains=search_query) |
                Q(variant__model__name__icontains=search_query)
            )

        queryset = queryset.order_by('-created_at')

        # Pagination support (10 per page default)
        from django.core.paginator import Paginator, EmptyPage
        page = request.GET.get('page')
        page_size = int(request.GET.get('page_size', 10))
        show_all = request.GET.get('all', 'false').lower() == 'true'

        is_full = request.GET.get('full', 'false').lower() == 'true'
        SerializerClass = PhoneSaleDetailSerializer if is_full else PhoneSaleListSerializer

        if not show_all and (page or getattr(user, 'is_staff_role', False)):
            page_num = int(page) if page and str(page).isdigit() else 1
            paginator = Paginator(queryset, page_size)
            try:
                page_obj = paginator.page(page_num)
            except EmptyPage:
                page_obj = []

            serializer = SerializerClass(page_obj, many=True, context={'request': request})
            return Response({
                'count': paginator.count,
                'total_pages': paginator.num_pages,
                'current_page': page_num,
                'page_size': page_size,
                'has_next': page_obj.has_next() if hasattr(page_obj, 'has_next') else False,
                'has_previous': page_obj.has_previous() if hasattr(page_obj, 'has_previous') else False,
                'results': serializer.data
            })

        serializer = SerializerClass(queryset, many=True, context={'request': request})
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

        # 1. Triage Health Check Deductions
        triage_answers = data.get('triage_answers', {})
        from apps.valuation.models import EvaluationTriageQuestion
        triage_questions = list(EvaluationTriageQuestion.objects.filter(is_active=True).order_by('display_order'))
        is_dead_device = False

        for tq in triage_questions:
            ans = str(triage_answers.get(tq.code, '')).strip().upper()
            if ans == 'NO':
                if tq.is_power_on_gate:
                    is_dead_device = True
                    floor = min_price if (min_price and min_price > 0) else Decimal('500.00')
                    amt = max(base_price - floor, Decimal('0.00'))
                    total_deduction += amt
                    answers_to_create.append((None, amt, f"{tq.question_text}: NO (Dead Device)"))
                    break
                else:
                    if tq.deduction_type == 'PERCENTAGE':
                        amt = (base_price * tq.deduction_value_on_no) / Decimal('100.00')
                    else:
                        amt = tq.deduction_value_on_no
                    total_deduction += amt
                    answers_to_create.append((None, amt, f"{tq.question_text}: NO"))

        # 2. Condition Options Deductions (if phone turns on)
        if not is_dead_device:
            for opt in options:
                if not opt.is_defect:
                    continue
                if opt.id in overrides:
                    override_val = overrides[opt.id]
                    if opt.deduction_type == 'PERCENTAGE':
                        amt = (base_price * override_val) / Decimal('100.00')
                    else:
                        amt = override_val
                else:
                    if opt.deduction_type == 'PERCENTAGE':
                        amt = (base_price * opt.default_deduction_value) / Decimal('100.00')
                    else:
                        amt = opt.default_deduction_value
                total_deduction += amt
                answers_to_create.append((opt, amt, ''))

        min_floor = min_price if (min_price and min_price > 0) else Decimal('500.00')
        estimated_price = max(base_price - total_deduction, min_floor)

        # Pickup lead-time & cutoff enforcement:
        # Same-day pickup is never permitted.
        # If booking after 8:00 PM (20:00 IST), next-day morning slots cannot be dispatched, so earliest is +2 days.
        # If booking before 8:00 PM, earliest is tomorrow (+1 day).
        now_ist = timezone.now().astimezone(IST)
        lead_days = 2 if now_ist.hour >= 20 else 1
        earliest_pickup_date = (now_ist + datetime.timedelta(days=lead_days)).date()

        req_pickup_date = data.get('pickup_date')
        if not req_pickup_date or req_pickup_date < earliest_pickup_date:
            final_pickup_date = earliest_pickup_date
        else:
            final_pickup_date = req_pickup_date

        with transaction.atomic():
            customer_user = request.user if request.user.is_authenticated and request.user.role == 'CUSTOMER' else None
            if not customer_user:
                # Auto-associate to registered customer account if matching phone or email exists
                customer_user = User.objects.filter(phone=data['customer_phone'], role='CUSTOMER').first()
                if not customer_user and data.get('customer_email'):
                    customer_user = User.objects.filter(email__iexact=data['customer_email'].strip(), role='CUSTOMER').first()

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
                pickup_date=final_pickup_date,
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

def _get_sale_instance(pk):
    """Safely retrieves a PhoneSale by UUID or by sale_code without throwing ValidationError"""
    if not pk:
        return None
    pk_str = str(pk).strip()
    try:
        import uuid
        u = uuid.UUID(pk_str)
        sale = PhoneSale.objects.filter(id=u).first()
        if sale:
            return sale
    except (ValueError, TypeError):
        pass

    sale = PhoneSale.objects.filter(sale_code__iexact=pk_str).first()
    if sale:
        return sale
    return None

@api_view(['GET'])
@permission_classes([AllowAny])
def sale_detail_view(request, pk):
    sale = _get_sale_instance(pk)
    if not sale:
        return Response({'detail': f'Sale order not found for identifier: {pk}'}, status=status.HTTP_404_NOT_FOUND)

    # Strict Role-based access validation
    user = request.user
    if user.is_authenticated:
        if user.role == 'CUSTOMER':
            is_owner = (
                sale.customer == user or
                (user.phone and sale.customer_phone == user.phone) or
                (user.email and sale.customer_email and sale.customer_email.strip().lower() == user.email.strip().lower())
            )
            if not is_owner:
                return Response({'detail': 'You do not have permission to view this order'}, status=status.HTTP_403_FORBIDDEN)
        elif user.role == 'COLLECTION_AGENT':
            if sale.assigned_agent and sale.assigned_agent != user:
                return Response({'detail': 'This order is assigned to another field agent'}, status=status.HTTP_403_FORBIDDEN)
    else:
        # Unauthenticated guest lookup: verify phone query param if provided
        phone = request.GET.get('phone')
        if phone:
            clean_phone = phone.strip()[-10:]
            clean_sale_phone = (sale.customer_phone or '').strip()[-10:]
            if clean_phone and clean_sale_phone and clean_phone != clean_sale_phone:
                return Response({'detail': 'Phone number does not match this order'}, status=status.HTTP_403_FORBIDDEN)

    serializer = PhoneSaleDetailSerializer(sale, context={'request': request})
    return Response(serializer.data)

@api_view(['POST'])
@permission_classes([AllowAny])
def accept_final_offer_view(request, pk):
    """Customer accepts the revised final offer after inspection"""
    sale = _get_sale_instance(pk)
    if not sale:
        return Response({'detail': f'Sale order not found for identifier: {pk}'}, status=status.HTTP_404_NOT_FOUND)

    if sale.status != 'FINAL_OFFER_SENT':
        return Response({'detail': f'Cannot accept offer in state: {sale.status}'}, status=status.HTTP_400_BAD_REQUEST)

    sale.status = 'CUSTOMER_ACCEPTED'
    now_ist = timezone.now().astimezone(IST)
    audit = f"[{now_ist.strftime('%d %b, %I:%M %p')}] Customer confirmed & accepted final buyback price of ₹{sale.final_price}. Awaiting agent physical device collection."
    sale.admin_notes = (sale.admin_notes + '\n' + audit).strip() if sale.admin_notes else audit
    sale.save()
    return Response({'message': 'Offer accepted successfully', 'status': sale.status, 'sale': PhoneSaleDetailSerializer(sale).data})

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_device_collected_view(request, pk):
    """Agent records physical device collection after customer confirmed offer"""
    if not getattr(request.user, 'is_staff_role', False):
        return Response({'detail': 'Staff access required'}, status=status.HTTP_403_FORBIDDEN)

    sale = _get_sale_instance(pk)
    if not sale:
        return Response({'detail': f'Sale order not found for identifier: {pk}'}, status=status.HTTP_404_NOT_FOUND)

    if sale.status not in ['CUSTOMER_ACCEPTED', 'FINAL_OFFER_SENT']:
        return Response({'detail': f'Device cannot be marked collected in status: {sale.status}'}, status=status.HTTP_400_BAD_REQUEST)

    now_ist = timezone.now().astimezone(IST)
    agent_name = getattr(request.user, 'full_name', '') or request.user.username
    sale.status = 'OWNERSHIP_TRANSFERRED'
    sale.customer_handover_signed = True
    audit = f"[{now_ist.strftime('%d %b, %I:%M %p')}] Physical device collected by agent {agent_name}. Device in company custody. Unlocked for Super Admin payout release."
    sale.admin_notes = (sale.admin_notes + '\n' + audit).strip() if sale.admin_notes else audit
    sale.save()

    return Response({
        'message': 'Device successfully collected! Ready for Super Admin payout release.',
        'status': sale.status,
        'sale': PhoneSaleDetailSerializer(sale).data
    })

@api_view(['POST'])
@permission_classes([AllowAny])
def reject_final_offer_view(request, pk):
    """Customer rejects revised offer (phone returned)"""
    sale = _get_sale_instance(pk)
    if not sale:
        return Response({'detail': f'Sale order not found for identifier: {pk}'}, status=status.HTTP_404_NOT_FOUND)

    sale.status = 'CUSTOMER_REJECTED'
    sale.save()
    return Response({'message': 'Offer rejected. Device return will be initiated.', 'status': sale.status})

@api_view(['POST'])
@permission_classes([AllowAny])
def cancel_order_view(request, pk):
    """Allow customer or admin to cancel a sale order prior to physical collection/payment"""
    sale = _get_sale_instance(pk)
    if not sale:
        return Response({'detail': f'Sale order not found for identifier: {pk}'}, status=status.HTTP_404_NOT_FOUND)

    non_cancellable = ['CANCELLED', 'PICKED_UP', 'OWNERSHIP_TRANSFERRED', 'PAYMENT_PENDING', 'PAYMENT_COMPLETED']
    if sale.status in non_cancellable:
        if sale.status == 'CANCELLED':
            return Response({'detail': 'This order has already been cancelled.'}, status=status.HTTP_400_BAD_REQUEST)
        return Response({
            'detail': f'Order cannot be cancelled in status: {sale.get_status_display()}. Please contact Dolly support.'
        }, status=status.HTTP_400_BAD_REQUEST)

    if request.user.is_authenticated and request.user.role == 'CUSTOMER':
        is_owner = (
            sale.customer == request.user or
            (request.user.phone and sale.customer_phone == request.user.phone) or
            (request.user.email and sale.customer_email and sale.customer_email.strip().lower() == request.user.email.strip().lower())
        )
        if not is_owner:
            return Response({'detail': 'You do not have permission to cancel this order.'}, status=status.HTTP_403_FORBIDDEN)

    reason = request.data.get('reason', '').strip()
    sale.status = 'CANCELLED'
    now_ist = timezone.now().astimezone(IST)
    audit = f"[{now_ist.strftime('%d %b, %I:%M %p')}] Order cancelled by customer. Reason: {reason or 'No reason specified'}."
    sale.admin_notes = (sale.admin_notes + '\n' + audit).strip() if sale.admin_notes else audit
    sale.save()

    return Response({
        'message': 'Order cancelled successfully.',
        'status': sale.status,
        'sale': PhoneSaleDetailSerializer(sale).data
    }, status=status.HTTP_200_OK)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def assign_pickup_view(request, pk):
    """Admin or Collection Agent schedules pickup and assigns agent"""
    if not getattr(request.user, 'is_staff_role', False):
        return Response({'detail': 'Staff access required'}, status=status.HTTP_403_FORBIDDEN)

    sale = _get_sale_instance(pk)
    if not sale:
        return Response({'detail': f'Sale order not found for identifier: {pk}'}, status=status.HTTP_404_NOT_FOUND)

    agent_id = request.data.get('agent_id')
    pickup_date = request.data.get('pickup_date')
    pickup_slot = request.data.get('pickup_slot')

    if getattr(request.user, 'is_agent_role', False) and not getattr(request.user, 'is_admin_role', False):
        sale.assigned_agent = request.user
    elif agent_id:
        try:
            agent = User.objects.filter(id=int(agent_id)).first()
            if agent:
                sale.assigned_agent = agent
        except (ValueError, TypeError):
            pass

    # Tomorrow is earliest booking date
    tomorrow = (timezone.now().astimezone(IST) + datetime.timedelta(days=1)).date()

    if pickup_date:
        try:
            if '-' in str(pickup_date):
                parts = str(pickup_date).split('-')
                if len(parts[0]) == 4: # YYYY-MM-DD
                    parsed_d = datetime.date(int(parts[0]), int(parts[1]), int(parts[2]))
                elif len(parts[2]) == 4: # DD-MM-YYYY
                    parsed_d = datetime.date(int(parts[2]), int(parts[1]), int(parts[0]))
                else:
                    parsed_d = datetime.date.fromisoformat(str(pickup_date))
            else:
                parsed_d = datetime.date.fromisoformat(str(pickup_date))
            sale.pickup_date = parsed_d
        except Exception:
            sale.pickup_date = tomorrow
    else:
        if not sale.pickup_date:
            sale.pickup_date = tomorrow

    if pickup_slot:
        sale.pickup_slot = pickup_slot

    sale.status = 'PICKUP_SCHEDULED'
    sale.save()
    return Response({'message': 'Pickup scheduled successfully', 'sale': PhoneSaleDetailSerializer(sale).data})

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def transfer_ownership_view(request, pk):
    """Agent/Admin records IMEI and physical device handover"""
    if not getattr(request.user, 'is_staff_role', False):
        return Response({'detail': 'Staff access required'}, status=status.HTTP_403_FORBIDDEN)

    sale = _get_sale_instance(pk)
    if not sale:
        return Response({'detail': f'Sale order not found for identifier: {pk}'}, status=status.HTTP_404_NOT_FOUND)

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
    """Admin reviews inspection or order and sets/overrides approved final price"""
    if not getattr(request.user, 'is_admin_role', False):
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

    sale = _get_sale_instance(pk)
    if not sale:
        return Response({'detail': f'Sale order not found for identifier: {pk}'}, status=status.HTTP_404_NOT_FOUND)

    if sale.status in ('DEVICE_COLLECTED', 'OWNERSHIP_TRANSFERRED', 'PAYMENT_PENDING', 'PAYMENT_COMPLETED', 'CANCELLED'):
        return Response(
            {'detail': f'Cannot change price when order is {sale.status.replace("_", " ").lower()}'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    approved_price = request.data.get('approved_price')
    if approved_price is None or str(approved_price).strip() == '':
        return Response({'detail': 'Approved price is required'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        new_price = Decimal(str(approved_price))
    except Exception:
        return Response({'detail': 'Invalid approved price format'}, status=status.HTTP_400_BAD_REQUEST)

    if new_price <= 0:
        return Response({'detail': 'Approved price must be greater than zero'}, status=status.HTTP_400_BAD_REQUEST)

    old_price = sale.final_price if sale.final_price is not None else sale.estimated_price
    reason = str(request.data.get('reason') or '').strip()

    sale.final_price = new_price
    sale.status = 'FINAL_OFFER_SENT'

    ist_now = timezone.now().astimezone(datetime.timezone(datetime.timedelta(hours=5, minutes=30)))
    note_line = f"[{ist_now.strftime('%d %b %Y %I:%M %p')}] Admin updated final price: ₹{old_price} -> ₹{new_price}"
    if reason:
        note_line += f" ({reason})"
    sale.admin_notes = f"{sale.admin_notes}\n{note_line}".strip() if sale.admin_notes else note_line
    sale.save()

    # Keep inspection suggested_final_price in sync so Admin & Agent views show the updated price
    inspection = getattr(sale, 'inspection', None)
    if inspection is not None:
        inspection.suggested_final_price = new_price
        inspection.save(update_fields=['suggested_final_price'])

    return Response({'message': 'Final offer updated', 'sale': PhoneSaleDetailSerializer(sale).data})

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def shift_pickup_to_next_day_view(request, pk):
    """Admin or Collection Agent manually shifts an order to tomorrow (or next available day)"""
    if not getattr(request.user, 'is_staff_role', False):
        return Response({'detail': 'Staff access required'}, status=status.HTTP_403_FORBIDDEN)

    sale = _get_sale_instance(pk)
    if not sale:
        return Response({'detail': f'Sale order not found for identifier: {pk}'}, status=status.HTTP_404_NOT_FOUND)

    now_ist = timezone.now().astimezone(IST)
    tomorrow_ist = (now_ist + datetime.timedelta(days=1)).date()

    cur_date = sale.pickup_date or now_ist.date()
    # Shift either to tomorrow or cur_date + 1 day
    new_date = max(tomorrow_ist, cur_date + datetime.timedelta(days=1))
    orig_str = sale.pickup_date.strftime('%d %b %Y') if sale.pickup_date else 'Unscheduled'

    sale.pickup_date = new_date
    sale.pickup_slot = request.data.get('pickup_slot') or 'Morning (10:00 AM - 1:00 PM)'
    if sale.status in ['SUBMITTED', 'INSPECTION_PENDING']:
        sale.status = 'PICKUP_SCHEDULED'

    actor = getattr(request.user, 'full_name', '') or request.user.username
    audit = f"[{now_ist.strftime('%d %b, %I:%M %p')}] Rescheduled from {orig_str} to {new_date.strftime('%d %b %Y')} by {actor}."
    sale.admin_notes = (sale.admin_notes + '\n' + audit).strip() if sale.admin_notes else audit
    sale.save()

    return Response({
        'message': f'Pickup successfully shifted to {new_date.strftime("%d %b %Y")}',
        'sale': PhoneSaleDetailSerializer(sale).data
    })

@api_view(['GET'])
@permission_classes([AllowAny])
def pincode_lookup_view(request):
    """Validates 6-digit PIN code and resolves city/state/serviceability"""
    pincode = request.GET.get('pincode', '')
    res = resolve_pincode(pincode)
    return Response(res, status=status.HTTP_200_OK if res.get('valid') else status.HTTP_400_BAD_REQUEST)

