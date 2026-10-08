from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction


class Command(BaseCommand):
    help = "Grant Django admin and full app management rights to an existing account."

    def add_arguments(self, parser):
        parser.add_argument("--email", required=True)

    @transaction.atomic
    def handle(self, *args, **options):
        users = list(get_user_model().objects.select_for_update().filter(email__iexact=options["email"].strip())[:2])
        if len(users) != 1:
            raise CommandError("Email must match exactly one existing account.")
        user = users[0]
        if not user.is_active:
            raise CommandError("Account is inactive; activate it explicitly before granting admin.")
        user.is_staff = user.is_superuser = True
        user.save(update_fields=["is_staff", "is_superuser"])
        self.stdout.write(self.style.SUCCESS(f"Admin rights granted: {user.email}"))
