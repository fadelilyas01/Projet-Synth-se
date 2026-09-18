from rest_framework import permissions
from django.conf import settings

class HasAPIKeyOrAuthenticated(permissions.BasePermission):
    """
    Règle de sécurité ShieldNet :
    Permet l'accès si l'utilisateur est un administrateur connecté (Django Admin / Session / JWT)
    OU si la requête inclut l'en-tête secret 'X-API-Key' correspondant à l'application mobile.
    """
    message = "Accès refusé : En-tête 'X-API-Key' manquant ou invalide, ou authentification requise."

    def has_permission(self, request, view):
        # 1. Accès autorisé pour tout utilisateur authentifié (Admin / Staff / JWT)
        if request.user and request.user.is_authenticated:
            return True

        # 2. Vérification de la clé API partagée envoyée par l'application Flutter
        api_key = request.headers.get('X-API-Key')
        expected_key = getattr(settings, 'API_KEY', 'ShieldNet_Secret_Token_UQO_2026')

        if api_key and api_key == expected_key:
            return True

        return False

class IsAdminStaffUser(permissions.BasePermission):
    """
    Exige que l'utilisateur soit authentifié avec des privilèges d'administrateur (is_staff = True).
    """
    message = "Accès réservé exclusivement aux administrateurs du système."

    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and request.user.is_staff)

