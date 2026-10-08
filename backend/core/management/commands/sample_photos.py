"""Replace generated sample placeholders with attributed apartment photos."""
from django.core.management.base import BaseCommand
from django.db import transaction

from core.models import Property

PHOTOS = (
    ("1609766857326-18a204c2cf31", "jt2I98bh53A"),
    ("1701092868263-2ed67ac8dfa0", "_BBps6MAJ2w"),
    ("1612419299101-6c294dc2901d", "QGxBeUDkeWk"),
)


class Command(BaseCommand):
    help = "Use attributed Unsplash interior photos for synthetic sample listings only."

    @transaction.atomic
    def handle(self, *args, **options):
        count = 0
        for listing in Property.objects.select_for_update().filter(description__contains="[bair-sample-v1:").order_by("pk"):
            if not listing.title.startswith("Жишээ зар #"):
                continue
            if listing.image and not listing.image.name.startswith("properties/samples-v1/"):
                continue
            marker = listing.description.split("[bair-sample-v1:", 1)[1].split("]", 1)[0]
            if not marker.isdigit():
                continue
            photo, slug = PHOTOS[(int(marker) - 1) % len(PHOTOS)]
            listing.remote_image_url = f"https://images.unsplash.com/photo-{photo}?auto=format&fit=crop&w=1200&q=85"
            listing.image = ""
            note = f"Жишээ интерьер зураг; энэ зарын бодит байрны зураг биш. Эх сурвалж: https://unsplash.com/photos/{slug}"
            if note not in listing.description:
                listing.description += "\n" + note
            listing.save(update_fields=["remote_image_url", "image", "description", "updated_at"])
            listing.images.filter(image__startswith="properties/samples-v1/").delete()
            count += 1
        self.stdout.write(self.style.SUCCESS(f"Assigned apartment photo URLs to {count} sample listings."))
