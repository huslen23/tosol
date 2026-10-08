from django.contrib import admin
from django.urls import path, include

from rest_framework.routers import DefaultRouter

from core.views import (
    register,
    verify,
    login_view,
    resend_otp,
)
from core.marketplace import PropertyViewSet, profile, logout
from core.passwords import change_password, forgot_password, reset_password
from django.conf import settings
from django.conf.urls.static import static
from .health import health

router = DefaultRouter()
from core.discovery import DistrictViewSet, ComplexViewSet
router.register(r"districts", DistrictViewSet, basename="district")
router.register(r"complexes", ComplexViewSet, basename="complex")
router.register(r"properties", PropertyViewSet, basename="property")


urlpatterns = [
    path("health/", health),
    path("admin/", admin.site.urls),

    path("api/", include(router.urls)),
    path("api/resend-otp/", resend_otp, name="resend_otp"),
    path("api/register/", register, name="register"),
    path("api/verify/", verify, name="verify"),
    path("api/login/", login_view, name="login"),
    path("api/profile/", profile, name="profile"),
    path("api/logout/", logout, name="logout"),
    path("api/password/change/", change_password),
    path("api/password/forgot/", forgot_password),
    path("api/password/reset/", reset_password),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
