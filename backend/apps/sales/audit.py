import json
import logging
from django.utils import timezone

logger = logging.getLogger('apps.audit')

def log_security_audit(user, action, target_type, target_id, details=None, request=None):
    """
    Centralized administrative and security audit logger.
    Records audit entries to logs/audit.log with full provenance:
    - User ID, role, and identifier
    - Action performed (e.g. PRICE_CHANGED, PAYOUT_RECORDED, AGENT_ASSIGNED)
    - Client IP address and User-Agent
    - Target resource and change details
    """
    ip_addr = None
    user_agent = None
    if request:
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip_addr = x_forwarded_for.split(',')[0].strip()
        else:
            ip_addr = request.META.get('REMOTE_ADDR')
        user_agent = request.META.get('HTTP_USER_AGENT', '')

    user_info = {
        'id': getattr(user, 'id', None) if user and user.is_authenticated else None,
        'email': getattr(user, 'email', None) if user and user.is_authenticated else 'anonymous',
        'role': str(getattr(user, 'role', 'ANON')),
    }

    entry = {
        'timestamp': timezone.now().isoformat(),
        'action': action,
        'user': user_info,
        'ip': ip_addr,
        'user_agent': user_agent,
        'target_type': target_type,
        'target_id': str(target_id) if target_id else None,
        'details': details or {},
    }

    try:
        logger.info(json.dumps(entry))
    except Exception as e:
        logger.error(f"Audit log writing failed: {e}")
