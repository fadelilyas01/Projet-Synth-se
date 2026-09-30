import hmac
from rest_framework import permissions
from django.conf import settings

class HasAPIKeyOrAuthenticated(permissions.BasePermission):
    message = 'Accès refusé : En-tête X-API-Key manquant ou invalide, ou authentification requise.'

    def has_permission(self, request, view):
        if getattr(request, 'user', None) and request.user.is_authenticated:
            return True

        api_key = request.headers.get('X-API-Key') or request.META.get('HTTP_X_API_KEY')
        expected_key = getattr(settings, 'API_KEY', None)

        if api_key and expected_key and hmac.compare_digest(str(api_key), str(expected_key)):
            return True

        return False

class IsManagerOrAdminUser(permissions.BasePermission):
    message = 'Accès réservé aux gestionnaires et administrateurs autorisés.'

    def has_permission(self, request, view):
        u = getattr(request, 'user', None)
        if not (u and u.is_authenticated):
            return False
        return bool(u.is_superuser or u.is_staff or u.groups.filter(name='Gestionnaires').exists())

class IsAdminStaffUser(IsManagerOrAdminUser):
    pass

class IsAdminOnlyUser(permissions.BasePermission):
    message = 'Accès strictement restreint aux administrateurs système (Superuser).'

    def has_permission(self, request, view):
        u = getattr(request, 'user', None)
        return bool(u and u.is_authenticated and u.is_superuser)
