import os
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User

class Command(BaseCommand):
    help = "Initialise ou met à jour le compte administrateur dédié pour l'accès Web et Mobile"

    def handle(self, *args, **options):
        email = os.environ.get('ADMIN_EMAIL', 'admin@shieldnet.app')
        password = os.environ.get('ADMIN_PASSWORD', 'admin123')
        username = 'admin'

        user = User.objects.filter(email__iexact=email).first()
        if not user:
            user = User.objects.filter(username__iexact=username).first()

        if user:
            user.email = email
            user.is_staff = True
            user.is_superuser = True
            user.set_password(password)
            user.save()
            self.stdout.write(self.style.SUCCESS(f"Compte administrateur mis à jour avec succès : {email}"))
        else:
            User.objects.create_superuser(
                username=username,
                email=email,
                password=password,
                first_name='Administrateur',
                last_name='ShieldNet'
            )
            self.stdout.write(self.style.SUCCESS(f"Compte administrateur créé avec succès : {email}"))
