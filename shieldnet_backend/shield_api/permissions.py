import hmac
from rest_framework import permissions
from django.conf import settings

class HasAPIKeyOrAuthenticated(permissions.BasePermission):
    """
    Règle de sécurité ShieldNet :
    Permet l'accès si l'utilisateur est un administrateur connecté (Django Admin / Session / JWT)
    OU si la requête inclut l'en-tête secret 'X-API-Key' correspondant à l'application mobile.
    Vérification en temps constant (hmac.compare_digest) pour immunité contre les attaques par canal auxiliaire (timing attacks).
    """
    message = "Accès refusé : En-tête 'X-API-Key' manquant ou invalide, ou authentification requise."

    def has_permission(self, request, view):
        # Accès accordé d'office si la session ou le token JWT est valide
        if request.user and request.user.is_authenticated:
            return True

        # Contrôle de la clé API partagée configurée pour l'application cliente mobile
        api_key = request.headers.get('X-API-Key')
        expected_key = getattr(settings, 'API_KEY', None)

        if api_key and expected_key and hmac.compare_digest(api_key, expected_key):
            return True

        return False

class IsAdminStaffUser(permissions.BasePermission):
    """
    Exige que l'utilisateur soit authentifié avec des privilèges d'administrateur (is_staff = True).
    """
    message = "Accès réservé exclusivement aux administrateurs du système."

    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and request.user.is_staff)

