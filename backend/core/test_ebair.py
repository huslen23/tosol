from io import StringIO

from django.core.management import call_command
from django.test import TestCase

from core.models import Property
from core.serializers import PropertySerializer
from core.management.commands.import_ebair import SOURCE, PHOTO


class EbairImportTests(TestCase):
    def test_import_preserves_existing_ads_and_rerun_skips(self):
        existing = Property.objects.create(title="Existing", price=100)
        before = Property.objects.filter(pk=existing.pk).values().get()
        call_command("import_ebair", stdout=StringIO())
        listing = Property.objects.get(source_url=SOURCE)
        self.assertEqual(PropertySerializer(listing).data["image"], PHOTO)
        self.assertEqual(PropertySerializer(listing).data["complex_name"], "Арга билиг")
        self.assertIsNone(listing.owner_id)
        self.assertEqual(listing.contact_phone, "")
        call_command("import_ebair", stdout=StringIO())
        self.assertEqual(Property.objects.count(), 2)
        self.assertEqual(Property.objects.filter(pk=existing.pk).values().get(), before)

    def test_uploaded_image_takes_precedence(self):
        listing = Property.objects.create(title="Photo", price=100, remote_image_url=PHOTO, image="properties/local.jpg")
        self.assertEqual(PropertySerializer(listing).data["image"], "/media/properties/local.jpg")

    def test_sample_photos_preserve_real_listings(self):
        real = Property.objects.create(title="Real", price=100, image="properties/real.jpg")
        sample = Property.objects.create(title="Жишээ зар #01", price=100, description="[bair-sample-v1:01]", image="properties/samples-v1/listing-01.png")
        call_command("sample_photos", stdout=StringIO())
        sample.refresh_from_db()
        real.refresh_from_db()
        self.assertIn("images.unsplash.com", PropertySerializer(sample).data["image"])
        self.assertEqual(real.image.name, "properties/real.jpg")
        description = sample.description
        call_command("sample_photos", stdout=StringIO())
        sample.refresh_from_db()
        self.assertEqual(sample.description, description)
