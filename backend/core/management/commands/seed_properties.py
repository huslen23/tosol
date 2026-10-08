"""Synthetic listings using current models, without copied ads or remote images."""
from decimal import Decimal
from io import BytesIO

from PIL import Image, ImageDraw
from django.contrib.auth import get_user_model
from django.core.files.base import ContentFile
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from core.models import Complex, District, Property, PropertyImage

SEED_USERNAME = "__bair_sample_properties_v1__"
SEED_EMAIL = "sample-properties-v1@example.invalid"
DISTRICTS = ("Баянзүрх", "Хан-Уул", "Сүхбаатар", "Баянгол", "Чингэлтэй", "Сонгинохайрхан", "Налайх", "Багануур")
COMPLEX_NAMES = ("Үүлэн", "Мөнгөн", "Нарлаг", "Тэнүүн", "Сондор", "Туяат", "Номин", "Солонгон")


def sample_values(index, complex_obj):
    rooms = 1 + ((index // 8 + index % 8) % 5)
    area = Decimal(rooms * 24 + 8 + index % 7) + Decimal("0.25") * (index % 4)
    total_floors = (9, 12, 16, 20)[index % 4]
    floor = 1 + ((index * 3) % total_floors)
    listing_type = "sale" if index < 20 else "rent"
    price = area * Decimal(2500000 + (index % 8) * 350000) if listing_type == "sale" else Decimal(650000 + rooms * 300000 + (index % 8) * 125000)
    action = "худалдана" if listing_type == "sale" else "түрээслүүлнэ"
    price_label = "Худалдах нийт үнэ" if listing_type == "sale" else "Сарын түрээс"
    return dict(
        title=f"Жишээ зар #{index + 1:02d} — {COMPLEX_NAMES[index % 8]} хотхоны {rooms} өрөө {action}",
        description=(
            f"Жишээ зар. Апп турших зориулалттай зохиомол мэдээлэл; бодит санал биш.\n"
            f"[bair-sample-v1:{index + 1:02d}]\n"
            f"{complex_obj.district.name} дүүрэг, {complex_obj.name}. "
            f"{rooms} өрөө, {area} м², {floor}/{total_floors} давхар.\n"
            f"{price_label}: {price:,.0f} ₮. "
            f"{'Тавилгатай, сарын төлбөрөөр түрээслэх жишээ.' if listing_type == 'rent' else 'Гал тогооны тавилгатай, худалдах жишээ.'}\n"
            f"Холбоо барих: Жишээ эзэмшигч {index + 1:02d}, "
            f"sample{index + 1:02d}@example.invalid. Утас нь туршилтын зохиомол дугаар."
        ),
        complex=complex_obj, district=complex_obj.district.name,
        location=f"Улаанбаатар, {complex_obj.district.name}, {complex_obj.name}",
        listing_type=listing_type, property_type="apartment", rooms=rooms,
        area=area, floor=floor, total_floors=total_floors, price=price,
        contact_phone=f"000000{index + 1:02d}", is_featured=index % 7 == 0,
    )


def placeholder(index):
    """Draw an original local PNG that Flutter can decode."""
    canvas = Image.new("RGB", (800, 600), (232, 239, 244))
    draw = ImageDraw.Draw(canvas)
    color = ((index * 31 + 40) % 160, (index * 17 + 60) % 160, 160)
    draw.rectangle((250, 150, 550, 460), fill=color)
    for x in range(280, 530, 70):
        for y in range(185, 400, 60):
            draw.rectangle((x, y, x + 35, y + 35), fill=(250, 235, 190))
    draw.rectangle((380, 400, 420, 460), fill=(60, 70, 80))
    draw.text((260, 500), f"SAMPLE LISTING {index + 1:02d} / LOCAL PLACEHOLDER", fill=(40, 50, 60))
    output = BytesIO()
    canvas.save(output, format="PNG")
    return output.getvalue()


class Command(BaseCommand):
    help = "Create 40 synthetic Жишээ зар listings; reruns skip samples and never update real listings."

    def add_arguments(self, parser):
        parser.add_argument("--owner-email", help="Assign samples to an existing account with this email.")

    @transaction.atomic
    def handle(self, *args, **options):
        User = get_user_model()
        email = options.get("owner_email")
        if email:
            owners = list(User.objects.select_for_update().filter(email__iexact=email.strip())[:2])
            if len(owners) != 1:
                raise CommandError("Owner email must match exactly one existing account; nothing changed.")
            owner = owners[0]
        else:
            owner = self.sample_owner(User)
        self.create_samples(owner)

    def sample_owner(self, User):
        owner, _ = User.objects.get_or_create(
            username=SEED_USERNAME,
            defaults={"email": SEED_EMAIL, "first_name": "Жишээ", "last_name": "Эзэмшигч", "is_active": False, "password": "!"},
        )
        # Serialize concurrent PostgreSQL runs without a model migration.
        owner = User.objects.select_for_update().get(pk=owner.pk)
        if owner.email != SEED_EMAIL or owner.is_active or owner.has_usable_password():
            raise CommandError("Reserved seed username belongs to another account; nothing changed.")
        return owner

    def create_samples(self, owner):
        storage = Property._meta.get_field("image").storage
        added = skipped = 0
        for index in range(40):
            marker = f"[bair-sample-v1:{index + 1:02d}]"
            if Property.objects.filter(description__contains=marker).exists():
                skipped += 1
                continue
            district, _ = District.objects.get_or_create(name=DISTRICTS[index % 8])
            complex_obj, _ = Complex.objects.get_or_create(
                district=district, name=f"Жишээ зар — {COMPLEX_NAMES[index % 8]} хотхон",
                defaults={"description": "Жишээ зарын зохиомол хотхон. Апп турших зориулалттай."},
            )
            listing = Property(owner=owner, **sample_values(index, complex_obj))
            listing.full_clean()
            filename = f"properties/samples-v1/listing-{index + 1:02d}.png"
            if not storage.exists(filename):
                filename = storage.save(filename, ContentFile(placeholder(index)))
            listing.image = filename
            listing.save()
            PropertyImage.objects.create(property=listing, image=filename)
            added += 1
        self.stdout.write(self.style.SUCCESS(f"Sample listings: {added} created, {skipped} skipped. Existing listings unchanged."))
