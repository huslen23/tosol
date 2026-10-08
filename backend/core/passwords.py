import secrets
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.hashers import check_password, make_password
from django.core.mail import send_mail
from django.db import transaction
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.decorators import api_view, permission_classes, throttle_classes, authentication_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import AnonRateThrottle

from .models import PasswordResetCode


class ResetThrottle(AnonRateThrottle):
    rate = "10/min"


def password_error(data):
    password = data.get("new_password")
    if not isinstance(password, str) or len(password) < 6 or len(password) > 128:
        return "Нууц үг 6–128 тэмдэгттэй байна."
    if password != data.get("password_confirm"):
        return "Нууц үг давтаж оруулсан утгатай таарахгүй байна."
    return None


@api_view(["POST"])
@permission_classes([IsAuthenticated])
@transaction.atomic
def change_password(request):
    user = get_user_model().objects.select_for_update().get(pk=request.user.pk)
    old_password = request.data.get("old_password")
    if not isinstance(old_password, str) or not user.check_password(old_password):
        return Response({"message": "Хуучин нууц үг буруу байна."}, status=400)
    error = password_error(request.data)
    if error:
        return Response({"message": error}, status=400)
    user.set_password(request.data["new_password"])
    user.save(update_fields=["password"])
    PasswordResetCode.objects.filter(user=user).delete()
    Token.objects.filter(user=user).delete()
    request.session.flush()
    return Response({"message": "Нууц үг шинэчлэгдлээ.", "token": Token.objects.create(user=user).key})


@api_view(["POST"])
@authentication_classes([])
@permission_classes([AllowAny])
@throttle_classes([ResetThrottle])
@transaction.atomic
def forgot_password(request):
    email = str(request.data.get("email", "")).strip().lower()
    result = {"message": "Бүртгэлтэй и-мэйл бол сэргээх код илгээгдэнэ. Код 10 минут хүчинтэй.", "reset_token": secrets.token_hex(32)}
    users = list(get_user_model().objects.select_for_update().filter(email__iexact=email, is_active=True)[:2])
    if len(users) != 1:
        return Response(result)
    user = users[0]
    previous = PasswordResetCode.objects.filter(user=user).first()
    if previous and timezone.now() - previous.created_at < timedelta(seconds=60):
        result["reset_token"] = previous.token
        return Response(result)
    code = f"{secrets.randbelow(1000000):06d}"
    try:
        send_mail("Нууц үг сэргээх код", f"Таны нууц үг сэргээх код: {code}\nКод 10 минут хүчинтэй. Та хүсэлт гаргаагүй бол энэ кодыг ашиглахгүй байж болно.", settings.DEFAULT_FROM_EMAIL, [user.email], fail_silently=False)
    except Exception:
        return Response({"message": "И-мэйл илгээж чадсангүй. Дахин оролдоно уу."}, status=503)
    PasswordResetCode.objects.filter(user=user).delete()
    PasswordResetCode.objects.create(user=user, token=result["reset_token"], code_hash=make_password(code), password_snapshot=user.password)
    return Response(result)


@api_view(["POST"])
@authentication_classes([])
@permission_classes([AllowAny])
@throttle_classes([ResetThrottle])
@transaction.atomic
def reset_password(request):
    error = password_error(request.data)
    if error:
        return Response({"message": error}, status=400)
    token = request.data.get("reset_token")
    code = request.data.get("code")
    if not isinstance(token, str) or not isinstance(code, str):
        return Response({"message": "Код буруу эсвэл хугацаа дууссан байна."}, status=400)
    # Lock user before challenge, matching change/forgot lock ordering.
    user_id = PasswordResetCode.objects.filter(token=token).values_list("user_id", flat=True).first()
    user = get_user_model().objects.select_for_update().filter(pk=user_id, is_active=True).first()
    challenge = PasswordResetCode.objects.select_for_update().filter(token=token, user=user).first() if user else None
    if not challenge or challenge.attempts >= 5 or timezone.now() - challenge.created_at > timedelta(minutes=10) or user.password != challenge.password_snapshot:
        return Response({"message": "Код буруу эсвэл хугацаа дууссан байна. Шинэ код авна уу."}, status=400)
    if not check_password(code, challenge.code_hash):
        challenge.attempts += 1
        challenge.save(update_fields=["attempts"])
        return Response({"message": "Код буруу байна. Хамгийн ихдээ 5 удаа оролдоно."}, status=400)
    user.set_password(request.data["new_password"])
    user.save(update_fields=["password"])
    challenge.delete()
    Token.objects.filter(user=user).delete()
    request.session.flush()
    return Response({"message": "Нууц үг сэргээгдлээ. Шинэ нууц үгээр нэвтэрнэ үү."})
