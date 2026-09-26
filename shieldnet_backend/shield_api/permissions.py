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

class IsManagerOrAdminUser(permissions.BasePermission):
    """
    Autorise les administrateurs (is_superuser) ET les gestionnaires/modérateurs (is_staff ou groupe Gestionnaires).
    Permet la gestion de la liste noire, la modération des signalements et la consultation des métriques.
    """
    message = "Accès réservé aux gestionnaires et administrateurs autorisés."

    def has_permission(self, request, view):
        u = request.user
        if not (u and u.is_authenticated):
            return False
        return bool(u.is_superuser or u.is_staff or u.groups.filter(name='Gestionnaires').exists())

class IsAdminStaffUser(IsManagerOrAdminUser):
    """
    Alias pour la rétro-compatibilité : autorise le personnel d'administration et de gestion.
    """
    pass

class IsAdminOnlyUser(permissions.BasePermission):
    """
    Exige des privilèges d'administration totale (is_superuser).
    Réservé aux opérations hautement critiques : purge de la base, gestion des comptes utilisateurs, modification des accès.
    """
    message = "Accès strictement restreint aux administrateurs système (Superuser)."

    def has_permission(self, request, view):
        u = request.user
        return bool(u and u.is_authenticated and u.is_superuser)

