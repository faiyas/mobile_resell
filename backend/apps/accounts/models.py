from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.db import models

class UserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('Email address is required')
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('role', 'ADMIN')
        return self.create_user(email, password, **extra_fields)

class User(AbstractBaseUser, PermissionsMixin):
    ROLE_CHOICES = (
        ('CUSTOMER', 'Customer'),
        ('ADMIN', 'Administrator'),
        ('SUPER_ADMIN', 'Super Admin'),
        ('COLLECTION_AGENT', 'Collection Team'),
    )

    email = models.EmailField(unique=True, max_length=255, db_index=True)
    phone = models.CharField(max_length=20, blank=True, default='', db_index=True)
    full_name = models.CharField(max_length=150, blank=True, default='')
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='CUSTOMER')

    @property
    def is_admin_role(self):
        role_str = str(self.role or '').strip().upper()
        return role_str in ['ADMIN', 'SUPER_ADMIN'] or bool(self.is_staff) or bool(self.is_superuser)

    @property
    def is_staff_role(self):
        role_str = str(self.role or '').strip().upper()
        return role_str in ['ADMIN', 'SUPER_ADMIN', 'COLLECTION_AGENT', 'AGENT', 'FIELD_AGENT'] or bool(self.is_staff) or bool(self.is_superuser)

    @property
    def is_agent_role(self):
        role_str = str(self.role or '').strip().upper()
        return role_str in ['COLLECTION_AGENT', 'AGENT', 'FIELD_AGENT']
    
    # Saved Customer Doorstep & Payout Details (Auto-filled on bookings)
    default_address = models.TextField(blank=True, default='')
    city = models.CharField(max_length=100, blank=True, default='')
    pincode = models.CharField(max_length=20, blank=True, default='')
    default_upi_id = models.CharField(max_length=100, blank=True, default='')
    
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    objects = UserManager()

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['full_name']

    def clean(self):
        super().clean()
        if self.phone:
            # Check for phone uniqueness
            existing = User.objects.filter(phone=self.phone)
            if self.pk:
                existing = existing.exclude(pk=self.pk)
            if existing.exists():
                from django.core.exceptions import ValidationError
                raise ValidationError({'phone': 'An account with this mobile number already exists.'})

    def save(self, *args, **kwargs):
        if self.phone:
            self.clean()
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.email} ({self.get_role_display()})"
