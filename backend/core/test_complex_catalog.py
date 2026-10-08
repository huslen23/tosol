from io import StringIO
from django.core.management import call_command
from django.test import TestCase
from .models import Complex, District, Property


class ComplexCatalogTests(TestCase):
    def test_adds_choices_and_rerun_preserves_existing_data(self):
        district = District.objects.create(name='Хан-Уул', description='Өөрийн тайлбар')
        complex_obj = Complex.objects.create(name='Ривер Гарден', district=district, address='Өөрийн хаяг')
        listing = Property.objects.create(title='Өөрийн зар', complex=complex_obj)
        before = Property.objects.filter(pk=listing.pk).values().get()
        call_command('seed_complexes', stdout=StringIO())
        self.assertGreater(Complex.objects.count(), 40)
        self.assertGreater(Complex.objects.filter(district=district).count(), 10)
        self.assertEqual(Complex.objects.filter(district=district, name__startswith='Ривер Гарден').count(), 1)
        snapshot = list(Complex.objects.order_by('id').values())
        call_command('seed_complexes', stdout=StringIO())
        self.assertEqual(list(Complex.objects.order_by('id').values()), snapshot)
        self.assertEqual(Property.objects.filter(pk=listing.pk).values().get(), before)
        self.assertEqual(Property.objects.count(), 1)
        complex_obj.refresh_from_db()
        district.refresh_from_db()
        self.assertEqual(complex_obj.address, 'Өөрийн хаяг')
        self.assertEqual(district.description, 'Өөрийн тайлбар')
