import threading
import logging
from django.db import connection
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Brand, PhoneModel
from .image_resolver import resolve_brand_logo, resolve_model_image

logger = logging.getLogger(__name__)

def _async_resolve_brand_logo(brand_id):
    """Worker function executed in background thread for Brand."""
    try:
        connection.close()  # Refresh thread DB connection
        brand = Brand.objects.filter(id=brand_id).first()
        if not brand or brand.logo_base64:
            return
            
        logo_b64 = resolve_brand_logo(brand.name)
        if logo_b64:
            Brand.objects.filter(id=brand_id, logo_base64='').update(logo_base64=logo_b64)
            logger.info(f"Auto-resolved brand logo for: {brand.name}")
    except Exception as e:
        logger.error(f"Error auto-resolving brand logo for id {brand_id}: {e}")
    finally:
        connection.close()

def _async_resolve_model_image(model_id):
    """Worker function executed in background thread for PhoneModel."""
    try:
        connection.close()  # Refresh thread DB connection
        model = PhoneModel.objects.select_related('brand').filter(id=model_id).first()
        if not model or model.image_base64:
            return
            
        brand_name = model.brand.name if model.brand else 'Device'
        img_b64 = resolve_model_image(brand_name, model.name)
        if img_b64:
            PhoneModel.objects.filter(id=model_id, image_base64='').update(image_base64=img_b64)
            logger.info(f"Auto-resolved phone image for: {brand_name} {model.name}")
    except Exception as e:
        logger.error(f"Error auto-resolving model image for id {model_id}: {e}")
    finally:
        connection.close()

@receiver(post_save, sender=Brand)
def trigger_brand_logo_autoseed(sender, instance, created, **kwargs):
    """Triggers non-blocking automatic logo resolution when a brand has no logo."""
    if not instance.logo_base64:
        # Launch non-blocking background thread
        thread = threading.Thread(
            target=_async_resolve_brand_logo,
            args=(instance.id,),
            daemon=True
        )
        thread.start()

@receiver(post_save, sender=PhoneModel)
def trigger_model_image_autoseed(sender, instance, created, **kwargs):
    """Triggers non-blocking automatic image resolution when a model has no image."""
    if not instance.image_base64:
        # Launch non-blocking background thread
        thread = threading.Thread(
            target=_async_resolve_model_image,
            args=(instance.id,),
            daemon=True
        )
        thread.start()
