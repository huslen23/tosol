# bair_project — үргэлжлүүлэх тэмдэглэл

## Reference зурагт тулгуурласан дизайн — 2026-10-08

- Хэрэглэгч `C:\Users\otgon\Downloads\916ecf7f-bddd-4aaf-8604-bb42340db18b.jfif` загварын өнгө/зохион байгуулалтыг хүссэн. Дараа нь **Өргөө нэрийг хэвээр үлдээх** гэж тодруулсан; апп, web, Android, iOS харагдах нэр Өргөө хэвээр.
- Өнгө: үндсэн `#2563EB`, идэвхтэй `#1E40AF`, цайвар `#EFF6FF`, дэвсгэр `#F8FAFC`, гарчиг `#0F172A`, тайлбар `#475569`, туслах `#94A3B8`. Цагаан, нимгэн хүрээтэй карт; цэнхэр товч, доод цэс, байшин хэлбэрийн code-native тэмдэг. Жишээний зарын төлөвүүдийг бодит өгөгдөлгүйгээр дуурайж нэмээгүй.
- Нүүрийн хайлт/ангилал дээд талд, том gradient hero хассан. Хайлтын болон шинээр нэмэгдсэн зарууд жижиг зурагтай нягт карт; зураг, title/price/өрөө/талбай/давхар, хадгалах ба харьцуулах боломжтой. Онцлох зарын том карт хэвээр. Профайл аватар/мэндчилгээний карт, нэвтрэх дэлгэц, зарын дэлгэрэнгүй, form болон шинэ газрын зураг/үнэлгээ нэг theme ашиглана.
- Хэрэглэгч **зураг солихыг цуцалсан**. Фото импортын шинэ команд, manifest, тестийг хассан; одоогийн зарын зургийг өөрчлөөгүй.
- Шинэ дизайны home/listings/detail golden зургуудыг Flutter renderer-ээр шалгаж шинэчилсэн. Сүүлийн бүх Flutter suite **27/27 PASS**; analyze **No issues found**; Django check **0 issues**. Backend функционал **41/41 PASS**, `core.0009` migration хэрэгжсэн, migration drift байхгүй.
- Шинэ дизайны web build **PASS**, `bair_app/build/web` бүрэн шинэчлэгдсэн (`API_BASE_URL=http://127.0.0.1:8000`). Өргөө нэр, шинэ дизайн, газрын зураг болон үнэлгээний өөрчлөлтүүд бүгд багтсан. Бодит browser/утсан дээр live газрын зургийн серверийн хүргэлтийг гараар шалгах шаардлагатай.

## Газрын зураг ба үнэлгээний хамрагдалт — 2026-10-08

- Зар дээр nullable latitude/longitude нэмсэн. `core.0009` PostgreSQL дээр хэрэгжсэн. Координатгүй хуучин зарууд хэвээр; байршил таамаглаж нэмээгүй. Serializer координатын хүрээ, finite утга, хосоор өгөх/арилгахыг шалгана.
- Property API `located=true`, `bbox=west,south,east,north` шүүлтүүртэй. Одоогийн үнэ/дүүрэг/өрөө/хадгалсан/өөрийн зарын шүүлтүүртэй хамт үйлчилнэ. Хүрээ буруу бол 400.
- Flutter хайлтын газрын зургийн товч, хүрээгээр хайх, эхний 100 тэмдэглэгээ, тэмдэглэгээнээс зар нээх нэмэгдсэн. Формоос зураг дээр цэг сонгох/солих/арилгах боломжтой. Нарийн хаягийг гараар бичнэ; reverse geocoding хийгээгүй. Дэлгэрэнгүйгийн external map координаттай бол координатаар нээнэ.
- OpenStreetMap raster зураг, attribution холбоос, хөдөлгөх/томруулах/жижигрүүлэх, алдааны тайлбар/дахин ачаалах. Шинэ dependency татах оролдлого network restriction-аар зогссон тул одоогийн Flutter/http/url_launcher-тай хэрэгжүүлсэн. Native tile 7 хоног disk cache; web browser cache.
- Comfort summary: rated_criteria_count, total_criteria_count, latest_rating_at. UI хүн/шалгуурын тоо ба жинд суурилсан хамрагдалтыг ялгаж харуулна. 1–4 хүний үед цөөн үнэлгээний тайлбар; энэ нь статистикийн баталгаа биш. Өмнөх score/60% ranking дүрэм хэвээр. Үнэлгээгүй шалгуурыг бодит онооны progress шиг харуулахгүй.
- Backend core 41/41 PASS. Flutter бүх suite 26/26 PASS, дараа нэмсэн map API/filter тесттэй map файл 2/2 PASS (нийт 27 тест). Golden жагсаалтын map товчийг шалгаж шинэчилсэн. Migration check: No changes detected; analyze: No issues found.
- Бодит browser/утсан дээр live map tile ачаалалт гараар баталгаажаагүй. Энэ орчны network restriction зургийн серверүүдийг дуудахад нөлөөлж байна.

## Хотхоны тав тухын үнэлгээ ба нийтэд нээлттэй сэтгэгдэл — 2026-10-08

- Хэрэглэгчийн шаардлага: зөвхөн хотхоныг үнэлнэ; анхдагч утгаас эхэлж хэрэглэгчдийн үнэлгээгээр өөрчлөгдөнө; сэтгэгдэл бүх хүнд харагдана; админ үнэлгээний хэсэгт бусдын агуулгыг өөрчлөх тусгай эрхгүй.
- `core/comfort.py`: 8 шалгуур, 20/15/15/10/10/10/10/10 анхдагч жин. Өгөгдөлгүй шалгуурын түр утга 50/100 бөгөөд хамрагдалт, бодит нийлбэрт орохгүй. Шалгуур бүр хэрэглэгчдийн онооны арифметик дундаж; өгөгдөлтэй хэсэгт жинг дахин нормчилно. Хамрагдалт <60% бол ranking_score=null, эцсийн эрэмбэд ашиглахгүй.
- Model: ComplexRating (хотхон/хэрэглэгч unique, scores, огноо), ComfortWeights (хэрэглэгчийн 100% жин), ComplexComment (нийтэд харагдах текст, зохиогч, огноо). `core.0006_comfortweights_complexcomment_complexrating` migration PostgreSQL дээр хэрэгжсэн; өмнөх заруудыг өөрчлөөгүй.
- Шалгуурын эх сурвалж, үнэлгээний тоо, сүүлд шинэчилсэн огноо, verified=false төлөвийг онооноос тусад нь буцаана. Бодит хэмжилт/асуулгын үр дүн гэж үзэхгүй. Үнэлгээний source нь хэрэглэгчдийн хувийн туршлага.
- API: complexes/{id}/comfort/ GET (public), my-rating/ PUT/DELETE (own), complexes/weights/ GET/PUT (personal), comments/ GET (public)/POST, comments/{id}/ PATCH/DELETE (own). Unknown/хоосон/0–100-аас гадуур оноо, буруу жин, хоосон/2000-аас урт сэтгэгдлийг шалгана.
- Админ бусдын үнэлгээ эсвэл сэтгэгдлийг засах/устгах эрхгүй. Rating/comment model Django admin-д бүртгэлгүй. Админ энгийн хэрэглэгчийн адил зөвхөн өөрийн агуулгыг удирдана. PROTECT нь хотхон эсвэл зохиогчийг устгаж агуулгыг арилгахыг хориглоно; үнэлгээ/сэтгэгдэлтэй хотхоны API delete 409.
- Flutter `screens/comfort_page.dart`: хотхоны дэлгэрэнгүйгээс нээгдэнэ; 8 шалгуурын оноо/жин/хамрагдалт/эх сурвалж, давуу/сайжруулах тал, үнэлгээ өгөх/засах/хасах, хувийн жин хадгалах, нийтэд харагдах сэтгэгдэл бичих/засах/устгах, pagination. Guest уншиж болно; бичихэд login шаардлагатай.
- Backend **35/35 PASS**, Flutter **25/25 PASS** (goldens багтсан), analyze **No issues found**, check **0 issues**, migration check **No changes detected**. 9 backend, 4 Flutter тест шинээр нэмсэн.
- Web build **PASS**, `bair_app/build/web` профайлын username болон хотхоны шинэ урсгалтай шинэчлэгдсэн. Бодит PostgreSQL өгөгдөл дээр guest APIClient (`HTTP_HOST=127.0.0.1`) comfort/comments GET **200/200**; анхны testserver host оролдлого ALLOWED_HOSTS-оор 400 болсон, зөв hostname-оор дахин баталгаажуулсан. Серверийн host тохиргоог өөрчлөөгүй.
- Бодит browser болон утсан дээр энэ шинэ урсгалыг гараар баталгаажуулаагүй. Хиймэл үнэлгээ/сэтгэгдэл бодит өгөгдлийн санд нэмээгүй.

## Профайл дахь username засвар — 2026-10-08

- Профайл засах дэлгэц овог, нэр, username-ийг PATCH /api/profile/ рүү илгээж, буцсан хэрэглэгчээр AppStore-ийг шинэчилнэ.
- UserSerializer username засахыг зөвшөөрнө. Django-ийн нэрийн формат/150 тэмдэгтийн шалгалт, том жижиг үсэг үл харгалзсан давхардлын шалгалт, @ тэмдэг хориглох нөхцөлтэй. Өөрийн одоогийн нэрийг хадгалж болно. Email болон админ эрх read-only хэвээр.
- Backend тест: овог/нэр/username хадгалах, шинэ нэрээр нэвтрэх, админ эрхийг profile PATCH-аар нэмэх боломжгүй, давхардсан/буруу username буцаах. Flutter тест: давхардлын дараа форм хадгалагдах, дахин засаж амжилттай хадгалах.
- Backend **26/26 PASS**, Flutter **21/21 PASS**, analyze **No issues found**. Энэ өөрчлөлтийн дараа web build дахин үүсгээгүй; өмнөх build artifact профайлын шинэ талбарыг агуулахгүй. Development app-ийг restart/hot restart хийж ашиглана.

## Нууц үгийн урсгалын үргэлжлэл — 2026-10-08

- Өмнөх бүртгэл/зураг/нууц үг/админ өөрчлөлтийг шалгаж үргэлжлүүлсэн. Энэ сессэд database болон хэрэглэгчийн эрх өөрчлөөгүй.
- Нууц үг сэргээхдээ «Өөр и-мэйл ашиглах» сонгоход өмнөх cooldown болон timer-ийг цэвэрлэдэг болгосон. Шинэ хаягт кодыг шууд хүсэж болно; серверийн хүсэлтийн хязгаар хэвээр.
- `bair_app/test/password_test.dart`: нууц үг солиход rotated token secure storage-д хадгалагдах; сэргээхэд өөр и-мэйлээр шинэ challenge авах, зөв reset_token/code илгээх, authentication цэвэрлэгдэх урсгалын 2 тест нэмсэн.
- Нууц үг, админ, профайл болон AppStore файлуудыг Dart formatter-аар цэгцэлсэн. README-ийн тестийн тоо болон нууц үгийн API зааврыг шинэчилсэн.
- Backend **24/24 PASS**, check **0 issues**, migration check **No changes detected**; core **0001–0005 бүгд [X]**.
- Flutter **20/20 PASS** (golden тестүүд багтсан); analyze **No issues found**.
- Web build **PASS** (`API_BASE_URL=http://127.0.0.1:8000`), `bair_app/build/web` шинэчлэгдсэн.
- Бодит SMTP хүргэлт, browser file picker болон төхөөрөмж дээрх урсгалуудыг энэ сессэд гараар баталгаажуулаагүй.

## Сүүлийн өөрчлөлтийн шалгалт — 2026-10-08

- Нууц үг сэргээх core.0005 migration хэрэгжээгүй байсныг PostgreSQL дээр хэрэгжүүлсэн.
- Register API тоон password/password_confirm илгээхэд 500 үүсэх алдааг зассан; 6–128 тэмдэгттэй string шаарддаг.
- Бүртгэлийн username/password_confirm, админ бичих эрх, username/email нэвтрэлт, нэмэгдсэн districts хүсэлтэд хуучин тестүүдийг тохируулсан.
- Нууц үг солих/token rotation, сэргээх/token invalidation/replay, кодын хугацаа/5 оролдлого, админ эрх, буруу password type-ийн 5 тест нэмсэн. Throttle cache-ийг тест бүрийн өмнө цэвэрлэж тусгаарласан.
- Backend: 24/24 PASS; check: 0 issues; makemigrations --check --dry-run: No changes detected.
- Flutter analyze: No issues found; test --no-pub --concurrency=1: 18/18 PASS. Зэрэгцээ давтан ажиллуулахад санах ой хүрэлцээгүй тул эцсийн шалгалтыг дарааллаар ажиллуулсан.
- Бодит SMTP хүргэлт, browser болон утсан дээрх шинэ урсгалуудыг гараар баталгаажуулаагүй.

Сесс: 2026-10-08. Өмнөх кодоос үргэлжлүүлсэн. Шинэ шалгалтын үр дүн болон үлдсэн ажлыг файлын төгсгөлийн хэсэгт бичсэн. **Зээлийн тооцоолуур нэмэхгүй.**

## Орчин, заавар

- Frontend: `bair_app` — Flutter mobile. Backend: `backend` — Django REST Framework + PostgreSQL.
- Монгол хэл, Өргөө нэртэй ногоон/цагаан загвар, доод navigation: Нүүр, Хайх, Хадгалсан, Профайл.
- Root болон frontend/backend дотор Git repository олдоогүй. Git status/diff/history авах боломжгүй. AGENTS.md олдоогүй.
- Байгаа файл, database, migration history-г устгаагүй. Нууц тохиргооны утгыг энэ файлд оруулаагүй.
- `https://www.ebair.mn/mn` бүтцийн жишгийг уншсан; сайт дахь зар, зураг хуулж ашиглаагүй.

## Сесс эхлэхэд байсан хэрэгжилт

- Register → email OTP → verify → login; session cookie, OTP 10 минутын хугацаа, дахин илгээх, token authentication.
- Profile GET/PATCH, logout; token secure storage-д хадгалдаг Flutter AppStore.
- Property CRUD, зөвхөн эзэмшигч өөрчлөх/устгах; sale/rent, үнэ/дүүрэг/өрөө/талбай, хайлт, эрэмбэ, pagination.
- Favorite хадгалах/цуцлах, saved болон mine жагсаалт.
- Зураг multipart upload/delete, 12 зураг ба зураг тус бүр 10 MB хязгаар; detail/gallery, утас дуудах/хуулах.
- Flutter home/search/profile/form/error/empty/loading дэлгэцүүд, backend admin зар/зураг/хэрэглэгчийн удирдлага.
- Backend-ийн өмнөх 9 тест бүгд давсан. Flutter-ийн өмнөх UI ажиллагааг энэ сессэд runtime-аар батлаагүй.
- Core 0001–0003 migration-ууд PostgreSQL дээр аль хэдийн хэрэгжсэн байсан.

## Энэ сессийн өөрчлөлт

- `backend/core/models.py`: District, Complex, Agent; Property.complex ба admin-аас удирдах is_featured.
- `backend/core/discovery.py`: дүүрэг/хотхон/агентын paginated, read-only list/detail API. Дүүргийн зарын тоо болон худалдах зарын дундаж үнэ/м² нь database-ийн бодит өгөгдлөөр тооцогдоно.
- `backend/core/marketplace.py`: featured, complex, agent filter; төсөв заавал шаарддаг recommendations action. Өмнөх filter/pagination-ийг ашиглаж, төсвөөс давсан эсвэл шалгуурт тохироогүй зар санал болгохгүй. Энэ нь шалгуурт тохирох хайлт, ML ranking биш.
- `backend/core/serializers.py`: хотхон ба дүүргийн нийцлийн validation, is_featured client-аас өөрчлөгдөхгүй.
- `backend/core/admin.py`, `backend/config/urls.py`: шинэ өгөгдлийн admin болон API бүртгэл.
- `backend/core/migrations/0004_complex_district_property_is_featured_agent_and_more.py`: шинэ хүснэгт/талбар; PostgreSQL дээр migrate хийж амжилттай хэрэгжүүлсэн.
- `backend/core/tests.py`: шинэ discovery API, холбоотой зарууд, төсвийн хязгаар, featured эрх, хотхон/дүүргийн validation тестүүд; нийт 12 тест.
- `bair_app/lib/screens/discovery_page.dart`: API-аас дүүрэг/хотхон/агентын list/detail, дараагийн хуудас, retry/empty/loading, холбоотой зар руу navigation, агентын утас.
- `bair_app/lib/screens/compare_page.dart`, `widgets/property_card.dart`, `services/app_store.dart`: сессийн хугацаанд 3 хүртэл зар сонгож API detail-аар харьцуулах, хасах, detail рүү орох.
- `screens/home_page.dart`: судлах navigation, санал болгох filter form, admin онцолсон зарууд. Худалдах/түрээслэх сонголт нүүрийн заруудыг дахин ачаална.
- `screens/property_page.dart`, `screens/filter_sheet.dart`, `services/api_client.dart`: recommendations endpoint-тэй холболт, төсвийн validation, харьцуулах дэлгэцийн товч.
- `screens/property_form_page.dart`, `models/property.dart`: хотхон сонголтыг API-аас дүүргээр нь ачаалж, complex ID хадгалах. Ачаалалт алдахад дахин оролдох боломжтой.
- `screens/property_detail_page.dart`: харьцуулалтад нэмэх/хасах, хаягаар гаднын газрын зурагт хайх. Нарийн координаттай map pin хэрэгжээгүй.
- Зээлийн тооцоолуур код/товч/дэлгэц нэмээгүй.

## Шалгалтын бодит үр дүн

- `manage.py check`: issues 0.
- `manage.py makemigrations --check --dry-run`: No changes detected.
- `manage.py test core --noinput`: **12/12 PASS**, PostgreSQL тусдаа test database; SMTP mocked.
- `manage.py migrate`: core.0004 OK. `showmigrations core`: 0001–0004 бүгд [X].
- Database engine-ийг Django connection-оор шалгахад `postgresql`.
- Одоогийн database дээр APIClient GET: properties, districts, complexes, agents, recommendations?max_price=400000000 бүгд **200**. Энэ нь HTTP network/emulator туршилт биш.
- Шууд SDK `dart.exe format lib`: 17 файл, формат зөв.
- Шууд SDK `dart.exe analyze lib test`: **No issues found**.
- Энгийн `flutter analyze; flutter test`: SDK cache дахь flutter.bat.lock руу бичих эрхгүй тул output-гүй хүлээж байсан; процессыг Ctrl+C-ээр зогсоосон.
- flutter_tools.snapshot-аар `test --no-pub`: SDK cache/lockfile руу бичих эрхгүй тул failed. Flutter analyze-г шууд туршихад SDK cache/libimobiledevice.stamp руу бичих эрхгүй тул failed. SDK workspace-ийн гадна байрладаг. Эрхийг өөрчлөөгүй.
- **Flutter widget/golden tests, APK build, emulator/бодит утасны гол урсгал, бодит SMTP хүргэлт энэ сессэд баталгаажаагүй.** Dart analyze амжилттайг Flutter runtime тесттэй андуурч болохгүй.

## Маргааш хийх ажил

### Сүүлчийн холболтын засвар

Хэрэглэгч компьютерээс бүртгүүлэхэд сервертэй холбогдохгүй байгааг мэдээлсэн. Backend runserver-ийг 0.0.0.0:8000 дээр асааж, бодит HTTP GET properties=200, POST register хоосон JSON=400 validation хариуг шалгасан; бодит SMTP бүртгэл явуулаагүй. ApiClient-ийн анхны URL-г Android-д 10.0.2.2, web/desktop/iOS-д 127.0.0.1 болгов. API_BASE_URL override хэвээр. Аппыг restart хийх шаардлагатай. Компьютерийн browser дахь session cookie/OTP урсгалыг цааш шалгах; mobile SessionClient cookie хадгалалт browser-т автоматаар адил ажиллана гэж үзэхгүй.

1. Бичих эрхтэй Flutter SDK/орчинд flutter analyze ба flutter test ажиллуулах. Шинэ боломжуудын meaningful widget/API integration тест нэмэх. Одоогийн тест mock нь шинэ complexes/discovery/featured endpoint-уудыг бүрэн дэмжихгүй байж болно.
2. UI өөрчлөгдсөн тул `test/widget_test.dart` golden screenshots хуучин: үр дүнг хараад зөв болсон үед `flutter test --update-goldens` ажиллуулах. Golden-ийг шалгалтгүй шинэчлэхгүй.
3. Emulator/утсан дээр login/OTP, saved, comparison, form+photos, edit/delete, discovery, recommendations гол урсгалыг турших; жижиг дэлгэцийн overflow/navigation шалгах.
4. Django admin-аас **бодит** дүүрэг/хотхон/агент мэдээлэл нэмэх, existing property-тэй хотхон холбоход district нэр нь яг таарах ёстой. Шинэ хүснэгтүүдийг энэ сессэд жишээ мэдээллээр дүүргээгүй. is_featured-г admin-аас сонгоно; онцолсон заргүй бол нүүрэнд хоосон төлөв гарна.
5. Recommendations нь одоогоор хатуу шалгуурын хайлт. Эрэмбийн score/soft preferences хийх эсэхийг дараагийн шаардлагаар шийдэх. Comparison сессийн санах ойд; апп дахин асахад арилна.
6. Хотхон сонголтын алдаа/дахин оролдох ба дүүрэг солих үеийн request race-ийг runtime тестээр шалгах. Харьцуулах зар устсан тохиолдолд бүх хүснэгтийн алдаа гарч retry үзүүлнэ; тус бүрийн unavailable төлөв сайжруулж болно.
7. API upload-ийн transport алдаа, partial photo save retry, token хугацаа/сэргээх UX, input edge cases болон admin validation-ийг үргэлжлүүлэн аудит хийх.
8. PROJECT_PROGRESS.md-г дараагийн шалгалтын бодит үр дүнгээр шинэчлэх. Нууц үг/token/.env утга хэвлэхгүй.

## Ажиллуулах команд — PowerShell

Backend (project root-оос):

```powershell
cd backend
.\venv\Scripts\python.exe manage.py check
.\venv\Scripts\python.exe manage.py migrate
.\venv\Scripts\python.exe manage.py showmigrations core
.\venv\Scripts\python.exe manage.py makemigrations --check --dry-run
.\venv\Scripts\python.exe manage.py test core --noinput
.\venv\Scripts\python.exe manage.py runserver 0.0.0.0:8000
```

Flutter (өөр terminal, project root-оос; SDK-д бичих эрхтэй орчинд):

```powershell
cd bair_app
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

API_BASE_URL `lib/services/api_client.dart`-д нэг тохиргоонд төвлөрсөн; `/api` нэмэхгүй. Emulator ID-г `flutter devices`-оос авна.

Бодит утас: ижил Wi-Fi, компьютерийн LAN IP-г ашиглаж backend terminal-д `DJANGO_ALLOWED_HOSTS`-д IP нэмэх. Жишээ IP-г өөрийн IP-аар солих:

```powershell
$env:DJANGO_ALLOWED_HOSTS = 'localhost,127.0.0.1,10.0.2.2,192.168.1.10'
.\venv\Scripts\python.exe manage.py runserver 0.0.0.0:8000
```

Flutter terminal:

```powershell
flutter run -d YOUR_DEVICE_ID --dart-define=API_BASE_URL=http://192.168.1.10:8000
```

Эсвэл USB: `adb reverse tcp:8000 tcp:8000`, дараа нь API_BASE_URL=http://127.0.0.1:8000. Firewall-ийн private network дахь 8000 порт хүрэх шаардлагатай. Android release-д HTTPS URL хэрэглэнэ. iOS build-д macOS/Xcode шаардлагатай.

## Үргэлжлүүлсэн сесс — 2026-10-08

Өмнөх кодыг хадгалж, алдаа засвар болон шалгалтыг хийсэн. AGENTS.md, Git repository байхгүй хэвээр. Database, migration history, бүртгэл/нэвтрэлт/имэйл OTP-г хадгалсан. Зээлийн тооцоолуур нэмээгүй.

### Хийсэн өөрчлөлт

- Глобал Flutter SDK-г `.tools/flutter` рүү хуулж бичих эрхийн асуудлыг шийдсэн. `scripts/flutter-local.cmd` workspace-ийн SDK snapshot, telemetry хавтсыг ашиглана. Глобал SDK болон permissions өөрчлөөгүй. `.tools/` Git-д орохгүй.
- Browser client `withCredentials=true`: register/verify/resend session cookie-г browser өөрөө дамжуулна. Mobile SessionClient cookie ажиллагаа хэвээр. Browser болон API ижил 127.0.0.1 hostname ашиглана.
- Recommendations шүүлтүүр арилгах үед төсөв болон худалдах/түрээслэх сонголтыг хадгалдаг болсон. Filter sheet-ийн дараах хуучин search debounce-г цуцална.
- Comparison-д нэг зар 404 болсон ч бусад зар харагдана; боломжгүй зарыг тусад нь харуулж хасах боломжтой. Сүлжээний бусад алдаанд retry хэвээр.
- Зураг upload-ийн SocketException/ClientException Монгол хэлтэй, ойлгомжтой алдаа буцаана.
- Хуучин widget mock-д complexes endpoint нэмсэн. `test/marketplace_test.dart`-д 9 тест нэмсэн: гурван discovery төрлийн pagination/detail/related navigation; устсан зартай comparison; 3 зарын хязгаар; recommendations budget/API/reset; хотхон ID-тай edit; district request race; upload transport error.
- Home/listings/detail golden зургуудыг хараад шинэчилсэн. Тестийн Roboto font ₮ тэмдэгтийг дутуу харуулдаг нь хуучин болон шинэ зурагт байсан хязгаарлалт; бодит төхөөрөмжийн font rendering тусдаа шалгана.

### Бодит шалгалтын үр дүн

- PostgreSQL `manage.py test core --noinput`: **12/12 PASS**, тусдаа test database, SMTP mocked.
- `manage.py check`: **0 issues**.
- `makemigrations --check --dry-run`: **No changes detected**.
- `showmigrations core`: **0001–0004 бүгд [X]**; шинэ migration шаардлагагүй.
- Workspace SDK `analyze --no-pub`: **No issues found**.
- `test --no-pub --update-goldens`: **15/15 PASS**.
- Golden шинэчлэлтийн дараах энгийн `test --no-pub`: **15/15 PASS**, golden comparison орсон.
- `dart format lib test`: **21 files**, эцсийн шалгалтаар өөрчлөлтгүй.
- `build web --no-pub --dart-define=API_BASE_URL=http://127.0.0.1:8000`: **PASS**, `bair_app/build/web` үүссэн. Wasm dry-run мөн амжилттай.
- Backend runserver дээр бодит HTTP GET: properties, districts, complexes, agents, recommendations?max_price=400000000 — **бүгд 200**. Одоогийн жагсаалтууд хоосон; хиймэл зар/admin өгөгдөл нэмээгүй.
- HTTP smoke шалгалтын server-ийг зогсоосон; ашиглахдаа дахин асаана.

### Үлдсэн баталгаажуулалт

- `devices`/`adb devices`: **FAILED**, `Cannot mkdir '\.android': Permission denied`. Android user-home тохируулах оролдлого асуудлыг шийдээгүй. Emulator/бодит утас, APK build шалгаагүй.
- Browser дээр бодит register → email OTP → verify → login болон SMTP хүргэлтийг гараар шалгаагүй. Mobile cookie unit test, backend mocked OTP тестүүд давсан; web client compile болсон.
- Бодит зураг сонгох/upload, partial photo retry, газрын зураг/утасны launcher, keychain болон font rendering-ийг төхөөрөмж дээр туршина.
- District/complex/agent бодит мэдээлэл, featured заруудыг admin-аас нэмнэ. Recommendations хатуу шүүлтүүрийн хайлт хэвээр. Comparison аппын сессийн санах ойд хадгалагдана.

### Ажиллуулах команд — энэ workspace

Backend (root-оос, тусдаа terminal):

```powershell
cd backend
.\venv\Scripts\python.exe manage.py runserver 0.0.0.0:8000
```

Frontend (root-оос, өөр terminal):

```powershell
cd bair_app
..\scripts\flutter-local.cmd analyze --no-pub
..\scripts\flutter-local.cmd test --no-pub
..\scripts\flutter-local.cmd run -d chrome --web-hostname=127.0.0.1 --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Android emulator бичих эрхтэй terminal-д ажиллаж байгаа бол:

```powershell
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Өөр компьютерт `.tools/flutter` SDK хуулбар эсвэл бичих эрхтэй SDK шаардлагатай; шинэ орчинд dependencies-ийг `flutter pub get`-ээр бэлдэнэ. Нууц үг/token/.env утга хэвлээгүй.

## Зураг нэмэх асуудлын шалгалт — 2026-10-08

- Хэрэглэгч notebook дээр зураг сонгоод хадгалах үед алдаа гарч байгааг мэдээлсэн. Алдааны яг текст болон Chrome/Windows runtime хараахан тодорхойгүй.
- Form preview нь `Image.file(File(blobPath))` ашиглаж байсан тул browser дээр ажиллахгүй. Сонгосон зураг бүрийн bytes-ийг уншиж cache-д хадгалан `Image.memory`-ээр харуулдаг болгосон. Зураг хасах/амжилттай upload хийхэд bytes cache цэвэрлэнэ. 12 зураг, 10 MB хязгаар хэвээр.
- `photo_upload_test.dart` нэмсэн: browser blob-той зураг preview, multipart images field/filename/bytes/token, upload 503-ийн дараах retry давхар зар үүсгэхгүй, зураг хасах урсгал шалгасан. ImagePicker injection зөвхөн тест болон өөр picker хэрэглэх боломж өгдөг; ердийн апп ImagePicker ашиглана.
- Flutter **17/17 PASS**, `analyze --no-pub`: **No issues found**. Golden өөрчлөх шаардлага гараагүй.
- Backend-ийн зураг upload/display/delete/invalid-file тест **1/1 PASS**. Одоогийн MEDIA_ROOT/properties/gallery дотор түр PNG бичиж унших шалгалт амжилттай; түр файлыг цэвэрлэсэн. Database, migration өөрчлөөгүй.
- Тухайн хэрэглэгчийн хадгалах үеийн алдааг бүрэн тогтоосон гэж үзэхгүй: алдааны текст хэрэгтэй. Бодит notebook browser дээр file picker → network upload урсгалыг автоматаар баталгаажуулаагүй. Аппыг restart хийгээд дахин туршина.
## Agent хэсгийг хассан — 2026-10-08

- Нүүрийн Agent товч, жагсаалт/дэлгэрэнгүй, утасны холбоос, API route, зарын agent шүүлтүүр, админ бүртгэл болон Agent загварыг хассан.
- `0008_remove_agent` migration үндсэн PostgreSQL өгөгдлийн санд хэрэгжсэн. Хэрэглэгч, зар болон хуучин migration түүхийг хадгалсан.
- Үнэлгээний тайлбарыг арилгах үед санах ой дахь холбоосыг цэвэрлэж, API-ийн хоосон тайлбарын хариуг тестээр баталгаажуулсан.
- Нүүрийн шинэ жишиг зургийг үзэж шинэчилсэн. Backend 37/37, Flutter 25/25 тест давсан. Django check, migration consistency болон Flutter analyze алдаагүй. Web build болон Wasm dry-run амжилттай. Agent хүснэгт байхгүйг давхар баталгаажуулсан; үндсэн санд 3 хэрэглэгч, 42 зар байна.
- Git repository байхгүй тул commit diff ашиглах боломжгүй; одоогийн код, өмнөх тэмдэглэл болон тестээр шалгасан. Бодит төхөөрөмж, SMTP хүргэлтийг энэ удаа шалгаагүй.
