import urllib.parse
from decimal import Decimal
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from django.db import transaction
from django.shortcuts import get_object_or_404
from .models import Payment
from .serializers import PaymentRecordSerializer, PaymentDetailSerializer, PaymentListSerializer
from apps.sales.models import PhoneSale

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_payment_qr_view(request, sale_id):
    """
    Generates exact dynamic UPI payment string and details for the admin.
    Admin can scan this QR code with Google Pay, PhonePe, or Paytm!
    """
    if not getattr(request.user, 'is_admin_role', False):
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

    sale = get_object_or_404(PhoneSale, id=sale_id)
    pay_amount = sale.final_price if sale.final_price is not None else sale.estimated_price

    upi_id = sale.beneficiary_upi_id.strip() if sale.beneficiary_upi_id else ''
    payee_name = urllib.parse.quote(sale.beneficiary_name.strip())
    note = urllib.parse.quote(f"Buyback-{sale.sale_code}")

    # Standard UPI URI Specification
    upi_uri = f"upi://pay?pa={upi_id}&pn={payee_name}&am={pay_amount:.2f}&cu=INR&tn={note}" if upi_id else None

    if sale.is_custom_device or not sale.variant:
        dev_summary = f"{sale.custom_device_category or 'Gadget'} {sale.custom_device_name or 'Custom Device'} ({sale.custom_device_specs or 'Spec'})"
    else:
        dev_summary = f"{sale.variant.model.brand.name} {sale.variant.model.name} ({sale.variant.storage})"

    return Response({
        'sale_id': str(sale.id),
        'sale_code': sale.sale_code,
        'customer_name': sale.customer_name,
        'customer_phone': sale.customer_phone,
        'beneficiary_name': sale.beneficiary_name,
        'beneficiary_type': sale.beneficiary_type,
        'beneficiary_upi_id': sale.beneficiary_upi_id,
        'beneficiary_account_no': sale.beneficiary_account_no,
        'beneficiary_ifsc': sale.beneficiary_ifsc,
        'amount_to_pay': float(pay_amount),
        'upi_uri': upi_uri,
        'device_summary': dev_summary,
    })

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def record_payout_view(request):
    """
    Admin pays through their UPI/Bank app (GPay/PhonePe),
    then uploads the confirmation screenshot (Base64) + 12-digit UTR.
    This marks the sale as PAYMENT_COMPLETED.
    """
    if not getattr(request.user, 'is_admin_role', False):
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

    serializer = PaymentRecordSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    data = serializer.validated_data
    from apps.sales.views import _get_sale_instance
    sale = _get_sale_instance(data['sale_id'])
    if not sale:
        return Response({'detail': f'Sale order not found for identifier: {data["sale_id"]}'}, status=status.HTTP_404_NOT_FOUND)

    # Ensure device is physically collected before payout release
    if sale.status not in ['OWNERSHIP_TRANSFERRED', 'CUSTOMER_ACCEPTED']:
        return Response({'detail': f'Payout blocked: device status is {sale.status}. Physical device collection required.'}, status=status.HTTP_400_BAD_REQUEST)

    # Ensure sale cannot be paid twice
    if hasattr(sale, 'payment'):
        return Response({'detail': f'Sale {sale.sale_code} has already been paid (UTR: {sale.payment.utr_number})!'}, status=status.HTTP_400_BAD_REQUEST)

    with transaction.atomic():
        payment = Payment.objects.create(
            sale=sale,
            amount=data['amount'],
            payment_method=data['payment_method'],
            beneficiary_name=sale.beneficiary_name,
            beneficiary_upi_id=sale.beneficiary_upi_id,
            beneficiary_account_no=sale.beneficiary_account_no,
            beneficiary_ifsc=sale.beneficiary_ifsc,
            utr_number=data['utr_number'],
            payment_proof_base64=data['payment_proof_base64'],
            admin_notes=data.get('admin_notes', ''),
            paid_by=request.user,
            is_verified=True,
        )

        sale.status = 'PAYMENT_COMPLETED'
        if not sale.final_price:
            sale.final_price = data['amount']
        sale.save()

        # Audit log critical financial payout execution
        try:
            from apps.sales.audit import log_security_audit
            log_security_audit(
                user=request.user,
                action='PAYOUT_RECORDED',
                target_type='Payment',
                target_id=str(payment.id),
                details={
                    'sale_code': sale.sale_code,
                    'amount': str(data['amount']),
                    'utr_number': data['utr_number'],
                    'payment_method': data['payment_method'],
                    'beneficiary_upi_id': sale.beneficiary_upi_id or '',
                },
                request=request
            )
        except Exception:
            pass

    return Response({
        'message': f"Payment for {sale.sale_code} successfully recorded. Order marked as PAID!",
        'payment': PaymentDetailSerializer(payment).data,
        'sale_status': sale.status,
    }, status=status.HTTP_201_CREATED)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def payments_list_view(request):
    """Admin view of all payout records and financial summary with date filters"""
    if not getattr(request.user, 'is_admin_role', False):
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

    payments = Payment.objects.all().select_related('sale__variant__model__brand', 'paid_by').defer('payment_proof_base64')
    
    import datetime
    from django.utils import timezone
    IST = datetime.timezone(datetime.timedelta(hours=5, minutes=30))
    now_ist = timezone.now().astimezone(IST)
    today = now_ist.date()

    period = request.GET.get('period', '').lower()
    start_date = request.GET.get('start_date')
    end_date = request.GET.get('end_date')

    if period == 'today':
        payments = payments.filter(paid_at__date=today)
    elif period == 'yesterday':
        yesterday = today - datetime.timedelta(days=1)
        payments = payments.filter(paid_at__date=yesterday)
    elif period in ['week', 'this_week']:
        start_week = today - datetime.timedelta(days=today.weekday())
        payments = payments.filter(paid_at__date__gte=start_week, paid_at__date__lte=today)
    elif period in ['month', 'this_month']:
        start_month = today.replace(day=1)
        payments = payments.filter(paid_at__date__gte=start_month, paid_at__date__lte=today)
    else:
        if start_date:
            try:
                sd = datetime.date.fromisoformat(start_date.strip())
                payments = payments.filter(paid_at__date__gte=sd)
            except (ValueError, TypeError):
                pass
        if end_date:
            try:
                ed = datetime.date.fromisoformat(end_date.strip())
                payments = payments.filter(paid_at__date__lte=ed)
            except (ValueError, TypeError):
                pass

    total_disbursed = sum(p.amount for p in payments)
    
    return Response({
        'total_count': payments.count(),
        'total_disbursed': float(total_disbursed),
        'period': period or 'all',
        'payments': PaymentListSerializer(payments, many=True).data,
    })

@api_view(['GET'])
@permission_classes([AllowAny])
def payment_receipt_view(request, sale_code):
    """Public/Customer receipt endpoint for viewing and printing payment voucher"""
    sale = get_object_or_404(PhoneSale, sale_code=sale_code)
    if not hasattr(sale, 'payment'):
        return Response({'detail': 'Payment has not been completed yet for this sale'}, status=status.HTTP_400_BAD_REQUEST)

    payment = sale.payment
    if sale.is_custom_device or not sale.variant:
        dev_title = f"{sale.custom_device_category or 'Gadget'} {sale.custom_device_name or 'Custom Device'}"
        dev_storage = sale.custom_device_specs or 'Standard'
    else:
        dev_title = f"{sale.variant.model.brand.name} {sale.variant.model.name}"
        dev_storage = sale.variant.storage

    import datetime
    ist = datetime.timezone(datetime.timedelta(hours=5, minutes=30))
    paid_at_ist = payment.paid_at.astimezone(ist) if payment.paid_at else None

    return Response({
        'receipt_number': f"REC-{payment.id:06d}",
        'sale_code': sale.sale_code,
        'date': paid_at_ist.strftime('%d-%b-%Y %I:%M %p IST') if paid_at_ist else '',
        'device': dev_title,
        'storage': dev_storage,
        'imei': sale.imei_number or 'Verified at handover',
        'customer_name': sale.customer_name,
        'customer_phone': sale.customer_phone,
        'payout_amount': float(payment.amount),
        'payment_method': payment.get_payment_method_display(),
        'utr_number': payment.utr_number,
        'beneficiary': {
            'name': payment.beneficiary_name,
            'upi_id': payment.beneficiary_upi_id,
            'account_no': payment.beneficiary_account_no,
            'ifsc': payment.beneficiary_ifsc,
        },
        'payment_proof_base64': payment.payment_proof_base64,
        'status': 'PAID',
    })
