"""A sourced selection catalog. Does not add property ads, scores or map locations."""
import json
import re
import unicodedata
from pathlib import Path

from django.core.management.base import BaseCommand
from django.db import transaction
from core.models import Complex, District


def name_keys(name):
    parts = re.split(r'[()]', unicodedata.normalize('NFKC', name))
    return {re.sub(r'\s+', ' ', part).strip().casefold() for part in parts if part.strip()}


class Command(BaseCommand):
    help = 'Add sourced real complex choices; reruns skip existing names and leave existing data unchanged.'

    @transaction.atomic
    def handle(self, *args, **options):
        catalog = json.loads((Path(__file__).resolve().parents[2] / 'data' / 'complex_catalog.json').read_text(encoding='utf-8'))
        added = skipped = 0
        for group in catalog:
            district, _ = District.objects.get_or_create(name=group['district'])
            # Serialize reruns by district; existing records are never renamed or overwritten.
            district = District.objects.select_for_update().get(pk=district.pk)
            existing = set()
            for name in district.complexes.values_list('name', flat=True):
                existing.update(name_keys(name))
            for name in group['names']:
                keys = name_keys(name)
                if existing & keys:
                    skipped += 1
                    continue
                Complex.objects.create(name=name, district=district)
                existing.update(keys)
                added += 1
        self.stdout.write(self.style.SUCCESS(f'Complex choices: {added} added, {skipped} already exist.'))
