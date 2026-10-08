from io import StringIO
from pathlib import Path
from tempfile import TemporaryDirectory

from PIL import Image
from django.contrib.auth import get_user_model
from django.core.management import call_command, CommandError
from django.test import TestCase, override_settings

from core.management.commands.seed_properties import SEED_USERNAME
from core.models import Complex, District, Property, PropertyImage


class SeedPropertiesTests(TestCase):
    def setUp(self):
        self.media = TemporaryDirectory()
        self.addCleanup(self.media.cleanup)
        settings = override_settings(MEDIA_ROOT=self.media.name)
        settings.enable()
        self.addCleanup(settings.disable)

    def seed(self):
        call_command("seed_properties", stdout=StringIO())

    def test_samples_rerun_and_real_data_preserved(self):
        district = District.objects.create(name="Баянзүрх", description="Бодит дүүрэг")
        complex_obj = Complex.objects.create(name="Бодит хотхон", district=district)
        real = Property.objects.create(title="Бодит зар", complex=complex_obj, price=150000000)
        before = Property.objects.filter(pk=real.pk).values().get()
        self.seed()
        samples = Property.objects.exclude(pk=real.pk)
        self.assertEqual(samples.count(), 40)
        self.assertEqual(samples.filter(listing_type="sale").count(), 20)
        self.assertEqual(samples.filter(listing_type="rent").count(), 20)
        self.assertEqual(samples.values("district").distinct().count(), 8)
        self.assertEqual(samples.values("rooms").distinct().count(), 5)
        for sample in samples:
            sample.full_clean()
            self.assertIn("Жишээ зар", sample.title)
            self.assertIn("Жишээ зар", sample.description)
            self.assertLessEqual(sample.floor, sample.total_floors)
            self.assertTrue(sample.contact_phone.startswith("000000"))
            self.assertEqual(sample.complex.district.name, sample.district)
            with Image.open(sample.image.path) as image:
                image.verify()
        snapshot = list(Property.objects.order_by("pk").values())
        files = sorted(Path(self.media.name).rglob("*.png"))
        self.seed()
        self.assertEqual(list(Property.objects.order_by("pk").values()), snapshot)
        self.assertEqual(sorted(Path(self.media.name).rglob("*.png")), files)
        self.assertEqual(PropertyImage.objects.count(), 40)
        self.assertEqual(Complex.objects.count(), 9)
        self.assertEqual(Property.objects.filter(pk=real.pk).values().get(), before)
        district.refresh_from_db()
        self.assertEqual(district.description, "Бодит дүүрэг")
        # Recreate only a removed sample, reusing its existing local placeholder.
        samples.first().delete()
        self.seed()
        self.assertEqual(Property.objects.count(), 41)
        self.assertEqual(PropertyImage.objects.count(), 40)
        self.assertEqual(sorted(Path(self.media.name).rglob("*.png")), files)

    def test_reserved_account_collision_changes_nothing(self):
        user = get_user_model().objects.create_user(username=SEED_USERNAME, password="real-password")
        self.assertRaises(CommandError, self.seed)
        user.refresh_from_db()
        self.assertTrue(user.check_password("real-password"))
        self.assertEqual(Property.objects.count(), 0)
        self.assertEqual(District.objects.count(), 0)

    def test_existing_owner_email_and_rerun(self):
        user = get_user_model().objects.create_user(
            username="sample-owner", email="gogohanibi@gmail.com", password="owner-password",
        )
        before = get_user_model().objects.filter(pk=user.pk).values().get()
        call_command("seed_properties", owner_email="gogohanibi@gmail.com", stdout=StringIO())
        self.assertEqual(Property.objects.filter(owner=user).count(), 40)
        call_command("seed_properties", owner_email="gogohanibi@gmail.com", stdout=StringIO())
        self.assertEqual(Property.objects.count(), 40)
        self.assertEqual(get_user_model().objects.filter(pk=user.pk).values().get(), before)

    def test_missing_owner_does_not_create_data(self):
        with self.assertRaises(CommandError):
            call_command("seed_properties", owner_email="missing@example.invalid", stdout=StringIO())
        self.assertEqual(Property.objects.count(), 0)
        self.assertEqual(get_user_model().objects.count(), 0)
