from pathlib import Path
import os

from django.conf import settings
from django.core.files import File
from django.core.files.storage import default_storage
from django.core.management.base import BaseCommand, CommandError

from core.models import Property, PropertyImage


class Command(BaseCommand):
    help = "Upload existing local listing images to Cloudinary and update their DB paths."

    def handle(self, *args, **options):
        if not os.environ.get("CLOUDINARY_URL"):
            raise CommandError("Set CLOUDINARY_URL before uploading media.")
        root = Path(settings.MEDIA_ROOT).resolve()
        uploaded = missing = 0
        for model in (Property, PropertyImage):
            for row in model.objects.exclude(image="").exclude(image__isnull=True).iterator():
                original = row.image.name
                path = (root / original).resolve()
                if not path.is_relative_to(root):
                    raise CommandError("Image path is outside MEDIA_ROOT.")
                if not path.is_file():
                    if default_storage.exists(original):
                        continue
                    missing += 1
                    self.stderr.write(f"Missing local and remote image: {model.__name__} #{row.pk}")
                    continue
                with path.open("rb") as stream:
                    name = default_storage.save(original, File(stream))
                # Only replace a path after upload succeeds; preserve the local file.
                model.objects.filter(pk=row.pk, image=original).update(image=name)
                uploaded += 1
        self.stdout.write(f"Uploaded: {uploaded}; missing: {missing}. Local files preserved.")
        if missing:
            raise CommandError("Some referenced images were unavailable. Resolve before deployment.")
