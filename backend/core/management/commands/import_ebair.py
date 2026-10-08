"""Import verified reference data with attribution; never replace existing ads."""
from decimal import Decimal

from django.core.management.base import BaseCommand
from django.db import transaction

from core.models import Complex, District, Property

SOURCE = "https://www.ebair.mn/mn/property/1981f78e-3a1e-41e0-a3fb-7c5fa9fc981e"
PHOTO = "https://images.ebair.mn/234744b1-fcc1-4b38-8c44-66db4696d6e4/1781206082973-nni2-7214642681015052547713297461122558614395762n.jpg"


class Command(BaseCommand):
    help = "Import an attributed ebair.mn apartment reference and its original image URL."

    @transaction.atomic
    def handle(self, *args, **options):
        district, _ = District.objects.get_or_create(name="Сүхбаатар")
        # Lock the unique district to serialize repeated imports.
        District.objects.select_for_update().get(pk=district.pk)
        if Property.objects.filter(source_url=SOURCE).exists():
            self.stdout.write("ebair reference already imported; skipped.")
            return
        complex_obj, _ = Complex.objects.get_or_create(name="Арга билиг", district=district)
        listing = Property(
            title="Арга билиг хотхонд 53.73 м², 2 өрөө байр худалдана",
            description=(
                "ebair.mn-ээс оруулсан лавлах зар. Манай хэрэглэгчийн өөрийн зар биш.\n"
                "Сүхбаатар дүүрэг, Арга билиг хотхон. 2 өрөө, 53.73 м², 3/16 давхар.\n"
                "Нийт үнэ: 240,000,000 ₮. Лифт, хамгаалалт, зогсоолтой.\n"
                "Эх зарын гарчигт 8-р хороо, дэлгэрэнгүйд 11-р хороо гэж зөрүүтэй бичсэн; "
                "нарийн хаяг, одоогийн үнэ болон зарын төлөвийг эх сурвалжаас лавлана уу.\n"
                "Холбоо барих дугаар эх сурвалж дээр нууцлагдсан.\n"
                f"Мэдээлэл ба зургийн эх сурвалж: {SOURCE}\n"
                "Шалгасан огноо: 2026-10-08. Зургийг эх сайтын холбоосоор ачаална."
            ),
            location="Улаанбаатар, Сүхбаатар дүүрэг, Арга билиг хотхон",
            district=district.name, complex=complex_obj,
            listing_type="sale", property_type="apartment", rooms=2,
            area=Decimal("53.73"), floor=3, total_floors=16,
            price=Decimal("240000000"), source_url=SOURCE, remote_image_url=PHOTO,
        )
        listing.full_clean()
        listing.save()
        self.stdout.write(self.style.SUCCESS(f"Imported ebair reference #{listing.pk} with original image URL."))
