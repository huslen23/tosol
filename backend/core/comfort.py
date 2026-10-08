import math

from rest_framework import serializers
from .models import ComfortWeights, ComplexComment


CRITERIA = [
    ('location', 'Байршил, хүртээмж', 20, 'Ажил / төв цэг хүртэлх хугацаа, замын боломж'),
    ('transport', 'Нийтийн тээвэр', 15, 'Автобусны буудлын зай, чиглэлийн хүртээмж'),
    ('environment', 'Хүрээлэн буй орчин', 15, 'Агаар, дуу чимээ, ногоон байгууламж'),
    ('safety', 'Аюулгүй байдлын нөхцөл', 10, 'Гэрэлтүүлэг, орцны хяналт'),
    ('infrastructure', 'Дэд бүтэц', 10, 'Ус, дулаан, цахилгааны найдвартай байдал'),
    ('building', 'Барилгын тав тух', 10, 'Лифт, дулаан, нарны тусгал, зогсоол'),
    ('services', 'Нийтийн үйлчилгээ', 10, 'Сургууль, цэцэрлэг, эмнэлэг, дэлгүүр'),
    ('cost', 'Үнэ, ашиглалтын зардал', 10, 'Төсөвт нийцэх байдал, СӨХ / ашиглалтын төлбөр'),
]
DEFAULT_WEIGHTS = {key: weight for key, _, weight, _ in CRITERIA}


def validate_values(value, *, weights=False):
    if not isinstance(value, dict) or not value or set(value) - set(DEFAULT_WEIGHTS):
        raise serializers.ValidationError('Зөв шалгуурын утгууд оруулна уу.')
    if weights and set(value) != set(DEFAULT_WEIGHTS):
        raise serializers.ValidationError('Бүх 8 шалгуурын жинг оруулна уу.')
    for number in value.values():
        if isinstance(number, bool) or not isinstance(number, (int, float)) or not math.isfinite(number) or not 0 <= number <= 100:
            raise serializers.ValidationError('Утга 0–100 хооронд байна.')
    if weights and not math.isclose(sum(value.values()), 100, abs_tol=0.000001):
        raise serializers.ValidationError('Нийт жин 100% байна.')
    return value


class RatingInput(serializers.Serializer):
    scores = serializers.JSONField()
    explanation = serializers.CharField(required=False, allow_blank=True, max_length=2000)

    def validate_scores(self, value):
        return validate_values(value)


class WeightsInput(serializers.Serializer):
    weights = serializers.JSONField()

    def validate_weights(self, value):
        return validate_values(value, weights=True)


class CommentSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    can_edit = serializers.SerializerMethodField()
    can_delete = serializers.SerializerMethodField()

    class Meta:
        model = ComplexComment
        fields = ['id', 'username', 'text', 'created_at', 'updated_at', 'can_edit', 'can_delete']
        read_only_fields = ['id', 'created_at', 'updated_at']

    def get_can_edit(self, obj):
        return obj.user_id == self.context['request'].user.pk

    def get_can_delete(self, obj):
        return obj.user_id == self.context['request'].user.pk


def user_weights(user):
    if user.is_authenticated:
        saved = ComfortWeights.objects.filter(user=user).first()
        if saved:
            return saved.weights
    return dict(DEFAULT_WEIGHTS)


def summary(complex_obj, user):
    weights = user_weights(user)
    ratings = list(complex_obj.comfort_ratings.select_related('user', 'explanation_comment').order_by('id'))
    rows = []
    numerator = available_weight = 0
    for key, label, _, hint in CRITERIA:
        values = [r.scores[key] for r in ratings if key in r.scores]
        if values:
            score = sum(values) / len(values)
            source = 'Хэрэглэгчдийн үнэлгээ'
            collected_at = max(r.updated_at for r in ratings if key in r.scores).isoformat()
            verified = False
            origin = 'community'
        else:
            score, source, collected_at, verified = 50, 'Системийн түр анхдагч утга', None, False
            origin = 'default'
        if origin != 'default':
            available_weight += weights[key]
            numerator += score * weights[key]
        rows.append({'key': key, 'label': label, 'hint': hint, 'score': round(score, 2),
                     'weight': weights[key], 'count': len(values), 'source': source,
                     'collected_at': collected_at, 'verified': verified, 'origin': origin})
    coverage = available_weight / sum(weights.values()) * 100
    score = round(numerator / available_weight, 2) if available_weight else 50
    return {'score': score, 'coverage': round(coverage, 2), 'rankable': coverage >= 60,
            'ranking_score': score if coverage >= 60 else None,
            'is_default': available_weight == 0, 'rating_count': len(ratings),
            'rated_criteria_count': sum(row['count'] > 0 for row in rows),
            'total_criteria_count': len(rows),
            'latest_rating_at': max((r.updated_at for r in ratings), default=None).isoformat() if ratings else None,
            'comment_count': complex_obj.comments.count(), 'criteria': rows, 'weights': weights,
            'default_weights': DEFAULT_WEIGHTS,
            'my_scores': next((r.scores for r in ratings if r.user_id == user.pk), {}),
            'my_explanation': next((r.explanation_comment.text if r.explanation_comment_id else ''
                                    for r in ratings if r.user_id == user.pk), ''),
            'quality_note': 'Хэрэглэгчийн үнэлгээ нь хувийн туршлага; баталгаажсан хэмжилт биш. Анхдагч 50 оноо хамрагдалтад орохгүй.'}
