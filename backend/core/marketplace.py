from decimal import Decimal, InvalidOperation
from django.db import transaction
from django.db.models import Q
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import viewsets, serializers
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, BasePermission, SAFE_METHODS
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response
from .models import Property, PropertyImage, Favorite
from .serializers import PropertySerializer, PropertyImageSerializer, UserSerializer


class OwnerPermission(BasePermission):
    def has_permission(self, request, view):
        return request.method in SAFE_METHODS or request.user.is_authenticated

    def has_object_permission(self, request, view, obj):
        return request.method in SAFE_METHODS or request.user.is_staff or obj.owner_id == request.user.pk


class PropertyPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100


class PropertyViewSet(viewsets.ModelViewSet):
    serializer_class = PropertySerializer
    permission_classes = [OwnerPermission]
    pagination_class = PropertyPagination

    def get_queryset(self):
        qs = Property.objects.select_related("owner", "complex__district").prefetch_related("images")
        params = self.request.query_params
        if params.get('located') == 'true':
            qs = qs.filter(latitude__isnull=False, longitude__isnull=False)
        if 'bbox' in params:
            try:
                west, south, east, north = [float(v) for v in params['bbox'].split(',')]
                import math
                if not all(math.isfinite(v) for v in (west, south, east, north)) or not (-180 <= west <= east <= 180 and -90 <= south <= north <= 90):
                    raise ValueError
            except (ValueError, TypeError):
                raise serializers.ValidationError({'bbox': 'Газрын зургийн хүрээ буруу байна.'})
            qs = qs.filter(longitude__gte=west, longitude__lte=east, latitude__gte=south, latitude__lte=north)
        if params.get("featured") == "true":
            qs = qs.filter(is_featured=True)
        for key, field in [("complex", "complex_id")]:
            if params.get(key):
                try:
                    value = int(params[key])
                    if value < 1:
                        raise ValueError
                except ValueError:
                    raise serializers.ValidationError({key: "Зөв ID оруулна уу."})
                qs = qs.filter(**{field: value})
        for field in ["listing_type", "property_type", "district"]:
            if params.get(field):
                qs = qs.filter(**{field: params[field]})
        if params.get("search"):
            query = params["search"]
            qs = qs.filter(Q(title__icontains=query) | Q(location__icontains=query) | Q(district__icontains=query) | Q(description__icontains=query))
        for param, field in {"min_price": "price__gte", "max_price": "price__lte", "min_area": "area__gte", "max_area": "area__lte", "rooms": "rooms"}.items():
            if params.get(param):
                try:
                    value = Decimal(params[param])
                    if not value.is_finite() or value < 0 or (param == "rooms" and value != value.to_integral_value()):
                        raise InvalidOperation
                except (InvalidOperation, ValueError):
                    raise serializers.ValidationError({param: "Эерэг тоо оруулна уу."})
                qs = qs.filter(**{field: value})
        if params.get("mine") == "true" or params.get("saved") == "true":
            if not self.request.user.is_authenticated:
                return qs.none()
            if params.get("mine") == "true":
                qs = qs.filter(owner=self.request.user)
            if params.get("saved") == "true":
                qs = qs.filter(favorites__user=self.request.user)
        ordering = params.get("ordering", "-created_at")
        if ordering not in ["price", "-price", "area", "-area", "-created_at"]:
            raise serializers.ValidationError({"ordering": "Эрэмбэлэх утга буруу байна."})
        return qs.order_by(ordering, "-id")

    @action(detail=False, methods=["get"])
    def recommendations(self, request):
        # Explicit constraints, with no fabricated or out-of-budget fallback.
        if not request.query_params.get("max_price"):
            raise serializers.ValidationError({"max_price": "Төсвөө оруулна уу."})
        queryset = self.get_queryset()
        page = self.paginate_queryset(queryset)
        return self.get_paginated_response(self.get_serializer(page, many=True).data)

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["favorite_ids"] = set(Favorite.objects.filter(user=self.request.user).values_list("property_id", flat=True)) if self.request.user.is_authenticated else set()
        return context

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)

    @action(detail=True, methods=["post", "delete"], permission_classes=[IsAuthenticated])
    def favorite(self, request, pk=None):
        property = self.get_object()
        if request.method == "POST":
            Favorite.objects.get_or_create(user=request.user, property=property)
            return Response({"is_favorite": True})
        Favorite.objects.filter(user=request.user, property=property).delete()
        return Response({"is_favorite": False})

    @action(detail=True, methods=["post", "delete"])
    def photos(self, request, pk=None):
        property = self.get_object()
        if request.method == "DELETE":
            photo = property.images.filter(pk=request.data.get("image_id")).first()
            if not photo:
                return Response({"message": "Зураг олдсонгүй."}, status=404)
            photo.delete()
            return Response(status=204)
        files = request.FILES.getlist("images")
        if not files:
            raise serializers.ValidationError({"images": "Зургаа сонгоно уу."})
        image_field = serializers.ImageField()
        for file in files:
            if file.size > 10 * 1024 * 1024:
                raise serializers.ValidationError({"images": "Зураг бүр 10 MB-аас бага байна."})
            try:
                image_field.run_validation(file)
            except DjangoValidationError as exc:
                raise serializers.ValidationError({"images": exc.messages}) from exc
        with transaction.atomic():
            Property.objects.select_for_update().get(pk=property.pk)
            if property.images.count() + len(files) + bool(property.image) > 12:
                raise serializers.ValidationError({"images": "Хамгийн ихдээ 12 зураг оруулна."})
            photos = [PropertyImage.objects.create(property=property, image=file) for file in files]
        return Response(PropertyImageSerializer(photos, many=True, context={"request": request}).data, status=201)


@api_view(["GET", "PATCH"])
@permission_classes([IsAuthenticated])
def profile(request):
    serializer = UserSerializer(request.user, data=request.data, partial=True) if request.method == "PATCH" else UserSerializer(request.user)
    if request.method == "PATCH":
        serializer.is_valid(raise_exception=True)
        serializer.save()
    return Response(serializer.data)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def logout(request):
    if request.auth:
        request.auth.delete()
    request.session.flush()
    return Response({"success": True})
