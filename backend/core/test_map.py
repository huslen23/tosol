from django.contrib.auth.models import User
from rest_framework.test import APITestCase
from .models import Property, District, Complex, ComplexRating


class MapTests(APITestCase):
    def setUp(self):
        self.owner = User.objects.create_user('mapper', password='password123')
        self.values = dict(owner=self.owner, title='Байр', location='Байр 1', district='Хан-Уул',
                           price=100000000, area=60, contact_phone='99112233')
        self.located = Property.objects.create(**self.values, latitude=47.92, longitude=106.92)
        self.unlocated = Property.objects.create(**self.values)
        Property.objects.create(**self.values, latitude=47.8, longitude=106.8)

    def test_bounds_and_existing_filters_exclude_unlocated(self):
        result = self.client.get('/api/properties/', {'bbox': '106.9,47.9,106.95,47.95', 'located': 'true', 'district': 'Хан-Уул'})
        self.assertEqual(result.status_code, 200)
        self.assertEqual([r['id'] for r in result.data['results']], [self.located.id])
        self.assertEqual(self.client.get('/api/properties/', {'located': 'true'}).data['count'], 2)
        self.assertEqual(self.client.get('/api/properties/').data['count'], 3)
        self.assertEqual(self.client.get('/api/properties/', {'bbox': '106.9,47.9,106.95,47.95', 'max_price': 50}).data['count'], 0)

    def test_invalid_bounds_return_400(self):
        for bbox in ['1,2,3', 'NaN,1,2,3', '0,0,181,90', '3,2,1,4', '0,5,10,1']:
            self.assertEqual(self.client.get('/api/properties/', {'bbox': bbox}).status_code, 400)

    def test_coordinate_pair_validation_clear_and_permissions(self):
        url = f'/api/properties/{self.unlocated.pk}/'
        self.client.force_authenticate(self.owner)
        for values in [{'latitude': 47.9}, {'latitude': 91, 'longitude': 100}, {'latitude': 40, 'longitude': -181}]:
            self.assertEqual(self.client.patch(url, values, format='json').status_code, 400)
        result = self.client.patch(url, {'latitude': 47.93, 'longitude': 106.93}, format='json')
        self.assertEqual(result.status_code, 200)
        self.assertEqual(result.data['latitude'], 47.93)
        self.assertEqual(self.client.patch(url, {'latitude': None}, format='json').status_code, 400)
        self.assertEqual(self.client.patch(url, {'latitude': None, 'longitude': None}, format='json').status_code, 200)
        other = User.objects.create_user('other_mapper')
        self.client.force_authenticate(other)
        self.assertEqual(self.client.patch(url, {'latitude': 40, 'longitude': 100}, format='json').status_code, 403)

    def test_rating_count_and_coverage_are_separate(self):
        complex_obj = Complex.objects.create(name='Хотхон', district=District.objects.create(name='Дүүрэг'))
        path = f'/api/complexes/{complex_obj.pk}/comfort/'
        empty = self.client.get(path).data
        self.assertEqual(empty['rated_criteria_count'], 0)
        self.assertEqual(empty['total_criteria_count'], 8)
        self.assertIsNone(empty['latest_rating_at'])
        ComplexRating.objects.create(complex=complex_obj, user=self.owner, scores={'location': 80})
        result = self.client.get(path).data
        self.assertEqual(result['rating_count'], 1)
        self.assertEqual(result['rated_criteria_count'], 1)
        self.assertEqual(result['coverage'], 20)
        self.assertIsNotNone(result['latest_rating_at'])
