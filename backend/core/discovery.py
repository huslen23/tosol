from django.db.models import Count, Avg, F, DecimalField, ExpressionWrapper
from rest_framework import serializers, viewsets
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import AllowAny, IsAuthenticated, IsAuthenticatedOrReadOnly
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied
from django.shortcuts import get_object_or_404
from rest_framework.permissions import BasePermission, SAFE_METHODS
from rest_framework.response import Response
from django.db.models.deletion import ProtectedError
from django.db import transaction
from .models import District, Complex, Property, ComplexRating, ComplexComment, ComfortWeights
from .comfort import summary, user_weights, RatingInput, WeightsInput, CommentSerializer


class DiscoveryPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100


class DistrictSerializer(serializers.ModelSerializer):
    property_count = serializers.SerializerMethodField()
    average_sale_price_per_m2 = serializers.SerializerMethodField()

    class Meta:
        model = District
        fields = ["id", "name", "description", "property_count", "average_sale_price_per_m2"]

    def get_property_count(self, obj):
        return Property.objects.filter(district=obj.name).count()

    def get_average_sale_price_per_m2(self, obj):
        value = Property.objects.filter(district=obj.name, listing_type="sale", area__gt=0, price__gt=0).aggregate(
            value=Avg(ExpressionWrapper(F("price") / F("area"), output_field=DecimalField())))["value"]
        return str(round(value, 2)) if value is not None else None


class ComplexSerializer(serializers.ModelSerializer):
    district_name = serializers.CharField(source="district.name", read_only=True)
    property_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = Complex
        fields = ["id", "name", "district", "district_name", "address", "description", "property_count"]


class AdminWritePermission(BasePermission):
    def has_permission(self, request, view):
        return request.method in SAFE_METHODS or bool(request.user.is_authenticated and request.user.is_staff)


class DistrictViewSet(viewsets.ModelViewSet):
    queryset = District.objects.order_by("name")
    serializer_class = DistrictSerializer
    pagination_class = DiscoveryPagination
    permission_classes = [AdminWritePermission]

    def destroy(self, request, *args, **kwargs):
        district = self.get_object()
        if Property.objects.filter(district=district.name).exists() or district.complexes.exists():
            return Response({"message": "Зар эсвэл хотхонтой дүүргийг устгах боломжгүй."}, status=409)
        try:
            return super().destroy(request, *args, **kwargs)
        except ProtectedError:
            return Response({"message": "Энэ дүүрэг хотхонтой холбоотой байна."}, status=409)

    @transaction.atomic
    def perform_update(self, serializer):
        old_name = serializer.instance.name
        district = serializer.save()
        if district.name != old_name:
            Property.objects.filter(district=old_name).update(district=district.name)


class ComplexViewSet(viewsets.ModelViewSet):
    serializer_class = ComplexSerializer
    pagination_class = DiscoveryPagination
    permission_classes = [AdminWritePermission]

    @action(detail=True, methods=['get'], permission_classes=[AllowAny])
    def comfort(self, request, pk=None):
        return Response(summary(self.get_object(), request.user))

    @action(detail=False, methods=['get', 'put'], permission_classes=[IsAuthenticated])
    def weights(self, request):
        if request.method == 'PUT':
            serializer = WeightsInput(data=request.data)
            serializer.is_valid(raise_exception=True)
            ComfortWeights.objects.update_or_create(user=request.user, defaults=serializer.validated_data)
        return Response({'weights': user_weights(request.user)})

    @action(detail=True, methods=['put', 'delete'], permission_classes=[IsAuthenticated], url_path='my-rating')
    @transaction.atomic
    def my_rating(self, request, pk=None):
        complex_obj = self.get_object()
        # Serialize upserts so concurrent saves cannot create duplicate ratings.
        Complex.objects.select_for_update().get(pk=complex_obj.pk)
        if request.method == 'DELETE':
            rating = ComplexRating.objects.filter(complex=complex_obj, user=request.user).first()
            if rating:
                comment_id = rating.explanation_comment_id
                rating.delete()
                if comment_id:
                    ComplexComment.objects.filter(pk=comment_id, user=request.user).delete()
        else:
            serializer = RatingInput(data=request.data)
            serializer.is_valid(raise_exception=True)
            data = dict(serializer.validated_data)
            explanation = data.pop('explanation', None)
            rating, _ = ComplexRating.objects.update_or_create(complex=complex_obj, user=request.user,
                                                               defaults=data)
            if explanation is not None:
                if explanation:
                    if rating.explanation_comment_id:
                        comment = rating.explanation_comment
                        comment.text = explanation
                        comment.save(update_fields=['text', 'updated_at'])
                    else:
                        rating.explanation_comment = ComplexComment.objects.create(
                            complex=complex_obj, user=request.user, text=explanation)
                        rating.save(update_fields=['explanation_comment'])
                elif rating.explanation_comment_id:
                    rating.explanation_comment.delete()
                    rating.explanation_comment = None
        return Response(summary(complex_obj, request.user))

    @action(detail=True, methods=['get', 'post'], permission_classes=[IsAuthenticatedOrReadOnly])
    def comments(self, request, pk=None):
        complex_obj = self.get_object()
        if request.method == 'POST':
            serializer = CommentSerializer(data=request.data, context={'request': request})
            serializer.is_valid(raise_exception=True)
            serializer.save(complex=complex_obj, user=request.user)
            return Response(serializer.data, status=201)
        comments = complex_obj.comments.select_related('user').all()
        page = self.paginate_queryset(comments)
        serializer = CommentSerializer(page, many=True, context={'request': request})
        return self.get_paginated_response(serializer.data)

    @action(detail=True, methods=['patch', 'delete'], permission_classes=[IsAuthenticated],
            url_path=r'comments/(?P<comment_id>\d+)')
    def comment(self, request, pk=None, comment_id=None):
        comment = get_object_or_404(ComplexComment, complex=self.get_object(), pk=comment_id)
        if request.method == 'DELETE':
            if comment.user_id != request.user.pk:
                raise PermissionDenied('Өөрийн сэтгэгдлийг л устгана.')
            comment.delete()
            return Response(status=204)
        if comment.user_id != request.user.pk:
            raise PermissionDenied('Өөрийн сэтгэгдлийг л засна.')
        serializer = CommentSerializer(comment, data=request.data, partial=True, context={'request': request})
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)

    def destroy(self, request, *args, **kwargs):
        complex_obj = self.get_object()
        if complex_obj.comfort_ratings.exists() or complex_obj.comments.exists():
            return Response({'message': 'Үнэлгээ, сэтгэгдэлтэй хотхоныг устгах боломжгүй.'}, status=409)
        return super().destroy(request, *args, **kwargs)

    @transaction.atomic
    def perform_update(self, serializer):
        complex_obj = serializer.save()
        complex_obj.properties.update(district=complex_obj.district.name)

    def get_queryset(self):
        qs = Complex.objects.select_related("district").annotate(property_count=Count("properties")).order_by("name", "id")
        if self.request.query_params.get("district"):
            qs = qs.filter(district__name=self.request.query_params["district"])
        return qs

