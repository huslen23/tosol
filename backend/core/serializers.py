from rest_framework import serializers
from decimal import Decimal
from django.contrib.auth.models import User
from .models import Property, PropertyImage


class UserSerializer(serializers.ModelSerializer):
    def validate_username(self, value):
        if '@' in value:
            raise serializers.ValidationError('Хэрэглэгчийн нэрэнд @ тэмдэг ашиглахгүй.')
        users = User.objects.filter(username__iexact=value)
        if self.instance:
            users = users.exclude(pk=self.instance.pk)
        if users.exists():
            raise serializers.ValidationError('Энэ хэрэглэгчийн нэр бүртгэлтэй байна.')
        return value

    class Meta:
        model = User
        fields = ["id", "username", "email", "first_name", "last_name", "is_staff", "is_superuser"]
        read_only_fields = ["id", "email", "is_staff", "is_superuser"]


class PropertyImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = PropertyImage
        fields = ["id", "image"]


class PropertySerializer(serializers.ModelSerializer):
    complex_name = serializers.CharField(source="complex.name", read_only=True, default="")
    price = serializers.DecimalField(max_digits=12, decimal_places=2, min_value=Decimal("0.01"))
    area = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=Decimal("0.01"))
    owner = UserSerializer(read_only=True)
    images = PropertyImageSerializer(many=True, read_only=True)
    is_favorite = serializers.SerializerMethodField()
    is_owner = serializers.SerializerMethodField()
    can_manage = serializers.SerializerMethodField()

    class Meta:
        model = Property
        fields = "__all__"
        read_only_fields = ["created_at", "updated_at", "is_featured", "source_url", "remote_image_url"]

    def to_representation(self, instance):
        data = super().to_representation(instance)
        if not data.get("image") and instance.remote_image_url:
            data["image"] = instance.remote_image_url
        return data

    def get_is_favorite(self, obj):
        return obj.pk in self.context.get("favorite_ids", set())

    def get_is_owner(self, obj):
        request = self.context.get("request")
        return bool(request and request.user.is_authenticated and obj.owner_id == request.user.pk)

    def get_can_manage(self, obj):
        request = self.context.get("request")
        return bool(request and request.user.is_authenticated and (request.user.is_staff or obj.owner_id == request.user.pk))

    def validate(self, attrs):
        import math
        latitude = attrs.get('latitude', getattr(self.instance, 'latitude', None))
        longitude = attrs.get('longitude', getattr(self.instance, 'longitude', None))
        if (latitude is None) != (longitude is None):
            raise serializers.ValidationError({'latitude': 'Байршлын хоёр координатыг хамт оруулна уу.'})
        if any(v is not None and not math.isfinite(v) for v in (latitude, longitude)):
            raise serializers.ValidationError({'latitude': 'Байршлын координат буруу байна.'})
        complex = attrs.get("complex", getattr(self.instance, "complex", None))
        if complex:
            district = attrs.get("district", getattr(self.instance, "district", ""))
            if district != complex.district.name:
                raise serializers.ValidationError({"complex": "Хотхон сонгосон дүүрэгт харьяалагдахгүй байна."})
        floor = attrs.get("floor", getattr(self.instance, "floor", 1))
        total = attrs.get("total_floors", getattr(self.instance, "total_floors", 1))
        if floor > total:
            raise serializers.ValidationError({"floor": "Давхар нь нийт давхраас их байж болохгүй."})
        for field in ["title", "location", "district", "contact_phone"]:
            value = attrs.get(field, getattr(self.instance, field, ""))
            if not value.strip():
                raise serializers.ValidationError({field: "Энэ талбарыг бөглөнө үү."})
        return attrs
