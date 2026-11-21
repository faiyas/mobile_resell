from django.db import models
from django.utils.text import slugify

class DeviceCategory(models.Model):
    name = models.CharField(max_length=100, unique=True) # Mobile, Tablet, Laptop, Smartwatch, Dead Phone, Other
    slug = models.SlugField(max_length=120, unique=True, blank=True)
    subtitle = models.CharField(max_length=150, blank=True, default='') # e.g. "Sell smartphones"
    icon_name = models.CharField(max_length=50, default='Smartphone')
    image_base64 = models.TextField(blank=True, default='')
    display_order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['display_order', 'name']

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(self.name)
        super().save(*args, **kwargs)

    def __str__(self):
        return self.name

class Brand(models.Model):
    category = models.ForeignKey(DeviceCategory, on_delete=models.CASCADE, related_name='brands', null=True, blank=True)
    name = models.CharField(max_length=100, unique=True)
    slug = models.SlugField(max_length=120, unique=True, blank=True)
    logo_base64 = models.TextField(blank=True, default='', help_text="Base64 encoded brand icon/logo")
    is_active = models.BooleanField(default=True)
    display_order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['display_order', 'name']

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(self.name)
        super().save(*args, **kwargs)

    def __str__(self):
        return self.name

class DeviceSeries(models.Model):
    brand = models.ForeignKey(Brand, on_delete=models.CASCADE, related_name='series')
    name = models.CharField(max_length=100) # e.g. "iPhone 11 Series", "iPhone 12 Series"
    display_order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['display_order', 'name']

    def __str__(self):
        return f"{self.brand.name} - {self.name}"

class PhoneModel(models.Model):
    brand = models.ForeignKey(Brand, on_delete=models.CASCADE, related_name='models')
    series = models.ForeignKey(DeviceSeries, on_delete=models.SET_NULL, null=True, blank=True, related_name='models')
    name = models.CharField(max_length=150)
    slug = models.SlugField(max_length=180, blank=True)
    image_base64 = models.TextField(blank=True, default='', help_text="Base64 encoded phone picture")
    release_year = models.PositiveIntegerField(null=True, blank=True)
    has_warranty = models.BooleanField(default=True, help_text="Set to False for older models out of warranty period so warranty question is skipped")
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-release_year', 'name']
        unique_together = ('brand', 'name')

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(f"{self.brand.name}-{self.name}")
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.brand.name} {self.name}"

class StorageVariant(models.Model):
    model = models.ForeignKey(PhoneModel, on_delete=models.CASCADE, related_name='variants')
    ram = models.CharField(max_length=50, blank=True, default='', help_text="e.g. 6GB, 8GB")
    storage = models.CharField(max_length=50, help_text="e.g. 64GB, 128GB, 256GB")
    base_price = models.DecimalField(max_digits=10, decimal_places=2, help_text="Base buyback price for mint condition")
    min_price = models.DecimalField(max_digits=10, decimal_places=2, default=500.00, help_text="Floor price regardless of damage")
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['base_price']
        unique_together = ('model', 'ram', 'storage')

    def __str__(self):
        spec = f"{self.ram} / {self.storage}" if self.ram else self.storage
        return f"{self.model} ({spec}) - Base: ₹{self.base_price}"

class CMSHomeSection(models.Model):
    SECTION_TYPES = (
        ('HERO_CAROUSEL', 'Hero Carousel / Banners'),
        ('QUICK_SERVICES', 'Quick Services Grid'),
        ('TOP_BRANDS', 'Top Brands List'),
        ('CATEGORIES', 'Device Categories'),
        ('SECURITY_BANNER', 'Security & Trust Banner'),
        ('CUSTOM_BANNER', 'Custom Promotional Banner'),
    )
    section_type = models.CharField(max_length=50, choices=SECTION_TYPES, unique=True)
    title = models.CharField(max_length=150)
    subtitle = models.CharField(max_length=255, blank=True, default='')
    data_json = models.JSONField(default=dict, blank=True, help_text="Configured slides, icons, links, and items")
    display_order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['display_order']

    def __str__(self):
        return f"[{self.section_type}] {self.title}"
