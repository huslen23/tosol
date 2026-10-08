from pathlib import Path
import os

# ==============================
# BASE DIR
# ==============================

BASE_DIR = Path(__file__).resolve().parent.parent


# ==============================
# SECURITY
# ==============================

SECRET_KEY = "django-insecure-change-this-secret-key"

DEBUG = True

ALLOWED_HOSTS = [
    "127.0.0.1",
    "localhost",
]


# ==============================
# APPLICATIONS
# ==============================
INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",

    "rest_framework",
    "rest_framework.authtoken",
    "corsheaders",
    "core",
]

# ==============================
# MIDDLEWARE
# ==============================

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",

    "corsheaders.middleware.CorsMiddleware",

    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]


# ==============================
# URL CONFIG
# ==============================

# config гэдгийг project-ийн folder нэрээр солино.
# Жишээ:
# backend/urls.py биш
# config/urls.py бол config.urls

ROOT_URLCONF = "config.urls"


# ==============================
# TEMPLATES
# ==============================

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",

        "DIRS": [
            BASE_DIR / "templates",
        ],

        "APP_DIRS": True,

        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]


# ==============================
# WSGI
# ==============================

WSGI_APPLICATION = "config.wsgi.application"


# ==============================
# DATABASE - POSTGRESQL
# ==============================

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",

        # PostgreSQL дээр үүсгэсэн database name
        "NAME": "bair_db",

        # PostgreSQL username
        "USER": "postgres",

        # PostgreSQL password
        "PASSWORD": "1234",

        "HOST": "localhost",

        # PostgreSQL default port
        "PORT": "5432",
    }
}


# ==============================
# PASSWORD VALIDATION
# ==============================

AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.CommonPasswordValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.NumericPasswordValidator",
    },
]


# ==============================
# LANGUAGE / TIME
# ==============================

LANGUAGE_CODE = "mn"

TIME_ZONE = "Asia/Ulaanbaatar"

USE_I18N = True

USE_TZ = True


# ==============================
# STATIC FILES
# ==============================

STATIC_URL = "static/"

STATICFILES_DIRS = []

STATIC_ROOT = BASE_DIR / "staticfiles"


# ==============================
# MEDIA FILES
# ==============================

MEDIA_URL = "/media/"

MEDIA_ROOT = BASE_DIR / "media"


# ==============================
# DEFAULT PRIMARY KEY
# ==============================

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"


# ============================================================
# EMAIL - DJANGO 6.1+
# ============================================================

# !!! EMAIL_BACKEND БИЧИХГҮЙ !!!
# !!! EMAIL_HOST БИЧИХГҮЙ !!!
# !!! EMAIL_PORT БИЧИХГҮЙ !!!
# !!! EMAIL_USE_TLS БИЧИХГҮЙ !!!
#
# Django 6.1 дээр MAILERS ашиглана.

MAILERS = {
    "default": {
        "BACKEND": "django.core.mail.backends.smtp.EmailBackend",

        "OPTIONS": {
            "host": "smtp.gmail.com",
            "port": 587,
            "use_tls": True,

            # Gmail
            "username": "ggosu9799@gmail.com",

            # Gmail-ийн энгийн password биш.
            # Google App Password байна.
            "password": "vebc jomj ziso euef",

            "timeout": 10,
        },
    },
}


# Mail илгээгчийн нэр / address
DEFAULT_FROM_EMAIL = "ggosu9799@gmail.com"


# ==============================
# LOGIN SETTINGS
# ==============================

LOGIN_URL = "/login/"

LOGIN_REDIRECT_URL = "/"

LOGOUT_REDIRECT_URL = "/"


# ==============================
# SESSION SETTINGS
# ==============================

SESSION_COOKIE_AGE = 60 * 60 * 24

SESSION_SAVE_EVERY_REQUEST = True


# ==============================
# DEVELOPMENT SECURITY
# ==============================

ALLOWED_HOSTS = [
    "127.0.0.1",
    "localhost",
]

CORS_ALLOW_ALL_ORIGINS = True
CORS_ALLOW_CREDENTIALS = True

# Mobile token authentication; registration keeps the existing session flow.
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": ["rest_framework.authentication.TokenAuthentication"],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.AllowAny"],
}
ALLOWED_HOSTS = os.environ.get("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1,10.0.2.2").split(",")
SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", SECRET_KEY)
DEBUG = os.environ.get("DJANGO_DEBUG", "true").lower() == "true"
for env_name, field in [("POSTGRES_DB", "NAME"), ("POSTGRES_USER", "USER"), ("POSTGRES_PASSWORD", "PASSWORD"), ("POSTGRES_HOST", "HOST"), ("POSTGRES_PORT", "PORT")]:
    DATABASES["default"][field] = os.environ.get(env_name, DATABASES["default"][field])
if os.environ.get("EMAIL_BACKEND"):
    MAILERS["default"]["BACKEND"] = os.environ["EMAIL_BACKEND"]
    MAILERS["default"]["OPTIONS"] = {}
if os.environ.get("EMAIL_HOST_USER"):
    MAILERS["default"]["OPTIONS"]["username"] = os.environ["EMAIL_HOST_USER"]
if os.environ.get("EMAIL_HOST_PASSWORD"):
    MAILERS["default"]["OPTIONS"]["password"] = os.environ["EMAIL_HOST_PASSWORD"]
DEFAULT_FROM_EMAIL = os.environ.get("DEFAULT_FROM_EMAIL", DEFAULT_FROM_EMAIL)
