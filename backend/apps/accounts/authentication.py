import datetime
import jwt
from django.conf import settings
from rest_framework import authentication, exceptions
from .models import User

def generate_jwt_token(user):
    payload = {
        'user_id': user.id,
        'email': user.email,
        'role': user.role,
        'exp': datetime.datetime.utcnow() + datetime.timedelta(days=7),
        'iat': datetime.datetime.utcnow(),
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm='HS256')

class JWTAuthentication(authentication.BaseAuthentication):
    def authenticate(self, request):
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return None

        parts = auth_header.split()
        if len(parts) != 2 or parts[0].lower() != 'bearer':
            return None

        token = parts[1]
        try:
            payload = jwt.decode(token, settings.SECRET_KEY, algorithms=['HS256'])
        except (jwt.ExpiredSignatureError, jwt.InvalidTokenError):
            # Do not raise AuthenticationFailed here to avoid bricking public endpoints
            # when a client has a stale or invalid token in localStorage.
            # Protected endpoints with IsAuthenticated will still reject AnonymousUser cleanly.
            return None

        try:
            user = User.objects.get(id=payload['user_id'])
        except User.DoesNotExist:
            return None

        if not user.is_active:
            raise exceptions.AuthenticationFailed('User is deactivated')

        return (user, token)
