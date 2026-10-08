from datetime import timedelta
from unittest.mock import patch

from django.contrib.auth.models import User
from django.core.cache import cache
from django.test import override_settings
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .models import District, PasswordResetCode


@override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend')
class AccountManagementTests(APITestCase):
    def setUp(self):
        cache.clear()
        self.user = User.objects.create_user('tester', 'tester@example.com', 'oldpass123')

    def challenge(self):
        with patch('core.passwords.secrets.randbelow', return_value=123456):
            response = self.client.post('/api/password/forgot/', {'email': self.user.email})
        self.assertEqual(response.status_code, 200)
        return {'reset_token': response.data['reset_token'], 'code': '123456',
                'new_password': 'newpass123', 'password_confirm': 'newpass123'}

    def test_reset_invalidates_token_and_rejects_replay(self):
        token = Token.objects.create(user=self.user)
        data = self.challenge()
        self.assertEqual(self.client.post('/api/password/reset/', data).status_code, 200)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password('newpass123'))
        self.assertFalse(Token.objects.filter(pk=token.pk).exists())
        self.assertEqual(self.client.post('/api/password/reset/', data).status_code, 400)

    def test_reset_expiry_and_attempt_limit(self):
        data = self.challenge()
        for _ in range(5):
            self.assertEqual(self.client.post('/api/password/reset/', {**data, 'code': '999999'}).status_code, 400)
        self.assertEqual(self.client.post('/api/password/reset/', data).status_code, 400)
        PasswordResetCode.objects.all().delete()
        data = self.challenge()
        PasswordResetCode.objects.update(created_at=timezone.now() - timedelta(minutes=11))
        self.assertEqual(self.client.post('/api/password/reset/', data).status_code, 400)

    def test_change_checks_old_password_and_rotates_token(self):
        token = Token.objects.create(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {token.key}')
        data = {'old_password': 'wrong', 'new_password': 'newpass123', 'password_confirm': 'newpass123'}
        self.assertEqual(self.client.post('/api/password/change/', data).status_code, 400)
        response = self.client.post('/api/password/change/', {**data, 'old_password': 'oldpass123'})
        self.assertEqual(response.status_code, 200)
        self.assertNotEqual(response.data['token'], token.key)
        self.assertEqual(self.client.get('/api/profile/').status_code, 401)

    def test_district_writes_require_admin(self):
        self.client.force_authenticate(self.user)
        self.assertEqual(self.client.post('/api/districts/', {'name': 'Test district'}).status_code, 403)
        self.user.is_staff = True
        self.user.save()
        response = self.client.post('/api/districts/', {'name': 'Test district'})
        self.assertEqual(response.status_code, 201)
        self.assertEqual(self.client.delete(f"/api/districts/{response.data['id']}/").status_code, 204)
        self.assertFalse(District.objects.exists())

    def test_register_rejects_non_string_password(self):
        response = self.client.post('/api/register/', {'username': 'newuser', 'email': 'new@example.com',
            'password': 123456, 'password_confirm': 123456}, format='json')
        self.assertEqual(response.status_code, 400)

    def test_profile_updates_names_and_username_without_changing_permissions(self):
        self.client.force_authenticate(self.user)
        response = self.client.patch('/api/profile/', {
            'first_name': 'Бат', 'last_name': 'Дорж', 'username': 'newtester',
            'is_staff': True, 'is_superuser': True,
        }, format='json')
        self.assertEqual(response.status_code, 200)
        self.user.refresh_from_db()
        self.assertEqual((self.user.first_name, self.user.last_name, self.user.username),
                         ('Бат', 'Дорж', 'newtester'))
        self.assertFalse(self.user.is_staff)
        self.assertFalse(self.user.is_superuser)
        self.client.force_authenticate(user=None)
        self.assertEqual(self.client.post('/api/login/', {
            'identifier': 'newtester', 'password': 'oldpass123',
        }, format='json').status_code, 200)

    def test_profile_rejects_duplicate_and_invalid_usernames(self):
        User.objects.create_user('taken', 'other@example.com', 'password123')
        self.client.force_authenticate(self.user)
        for username in ['taken', 'TAKEN', '', 'bad name', 'email@example.com', 'x' * 151]:
            with self.subTest(username=username):
                response = self.client.patch('/api/profile/', {'username': username}, format='json')
                self.assertEqual(response.status_code, 400)
                self.assertIn('username', response.data)
        self.assertEqual(self.client.patch('/api/profile/', {'username': 'tester'}, format='json').status_code, 200)
        self.user.refresh_from_db()
        self.assertEqual(self.user.username, 'tester')
