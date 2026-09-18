from django.utils import timezone

from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from django.core.cache import cache
from django.utils.dateparse import parse_datetime
from .models import AuditLog, AuditLogAction
from .serializers import AuditLogSerializer

import secrets
from django.db import models
from django.contrib.auth.models import User
from rest_framework import generics, status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.throttling import AnonRateThrottle, UserRateThrottle
from rest_framework_simplejwt.tokens import RefreshToken
from drf_spectacular.utils import extend_schema

from .models import BlacklistedNumber, SpamReport, SafeReport
from .permissions import HasAPIKeyOrAuthenticated, IsAdminStaffUser
from .serializers import (
    BlacklistedNumberSerializer,
    SpamReportCreateSerializer,
    SafeReportCreateSerializer,
    SafeReportSerializer,
    CheckNumberResponseSerializer,
    UserSerializer,
    UserRegisterSerializer,
    EmailLoginSerializer,
    GoogleLoginSerializer,
)
from .services import (
    ReputationService,
    FalsePositiveConsensusService,
    DatabaseSanitizerService,
    hash_phone_number,
    mask_phone_number,
)

class StrictReportSubmissionThrottle(AnonRateThrottle):
    """
    Limiteur de débit strict anti-pollution: Max 10 signalements par heure par adresse IP anonyme.
    """
    rate = '10/hour'

class BlacklistDownloadView(APIView):
    """
    GET /api/v1/blacklist/
    Supporte :
    - La liste classique (compatibilité tests & anciens clients)
    - La synchronisation incrémentale (Delta Sync via ?since=<ISO-8601>)
    - La réconciliation des faux positifs (renvoie les numéros 'removed' à purger)
    """
    permission_classes = [HasAPIKeyOrAuthenticated]

    def get(self, request, *args, **kwargs):
        since_param = request.query_params.get('since')
        delta_mode = since_param is not None or request.query_params.get('delta') == 'true'

        now_iso = timezone.now().isoformat()
        active_qs = BlacklistedNumber.objects.filter(is_blocked=True, is_whitelisted=False, risk_score__gte=30)

        if delta_mode and since_param:
            clean_since = since_param.strip()
            if '+' not in clean_since and ' ' in clean_since:
                parts = clean_since.rsplit(' ', 1)
                if len(parts) == 2 and (':' in parts[1] or len(parts[1]) in (2, 4)):
                    clean_since = f"{parts[0]}+{parts[1]}"
                elif 'T' in clean_since:
                    clean_since = clean_since.replace(' ', '+')
            since_dt = parse_datetime(clean_since)
            if since_dt and timezone.is_naive(since_dt):
                since_dt = timezone.make_aware(since_dt, timezone.get_current_timezone())
            if since_dt:
                updated_active = active_qs.filter(updated_at__gte=since_dt)
                # Numéros supprimés, blanchis ou désactivés depuis 'since'
                removed_hashes = BlacklistedNumber.objects.filter(
                    models.Q(is_whitelisted=True) | models.Q(is_blocked=False) | models.Q(risk_score__lt=30),
                    updated_at__gte=since_dt
                ).values_list('phone_hash', flat=True)

                serializer = BlacklistedNumberSerializer(updated_active, many=True)
                return Response({
                    'active': serializer.data,
                    'removed': list(removed_hashes),
                    'sync_timestamp': now_iso,
                    'is_delta': True,
                })

        if delta_mode:
            serializer = BlacklistedNumberSerializer(active_qs, many=True)
            return Response({
                'active': serializer.data,
                'removed': [],
                'sync_timestamp': now_iso,
                'is_delta': False,
            })

        # Mode liste classique
        serializer = BlacklistedNumberSerializer(active_qs, many=True)
        return Response(serializer.data)


class SubmitReportView(APIView):
    """
    POST /api/v1/reports/
    Soumet un nouveau signalement avec protection stricte anti-pollution BDD.
    """
    permission_classes = [HasAPIKeyOrAuthenticated]
    throttle_classes = [StrictReportSubmissionThrottle, UserRateThrottle]

    @extend_schema(request=SpamReportCreateSerializer, responses={201: BlacklistedNumberSerializer})
    def post(self, request):
        serializer = SpamReportCreateSerializer(data=request.data)
        if serializer.is_valid():
            data = serializer.validated_data
            user = request.user if request.user.is_authenticated else None
            
            report = ReputationService.process_new_report(
                phone_hash=data['phone_hash'],
                category=data['category'],
                masked_number=data.get('masked_number'),
                user=user,
            )

            number_obj = BlacklistedNumber.objects.get(phone_hash=data['phone_hash'])
            return Response(
                BlacklistedNumberSerializer(number_obj).data,
                status=status.HTTP_201_CREATED
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class SubmitSafeReportView(APIView):
    """
    POST /api/v1/reports/safe/
    Soumet un avis favorable ou une contestation de faux positif.
    Déclenche instantanément l'algorithme de consensualité et réhabilite
    automatiquement le numéro si le consensus légitime est validé.
    """
    permission_classes = [HasAPIKeyOrAuthenticated]
    throttle_classes = [StrictReportSubmissionThrottle, UserRateThrottle]

    @extend_schema(request=SafeReportCreateSerializer)
    def post(self, request):
        serializer = SafeReportCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        data = serializer.validated_data
        user = request.user if request.user.is_authenticated else None
        ip_addr = request.META.get('REMOTE_ADDR')

        report, auto_whitelisted = FalsePositiveConsensusService.register_safe_feedback(
            phone_hash=data['phone_hash'],
            reason=data.get('reason', 'service'),
            comment=data.get('comment', ''),
            user=user,
            ip_address=ip_addr,
            masked_number=data.get('masked_number'),
        )

        analysis = FalsePositiveConsensusService.evaluate_consensus(data['phone_hash'])
        number_obj = BlacklistedNumber.objects.filter(phone_hash=data['phone_hash']).first()

        detail_msg = (
            "Consensus atteint ! Numéro identifié comme faux positif et réhabilité automatiquement."
            if auto_whitelisted else
            "Avis légitime enregistré. En attente de confirmation par consensus communautaire."
        )

        return Response({
            'detail': detail_msg,
            'phone_hash': data['phone_hash'],
            'safe_reports_count': analysis['safe_count'],
            'spam_reports_count': analysis['spam_count'],
            'consensus_score': analysis['consensus_ratio'],
            'auto_whitelisted': auto_whitelisted,
            'is_whitelisted': number_obj.is_whitelisted if number_obj else False,
            'is_blocked': number_obj.is_blocked if number_obj else False,
            'whitelist_reason': number_obj.whitelist_reason if number_obj else '',
        }, status=status.HTTP_201_CREATED)

class ConsensusStatusView(APIView):
    """
    GET /api/v1/consensus/<str:phone_hash>/
    Expose en temps réel l'évaluation détaillée de consensualité et de faux positif pour un numéro.
    """
    permission_classes = [HasAPIKeyOrAuthenticated]

    def get(self, request, phone_hash):
        analysis = FalsePositiveConsensusService.evaluate_consensus(phone_hash)
        number_obj = BlacklistedNumber.objects.filter(phone_hash=phone_hash).first()
        return Response({
            'phone_hash': phone_hash,
            'spam_count': analysis['spam_count'],
            'safe_count': analysis['safe_count'],
            'consensus_ratio': analysis['consensus_ratio'],
            'quorum_met': analysis['quorum_met'],
            'is_false_positive': analysis['is_false_positive'],
            'is_whitelisted': number_obj.is_whitelisted if number_obj else False,
            'is_blocked': number_obj.is_blocked if number_obj else False,
            'whitelist_reason': number_obj.whitelist_reason if number_obj else '',
            'details': analysis['details'],
        })

class CheckNumberView(APIView):
    """
    GET /api/v1/check/<phone_hash>/
    Vérifie le score de risque, la consensualité et le statut d'un numéro d'après son empreinte SHA-256.
    """
    permission_classes = [HasAPIKeyOrAuthenticated]

    @extend_schema(responses={200: CheckNumberResponseSerializer})
    def get(self, request, phone_hash):
        try:
            number = BlacklistedNumber.objects.get(phone_hash=phone_hash)
            # Un numéro est considéré comme spam s'il est bloqué ET non blanchi
            is_spam = number.is_blocked and not number.is_whitelisted
            return Response({
                'is_spam': is_spam,
                'risk_score': number.risk_score,
                'category': number.category,
                'reports_count': number.reports_count,
                'safe_reports_count': number.safe_reports_count,
                'consensus_score': number.consensus_score,
                'is_whitelisted': number.is_whitelisted,
                'whitelist_reason': number.whitelist_reason,
            })
        except BlacklistedNumber.DoesNotExist:
            return Response({
                'is_spam': False,
                'risk_score': 0,
                'category': None,
                'reports_count': 0,
                'safe_reports_count': 0,
                'consensus_score': 0.0,
                'is_whitelisted': False,
                'whitelist_reason': None,
            })


class RegisterView(APIView):
    """
    POST /api/v1/auth/register/
    Création d'un nouveau compte utilisateur avec email et mot de passe.
    """
    permission_classes = [permissions.AllowAny]

    @extend_schema(request=UserRegisterSerializer)
    def post(self, request):
        serializer = UserRegisterSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            refresh = RefreshToken.for_user(user)
            return Response({
                'user': UserSerializer(user).data,
                'tokens': {
                    'refresh': str(refresh),
                    'access': str(refresh.access_token),
                }
            }, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class EmailLoginView(APIView):
    """
    POST /api/v1/auth/login/
    Connexion directe par email et mot de passe.
    """
    permission_classes = [permissions.AllowAny]

    @extend_schema(request=EmailLoginSerializer)
    def post(self, request):
        serializer = EmailLoginSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.validated_data['user']
            refresh = RefreshToken.for_user(user)
            return Response({
                'user': UserSerializer(user).data,
                'tokens': {
                    'refresh': str(refresh),
                    'access': str(refresh.access_token),
                }
            }, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class GoogleLoginView(APIView):
    """
    POST /api/v1/auth/google/
    Connexion / Inscription transparente avec un compte Google (adresse email).
    Si le compte n'existe pas encore, il est automatiquement créé sans exiger de mot de passe.
    """
    permission_classes = [permissions.AllowAny]

    @extend_schema(request=GoogleLoginSerializer)
    def post(self, request):
        serializer = GoogleLoginSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data['email']
        name = serializer.validated_data.get('name', '').strip()

        user = User.objects.filter(email__iexact=email).first()
        if not user:
            # Auto-provisioning immédiat pour le compte Google
            first_name = name.split()[0] if name else email.split('@')[0]
            last_name = ' '.join(name.split()[1:]) if len(name.split()) > 1 else ''
            random_password = secrets.token_urlsafe(24)
            user = User.objects.create_user(
                username=email,
                email=email,
                password=random_password,
                first_name=first_name,
                last_name=last_name,
            )

        if not user.is_active:
            return Response({'detail': 'Ce compte utilisateur est désactivé.'}, status=status.HTTP_403_FORBIDDEN)

        refresh = RefreshToken.for_user(user)
        return Response({
            'user': UserSerializer(user).data,
            'tokens': {
                'refresh': str(refresh),
                'access': str(refresh.access_token),
            }
        }, status=status.HTTP_200_OK)

class UserProfileView(APIView):
    """
    GET /api/v1/auth/me/
    Récupère le profil de l'utilisateur connecté via son jeton JWT.
    """
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses={200: UserSerializer})
    def get(self, request):
        return Response(UserSerializer(request.user).data)

class AdminStatsView(APIView):
    """
    GET /api/v1/admin/stats/
    Fournit une vue d'ensemble complète de l'état du système pour les administrateurs.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        if not request.user.is_staff:
            return Response({'detail': 'Accès réservé aux administrateurs.'}, status=status.HTTP_403_FORBIDDEN)

        total_blacklisted = BlacklistedNumber.objects.count()
        total_blocked = BlacklistedNumber.objects.filter(is_blocked=True).count()
        total_whitelisted = BlacklistedNumber.objects.filter(is_whitelisted=True).count()
        total_reports = SpamReport.objects.count()
        total_safe_reports = SafeReport.objects.count()
        total_auto_consensus = BlacklistedNumber.objects.filter(whitelist_reason='auto_consensus').count()
        total_users = User.objects.count()

        recent_reports = []
        for r in SpamReport.objects.order_by('-created_at')[:15]:
            num_obj = BlacklistedNumber.objects.filter(phone_hash=r.phone_hash).first()
            recent_reports.append({
                'id': str(r.id),
                'phone_hash': r.phone_hash,
                'masked_number': (num_obj.masked_number if num_obj and num_obj.masked_number else 'Inconnu'),
                'category': r.category,
                'risk_score': num_obj.risk_score if num_obj else 0,
                'is_whitelisted': num_obj.is_whitelisted if num_obj else False,
                'whitelist_reason': num_obj.whitelist_reason if num_obj else '',
                'is_blocked': num_obj.is_blocked if num_obj else True,
                'created_at': r.created_at.isoformat(),
            })

        return Response({
            'total_blacklisted': total_blacklisted,
            'total_blocked': total_blocked,
            'total_whitelisted': total_whitelisted,
            'total_safe_reports': total_safe_reports,
            'total_auto_consensus': total_auto_consensus,
            'total_reports': total_reports,
            'total_users': total_users,
            'recent_reports': recent_reports,
        })

class AdminModerateView(APIView):
    """
    POST /api/v1/admin/moderate/
    Permet à l'administrateur de blanchir (whitelist) ou bloquer un numéro à distance.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        if not request.user.is_staff:
            return Response({'detail': 'Accès réservé aux administrateurs.'}, status=status.HTTP_403_FORBIDDEN)

        phone_hash = request.data.get('phone_hash')
        action = request.data.get('action')  # 'whitelist' ou 'block'

        if not phone_hash or action not in ['whitelist', 'block']:
            return Response({'detail': 'Paramètres invalides (phone_hash et action: whitelist|block requis).'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            entry = BlacklistedNumber.objects.get(phone_hash=phone_hash)
            if action == 'whitelist':
                entry.is_whitelisted = True
                entry.is_blocked = False
                entry.risk_score = 0
                entry.whitelist_reason = 'manual_admin'
                entry.save()
                AuditLog.objects.create(user=request.user, action=AuditLogAction.WHITELIST_UNBLOCK, details=f'Numéro blanchi: {entry.masked_number or phone_hash[:10]}', target_hash=phone_hash, source='MOBILE_ADMIN')
                return Response({'detail': f'Numéro {entry.masked_number or phone_hash[:8]} blanchi avec succès (décision admin).'})
            elif action == 'block':
                entry.is_blocked = True
                entry.is_whitelisted = False
                entry.whitelist_reason = ''
                if entry.risk_score < 50:
                    entry.risk_score = 75
                entry.save()
                AuditLog.objects.create(user=request.user, action=AuditLogAction.APPROVE_BLOCK, details=f'Numéro bloqué: {entry.masked_number or phone_hash[:10]}', target_hash=phone_hash, source='MOBILE_ADMIN')
                return Response({'detail': f'Numéro {entry.masked_number or phone_hash[:8]} bloqué avec succès.'})
        except BlacklistedNumber.DoesNotExist:
            return Response({'detail': 'Numéro introuvable.'}, status=status.HTTP_404_NOT_FOUND)

class AdminBlacklistManagerView(APIView):
    """
    GET /api/v1/admin/blacklist/ : Liste complète filtrable et consultable de tous les numéros.
    POST /api/v1/admin/blacklist/ : Ajout direct d'un numéro par l'administrateur.
    """
    permission_classes = [IsAdminStaffUser]

    def get(self, request):
        qs = BlacklistedNumber.objects.all().order_by('-updated_at')
        search = request.query_params.get('q', '').strip()
        filt = request.query_params.get('filter', 'all').lower()
        category = request.query_params.get('category', '').strip()

        if search:
            qs = qs.filter(models.Q(masked_number__icontains=search) | models.Q(phone_hash__icontains=search))
        if filt == 'blocked':
            qs = qs.filter(is_blocked=True, is_whitelisted=False)
        elif filt == 'whitelisted':
            qs = qs.filter(is_whitelisted=True)
        elif filt == 'auto_consensus':
            qs = qs.filter(whitelist_reason='auto_consensus')
        if category:
            qs = qs.filter(category=category)

        return Response(BlacklistedNumberSerializer(qs[:100], many=True).data)

    def post(self, request):
        raw_number = request.data.get('phone_number')
        phone_hash = request.data.get('phone_hash')
        category = request.data.get('category', 'fraud')
        risk_score = int(request.data.get('risk_score', 75))
        is_blocked = request.data.get('is_blocked', True)
        is_whitelisted = request.data.get('is_whitelisted', False)

        if raw_number:
            phone_hash = hash_phone_number(raw_number)
            masked_number = mask_phone_number(raw_number)
        elif phone_hash:
            masked_number = request.data.get('masked_number', f"+1 *** **{phone_hash[-2:]}")
        else:
            return Response({'detail': 'phone_number ou phone_hash requis.'}, status=status.HTTP_400_BAD_REQUEST)

        obj, created = BlacklistedNumber.objects.update_or_create(
            phone_hash=phone_hash,
            defaults={
                'masked_number': masked_number,
                'category': category,
                'risk_score': risk_score,
                'is_blocked': is_blocked,
                'is_whitelisted': is_whitelisted,
            }
        )
        AuditLog.objects.create(
            user=request.user,
            action=AuditLogAction.MANUAL_ADD,
            details=f"Numéro {masked_number} ajouté/modifié manuellement (catégorie: {category}, score: {risk_score})",
            target_hash=phone_hash,
            source='MOBILE_ADMIN'
        )
        return Response(BlacklistedNumberSerializer(obj).data, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)

class AdminBlacklistDetailView(APIView):
    """
    DELETE /api/v1/admin/blacklist/<phone_hash>/ : Suppression définitive d'un numéro.
    """
    permission_classes = [IsAdminStaffUser]

    def delete(self, request, phone_hash):
        try:
            entry = BlacklistedNumber.objects.get(phone_hash=phone_hash)
            masked = entry.masked_number or phone_hash[:10]
            entry.delete()
            AuditLog.objects.create(
                user=request.user,
                action=AuditLogAction.DELETE_NUMBER,
                details=f"Suppression définitive du numéro: {masked}",
                target_hash=phone_hash,
                source='MOBILE_ADMIN'
            )
            return Response({'detail': f'Numéro supprimé de la liste noire.'})
        except BlacklistedNumber.DoesNotExist:
            return Response({'detail': 'Numéro introuvable.'}, status=status.HTTP_404_NOT_FOUND)

class AdminUsersListView(APIView):
    """
    GET /api/v1/admin/users/ : Liste tous les utilisateurs inscrits.
    """
    permission_classes = [IsAdminStaffUser]

    def get(self, request):
        users = User.objects.all().order_by('-date_joined')
        data = []
        for u in users:
            reports_count = SpamReport.objects.filter(reporter=u).count()
            data.append({
                'id': u.id,
                'email': u.email,
                'username': u.username,
                'name': f"{u.first_name} {u.last_name}".strip() or u.username,
                'is_staff': u.is_staff,
                'is_active': u.is_active,
                'date_joined': u.date_joined.isoformat(),
                'reports_count': reports_count,
            })
        return Response(data)

class AdminReportsListView(APIView):
    """
    GET /api/v1/admin/reports/ : Liste tous les signalements utilisateurs.
    DELETE /api/v1/admin/reports/<report_id>/ : Suppression d'un signalement.
    """
    permission_classes = [IsAdminStaffUser]

    def get(self, request):
        reports = SpamReport.objects.all().order_by('-created_at')[:50]
        data = []
        for r in reports:
            num = BlacklistedNumber.objects.filter(phone_hash=r.phone_hash).first()
            data.append({
                'id': str(r.id),
                'phone_hash': r.phone_hash,
                'masked_number': num.masked_number if num and num.masked_number else 'Inconnu',
                'category': r.category,
                'comment': r.comment or '',
                'created_at': r.created_at.isoformat(),
                'reporter_email': r.reporter.email if r.reporter else 'Anonyme',
                'risk_score': num.risk_score if num else 0,
                'is_whitelisted': num.is_whitelisted if num else False,
                'whitelist_reason': num.whitelist_reason if num else '',
            })
        return Response(data)

    def delete(self, request, report_id):
        try:
            report = SpamReport.objects.get(id=report_id)
            target_hash = report.phone_hash
            report.delete()
            AuditLog.objects.create(
                user=request.user,
                action=AuditLogAction.DELETE_REPORT,
                details=f"Suppression du signalement ID {report_id} pour {target_hash[:10]}",
                target_hash=target_hash,
                source='MOBILE_ADMIN'
            )
            return Response({'detail': 'Signalement supprimé avec succès.'})
        except SpamReport.DoesNotExist:
            return Response({'detail': 'Signalement introuvable.'}, status=status.HTTP_404_NOT_FOUND)

class AdminPurgeJunkView(APIView):
    """
    POST /api/v1/admin/purge/ : Nettoie et purge les faux spams et orphelins (>30j).
    """
    permission_classes = [IsAdminStaffUser]

    def post(self, request):
        purged = DatabaseSanitizerService.purge_obsolete_and_unverified_junk()
        AuditLog.objects.create(
            user=request.user,
            action=AuditLogAction.PURGE_DATABASE,
            details=f"Purge automatique de {purged} enregistrement(s) obsolète(s)",
            source='MOBILE_ADMIN'
        )
        return Response({
            'purged_count': purged,
            'detail': f"{purged} enregistrement(s) obsolète(s) nettoyé(s) avec succès."
        })

class AdminConsensusAuditView(APIView):
    """
    POST /api/v1/admin/consensus-audit/ : Audit et réévaluation automatique des faux positifs par consensus.
    """
    permission_classes = [IsAdminStaffUser]

    def post(self, request):
        audit_res = FalsePositiveConsensusService.run_consensus_audit()
        AuditLog.objects.create(
            user=request.user,
            action=AuditLogAction.WHITELIST_UNBLOCK,
            details=f"Audit global de consensualité : {audit_res['auto_whitelisted_count']} faux positif(s) réhabilité(s)",
            source='AUTO_CONSENSUS'
        )
        return Response({
            'detail': f"{audit_res['auto_whitelisted_count']} faux positif(s) réhabilité(s) automatiquement par consensus.",
            'candidates_audited': audit_res['candidates_audited'],
            'auto_whitelisted_count': audit_res['auto_whitelisted_count'],
            'auto_whitelisted_hashes': audit_res['auto_whitelisted_hashes'],
        })

class HealthCheckView(APIView):
    """
    GET /api/v1/health/
    Sonde de disponibilité et de santé système (Liveness & Readiness Probe).
    Vérifie la connectivité base de données, les métriques d'exploitation et le statut.
    Permet à Docker, Kubernetes ou aux outils de supervision d'assurer la haute disponibilité.
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        from django.db import connection
        health_data = {
            'status': 'healthy',
            'timestamp': timezone.now().isoformat(),
            'version': '1.0.0',
            'components': {}
        }
        http_code = status.HTTP_200_OK

        # 1. Vérification connectivité BDD
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1;")
                cursor.fetchone()
            health_data['components']['database'] = {
                'status': 'up',
                'engine': connection.vendor,
            }
        except Exception as e:
            health_data['status'] = 'unhealthy'
            health_data['components']['database'] = {
                'status': 'down',
                'error': str(e),
            }
            http_code = status.HTTP_503_SERVICE_UNAVAILABLE

        # 2. Métriques d'exploitation
        if http_code == status.HTTP_200_OK:
            health_data['components']['metrics'] = {
                'active_blacklist_count': BlacklistedNumber.objects.filter(is_blocked=True, is_whitelisted=False, risk_score__gte=30).count(),
                'total_spam_reports': SpamReport.objects.count(),
                'total_safe_reports': SafeReport.objects.count(),
                'auto_consensus_count': BlacklistedNumber.objects.filter(whitelist_reason='auto_consensus').count(),
                'audit_logs_count': AuditLog.objects.count(),
            }

        return Response(health_data, status=http_code)

class AdminSafeReportsListView(APIView):
    """
    GET /api/v1/admin/safe-reports/ : Liste tous les avis favorables / contestations soumis.
    """
    permission_classes = [IsAdminStaffUser]

    def get(self, request):
        reports = SafeReport.objects.all().order_by('-created_at')[:50]
        data = []
        for r in reports:
            num = BlacklistedNumber.objects.filter(phone_hash=r.phone_hash).first()
            data.append({
                'id': str(r.id),
                'phone_hash': r.phone_hash,
                'masked_number': num.masked_number if num and num.masked_number else 'Inconnu',
                'reason': r.reason,
                'comment': r.comment or '',
                'created_at': r.created_at.isoformat(),
                'reporter_email': r.reporter.email if r.reporter else 'Anonyme',
                'is_whitelisted': num.is_whitelisted if num else False,
                'whitelist_reason': num.whitelist_reason if num else '',
            })
        return Response(data)






# ==============================================================================
# SIGNAUX DJANGO : INVALIDATION AUTOMATIQUE DU CACHE MEMOIRE
# ==============================================================================
@receiver([post_save, post_delete], sender=BlacklistedNumber)
def invalidate_blacklist_cache(sender, **kwargs):
    cache.clear()

@receiver([post_save, post_delete], sender=SpamReport)
def invalidate_report_cache(sender, **kwargs):
    cache.clear()


# ==============================================================================
# STATUT DE SYNCHRONISATION & BROADCAST
# ==============================================================================
class SyncStatusView(APIView):
    """
    GET /api/v1/sync/status/
    Endpoint ultra-rapide permettant au mobile de vérifier si la liste noire a changé.
    """
    permission_classes = [HasAPIKeyOrAuthenticated]

    def get(self, request):
        latest = BlacklistedNumber.objects.order_by('-updated_at').first()
        total_active = BlacklistedNumber.objects.filter(is_blocked=True, is_whitelisted=False, risk_score__gte=30).count()
        return Response({
            'last_modified': latest.updated_at.isoformat() if latest else timezone.now().isoformat(),
            'total_active': total_active,
            'server_time': timezone.now().isoformat(),
        })

# ==============================================================================
# JOURNAL D'AUDIT ET TRAÇABILITÉ (ADMINISTRATION)
# ==============================================================================
class AdminAuditLogsListView(APIView):
    """
    GET /api/v1/admin/audit-logs/
    Liste chronologique des actions d'administration (Web & Mobile).
    """
    permission_classes = [IsAdminStaffUser]

    def get(self, request):
        page = int(request.query_params.get('page', 1))
        limit = int(request.query_params.get('limit', 50))
        offset = (page - 1) * limit

        logs = AuditLog.objects.all().select_related('user')[offset:offset + limit]
        serializer = AuditLogSerializer(logs, many=True)
        total = AuditLog.objects.count()
        return Response({
            'results': serializer.data,
            'total': total,
            'page': page,
            'has_more': (offset + limit) < total,
        })
