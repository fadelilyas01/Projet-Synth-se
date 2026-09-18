from django.contrib.auth.backends import ModelBackend
from django.contrib.auth.models import User
from django.db.models import Q

class EmailOrUsernameModelBackend(ModelBackend):
    """
    Permet l'authentification transparente avec l'adresse courriel OU le nom d'utilisateur.
    Garantit que l'administrateur et les utilisateurs peuvent se connecter indifféremment
    avec leur adresse courriel dédiée (ex: admin@shieldnet.app) ou leur identifiant
    sur l'interface Web Django (/admin/) et sur l'API mobile.
    """
    def authenticate(self, request, username=None, password=None, **kwargs):
        if username is None:
            username = kwargs.get('email')

        if not username or not password:
            return None

        # Recherche insensible à la casse par email ou par username
        user = User.objects.filter(
            Q(email__iexact=username) | Q(username__iexact=username)
        ).first()

        if user and user.check_password(password) and self.user_can_authenticate(user):
            return user

        return None
