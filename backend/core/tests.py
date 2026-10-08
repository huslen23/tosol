import io
import tempfile
from decimal import Decimal
from datetime import timedelta
from pathlib import Path
from unittest.mock import patch
from PIL import Image
from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase, APIClient
from .models import Property, EmailOTP, Favorite, District, Complex


class AuthenticationTests(APITestCase):
    def register(self):
        with patch('core.views.send_mail') as send:
            response = self.client.post('/api/register/', {'email': '  Example@Test.mn ', 'password': 'password123', 'password_confirm': 'password123', 'username': 'example', 'first_name': 'Бат', 'last_name': 'Дорж'}, format='json')
        self.assertEqual(response.status_code, 200)
        send.assert_called_once()
        self.assertNotIn('register_password', self.client.session)
        self.assertNotEqual(self.client.session['register_password_hash'], 'password123')
        return EmailOTP.objects.get(email='example@test.mn')

    def test_register_verify_login_profile_logout(self):
        otp = self.register()
        self.assertEqual(self.client.post('/api/verify/', {'email': otp.email, 'otp': 'wrong'}).status_code, 400)
        response = self.client.post('/api/verify/', {'email': otp.email, 'otp': otp.otp}, format='json')
        self.assertEqual(response.status_code, 201)
        user = User.objects.get(email=otp.email)
        self.assertTrue(user.check_password('password123'))
        self.assertNotIn('register_password_hash', self.client.session)
        self.assertEqual(self.client.post('/api/verify/', {'email': otp.email, 'otp': otp.otp}).status_code, 400)
        self.assertEqual(self.client.post('/api/login/', {'email': otp.email, 'password': 'wrong'}).status_code, 401)
        response = self.client.post('/api/login/', {'email': 'EXAMPLE@Test.mn', 'password': 'password123'}, format='json')
        self.assertEqual(response.status_code, 200)
        token = response.data['token']
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {token}')
        self.assertEqual(self.client.get('/api/profile/').data['first_name'], 'Бат')
        self.assertEqual(self.client.patch('/api/profile/', {'first_name': 'Саруул'}, format='json').status_code, 200)
        user.refresh_from_db()
        self.assertEqual(user.first_name, 'Саруул')
        self.assertEqual(self.client.post('/api/logout/').status_code, 200)
        self.assertEqual(self.client.get('/api/profile/').status_code, 401)
        self.assertFalse(Token.objects.filter(key=token).exists())

    def test_otp_requires_same_registration_session(self):
        otp = self.register()
        other = APIClient()
        self.assertEqual(other.post('/api/verify/', {'email': otp.email, 'otp': otp.otp}).status_code, 400)
        self.assertEqual(other.post('/api/resend-otp/', {'email': otp.email}).status_code, 400)
        self.assertFalse(User.objects.filter(email=otp.email).exists())

    def test_registration_token_verifies_without_browser_cookie(self):
        otp = self.register()
        from .views import registration_token
        token = registration_token(self.client.session)
        browser = APIClient()
        response = browser.post('/api/verify/', {
            'email': otp.email, 'otp': otp.otp, 'registration_token': token,
        }, format='json')
        self.assertEqual(response.status_code, 201)
        self.assertTrue(User.objects.get(email=otp.email).check_password('password123'))
        # The restored session is cleared after verification, including replay.
        self.assertEqual(APIClient().post('/api/resend-otp/', {
            'email': otp.email, 'registration_token': token,
        }, format='json').status_code, 400)

    def test_registration_token_resend_without_cookie(self):
        with patch('core.views.send_mail'):
            response = self.client.post('/api/register/', {
                'email': 'example@test.mn', 'password': 'password123', 'password_confirm': 'password123', 'username': 'example',
            }, format='json')
        token = response.data['registration_token']
        browser = APIClient()
        with patch('core.views.send_mail'):
            response = browser.post('/api/resend-otp/', {
                'email': 'example@test.mn', 'registration_token': token,
            }, format='json')
        self.assertEqual(response.status_code, 200)
        otp = EmailOTP.objects.get(email='example@test.mn')
        response = APIClient().post('/api/verify/', {
            'email': otp.email, 'otp': otp.otp,
            'registration_token': response.data['registration_token'],
        }, format='json')
        self.assertEqual(response.status_code, 201)

    def test_registration_token_rejects_tampering_mismatch_and_expiry(self):
        otp = self.register()
        from .views import registration_token
        token = registration_token(self.client.session)
        for bad_token, email in [(token + 'x', otp.email), (token, 'other@test.mn')]:
            self.assertEqual(APIClient().post('/api/verify/', {
                'email': email, 'otp': otp.otp, 'registration_token': bad_token,
            }, format='json').status_code, 400)
        from django.core import signing
        with patch('core.views.signing.loads', side_effect=signing.SignatureExpired):
            self.assertEqual(APIClient().post('/api/verify/', {
                'email': otp.email, 'otp': otp.otp, 'registration_token': token,
            }, format='json').status_code, 400)
        self.assertFalse(User.objects.filter(email=otp.email).exists())

    def test_expired_otp_and_resend(self):
        otp = self.register()
        EmailOTP.objects.filter(pk=otp.pk).update(created_at=timezone.now() - timedelta(minutes=11))
        self.assertEqual(self.client.post('/api/verify/', {'email': otp.email, 'otp': otp.otp}).status_code, 400)
        with patch('core.views.send_mail'):
            self.assertEqual(self.client.post('/api/resend-otp/', {'email': otp.email}).status_code, 200)
        current = EmailOTP.objects.get(email=otp.email)
        self.assertNotEqual(current.pk, otp.pk)
        self.assertEqual(self.client.post('/api/verify/', {'email': otp.email, 'otp': current.otp}).status_code, 201)

    def test_validation_and_duplicate_registration(self):
        self.assertEqual(self.client.post('/api/register/', {'email': 'bad', 'password': 'password123'}).status_code, 400)
        otp = self.register()
        self.client.post('/api/verify/', {'email': otp.email, 'otp': otp.otp})
        self.assertEqual(self.client.post('/api/register/', {'email': 'EXAMPLE@test.mn', 'password': 'password123'}).status_code, 400)


class MarketplaceTests(APITestCase):
    def setUp(self):
        self.owner = User.objects.create_user(username='owner', email='owner@test.mn', password='password123')
        self.other = User.objects.create_user(username='other', email='other@test.mn', password='password123')
        self.payload = {'title': 'Саруул хотхон', 'description': 'Нар сайн үздэг байр', 'location': 'Зайсан', 'district': 'Хан-Уул', 'price': '350000000.00', 'area': '70.00', 'rooms': 3, 'floor': 4, 'total_floors': 12, 'contact_phone': '99112233', 'listing_type': 'sale', 'property_type': 'apartment'}
        self.property = Property.objects.create(owner=self.owner, **self.payload)

    def auth(self, user):
        token = Token.objects.get_or_create(user=user)[0]
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {token.key}')

    def test_discovery_details_and_linked_properties(self):
        district = District.objects.create(name='Хан-Уул', description='Дүүргийн мэдээлэл')
        complex = Complex.objects.create(name='Саруул', district=district, address='Зайсан')
        self.property.complex = complex
        self.property.save()
        response = self.client.get(f'/api/districts/{district.pk}/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['property_count'], 1)
        self.assertEqual(Decimal(response.data['average_sale_price_per_m2']), Decimal('5000000'))
        self.assertEqual(self.client.get('/api/complexes/', {'district': district.name}).data['count'], 1)
        self.assertEqual(self.client.get(f'/api/complexes/{complex.pk}/').data['property_count'], 1)
        self.assertEqual(self.client.get('/api/agents/').status_code, 404)
        for key, value in [('complex', complex.pk)]:
            self.assertEqual(self.client.get('/api/properties/', {key: value}).data['count'], 1)
            self.assertEqual(self.client.get('/api/properties/', {key: 'bad'}).status_code, 400)
        self.assertEqual(self.client.post('/api/districts/', {'name': 'Other'}).status_code, 401)

    def test_recommendations_respect_budget_and_require_valid_constraints(self):
        url = '/api/properties/recommendations/'
        self.assertEqual(self.client.get(url).status_code, 400)
        self.assertEqual(self.client.get(url, {'max_price': 'NaN'}).status_code, 400)
        self.assertEqual(self.client.get(url, {'max_price': 300000000}).data['count'], 0)
        response = self.client.get(url, {'max_price': 400000000, 'district': 'Хан-Уул', 'rooms': 3, 'min_area': 60, 'max_area': 80})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['count'], 1)
        self.assertEqual(self.client.get(url, {'max_price': 400000000, 'rooms': 2}).data['count'], 0)

    def test_featured_is_admin_controlled_and_complex_matches_district(self):
        self.auth(self.owner)
        response = self.client.patch(f'/api/properties/{self.property.pk}/', {'is_featured': True}, format='json')
        self.assertEqual(response.status_code, 200)
        self.property.refresh_from_db()
        self.assertFalse(self.property.is_featured)
        self.property.is_featured = True
        self.property.save()
        self.assertEqual(self.client.get('/api/properties/', {'featured': 'true'}).data['count'], 1)
        district = District.objects.create(name='Баянзүрх')
        complex = Complex.objects.create(name='Хотхон', district=district)
        self.assertEqual(self.client.patch(f'/api/properties/{self.property.pk}/', {'complex': complex.pk}, format='json').status_code, 400)
        self.assertEqual(self.client.patch(f'/api/properties/{self.property.pk}/', {'complex': complex.pk, 'district': district.name}, format='json').status_code, 200)

    def test_read_search_filter_pagination(self):
        Property.objects.create(owner=self.other, **{**self.payload, 'title': 'Түрээс', 'listing_type': 'rent', 'price': '2000000', 'rooms': 2})
        response = self.client.get('/api/properties/', {'listing_type': 'sale', 'district': 'Хан-Уул', 'search': 'Зайсан', 'rooms': 3, 'min_area': 50, 'max_price': 400000000, 'ordering': 'price'})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['count'], 1)
        self.assertEqual(response.data['results'][0]['id'], self.property.id)
        self.assertIsNotNone(self.client.get('/api/properties/', {'page_size': 1}).data['next'])
        self.assertEqual(self.client.get('/api/properties/', {'max_price': 'NaN'}).status_code, 400)
        self.assertEqual(self.client.get('/api/properties/', {'rooms': '2.5'}).status_code, 400)

    def test_only_owner_can_edit_delete_and_upload(self):
        url = f'/api/properties/{self.property.id}/'
        self.assertEqual(self.client.post('/api/properties/', self.payload, format='json').status_code, 401)
        self.auth(self.other)
        self.assertEqual(self.client.patch(url, {'price': 100}, format='json').status_code, 403)
        self.assertEqual(self.client.delete(url).status_code, 403)
        self.assertEqual(self.client.post(url + 'photos/', {}).status_code, 403)
        self.auth(self.owner)
        response = self.client.patch(url, {'price': 360000000}, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data['is_owner'])
        self.assertEqual(self.client.delete(url).status_code, 204)

    def test_create_validation_and_owner_assignment(self):
        self.auth(self.owner)
        for fields in [{'price': 0}, {'area': 0}, {'floor': 15}, {'contact_phone': 'x'}, {'title': ''}]:
            self.assertEqual(self.client.post('/api/properties/', {**self.payload, **fields}, format='json').status_code, 400)
        response = self.client.post('/api/properties/', {**self.payload, 'owner': self.other.id}, format='json')
        self.assertEqual(response.status_code, 201)
        self.assertEqual(Property.objects.get(pk=response.data['id']).owner, self.owner)
        self.assertEqual(self.client.get('/api/properties/', {'mine': 'true'}).data['count'], 2)

    def test_saved_properties_are_private_and_idempotent(self):
        url = f'/api/properties/{self.property.id}/favorite/'
        self.assertEqual(self.client.post(url).status_code, 401)
        self.auth(self.other)
        self.assertEqual(self.client.post(url).status_code, 200)
        self.assertEqual(self.client.post(url).status_code, 200)
        self.assertEqual(Favorite.objects.count(), 1)
        saved = self.client.get('/api/properties/', {'saved': 'true'})
        self.assertEqual(saved.data['count'], 1)
        self.assertTrue(saved.data['results'][0]['is_favorite'])
        self.auth(self.owner)
        self.assertEqual(self.client.get('/api/properties/', {'saved': 'true'}).data['count'], 0)
        self.auth(self.other)
        self.assertEqual(self.client.delete(url).status_code, 200)
        self.assertEqual(self.client.get('/api/properties/', {'saved': 'true'}).data['count'], 0)

    def test_photo_upload_display_delete_and_invalid_file(self):
        self.auth(self.owner)
        image = io.BytesIO()
        Image.new('RGB', (20, 20), 'green').save(image, format='PNG')
        url = f'/api/properties/{self.property.id}/photos/'
        with tempfile.TemporaryDirectory(dir=Path(__file__).resolve().parent.parent) as media, override_settings(MEDIA_ROOT=media):
            response = self.client.post(url, {'images': SimpleUploadedFile('room.png', image.getvalue(), content_type='image/png')}, format='multipart')
            self.assertEqual(response.status_code, 201)
            photo_id = response.data[0]['id']
            detail = self.client.get(f'/api/properties/{self.property.id}/')
            self.assertIn('http://testserver/media/', detail.data['images'][0]['image'])
            self.assertEqual(self.client.post(url, {'images': SimpleUploadedFile('bad.txt', b'not image')}, format='multipart').status_code, 400)
            self.assertEqual(self.client.delete(url, {'image_id': photo_id}, format='json').status_code, 204)
            self.assertEqual(self.property.images.count(), 0)
