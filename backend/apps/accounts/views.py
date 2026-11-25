from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from django.contrib.auth import authenticate
from .models import User
from .serializers import UserSerializer, RegisterSerializer, LoginSerializer
from .authentication import generate_jwt_token

def is_admin_user(user):
    if not user or not user.is_authenticated:
        return False
    role_str = str(getattr(user, 'role', '') or '').strip().upper()
    return role_str in ['ADMIN', 'SUPER_ADMIN'] or bool(getattr(user, 'is_staff', False)) or bool(getattr(user, 'is_superuser', False))

@api_view(['POST'])
@permission_classes([AllowAny])
def register_view(request):
    data = request.data.copy() if hasattr(request.data, 'copy') else dict(request.data)
    is_admin = is_admin_user(request.user)
    if not is_admin:
        data['role'] = 'CUSTOMER'

    serializer = RegisterSerializer(data=data, context={'is_admin': is_admin})
    if serializer.is_valid():
        user = serializer.save()
        token = generate_jwt_token(user)
        return Response({
            'message': 'Registration successful',
            'token': token,
            'user': UserSerializer(user).data
        }, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['POST'])
@permission_classes([AllowAny])
def login_view(request):
    serializer = LoginSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    identifier = serializer.validated_data['email'].strip()
    password = serializer.validated_data['password']

    # Support login with either email or 10-digit mobile number
    user = None
    clean_digits = ''.join(filter(str.isdigit, identifier))
    if len(clean_digits) >= 10:
        user = User.objects.filter(phone__endswith=clean_digits[-10:]).first()
    if not user:
        user = User.objects.filter(email__iexact=identifier).first()

    if not user:
        return Response({'detail': 'Invalid email/phone or password'}, status=status.HTTP_401_UNAUTHORIZED)

    if not user.check_password(password):
        return Response({'detail': 'Invalid email or password'}, status=status.HTTP_401_UNAUTHORIZED)

    if not user.is_active:
        return Response({'detail': 'Account is inactive'}, status=status.HTTP_403_FORBIDDEN)

    token = generate_jwt_token(user)
    return Response({
        'message': 'Login successful',
        'token': token,
        'user': UserSerializer(user).data
    })

@api_view(['GET', 'PUT', 'PATCH'])
@permission_classes([IsAuthenticated])
def me_view(request):
    if request.method in ['PUT', 'PATCH']:
        serializer = UserSerializer(request.user, data=request.data, partial=True)
        if serializer.is_valid():
            user = serializer.save()
            return Response({
                'message': 'Profile updated successfully',
                'user': UserSerializer(user).data
            })
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    return Response({
        'user': UserSerializer(request.user).data
    })

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def collection_agents_view(request):
    """List or create collection agents (Admin only)"""
    if not is_admin_user(request.user):
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)
    
    if request.method == 'POST':
        data = request.data.copy() if hasattr(request.data, 'copy') else dict(request.data)
        data['role'] = 'COLLECTION_AGENT'
        if not data.get('email') or not str(data.get('email', '')).strip():
            raw_ph = ''.join(c for c in str(data.get('phone', '')) if c.isdigit())
            data['email'] = f"agent_{raw_ph or 'new'}@dollybuyback.com"
        serializer = RegisterSerializer(data=data, context={'is_admin': True})
        if serializer.is_valid():
            agent = serializer.save()
            return Response({
                'message': 'Collection Agent created successfully',
                'agent': UserSerializer(agent).data
            }, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    agents = User.objects.filter(role__in=['COLLECTION_AGENT', 'AGENT', 'FIELD_AGENT'], is_active=True)
    return Response(UserSerializer(agents, many=True).data)

@api_view(['GET', 'PUT', 'PATCH', 'DELETE'])
@permission_classes([IsAuthenticated])
def agent_detail_view(request, agent_id):
    """View, update or delete a field agent (Admin only)"""
    if not is_admin_user(request.user):
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

    try:
        agent = User.objects.get(pk=agent_id)
    except User.DoesNotExist:
        return Response({'detail': 'Agent not found'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        return Response(UserSerializer(agent).data)

    if request.method in ['PUT', 'PATCH']:
        data = request.data
        if 'full_name' in data and data['full_name']:
            agent.full_name = str(data['full_name']).strip()
        if 'phone' in data and data['phone']:
            agent.phone = str(data['phone']).strip()
        if 'email' in data and data['email']:
            agent.email = str(data['email']).strip().lower()
        if 'password' in data and data['password']:
            new_pass = str(data['password']).strip()
            if len(new_pass) < 6:
                return Response({'detail': 'Password must be at least 6 characters'}, status=status.HTTP_400_BAD_REQUEST)
            agent.set_password(new_pass)
        if 'is_active' in data:
            agent.is_active = bool(data['is_active'])
        agent.save()
        return Response({
            'message': 'Agent details updated successfully',
            'agent': UserSerializer(agent).data
        })

    if request.method == 'DELETE':
        from apps.sales.models import PhoneSale
        # Unassign any active orders currently assigned to this agent back to the unassigned queue
        PhoneSale.objects.filter(assigned_agent=agent).update(assigned_agent=None)

        agent_name = agent.full_name or agent.phone or f"#{agent.id}"

        # Check if agent has performed inspections or payouts (protected by ForeignKey models.PROTECT)
        has_inspections = False
        has_payouts = False
        try:
            has_inspections = agent.inspections_performed.exists()
        except Exception:
            pass
        try:
            has_payouts = agent.payouts_authorized.exists()
        except Exception:
            pass

        if has_inspections or has_payouts:
            # Soft-delete / deactivate so historical audit and inspection records remain valid
            agent.is_active = False
            agent.save()
            return Response({
                'message': f"Agent '{agent_name}' deactivated and removed from active roster (audit records preserved).",
                'deleted': True
            })
        else:
            # Hard delete if no dependent records
            agent.delete()
            return Response({
                'message': f"Agent '{agent_name}' permanently deleted.",
                'deleted': True
            })

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def customers_view(request):
    """List and manage registered customers (Admin only)"""
    if not is_admin_user(request.user):
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

    if request.method == 'POST':
        data = request.data.copy() if hasattr(request.data, 'copy') else dict(request.data)
        data['role'] = 'CUSTOMER'
        if not data.get('email') or not str(data.get('email', '')).strip():
            raw_ph = ''.join(c for c in str(data.get('phone', '')) if c.isdigit())
            data['email'] = f"cust_{raw_ph or 'new'}@dollybuyback.com"
        serializer = RegisterSerializer(data=data, context={'is_admin': True})
        if serializer.is_valid():
            customer = serializer.save()
            for field in ['default_address', 'city', 'pincode', 'default_upi_id']:
                if field in data and data[field]:
                    setattr(customer, field, str(data[field]).strip())
            customer.save()
            return Response({
                'message': 'Customer account created successfully',
                'customer': UserSerializer(customer).data
            }, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    search = request.GET.get('search', '').strip()
    customers = User.objects.filter(role='CUSTOMER')
    if search:
        from django.db.models import Q
        customers = customers.filter(
            Q(full_name__icontains=search) |
            Q(phone__icontains=search) |
            Q(email__icontains=search) |
            Q(city__icontains=search)
        )
    customers = customers.order_by('-created_at')
    return Response(UserSerializer(customers, many=True).data)

@api_view(['GET', 'PUT', 'PATCH', 'DELETE'])
@permission_classes([IsAuthenticated])
def customer_detail_view(request, user_id):
    """View, update or toggle active state of a customer (Admin only)"""
    if not is_admin_user(request.user):
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)

    try:
        customer = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        return Response({'detail': 'Customer not found'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        return Response(UserSerializer(customer).data)

    if request.method in ['PUT', 'PATCH']:
        data = request.data
        if 'role' in data and data['role'] in ['CUSTOMER', 'COLLECTION_AGENT', 'ADMIN', 'SUPER_ADMIN']:
            customer.role = data['role']
        if 'is_active' in data:
            customer.is_active = bool(data['is_active'])
        if 'full_name' in data and data['full_name']:
            customer.full_name = str(data['full_name']).strip()
        if 'phone' in data and data['phone']:
            customer.phone = str(data['phone']).strip()
        if 'email' in data and data['email']:
            customer.email = str(data['email']).strip().lower()
        if 'default_address' in data:
            customer.default_address = str(data['default_address']).strip()
        if 'city' in data:
            customer.city = str(data['city']).strip()
        if 'pincode' in data:
            customer.pincode = str(data['pincode']).strip()
        if 'default_upi_id' in data:
            customer.default_upi_id = str(data['default_upi_id']).strip()
        customer.save()
        return Response({
            'message': 'Customer details updated successfully',
            'customer': UserSerializer(customer).data
        })

    if request.method == 'DELETE':
        action = request.GET.get('action', '').lower()
        if action == 'toggle':
            customer.is_active = not customer.is_active
            customer.save()
            return Response({
                'message': f"Customer {'activated' if customer.is_active else 'deactivated'} successfully",
                'is_active': customer.is_active
            })

        # Permanent deletion of customer profile
        from apps.sales.models import PhoneSale
        PhoneSale.objects.filter(customer=customer).update(customer=None)
        cust_name = customer.full_name or customer.phone or f"#{customer.id}"
        customer.delete()
        return Response({
            'message': f"Customer '{cust_name}' deleted successfully",
            'deleted': True
        }, status=status.HTTP_200_OK)

@api_view(['POST', 'DELETE'])
@permission_classes([IsAuthenticated])
def delete_account_view(request):
    """Allow an authenticated user to permanently delete their account and erase personal data (Mandatory for App Store & Play Store compliance)"""
    user = request.user
    user.is_active = False
    # Anonymize personal info to protect privacy while maintaining transaction audit integrity
    user.phone = f"del_{user.id}_{user.phone[-4:]}"
    user.email = f"deleted_{user.id}@dollyresell.com"
    user.full_name = "Deleted User"
    user.default_address = ""
    user.default_upi_id = ""
    user.save()
    return Response({'message': 'Your account and personal data have been deleted successfully.'}, status=status.HTTP_200_OK)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def change_password_view(request):
    """Allow an authenticated user to change their own password, or admin to reset"""
    data = request.data
    old_password = data.get('old_password', '')
    new_password = str(data.get('new_password', '')).strip()

    if not new_password or len(new_password) < 6:
        return Response({'detail': 'New password must be at least 6 characters long'}, status=status.HTTP_400_BAD_REQUEST)

    is_admin = getattr(request.user, 'is_admin_role', False)
    if not is_admin or old_password:
        if not request.user.check_password(old_password):
            return Response({'detail': 'Current password does not match'}, status=status.HTTP_400_BAD_REQUEST)

    request.user.set_password(new_password)
    request.user.save()
    return Response({'message': 'Password changed successfully!'}, status=status.HTTP_200_OK)

@api_view(['POST'])
@permission_classes([AllowAny])
def send_customer_otp_view(request):
    """Send an OTP code to customer mobile for registration or forgot password"""
    data = request.data
    phone = str(data.get('phone', '')).strip()
    purpose = str(data.get('purpose', 'REGISTRATION')).upper()
    if purpose not in ['REGISTRATION', 'PASSWORD_RESET']:
        purpose = 'REGISTRATION'

    clean_digits = ''.join(c for c in phone if c.isdigit())
    clean_phone = clean_digits[-10:] if len(clean_digits) >= 10 else ''
    if len(clean_phone) != 10:
        return Response({'detail': 'Please enter a valid 10-digit mobile number'}, status=status.HTTP_400_BAD_REQUEST)

    existing_user = User.objects.filter(phone__endswith=clean_phone).first()
    if purpose == 'REGISTRATION' and existing_user:
        return Response({'detail': 'An account with this mobile number already exists. Please sign in with your password.'}, status=status.HTTP_400_BAD_REQUEST)

    if purpose == 'PASSWORD_RESET' and not existing_user:
        return Response({'detail': 'No account found with this mobile number. Please register.'}, status=status.HTTP_404_NOT_FOUND)

    from .sms_service import send_customer_otp
    res = send_customer_otp(clean_phone, purpose=purpose)
    if res.get('success'):
        return Response(res, status=status.HTTP_200_OK)
    else:
        return Response(res, status=status.HTTP_400_BAD_REQUEST)

@api_view(['POST'])
@permission_classes([AllowAny])
def verify_register_customer_view(request):
    """Verify 6-digit OTP and complete customer registration with password"""
    data = request.data
    full_name = str(data.get('full_name', '')).strip()
    phone = str(data.get('phone', '')).strip()
    password = str(data.get('password', '')).strip()
    otp_code = str(data.get('otp_code', '')).strip()

    clean_digits = ''.join(c for c in phone if c.isdigit())
    clean_phone = clean_digits[-10:] if len(clean_digits) >= 10 else ''

    if not full_name:
        return Response({'detail': 'Full name is required.'}, status=status.HTTP_400_BAD_REQUEST)
    if len(clean_phone) != 10:
        return Response({'detail': 'Please enter a valid 10-digit mobile number.'}, status=status.HTTP_400_BAD_REQUEST)
    if not password or len(password) < 6:
        return Response({'detail': 'Password must be at least 6 characters long.'}, status=status.HTTP_400_BAD_REQUEST)
    if not otp_code or len(otp_code) < 4:
        return Response({'detail': 'Please enter the verification code sent to your mobile.'}, status=status.HTTP_400_BAD_REQUEST)

    if User.objects.filter(phone__endswith=clean_phone).exists():
        return Response({'detail': 'An account with this mobile number already exists. Please sign in.'}, status=status.HTTP_400_BAD_REQUEST)

    from .models import PhoneOTP
    otp = PhoneOTP.objects.filter(phone=clean_phone, purpose='REGISTRATION', is_verified=False).first()
    if not otp or otp.is_expired():
        return Response({'detail': 'Verification code has expired or is invalid. Please request a new code.'}, status=status.HTTP_400_BAD_REQUEST)

    if otp.otp_code != otp_code:
        otp.attempts += 1
        otp.save()
        if otp.attempts >= 3:
            otp.delete()
            from django.conf import settings
            admin_phone = getattr(settings, 'ADMIN_SUPPORT_PHONE', '9025232453')
            return Response({
                'detail': 'Too many incorrect attempts. Please call our Admin Desk to activate your account directly!',
                'fallback_to_admin': True,
                'admin_phone': admin_phone
            }, status=status.HTTP_400_BAD_REQUEST)
        return Response({'detail': f'Incorrect code. {3 - otp.attempts} attempts remaining.'}, status=status.HTTP_400_BAD_REQUEST)

    # Validated
    otp.is_verified = True
    otp.save()

    email = str(data.get('email', '')).strip()
    if not email:
        email = f"{clean_phone}@dollybuyback.com"
    if User.objects.filter(email__iexact=email).exists():
        import random
        email = f"cust_{clean_phone}_{random.randint(100, 999)}@dollybuyback.com"

    user = User.objects.create_user(
        email=email,
        phone=clean_phone,
        full_name=full_name,
        password=password,
        role='CUSTOMER'
    )
    token = generate_jwt_token(user)
    return Response({
        'message': 'Account verified and created successfully!',
        'token': token,
        'user': UserSerializer(user).data
    }, status=status.HTTP_201_CREATED)

@api_view(['POST'])
@permission_classes([AllowAny])
def reset_password_customer_view(request):
    """Verify OTP and reset customer password"""
    data = request.data
    phone = str(data.get('phone', '')).strip()
    otp_code = str(data.get('otp_code', '')).strip()
    new_password = str(data.get('new_password', '')).strip()

    clean_digits = ''.join(c for c in phone if c.isdigit())
    clean_phone = clean_digits[-10:] if len(clean_digits) >= 10 else ''

    if len(clean_phone) != 10:
        return Response({'detail': 'Please enter a valid 10-digit mobile number.'}, status=status.HTTP_400_BAD_REQUEST)
    if not new_password or len(new_password) < 6:
        return Response({'detail': 'New password must be at least 6 characters long.'}, status=status.HTTP_400_BAD_REQUEST)
    if not otp_code or len(otp_code) < 4:
        return Response({'detail': 'Please enter the verification code.'}, status=status.HTTP_400_BAD_REQUEST)

    user = User.objects.filter(phone__endswith=clean_phone).first()
    if not user:
        return Response({'detail': 'No account found with this mobile number.'}, status=status.HTTP_404_NOT_FOUND)

    from .models import PhoneOTP
    otp = PhoneOTP.objects.filter(phone=clean_phone, purpose='PASSWORD_RESET', is_verified=False).first()
    if not otp or otp.is_expired():
        return Response({'detail': 'Verification code has expired. Please request a new code.'}, status=status.HTTP_400_BAD_REQUEST)

    if otp.otp_code != otp_code:
        otp.attempts += 1
        otp.save()
        if otp.attempts >= 3:
            otp.delete()
            from django.conf import settings
            admin_phone = getattr(settings, 'ADMIN_SUPPORT_PHONE', '9025232453')
            return Response({
                'detail': 'Too many incorrect attempts. Please call Admin to reset your password.',
                'fallback_to_admin': True,
                'admin_phone': admin_phone
            }, status=status.HTTP_400_BAD_REQUEST)
        return Response({'detail': f'Incorrect code. {3 - otp.attempts} attempts remaining.'}, status=status.HTTP_400_BAD_REQUEST)

    # Validated
    otp.is_verified = True
    otp.save()

    user.set_password(new_password)
    user.save()

    token = generate_jwt_token(user)
    return Response({
        'message': 'Password reset successfully! You are now signed in.',
        'token': token,
        'user': UserSerializer(user).data
    }, status=status.HTTP_200_OK)
