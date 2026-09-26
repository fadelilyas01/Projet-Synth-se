import os
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User, Group, Permission
from django.contrib.contenttypes.models import ContentType
from shield_api.models import BlacklistedNumber, SpamReport, SafeReport, AuditLog

class Command(BaseCommand):
    help = "Initialise ou met à jour le compte gestionnaire/modérateur dédié et son groupe de permissions"

    def handle(self, *args, **options):
        # 1. Configuration ou création du groupe Gestionnaires
        group, _ = Group.objects.get_or_create(name='Gestionnaires')

        # Attribution des permissions de modération opérationnelle
        models_for_perms = [
            (BlacklistedNumber, ['add', 'change', 'view']),
            (SpamReport, ['view', 'delete']),
            (SafeReport, ['view']),
            (AuditLog, ['view']),
        ]

        assigned_count = 0
        for model_cls, actions in models_for_perms:
            ct = ContentType.objects.get_for_model(model_cls)
            for act in actions:
                codename = f"{act}_{model_cls._meta.model_name}"
                perm = Permission.objects.filter(content_type=ct, codename=codename).first()
                if perm:
                    group.permissions.add(perm)
                    assigned_count += 1

        # 2. Création ou mise à jour du compte Gestionnaire
        email = os.environ.get('MANAGER_EMAIL', 'manager@shieldnet.app')
        password = os.environ.get('MANAGER_PASSWORD', 'manager123')
        username = 'manager'

        user = User.objects.filter(email__iexact=email).first()
        if not user:
            user = User.objects.filter(username__iexact=username).first()

        if user:
            user.email = email
            user.first_name = 'Gestionnaire'
            user.last_name = 'Modération'
            user.is_staff = True
            user.is_superuser = False
            user.set_password(password)
            user.save()
            user.groups.add(group)
            self.stdout.write(self.style.SUCCESS(f"Compte gestionnaire mis à jour avec succès : {email}"))
        else:
            user = User.objects.create_user(
                username=username,
                email=email,
                password=password,
                first_name='Gestionnaire',
                last_name='Modération',
                is_staff=True,
                is_superuser=False
            )
            user.groups.add(group)
            self.stdout.write(self.style.SUCCESS(f"Compte gestionnaire créé avec succès : {email}"))
