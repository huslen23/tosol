from django.db import models
from django.conf import settings
from django.core.validators import MinValueValidator, MaxValueValidator, RegexValidator


class District(models.Model):
    name = models.CharField(max_length=80, unique=True)
    description = models.TextField(blank=True)

    def __str__(self):
        return self.name


class Complex(models.Model):
    name = models.CharField(max_length=160)
    district = models.ForeignKey(District, on_delete=models.PROTECT, related_name="complexes")
    address = models.CharField(max_length=255, blank=True)
    description = models.TextField(blank=True)

    def __str__(self):
        return self.name


class ComplexRating(models.Model):
    complex = models.ForeignKey(Complex, on_delete=models.PROTECT, related_name='comfort_ratings')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT)
    scores = models.JSONField(default=dict)
    explanation_comment = models.OneToOneField('ComplexComment', null=True, blank=True,
        on_delete=models.SET_NULL, related_name='rating')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=['complex', 'user'], name='unique_complex_user_rating')]


class ComfortWeights(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    weights = models.JSONField(default=dict)


class ComplexComment(models.Model):
    complex = models.ForeignKey(Complex, on_delete=models.PROTECT, related_name='comments')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT)
    text = models.TextField(max_length=2000)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at', '-id']


class Property(models.Model):
    source_url = models.URLField(max_length=1000, blank=True)
    remote_image_url = models.URLField(max_length=1000, blank=True)
    latitude = models.FloatField(null=True, blank=True, validators=[MinValueValidator(-90), MaxValueValidator(90)])
    longitude = models.FloatField(null=True, blank=True, validators=[MinValueValidator(-180), MaxValueValidator(180)])
    complex = models.ForeignKey(Complex, null=True, blank=True, on_delete=models.SET_NULL, related_name="properties")
    is_featured = models.BooleanField(default=False, db_index=True)
    owner = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.CASCADE, related_name="properties")
    listing_type = models.CharField(max_length=4, choices=[("sale", "Худалдах"), ("rent", "Түрээслэх")], default="sale", db_index=True)
    property_type = models.CharField(max_length=12, choices=[("apartment", "Орон сууц"), ("house", "Хаус"), ("office", "Оффис"), ("land", "Газар")], default="apartment", db_index=True)
    district = models.CharField(max_length=80, blank=True, db_index=True)
    rooms = models.PositiveSmallIntegerField(default=1, validators=[MinValueValidator(1), MaxValueValidator(100)])
    area = models.DecimalField(max_digits=10, decimal_places=2, default=1, validators=[MinValueValidator(0.01)])
    floor = models.PositiveSmallIntegerField(default=1, validators=[MaxValueValidator(200)])
    total_floors = models.PositiveSmallIntegerField(default=1, validators=[MinValueValidator(1), MaxValueValidator(200)])
    contact_phone = models.CharField(max_length=20, blank=True, validators=[RegexValidator(r"^\+?[0-9]{8,15}$", "Утасны дугаараа зөв оруулна уу.")])
    updated_at = models.DateTimeField(auto_now=True)
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)

    location = models.CharField(
        max_length=255,
        default=""
    )

    price = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
        validators=[MinValueValidator(0.01)]
    )

    image = models.ImageField(
        upload_to="properties/",
        blank=True,
        null=True
    )

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.title


class PropertyImage(models.Model):
    property = models.ForeignKey(Property, on_delete=models.CASCADE, related_name="images")
    image = models.ImageField(upload_to="properties/gallery/")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["id"]


class Favorite(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="favorites")
    property = models.ForeignKey(Property, on_delete=models.CASCADE, related_name="favorites")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["user", "property"], name="unique_user_favorite")]


class PasswordResetCode(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    token = models.CharField(max_length=64, unique=True)
    code_hash = models.CharField(max_length=128)
    password_snapshot = models.CharField(max_length=128)
    attempts = models.PositiveSmallIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)


class EmailOTP(models.Model):
    email = models.EmailField()

    otp = models.CharField(
        max_length=6
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    is_verified = models.BooleanField(
        default=False
    )

    def __str__(self):
        return f"{self.email} - {self.otp}"
