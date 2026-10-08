import secrets
from datetime import timedelta
from importlib import import_module
from django.utils import timezone
from django.contrib.auth.hashers import make_password
from django.core.validators import validate_email
from django.core.exceptions import ValidationError
from rest_framework.authtoken.models import Token
from django.db import transaction

from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.core.mail import send_mail
from django.conf import settings
from django.core import signing

from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from .models import EmailOTP
from .serializers import UserSerializer
from django.db.models import Q


REGISTRATION_SALT = "core.registration-session"


def registration_token(session):
    session.save()
    return signing.dumps(
        {"session_key": session.session_key, "email": session["register_email"]},
        salt=REGISTRATION_SALT,
    )


def restore_registration_session(request):
    token = request.data.get("registration_token")
    if not token:
        return True  # Existing session-cookie clients remain supported.
    try:
        data = signing.loads(token, salt=REGISTRATION_SALT, max_age=600)
        email = str(request.data.get("email", "")).strip().lower()
        if data.get("email") != email or not data.get("session_key"):
            return False
        store = import_module(settings.SESSION_ENGINE).SessionStore(
            session_key=data["session_key"]
        )
        if store.get("register_email") != email:
            return False
        request._request.session = store
        return True
    except (signing.BadSignature, TypeError, ValueError, AttributeError):
        return False


# =========================================================
# PROPERTY CRUD
# =========================================================



# =========================================================
# REGISTER
# =========================================================

@api_view(["POST"])
def register(request):
    email = str(request.data.get("email", "")).strip().lower()
    password = request.data.get("password")
    first_name = request.data.get("first_name", "")
    last_name = request.data.get("last_name", "")
    username = str(request.data.get("username", "")).strip()
    if request.data.get("password_confirm") != password:
        return Response({"message": "Нууц үг давтаж оруулсан утгатай таарахгүй байна."}, status=400)
    if not username or "@" in username:
        return Response({"message": "Хэрэглэгчийн нэр оруулна уу. @ тэмдэг ашиглахгүй."}, status=400)
    try:
        User._meta.get_field("username").clean(username, None)
    except ValidationError:
        return Response({"message": "Хэрэглэгчийн нэр 150 хүртэл тэмдэгттэй, зөвшөөрөгдсөн тэмдэгтээр байна."}, status=400)
    if User.objects.filter(username__iexact=username).exists():
        return Response({"message": "Энэ хэрэглэгчийн нэр бүртгэлтэй байна."}, status=400)

    try:
        validate_email(email)
    except ValidationError:
        return Response({"success": False, "message": "И-мэйл хаягаа зөв оруулна уу."}, status=400)

    if not email:
        return Response(
            {
                "success": False,
                "message": "И-мэйл хаяг оруулна уу."
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    if not password:
        return Response(
            {
                "success": False,
                "message": "Нууц үг оруулна уу."
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    if not isinstance(password, str) or not 6 <= len(password) <= 128:
        return Response(
            {
                "success": False,
                "message": "Нууц үг 6–128 тэмдэгттэй байна."
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    if User.objects.filter(email__iexact=email).exists():
        return Response(
            {
                "success": False,
                "message": "Энэ и-мэйл хаяг бүртгэлтэй байна."
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    # Өмнөх OTP байвал устгана
    EmailOTP.objects.filter(email=email).delete()

    # 6 оронтой OTP
    otp = str(secrets.randbelow(900000) + 100000)

    # OTP database-д хадгалах
    EmailOTP.objects.create(
        email=email,
        otp=otp,
        is_verified=False
    )

    # OTP email илгээх
    try:
        send_mail(
            subject="Бүртгэл баталгаажуулах код",
            message=f"""
Сайн байна уу?

Таны баталгаажуулах код:

{otp}

Кодоо системд оруулж бүртгэлээ баталгаажуулна уу.
""",
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[email],
            fail_silently=False,
        )

    except Exception as e:
        return Response(
            {
                "success": False,
                "message": "И-мэйл илгээх үед алдаа гарлаа.",
                "error": str(e)
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

    # User-ийг одоохондоо үүсгэхгүй.
    # Verify хийх үед үүсгэхийн тулд мэдээллийг session-д хадгална.
    request.session["register_email"] = email
    request.session["register_password_hash"] = make_password(password)
    request.session["register_first_name"] = first_name
    request.session["register_last_name"] = last_name
    request.session["register_username"] = username

    return Response(
        {
            "success": True,
            "message": "Баталгаажуулах код таны и-мэйл рүү илгээгдлээ.",
            "email": email,
            "registration_token": registration_token(request.session),
        },
        status=status.HTTP_200_OK
    )


# =========================================================
# VERIFY OTP
# =========================================================

@api_view(["POST"])
@transaction.atomic
def verify(request):
    email = str(request.data.get("email", "")).strip().lower()
    otp = request.data.get("otp")

    if not restore_registration_session(request):
        return Response({"success": False, "message": "Бүртгэлийн хугацаа дууссан. Дахин бүртгүүлнэ үү."}, status=400)

    if not email or not otp:
        return Response(
            {
                "success": False,
                "message": "И-мэйл болон баталгаажуулах код оруулна уу."
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    try:
        otp_object = EmailOTP.objects.select_for_update().filter(
            email=email,
            otp=str(otp)
        ).latest("created_at")

    except EmailOTP.DoesNotExist:
        return Response(
            {
                "success": False,
                "message": "Баталгаажуулах код буруу байна."
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    if otp_object.is_verified:
        return Response(
            {
                "success": False,
                "message": "Энэ код өмнө нь ашиглагдсан байна."
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    if timezone.now() - otp_object.created_at > timedelta(minutes=10):
        return Response({"success": False, "message": "Кодын хугацаа дууссан. Дахин код авна уу."}, status=400)

    register_email = request.session.get("register_email")
    register_password = request.session.get("register_password_hash") or request.session.get("register_password")
    first_name = request.session.get("register_first_name", "")
    last_name = request.session.get("register_last_name", "")
    username = request.session.get("register_username", email)
    if User.objects.filter(username__iexact=username).exists():
        return Response({"message": "Энэ хэрэглэгчийн нэр бүртгэлтэй байна. Дахин бүртгүүлнэ үү."}, status=400)

    if register_email != email or not register_password:
        return Response(
            {
                "success": False,
                "message": "Бүртгэлийн мэдээлэл олдсонгүй. Дахин бүртгүүлнэ үү."
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    if User.objects.filter(email__iexact=email).exists():
        return Response(
            {
                "success": False,
                "message": "Энэ и-мэйл хаяг аль хэдийн бүртгэлтэй байна."
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    # User үүсгэнэ.
    # username дээр email ашиглаж байна.
    user = User.objects.create_user(
        username=username,
        email=email,
        password=None,
        first_name=first_name,
        last_name=last_name,
    )

    if request.session.get("register_password_hash"):
        user.password = register_password
    else:
        user.set_password(register_password)
    user.is_active = True
    user.save()

    otp_object.is_verified = True
    otp_object.save()

    # Session цэвэрлэх
    request.session.pop("register_email", None)
    request.session.pop("register_password", None)
    request.session.pop("register_password_hash", None)
    request.session.pop("register_first_name", None)
    request.session.pop("register_last_name", None)
    request.session.pop("register_username", None)

    return Response(
        {
            "success": True,
            "message": "Бүртгэл амжилттай баталгаажлаа.",
            "user": UserSerializer(user).data
        },
        status=status.HTTP_201_CREATED
    )


# =========================================================
# LOGIN
# =========================================================

@api_view(["POST"])
def login_view(request):
    email = str(request.data.get("identifier") or request.data.get("username") or request.data.get("email", "")).strip()
    password = request.data.get("password")

    if not email or not password:
        return Response(
            {
                "success": False,
                "message": "И-мэйл болон нууц үгээ оруулна уу."
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    try:
        db_user = User.objects.get(Q(email__iexact=email) | Q(username__iexact=email))

    except (User.DoesNotExist, User.MultipleObjectsReturned):
        return Response(
            {
                "success": False,
                "message": "И-мэйл эсвэл нууц үг буруу байна."
            },
            status=status.HTTP_401_UNAUTHORIZED
        )

    user = authenticate(
        username=db_user.username,
        password=password
    )

    if user is None:
        return Response(
            {
                "success": False,
                "message": "И-мэйл эсвэл нууц үг буруу байна."
            },
            status=status.HTTP_401_UNAUTHORIZED
        )

    if not user.is_active:
        return Response(
            {
                "success": False,
                "message": "Хэрэглэгчийн эрх идэвхгүй байна."
            },
            status=status.HTTP_403_FORBIDDEN
        )

    return Response(
        {
            "success": True,
            "message": "Амжилттай нэвтэрлээ.",
            "token": Token.objects.get_or_create(user=user)[0].key,
            "user": UserSerializer(user).data
        },
        status=status.HTTP_200_OK
    )
@api_view(["POST"])
def resend_otp(request):
    email = str(request.data.get("email", "")).strip().lower()
    if not restore_registration_session(request):
        return Response({"success": False, "message": "Бүртгэлийн хугацаа дууссан. Дахин бүртгүүлнэ үү."}, status=400)
    if request.session.get("register_email") != email:
        return Response({"success": False, "message": "Бүртгэлээ дахин эхлүүлнэ үү."}, status=400)

    if not email:
        return Response(
            {
                "success": False,
                "message": "И-мэйл хаяг оруулна уу."
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    otp = str(secrets.randbelow(900000) + 100000)

    EmailOTP.objects.filter(email=email).delete()

    EmailOTP.objects.create(
        email=email,
        otp=otp,
        is_verified=False
    )

    try:
        send_mail(
            subject="Шинэ баталгаажуулах код",
            message=f"""
Сайн байна уу?

Таны шинэ баталгаажуулах код:

{otp}

Кодоо системд оруулж бүртгэлээ баталгаажуулна уу.
""",
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[email],
            fail_silently=False,
        )

    except Exception as e:
        return Response(
            {
                "success": False,
                "message": "И-мэйл илгээх үед алдаа гарлаа.",
                "error": str(e)
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

    return Response(
        {
            "success": True,
            "message": "Шинэ OTP код дахин илгээгдлээ.",
            "registration_token": registration_token(request.session),
        },
        status=status.HTTP_200_OK
    )

