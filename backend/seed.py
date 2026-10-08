"""Compatibility entry point for manage.py shell."""
from django.core.management import call_command

call_command("seed_properties")
