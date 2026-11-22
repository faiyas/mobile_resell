from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from django.contrib.auth import authenticate
from .models import User
from .serializers import UserSerializer, RegisterSerializer, LoginSerializer
from .authentication import generate_jwt_token

@api_view(['POST'])
@permission_classes([AllowAny])
def register_view(request):
    data = request.data.copy() if hasattr(request.data, 'copy') else dict(request.data)
    is_admin = bool(request.user and request.user.is_authenticated and getattr(request.user, 'role', '') == 'ADMIN')
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

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def collection_agents_view(request):
    """List collection agents for assignment (Admin only)"""
    if request.user.role not in ['ADMIN', 'SUPER_ADMIN']:
        return Response({'detail': 'Admin access required'}, status=status.HTTP_403_FORBIDDEN)
    
    agents = User.objects.filter(role='COLLECTION_AGENT', is_active=True)
    return Response(UserSerializer(agents, many=True).data)
