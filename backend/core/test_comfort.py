from django.contrib import admin
from django.contrib.auth.models import User
from django.db.models.deletion import ProtectedError
from rest_framework.test import APITestCase

from .comfort import DEFAULT_WEIGHTS
from .models import Complex, ComplexRating, ComplexComment, District


class ComfortTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user('reviewer', password='password123')
        self.other = User.objects.create_user('other', password='password123')
        self.admin = User.objects.create_user('admin', password='password123', is_staff=True, is_superuser=True)
        self.complex = Complex.objects.create(name='Хотхон', district=District.objects.create(name='Дүүрэг'))
        self.path = f'/api/complexes/{self.complex.pk}/'

    def rating(self, user, scores):
        self.client.force_authenticate(user)
        return self.client.put(self.path + 'my-rating/', {'scores': scores}, format='json')

    def test_default_is_provisional_and_guest_can_read(self):
        result = self.client.get(self.path + 'comfort/')
        self.assertEqual(result.status_code, 200)
        self.assertEqual(result.data['score'], 50)
        self.assertEqual(result.data['coverage'], 0)
        self.assertIsNone(result.data['ranking_score'])
        self.assertFalse(result.data['rankable'])
        self.assertTrue(result.data['is_default'])
        self.assertEqual(sum(result.data['weights'].values()), 100)
        self.assertTrue(all(row['score'] == 50 and row['origin'] == 'default' for row in result.data['criteria']))

    def test_rating_explanation_is_optional_and_public_when_provided(self):
        self.rating(self.user, {'location': 80})
        self.assertFalse(ComplexComment.objects.exists())
        for text in ['', '   ']:
            result = self.client.put(self.path + 'my-rating/', {
                'scores': {'location': 80}, 'explanation': text,
            }, format='json')
            self.assertEqual(result.status_code, 200)
            self.assertEqual(result.data['my_explanation'], '')
            self.assertFalse(ComplexComment.objects.exists())
        result = self.client.put(self.path + 'my-rating/', {
            'scores': {'location': 80}, 'explanation': '  Автобус ойрхон.  ',
        }, format='json')
        self.assertEqual(result.status_code, 200)
        self.assertEqual(result.data['my_explanation'], 'Автобус ойрхон.')
        self.assertEqual(result.data['score'], 80)
        self.client.force_authenticate(user=None)
        result = self.client.get(self.path + 'comments/')
        self.assertEqual(result.status_code, 200)
        self.assertEqual(result.data['results'][0]['text'], 'Автобус ойрхон.')

    def test_explanation_edits_clear_and_delete_without_duplicates(self):
        self.client.force_authenticate(self.user)
        for text in ['Эхний тайлбар', 'Зассан тайлбар']:
            self.client.put(self.path + 'my-rating/', {'scores': {'location': 70}, 'explanation': text}, format='json')
        self.assertEqual(ComplexComment.objects.count(), 1)
        self.assertEqual(ComplexRating.objects.count(), 1)
        # Older clients omitting explanation keep existing text.
        self.assertEqual(self.rating(self.user, {'location': 90}).data['my_explanation'], 'Зассан тайлбар')
        result = self.client.put(self.path + 'my-rating/', {'scores': {'location': 90}, 'explanation': 'x' * 2001}, format='json')
        self.assertEqual(result.status_code, 400)
        comment = ComplexComment.objects.get()
        self.client.patch(self.path + f'comments/{comment.pk}/', {'text': 'Сэтгэгдлээс зассан'}, format='json')
        self.assertEqual(self.client.get(self.path + 'comfort/').data['my_explanation'], 'Сэтгэгдлээс зассан')
        self.client.delete(self.path + f'comments/{comment.pk}/')
        self.assertEqual(self.client.get(self.path + 'comfort/').data['my_explanation'], '')
        self.assertEqual(ComplexRating.objects.count(), 1)
        self.client.put(self.path + 'my-rating/', {'scores': {'location': 90}, 'explanation': 'Нэмсэн'}, format='json')
        cleared = self.client.put(self.path + 'my-rating/', {'scores': {'location': 90}, 'explanation': ''}, format='json')
        self.assertEqual(cleared.data['my_explanation'], '')
        self.assertFalse(ComplexComment.objects.exists())
        self.client.put(self.path + 'my-rating/', {'scores': {'location': 90}, 'explanation': 'Дахин'}, format='json')
        self.client.delete(self.path + 'my-rating/')
        self.assertFalse(ComplexComment.objects.exists())
        self.assertFalse(ComplexRating.objects.exists())

    def test_partial_data_and_60_percent_threshold(self):
        result = self.rating(self.user, {'location': 100, 'transport': 0})
        self.assertEqual(result.status_code, 200)
        self.assertEqual(result.data['coverage'], 35)
        self.assertAlmostEqual(result.data['score'], 57.14, places=2)
        self.assertIsNone(result.data['ranking_score'])
        result = self.rating(self.user, {'location': 80, 'transport': 80, 'environment': 80, 'safety': 80})
        self.assertEqual(result.data['coverage'], 60)
        self.assertTrue(result.data['rankable'])
        self.assertEqual(result.data['ranking_score'], 80)

    def test_average_per_criterion_update_and_delete(self):
        self.rating(self.user, {'location': 100, 'transport': 0})
        result = self.rating(self.other, {'location': 0})
        self.assertEqual(result.data['criteria'][0]['score'], 50)
        self.assertEqual(result.data['criteria'][0]['count'], 2)
        self.assertEqual(result.data['criteria'][1]['score'], 0)
        self.assertEqual(result.data['criteria'][1]['count'], 1)
        self.assertEqual(result.data['score'], 28.57)
        self.assertFalse(result.data['criteria'][0]['verified'])
        self.assertIsNotNone(result.data['criteria'][0]['collected_at'])
        self.rating(self.other, {'location': 80})
        self.assertEqual(ComplexRating.objects.count(), 2)
        self.client.delete(self.path + 'my-rating/')
        self.client.force_authenticate(self.user)
        result = self.client.delete(self.path + 'my-rating/')
        self.assertEqual(result.data['score'], 50)
        self.assertTrue(result.data['is_default'])

    def test_invalid_scores_are_rejected_without_overwriting(self):
        self.rating(self.user, {'location': 70})
        for scores in [{}, {'unknown': 20}, {'location': -1}, {'location': 101},
                       {'location': True}, {'location': '80'}, {'location': None}, [20]]:
            with self.subTest(scores=scores):
                self.assertEqual(self.rating(self.user, scores).status_code, 400)
        self.assertEqual(ComplexRating.objects.get(user=self.user).scores, {'location': 70})

    def test_weights_are_personal_and_persisted(self):
        self.rating(self.user, {'location': 100, 'transport': 0})
        weights = {key: 0 for key in DEFAULT_WEIGHTS}
        weights['transport'] = 100
        self.assertEqual(self.client.put('/api/complexes/weights/', {'weights': weights}, format='json').status_code, 200)
        result = self.client.get(self.path + 'comfort/')
        self.assertEqual(result.data['score'], 0)
        self.assertEqual(result.data['coverage'], 100)
        self.assertEqual(self.client.get('/api/complexes/weights/').data['weights'], weights)
        self.client.force_authenticate(self.other)
        result = self.client.get(self.path + 'comfort/')
        self.assertEqual(result.data['weights'], DEFAULT_WEIGHTS)
        self.assertEqual(result.data['score'], 57.14)
        self.assertEqual(ComplexRating.objects.get(user=self.user).scores['location'], 100)

    def test_invalid_weights_and_guest_writes(self):
        self.assertEqual(self.client.put(self.path + 'my-rating/', {'scores': {'location': 80}}, format='json').status_code, 401)
        self.assertEqual(self.client.post(self.path + 'comments/', {'text': 'Hello'}).status_code, 401)
        self.assertEqual(self.client.get('/api/complexes/weights/').status_code, 401)
        self.client.force_authenticate(self.user)
        for weights in [{}, {'location': 100}, {**DEFAULT_WEIGHTS, 'location': 21},
                        {**DEFAULT_WEIGHTS, 'location': -1}]:
            self.assertEqual(self.client.put('/api/complexes/weights/', {'weights': weights}, format='json').status_code, 400)

    def test_public_comments_pagination_and_owner_edit_delete(self):
        self.client.force_authenticate(self.user)
        result = self.client.post(self.path + 'comments/', {'text': 'Сайхан хотхон'}, format='json')
        self.assertEqual(result.status_code, 201)
        comment_path = self.path + f"comments/{result.data['id']}/"
        self.assertEqual(self.client.patch(comment_path, {'text': 'Шинэ сэтгэгдэл'}, format='json').status_code, 200)
        self.client.post(self.path + 'comments/', {'text': 'Дахин сэтгэгдэл'}, format='json')
        self.client.force_authenticate(user=None)
        result = self.client.get(self.path + 'comments/?page_size=1')
        self.assertEqual(result.status_code, 200)
        self.assertEqual(result.data['count'], 2)
        self.assertIsNotNone(result.data['next'])
        self.assertEqual(result.data['results'][0]['username'], 'reviewer')
        self.assertFalse(result.data['results'][0]['can_edit'])
        self.assertFalse(result.data['results'][0]['can_delete'])
        self.client.force_authenticate(self.user)
        self.assertEqual(self.client.delete(comment_path).status_code, 204)

    def test_admin_cannot_manipulate_other_users_content_or_delete_complex(self):
        self.rating(self.user, {'location': 80})
        result = self.client.post(self.path + 'comments/', {'text': 'Миний сэтгэгдэл'})
        comment_path = self.path + f"comments/{result.data['id']}/"
        self.client.force_authenticate(self.admin)
        self.assertEqual(self.client.patch(comment_path, {'text': 'Засах'}, format='json').status_code, 403)
        self.assertEqual(self.client.delete(comment_path).status_code, 403)
        # Even an injected user id only writes the caller's own rating.
        self.client.put(self.path + 'my-rating/', {'user': self.user.pk, 'scores': {'location': 0}}, format='json')
        self.assertEqual(ComplexRating.objects.get(user=self.user).scores, {'location': 80})
        self.assertEqual(self.client.delete(self.path).status_code, 409)
        self.assertNotIn(ComplexRating, admin.site._registry)
        self.assertNotIn(ComplexComment, admin.site._registry)
        with self.assertRaises(ProtectedError):
            self.complex.delete()
        with self.assertRaises(ProtectedError):
            self.user.delete()

    def test_comment_validation_and_complex_scope(self):
        self.client.force_authenticate(self.user)
        for text in ['', '   ', 'x' * 2001]:
            self.assertEqual(self.client.post(self.path + 'comments/', {'text': text}, format='json').status_code, 400)
        self.assertEqual(self.client.get('/api/districts/1/comfort/').status_code, 404)
        self.assertEqual(self.client.get('/api/properties/1/comfort/').status_code, 404)
        result = self.client.post(self.path + 'comments/', {'text': 'Туршилт'})
        other_complex = Complex.objects.create(name='Өөр хотхон', district=self.complex.district)
        self.assertEqual(self.client.delete(f"/api/complexes/{other_complex.pk}/comments/{result.data['id']}/").status_code, 404)
