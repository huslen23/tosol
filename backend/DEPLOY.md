# Backend deployment

Database: existing Neon database. Media: Cloudinary. API: Render Web Service.
Do not use the Render filesystem for uploaded images: it is ephemeral.

## Before deploying

1. Create a Cloudinary account and copy its CLOUDINARY_URL into backend/.env.
2. Install dependencies locally:
   `.\backend\venv\Scripts\python.exe -m pip install -r backend/requirements.txt`
3. Stop local API writes. Back up Neon before modifying image paths. Keep the
   existing DB dumps and backend/media as recovery copies.
4. Upload images to Cloudinary, using the Neon URL already in backend/.env:
   `powershell -ExecutionPolicy Bypass -File scripts/backend-online.ps1 upload_media`
5. Verify image URLs and push these source changes through GitHub Desktop.
   Never commit .env, .local-secrets.json, media, or database backups.

## Render Web Service

Repository: https://github.com/huslen23/tosol
Branch: main
Root Directory: backend
Runtime: Python
Build Command: bash build.sh
Start Command: bash start.sh
Health Check Path: /health/

Choose a service plan only after reviewing its price. Free services block
outbound SMTP ports including Gmail's 587, so Gmail OTP requires a compatible
paid plan or a separately configured HTTPS email provider. Do not launch an
OTP-dependent registration flow with email delivery unverified.

Environment variables:

- PYTHON_VERSION: a Render-supported Python 3.14 patch version
- DATABASE_URL: the existing Neon connection URL, including SSL options
- CLOUDINARY_URL: Cloudinary credentials
- DJANGO_DEBUG: false
- DJANGO_SECRET_KEY: generate a new random secret for production
- EMAIL_HOST_USER / EMAIL_HOST_PASSWORD: SMTP user and a newly issued App Password
- DEFAULT_FROM_EMAIL: the sender address
- CORS_ALLOWED_ORIGINS: actual Flutter web origins, comma-separated
- CSRF_TRUSTED_ORIGINS: actual Flutter web origins, comma-separated

Render's own hostname is added to ALLOWED_HOSTS automatically. For custom API
domains set DJANGO_ALLOWED_HOSTS (hostnames only, comma-separated).

## Verify after deployment

Check /health/ and /api/properties/, image loading, login, OTP delivery, password
reset, and an authenticated image upload. /health/ checks the process only;
the API request also verifies database connectivity.

Run Flutter with the real deployed API URL:

`flutter run --dart-define=API_BASE_URL=https://YOUR-SERVICE.onrender.com`

For releases, pass the same dart-define to flutter build. Browser frontend
hosting is separate from hosting this API. Keep local backups until deployment
and uploads are verified. Removing old secrets from current files does not
revoke them or remove them from Git history.
