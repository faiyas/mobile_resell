from django.db import models
from django.utils.text import slugify

class Brand(models.Model):
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

class PhoneModel(models.Model):
    brand = models.ForeignKey(Brand, on_delete=models.CASCADE, related_name='models')
    name = models.CharField(max_length=150)
    slug = models.SlugField(max_length=180, blank=True)
    image_base64 = models.TextField(blank=True, default='', help_text="Base64 encoded phone picture")
    release_year = models.PositiveIntegerField(null=True, blank=True)
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
