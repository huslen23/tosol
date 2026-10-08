# Өргөө — Flutter + Django + PostgreSQL

## Байрны зураг — 2026-10-08

40 жишээ зарын PNG загварын оронд Unsplash-ийн 3 интерьер зурагны холбоосыг ээлжлэн ашиглана. Тайлбарт жишээ зураг болохыг болон эх сурвалжийг тэмдэглэсэн. Энэ орчинд гадаад зураг татах холболт хаалттай тул файл татаж хадгалаагүй; зураг хэрэглэгчийн интернэт холболтоор ачаална. Бодит зураг ачаалалтыг browser дээр баталгаажуулаагүй.

`core.0010` migration `source_url`, `remote_image_url` нэмсэн. API үндсэн local зураггүй үед remote холбоосыг `image` талбараар буцаана; байршуулсан local зураг давуу эрхтэй. `manage.py sample_photos` зөвхөн marker-тай жишээ зарын generated зурагнуудыг шинэчилнэ. Хэрэглэгчийн local зурагтай заруудыг алгасана.

`manage.py import_ebair` Арга билиг хотхоны нэг лавлах зарыг мэдээлэл, анхны зурагны холбоос, эх сурвалжтай оруулна. Давтан ажиллуулахад алгасана. Хороо зөрүүтэй байгааг тайлбарт тэмдэглэсэн; эзэмшигч, утас зохиож бөглөөгүй. Backend-ийн импорт, зурагны сонголт болон seed-ийн 7 тест PASS.

Аппын харагдах загвар хэрэглэгчийн өгсөн reference зурагт нийцсэн: үндсэн өнгө `#2563EB`, цайвар дэвсгэр `#F8FAFC`, цагаан карт, бараан гарчиг `#0F172A`. Нүүрийн хайлт/ангилал, жижиг зурагтай зарын жагсаалт, профайл, нэвтрэх дэлгэц, доод цэс шинэчлэгдсэн. Газрын зураг ба үнэлгээний боломжууд шинэ загварт ажиллана. Хэрэглэгч зураг солих ажлыг цуцалсан; зарын зургууд өөрчлөгдөөгүй.

## Газрын зураг ба үнэлгээний мэдээлэл — 2026-10-08

Хайлтын баруун дээд газрын зургийн товчоор зураг нээнэ. Үнэ, дүүрэг, өрөө болон бусад шүүлтүүр зураг дээр мөн үйлчилнэ. Зургийг хөдөлгөж «Энэ орчимд хайх» дарна; эхний 100 зарын тэмдэглэгээг харуулна. Зар нэмэх/засах формоос байрны цэгийг сонгоно. Нарийн хаягийг гараар бичнэ; автоматаар хаяг тодорхойлохгүй. Координатгүй зар жагсаалтад харагдах боловч зураг дээр гарахгүй.

`core.0009` migration зарын `latitude`, `longitude` талбар нэмнэ. API `located=true`, `bbox=west,south,east,north` шүүлтүүртэй. Хоёр координат хамт өгөгдөнө, эсвэл хоёулаа null байна. Газрын зургийн эх сурвалж OpenStreetMap; интернэт шаардлагатай. Native client зургийн хэсгүүдийг 7 хоног cache хийдэг; web нь browser cache ашиглана.

Хотхоны үнэлгээний хэсэг хэрэглэгчийн тоо, үнэлэгдсэн шалгуурын тоо, жинд суурилсан хамрагдалт, хамгийн сүүлд үнэлсэн огноог харуулна. 1–4 хүнтэй үед цөөн үнэлгээний тайлбар гарна. Энэ нь статистикийн баталгаажсан итгэлцлийн түвшин биш; оноо болон өмнөх эрэмбэлэх дүрмийг өөрчлөөгүй.



> 2026-10-08 шинэ шалгалт: Agent хэсгийг хассан; дэлгэрэнгүй болон шалгалтын үр дүн: [PROJECT_PROGRESS.md](PROJECT_PROGRESS.md).

Flutter SDK бичих эрхийн асуудлыг энэ workspace-д `.tools/flutter` хуулбараар шийдсэн. Төслийн root-оос:

```powershell
cd bair_app
..\scripts\flutter-local.cmd analyze --no-pub
..\scripts\flutter-local.cmd test --no-pub
..\scripts\flutter-local.cmd run -d chrome --web-hostname=127.0.0.1 --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Backend-ийг тусдаа terminal-д өмнөх `runserver` командаар асаана. Browser болон API-д ижил `127.0.0.1` hostname ашиглах нь бүртгэлийн session cookie дамжихад шаардлагатай. Browser client cookie credentials-ийг зөвшөөрдөг; browser дээрх бодит OTP/SMTP хүргэлтийг гараар турших шаардлагатай.

`flutter-local.cmd` глобал SDK болон profile-д бичихээс зайлсхийж workspace-ийн SDK, telemetry хавтсыг ашиглана. `.tools/` Git-д орохгүй. Өөр компьютерт SDK-гаа `.tools/flutter` рүү хуулна, эсвэл бичих эрхтэй SDK дээр энгийн `flutter` команд хэрэглэнэ. Workspace хуулбар нь development/test зориулалттай; Android төхөөрөмжийн шалгалт энэ орчинд `adb` эрхийн алдаанаас болоод баталгаажаагүй.

Монгол хэлтэй үл хөдлөх хөрөнгийн **mobile апп**. Нүүр, худалдах/түрээслэх зарууд, хайлт/шүүлтүүр, дэлгэрэнгүй ба зургийн галерей, хадгалсан байр, өөрийн зар нэмэх/засах/устгах, профайл засах боломжтой. Бүртгэл → и-мэйл OTP → нэвтрэх урсгал хэвээр. Flutter нь Django REST API ашиглана; PostgreSQL үндсэн өгөгдлийн сан.

## Ажиллуулах — Windows PowerShell

Эхний terminal:

```powershell
cd C:\Users\otgon\Desktop\bair_project\backend
.\venv\Scripts\python.exe manage.py migrate
.\venv\Scripts\python.exe manage.py runserver 0.0.0.0:8000
```

Хоёр дахь terminal:

```powershell
cd C:\Users\otgon\Desktop\bair_project\bair_app
flutter pub get
flutter emulators --launch Medium_Phone_API_37.0
flutter devices
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

`emulator-5554` өөр байвал `flutter devices` дээрх Android төхөөрөмжийн ID-г хэрэглэнэ. `10.0.2.2` нь Android emulator-оос компьютерийн localhost руу холбогдох хаяг. Backend terminal ажиллаж байх ёстой.

## Бодит Android утас

Компьютер, утсаа нэг Wi-Fi-д холбоно. USB debugging асааж USB-ээр холбоод `flutter devices`-ээр ID-г харна. Компьютерийн IPv4 хаягийг `ipconfig`-оор олно. Жишээ нь `192.168.1.10` бол backend terminal-д:

```powershell
$env:DJANGO_ALLOWED_HOSTS = "localhost,127.0.0.1,10.0.2.2,192.168.1.10"
.\venv\Scripts\python.exe manage.py runserver 0.0.0.0:8000
```

Flutter terminal-д:

```powershell
flutter run -d YOUR_DEVICE_ID --dart-define=API_BASE_URL=http://192.168.1.10:8000
```

`YOUR_DEVICE_ID` болон IP-г өөрийн утгад солино. Windows Firewall-д private network дээр порт 8000-ыг нээх шаардлагатай байж болно. USB ашиглаж байгаа бол LAN тохируулахын оронд `adb reverse tcp:8000 tcp:8000` ажиллуулаад `API_BASE_URL=http://127.0.0.1:8000` ашиглаж болно.

## Тохиргоо

Одоогийн PostgreSQL болон SMTP тохиргоог хадгалсан. Дараах environment variable-уудаар солих боломжтой:

| Variable | Зориулалт |
|---|---|
| `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_HOST`, `POSTGRES_PORT` | PostgreSQL холболт |
| `DJANGO_ALLOWED_HOSTS` | Серверт хандах хостууд, таслалаар тусгаарлана |
| `DJANGO_SECRET_KEY`, `DJANGO_DEBUG` | Django тохиргоо |
| `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD`, `DEFAULT_FROM_EMAIL` | SMTP илгээгч |
| `EMAIL_BACKEND` | Хөгжүүлэлтийн үед `django.core.mail.backends.console.EmailBackend` бол OTP backend terminal-д хэвлэгдэнэ |
| Flutter `--dart-define=API_BASE_URL=...` | API серверийн үндсэн URL, `/api` нэмэхгүй |

Шинэ backend орчинд Python 3.14+ ашиглаж `python -m venv venv`, дараа нь `venv\Scripts\python.exe -m pip install -r requirements.txt` ажиллуулна. PostgreSQL дээр database/user-ийг урьдчилан үүсгэнэ.

Android debug/profile build локал HTTP холболтыг зөвшөөрнө. Release build-д HTTPS API URL хэрэглэнэ. iOS-д зураг сонгох, local network, keychain entitlement тохируулсан; iOS build нь macOS/Xcode шаарддаг.

## Жишээ зар үүсгэх

```powershell
cd C:\Users\otgon\Desktop\bair_project\backend
.\venv\Scripts\python.exe manage.py migrate
.\venv\Scripts\python.exe manage.py seed_properties
```

40 орон сууцны жишээ зар (20 худалдах, 20 түрээслэх), 8 дүүрэг, 1–5 өрөө үүсгэнэ. Үнэ нь төгрөгөөр, түрээсийн үнэ нь сарын төлбөрөөр өгөгдөнө. Үнэ, дүүрэг, хотхон, өрөө, м², давхар/нийт давхар, төрөл, тайлбар нь одоогийн model-д таарна. Мэдээллийн бүтцийн жишиг: [ebair.mn-ийн зар](https://www.ebair.mn/mn/property/1981f78e-3a1e-41e0-a3fb-7c5fa9fc981e). Бүх утга зохиомол; бодит зар, нэр, холбоо барих мэдээлэл, зураг хуулбарлахгүй.

Зар бүрийн нэр, тайлбарт **Жишээ зар** тэмдэглэгээтэй. Зохиомол эзэмшигч, `example.invalid` и-мэйл, `00000001`–`00000040` туршилтын утас ашиглана. Command өөрөө локал PNG placeholder зурж, үндсэн зураг болон галерейд холбоно; гаднын зураг татахгүй.

Дахин ажиллуулахад тусгай идэвхгүй эзэмшигч болон тайлбар дахь `[bair-sample-v1:NN]` тэмдэглэгээгээр өмнө үүссэн заруудыг алгасана. Тэмдэглэгээг хадгална. Устгасан жишээ зарыг нөхөж үүсгэнэ. Одоо байгаа зар, хэрэглэгч, дүүрэг, хотхоны мэдээллийг өөрчлөхгүй. Model migration нэмэхгүй. Хуучин `seed.py` мөн энэ command-ийг дуудаж, зар устгахгүй.

Бүртгэлтэй хэрэглэгчээр оруулах: `.\venv\Scripts\python.exe manage.py seed_properties --owner-email gogohanibi@gmail.com`. Хаяг нь яг нэг бүртгэлтэй таарах ёстой; бүртгэл үүсгэхгүй, хэрэглэгчийн мэдээллийг өөрчлөхгүй. Өмнөх seed зарууд байвал эзэмшигчийг солихгүй, давхардуулахгүй.

Шалгах: `.\venv\Scripts\python.exe manage.py test core.test_seed --noinput` (тусдаа тестийн өгөгдлийн сан, түр зураг хадгалах хавтас ашиглана).

## API

| Endpoint | Үйлдэл |
|---|---|
| `POST /api/register/` | Бүртгэл эхлүүлэх, и-мэйл OTP илгээх; session cookie хадгална |
| `POST /api/verify/` | И-мэйл, OTP баталгаажуулах; register-ийн session cookie шаардлагатай |
| `POST /api/resend-otp/` | Ижил session-ээр шинэ код авах |
| `POST /api/login/` | И-мэйл/нууц үг шалгаж token, хэрэглэгч буцаах |
| `GET, PATCH /api/profile/` | Өөрийн профайл харах; овог, нэр, username засах |
| `POST /api/logout/` | Token хүчингүй болгох |
| `POST /api/password/change/` | Хуучин нууц үг шалгаж шинэчлэх, шинэ token буцаах |
| `POST /api/password/forgot/` | И-мэйлээр сэргээх код хүсэх, `reset_token` авах |
| `POST /api/password/reset/` | `reset_token`, код, шинэ нууц үгээр сэргээх |
| `GET, POST /api/properties/` | Зарын жагсаалт, шинэ зар |
| `GET, PATCH, DELETE /api/properties/{id}/` | Дэлгэрэнгүй, эзэмшигч засах/устгах |
| `POST, DELETE /api/properties/{id}/favorite/` | Хадгалах/хадгалснаас хасах |
| `POST /api/properties/{id}/photos/` | Multipart `images` нэрээр олон зураг илгээх |
| `DELETE /api/properties/{id}/photos/` | JSON `image_id`-аар зураг хасах |

Нэвтэрсэн хүсэлтүүд `Authorization: Token <token>` header ашиглана. Token нь төхөөрөмжийн secure storage-д хадгалагдана. Зочин зар харах/хайх боломжтой, бичих үйлдэлд нэвтрэх шаардлагатай. Хадгалсан байр нь хэрэглэгч тус бүрийн өгөгдөл.

Жагсаалт `{count, next, previous, results}` хэлбэртэй. `search`, `listing_type=sale|rent`, `property_type=apartment|house|office|land`, `district`, `rooms`, `min_price`, `max_price`, `min_area`, `max_area`, `ordering=price|-price|area|-area|-created_at`, `page`, `page_size`, `mine=true`, `saved=true` параметрүүдийг дэмжинэ.

Migration нь хуучин заруудыг устгахгүй. Өмнө эзэмшигчгүй байсан заруудыг харах боломжтой; эзэмшигчийг Django admin-д тохируулсны дараа тухайн хэрэглэгч засна. Шинэ зар нэвтэрсэн хэрэглэгчийг эзэмшигчээр автоматаар авна. Зураг файлууд `backend/media/` дотор, зураг/зарын мэдээлэл PostgreSQL-д хадгалагдана. Нэг зар 12 зураг хүртэл, зураг бүр 10 MB хүртэл.

## Хотхоны тав тухын үнэлгээ, сэтгэгдэл

Нүүр → Хотхонууд → хотхон → **Тав тухын үнэлгээ, сэтгэгдэл**. Зөвхөн хотхоныг үнэлнэ; нэг зар болон дүүргийг үнэлэхгүй. Нэвтрээгүй хүн ч оноо, бүх нийтэлсэн сэтгэгдлийг харж болно. Үнэлгээ өгөх, сэтгэгдэл бичихэд нэвтэрнэ.

8 шалгуурын анхдагч жин: байршил 20%, тээвэр 15%, орчин 15%, аюулгүй байдал 10%, дэд бүтэц 10%, барилгын тав тух 10%, үйлчилгээ 10%, зардал 10%. Нийт 100% жинг хэрэглэгч бүр өөрийн бүртгэлдээ хадгалж болно; бусдын оноо эсвэл жинг өөрчлөхгүй.

Өгөгдөлгүй шалгуурт 50/100 **түр анхдагч** утга харуулна; бодит үнэлгээ болон хамрагдалтад оруулахгүй. Хэрэглэгч мэдэх шалгуураа 0–100 оноогоор үнэлж, мэдэхгүйг орхино. Шалгуурын оноо нь тухайн шалгуурыг үнэлсэн хэрэглэгчдийн арифметик дундаж. Нийлбэр оноо нь өгөгдөлтэй шалгуурын жинлэсэн дундаж. Хамрагдалт 60%-аас бага бол «мэдээлэл хангалтгүй», `ranking_score=null` байна. Анхдагч 50 нь хэрэглэгчийн оноотой холилдохгүй; эцсийн эрэмбийн оноо биш.

Эх сурвалж нь хэрэглэгчдийн хувийн туршлага; баталгаажсан хэмжилт биш. Шалгуур бүрийн үнэлгээний тоо, сүүлд шинэчилсэн огноо, эх сурвалж, баталгаажаагүй төлөвийг тусад нь харуулна. Жин болон анхдагч оноо нь судалгаагаар батлагдсан үр дүн биш.

Хэрэглэгч хотхонд нэг үнэлгээтэй; засахад шинэ үнэлгээ нэмэхгүй, өмнөхийг шинэчилнэ. Үнэлгээний тайлбар **заавал биш**: хоосон орхиж болно. Бичсэн тайлбар сэтгэгдлийн хэсэгт нийтэд харагдана; үнэлгээг засахад тайлбар давхар үүсэхгүй. Тайлбарыг хоосолж хадгалах, эсвэл үнэлгээг хасахад тухайн тайлбар хасагдана. Тусдаа нийтэлсэн сэтгэгдлүүд хадгалагдана. Сэтгэгдэл 1–2000 тэмдэгттэй, хуудаслагдана; зохиогч өөрийн сэтгэгдлийг засаж, устгана. Админд бусдын үнэлгээ, сэтгэгдлийг өөрчлөх тусгай эрх байхгүй; эдгээр model Django admin-д бүртгэлгүй. Админ энгийн хэрэглэгчийн адил зөвхөн өөрийн агуулгыг удирдана. Үнэлгээ/сэтгэгдэлтэй хотхон болон зохиогчийг устгах замаар агуулгыг арилгахыг `PROTECT` хамгаална.

| API | Үйлдэл |
|---|---|
| `GET /api/complexes/{id}/comfort/` | Нийтэд харагдах оноо, хамрагдалт, шалгуурын тайлбар; нэвтэрсэн бол өөрийн жин/оноо |
| `PUT, DELETE /api/complexes/{id}/my-rating/` | Өөрийн `scores` үнэлгээ, заавал биш `explanation` тайлбарыг хадгалах/хасах |
| `GET, PUT /api/complexes/weights/` | Өөрийн `weights` жинг харах/хадгалах; нийт 100% |
| `GET, POST /api/complexes/{id}/comments/` | Сэтгэгдэл харах/нийтлэх |
| `PATCH, DELETE /api/complexes/{id}/comments/{comment_id}/` | Өөрийн сэтгэгдлийг засах/устгах |

`scores` болон `weights` түлхүүрүүд: `location`, `transport`, `environment`, `safety`, `infrastructure`, `building`, `services`, `cost`. Үнэлгээнд зөвхөн мэдэх шалгуурын түлхүүрийг илгээнэ. Жинд бүх 8 түлхүүр шаардлагатай; 0 жинтэй шалгуур нийлбэрт орохгүй. `core.0006` migration шинэ хүснэгтүүдийг нэмнэ.

## Шалгалт

```powershell
cd C:\Users\otgon\Desktop\bair_project\backend
.\venv\Scripts\python.exe manage.py check
.\venv\Scripts\python.exe manage.py makemigrations --check --dry-run
.\venv\Scripts\python.exe manage.py test core --noinput

cd C:\Users\otgon\Desktop\bair_project\bair_app
flutter analyze
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Django тест нь тусдаа `test_bair_db` PostgreSQL database үүсгэдэг. PostgreSQL хэрэглэгчид test database үүсгэх эрх хэрэгтэй. Тестийн и-мэйл илгээлтийг mock хийдэг; бодит SMTP хүргэлтийг шалгаагүй.

Flutter тестэд session cookie, алдааны Монгол текст, navigation, шүүлтүүр, нэвтрэлт, хадгалах, дэлгэрэнгүй, зарын формыг шалгана. `bair_app/docs/screenshots/` дахь зургууд нь Flutter renderer-ээр тестийн зарын өгөгдөлтэй үүсгэсэн preview. Дизайн өөрчилсөн үед `flutter test --update-goldens` ажиллуулна.

Дизайны функционал жишиг: [ebair.mn](https://www.ebair.mn/mn). Өргөө нь өөрийн нэр, өнгө, Flutter navigation-тай; жишиг сайтын зар, зураг, лого хуулж ашиглаагүй.

## 2026-10-08 шинэчлэлт

Agent хэсгийг апп, API болон админаас хассан. `core.0008_remove_agent` migration нь Agent хүснэгтийг устгана; хэрэглэгч болон зарын мэдээлэл хэвээр үлдэнэ. Хуучин migration файлууд нь өгөгдлийн сангийн түүхийг хадгалах зорилгоор үлдсэн.

Тав тухын үнэлгээний тайлбарыг хоослох үед санах ой дахь холбоосыг мөн цэвэрлэж, API хоосон тайлбар буцаахыг тестээр баталгаажуулсан.
