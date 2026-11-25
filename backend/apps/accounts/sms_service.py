import os
import random
import requests
import datetime
from django.conf import settings
from django.utils import timezone
from .models import PhoneOTP

def generate_6_digit_otp():
    return f"{random.randint(100000, 999999)}"

def send_customer_otp(phone, purpose='REGISTRATION'):
    """
    Sends a 6-digit OTP to customer mobile via Fast2SMS API.
    If Fast2SMS delivery fails (balance, DND, error), returns fallback_to_admin=True
    so the customer can call the admin desk to be created manually without OTP.
    """
    clean_digits = ''.join(c for c in str(phone) if c.isdigit())
    if len(clean_digits) > 10:
        clean_phone = clean_digits[-10:]
    else:
        clean_phone = clean_digits

    if len(clean_phone) != 10:
        return {
            'success': False,
            'message': 'Please enter a valid 10-digit mobile number.',
            'fallback_to_admin': False
        }

    otp_code = generate_6_digit_otp()
    expires_at = timezone.now() + datetime.timedelta(minutes=10)

    # Invalidate previous unverified OTPs for this phone + purpose
    PhoneOTP.objects.filter(phone=clean_phone, purpose=purpose, is_verified=False).delete()

    PhoneOTP.objects.create(
        phone=clean_phone,
        otp_code=otp_code,
        purpose=purpose,
        expires_at=expires_at
    )

    api_key = getattr(settings, 'FAST2SMS_API_KEY', '') or os.environ.get('FAST2SMS_API_KEY', '')
    admin_phone = getattr(settings, 'ADMIN_SUPPORT_PHONE', '9025232453')

    # If Fast2SMS key is not yet set in environment, log to console for development testing
    if not api_key or api_key.strip() == '' or 'YOUR_' in api_key:
        print(f"\n[FAST2SMS TEST CONSOLE] Mobile: {clean_phone} | Code: {otp_code} | Purpose: {purpose}\n")
        return {
            'success': True,
            'message': f'Verification OTP sent to {clean_phone}',
            'dev_mode': True,
            'otp': otp_code if settings.DEBUG else None
        }

    # Call Fast2SMS API
    try:
        url = "https://www.fast2sms.com/dev/bulkV2"
        headers = {
            "authorization": api_key.strip(),
            "Content-Type": "application/json"
        }
        payload = {
            "route": "otp",
            "variables_values": otp_code,
            "numbers": clean_phone
        }
        resp = requests.post(url, json=payload, headers=headers, timeout=8)
        data = resp.json() if resp.status_code == 200 else {}

        if resp.status_code == 200 and data.get("return") is True:
            return {
                'success': True,
                'message': f'Verification code sent successfully to {clean_phone}'
            }
        else:
            raw_msg = data.get("message", ["SMS Gateway error"])
            err_msg = raw_msg[0] if isinstance(raw_msg, list) and raw_msg else str(raw_msg)
            print(f"[FAST2SMS FAILED] {err_msg} | Response: {resp.text}")
            return {
                'success': False,
                'message': 'SMS delivery unavailable to your number. Please call our Admin Desk to activate your account directly!',
                'fallback_to_admin': True,
                'admin_phone': admin_phone,
                'error_detail': err_msg
            }
    except Exception as e:
        print(f"[FAST2SMS EXCEPTION] {e}")
        return {
            'success': False,
            'message': 'SMS delivery service timed out. Please call our Admin Desk to activate your account directly!',
            'fallback_to_admin': True,
            'admin_phone': admin_phone,
            'error_detail': str(e)
        }
