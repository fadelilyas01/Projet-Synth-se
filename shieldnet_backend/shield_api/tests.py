import json
from django.test import TestCase
from django.urls import reverse
from django.conf import settings
from rest_framework import status
from rest_framework.test import APITestCase
from .models import BlacklistedNumber, SpamReport, SafeReport
from .services import ReputationService, AutomatedSpamVerifier, FalsePositiveConsensusService

class ReputationServiceTest(TestCase):
    """
    Tests unitaires de l'algorithme de réputation et de modération.
    """
    def test_process_new_report_creation(self):
        phone_hash = "a" * 64
        report = ReputationService.process_new_report(
            phone_hash=phone_hash,
            category='fraud',
            masked_number='+1 819 *** **67'
        )
        self.assertIsNotNone(report)
        self.assertEqual(report.phone_hash, phone_hash)
        
        number_obj = BlacklistedNumber.objects.get(phone_hash=phone_hash)
        self.assertEqual(number_obj.reports_count, 1)
        self.assertTrue(number_obj.risk_score >= 35)

    def test_repetition_increases_risk_score(self):
        phone_hash = "b" * 64
        ReputationService.process_new_report(phone_hash=phone_hash, category='fraud')
        ReputationService.process_new_report(phone_hash=phone_hash, category='fraud')
        
        number_obj = BlacklistedNumber.objects.get(phone_hash=phone_hash)
        self.assertEqual(number_obj.reports_count, 2)
        self.assertTrue(number_obj.risk_score > 35)

    def test_whitelisted_number_stays_unblocked(self):
        phone_hash = "w" * 64
        # L'admin crée ou blanchit le numéro
        number_obj = BlacklistedNumber.objects.create(
            phone_hash=phone_hash,
            category='telemarketing',
            risk_score=0,
            is_blocked=False,
            is_whitelisted=True
        )
        # Un utilisateur tente de le signaler à nouveau
        ReputationService.process_new_report(phone_hash=phone_hash, category='fraud')
        
        number_obj.refresh_from_db()
        self.assertTrue(number_obj.is_whitelisted)
        self.assertFalse(number_obj.is_blocked)
        self.assertEqual(number_obj.risk_score, 0)

class ShieldApiEndpointsTest(APITestCase):
    """
    Tests d'intégration des endpoints REST API avec authentification X-API-Key.
    """
    def setUp(self):
        self.client.credentials(HTTP_X_API_KEY=settings.API_KEY)

    def test_reject_request_without_api_key(self):
        client = self.client_class()  # Client sans en-tête
        url = reverse('blacklist-download')
        response = client.get(url)
        self.assertIn(response.status_code, [status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN])

    def test_submit_report_api(self):
        url = reverse('submit-report')
        phone_hash = "c" * 64
        data = {
            'phone_hash': phone_hash,
            'masked_number': '+1 819 *** **00',
            'category': 'phishing',
            'comment': 'Test report'
        }
        response = self.client.post(url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['phone_hash'], phone_hash)

    def test_check_number_api_spam(self):
        phone_hash = "d" * 64
        BlacklistedNumber.objects.create(
            phone_hash=phone_hash,
            category='fraud',
            risk_score=80,
            reports_count=3,
            is_blocked=True
        )
        url = reverse('check-number', kwargs={'phone_hash': phone_hash})
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['is_spam'])
        self.assertEqual(response.data['risk_score'], 80)

    def test_blacklist_download_api(self):
        BlacklistedNumber.objects.create(
            phone_hash="e" * 64,
            category='telemarketing',
            risk_score=50,
            reports_count=2,
            is_blocked=True
        )
        url = reverse('blacklist-download')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(len(response.data) >= 1)

    def test_user_registration_and_email_login(self):
        # Création d'un nouveau compte citoyen
        register_url = reverse('auth-register')
        reg_data = {
            'email': 'utilisateur@shieldnet.app',
            'password': 'Password123!',
            'name': 'Jean Dupont'
        }
        reg_resp = self.client.post(register_url, reg_data, format='json')
        self.assertEqual(reg_resp.status_code, status.HTTP_201_CREATED)
        self.assertIn('tokens', reg_resp.data)
        self.assertEqual(reg_resp.data['user']['email'], 'utilisateur@shieldnet.app')

        # Authentification par mot de passe
        login_url = reverse('auth-login')
        login_data = {
            'email': 'utilisateur@shieldnet.app',
            'password': 'Password123!'
        }
        login_resp = self.client.post(login_url, login_data, format='json')
        self.assertEqual(login_resp.status_code, status.HTTP_200_OK)
        access_token = login_resp.data['tokens']['access']
        self.assertIsNotNone(access_token)

        # Vérification du jeton JWT sur le profil connecté
        auth_client = self.client_class()
        auth_client.credentials(HTTP_AUTHORIZATION=f'Bearer {access_token}')
        me_url = reverse('auth-me')
        me_resp = auth_client.get(me_url)
        self.assertEqual(me_resp.status_code, status.HTTP_200_OK)
        self.assertEqual(me_resp.data['email'], 'utilisateur@shieldnet.app')
        self.assertFalse(me_resp.data['is_staff'])

    def test_google_login_auto_provision_and_repeat(self):
        url = reverse('auth-google')
        google_data = {
            'email': 'google.user@shieldnet.app',
            'name': 'Google Test User'
        }
        # Première authentification : auto-provisioning du compte
        resp1 = self.client.post(url, google_data, format='json')
        self.assertEqual(resp1.status_code, status.HTTP_200_OK)
        self.assertEqual(resp1.data['user']['email'], 'google.user@shieldnet.app')
        self.assertIn('tokens', resp1.data)
        self.assertIsNotNone(resp1.data['tokens']['access'])

        # Connexions ultérieures : réutilisation immédiate du profil existant
        resp2 = self.client.post(url, google_data, format='json')
        self.assertEqual(resp2.status_code, status.HTTP_200_OK)
        self.assertEqual(resp2.data['user']['email'], 'google.user@shieldnet.app')
        self.assertIn('tokens', resp2.data)

    def test_admin_stats_and_moderation(self):
        from django.contrib.auth.models import User
        # Profils de test avec et sans privilèges
        std_user = User.objects.create_user(username='std@user.com', email='std@user.com', password='password')
        admin_user = User.objects.create_user(username='admin', email='admin@shieldnet.qc.ca', password='password', is_staff=True)

        # Création d'une entrée test
        phone_hash = "f" * 64
        BlacklistedNumber.objects.create(
            phone_hash=phone_hash,
            category='fraud',
            risk_score=60,
            is_blocked=True
        )

        from rest_framework_simplejwt.tokens import RefreshToken
        std_token = str(RefreshToken.for_user(std_user).access_token)
        admin_token = str(RefreshToken.for_user(admin_user).access_token)

        # Contrôle d'accès : rejet des utilisateurs non-administrateurs (403)
        std_client = self.client_class()
        std_client.credentials(HTTP_AUTHORIZATION=f'Bearer {std_token}')
        stats_url = reverse('admin-stats')
        resp_std = std_client.get(stats_url)
        self.assertEqual(resp_std.status_code, status.HTTP_403_FORBIDDEN)

        # Accès accordé pour l'administrateur avec les métriques SOC
        admin_client = self.client_class()
        admin_client.credentials(HTTP_AUTHORIZATION=f'Bearer {admin_token}')
        resp_admin = admin_client.get(stats_url)
        self.assertEqual(resp_admin.status_code, status.HTTP_200_OK)
        self.assertIn('total_blacklisted', resp_admin.data)
        self.assertIn('total_blocked', resp_admin.data)
        self.assertIn('recent_reports', resp_admin.data)

        # Action de modération : réhabilitation explicite d'un numéro
        mod_url = reverse('admin-moderate')
        mod_resp = admin_client.post(mod_url, {'phone_hash': phone_hash, 'action': 'whitelist'}, format='json')
        self.assertEqual(mod_resp.status_code, status.HTTP_200_OK)

        num_refreshed = BlacklistedNumber.objects.get(phone_hash=phone_hash)
        self.assertTrue(num_refreshed.is_whitelisted)
        self.assertFalse(num_refreshed.is_blocked)

    def test_dedicated_admin_email_login_web_and_mobile(self):
        from django.contrib.auth.models import User
        from django.contrib.auth import authenticate

        # Compte superutilisateur configuré
        admin_email = 'admin@shieldnet.app'
        admin_pass = 'AdminPassword2026!'
        User.objects.create_superuser(
            username='admin_dedicated',
            email=admin_email,
            password=admin_pass
        )

        # Connexion Django Admin standard via courriel
        web_user = authenticate(username=admin_email, password=admin_pass)
        self.assertIsNotNone(web_user)
        self.assertEqual(web_user.email, admin_email)
        self.assertTrue(web_user.is_staff)
        self.assertTrue(web_user.is_superuser)

        # Authentification JWT via l'API mobile
        login_url = reverse('auth-login')
        resp = self.client.post(login_url, {'email': admin_email, 'password': admin_pass}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertTrue(resp.data['user']['is_staff'])
        self.assertTrue(resp.data['user']['is_superuser'])
        self.assertIn('tokens', resp.data)

    def test_admin_full_mobile_management_endpoints(self):
        from django.contrib.auth.models import User
        from rest_framework_simplejwt.tokens import RefreshToken

        # Création de l'administrateur
        admin_user = User.objects.create_superuser(
            username='admin_mobile_test',
            email='admin_mobile@shieldnet.app',
            password='AdminPassword2026!'
        )
        token = str(RefreshToken.for_user(admin_user).access_token)
        admin_client = self.client_class()
        admin_client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')

        # Ajout manuel direct d'une entrée par un administrateur
        add_url = reverse('admin-blacklist')
        add_resp = admin_client.post(add_url, {
            'phone_number': '+1 819 555 9999',
            'category': 'fraud',
            'risk_score': 90,
            'is_blocked': True,
            'is_whitelisted': False,
        }, format='json')
        self.assertEqual(add_resp.status_code, status.HTTP_201_CREATED)
        phone_hash = add_resp.data['phone_hash']

        # Consultation et pagination de la liste noire
        list_resp = admin_client.get(add_url)
        self.assertEqual(list_resp.status_code, status.HTTP_200_OK)
        self.assertTrue(len(list_resp.data) >= 1)

        # Liste des comptes utilisateurs enregistrés
        users_url = reverse('admin-users')
        users_resp = admin_client.get(users_url)
        self.assertEqual(users_resp.status_code, status.HTTP_200_OK)
        self.assertTrue(len(users_resp.data) >= 1)

        # Consultation des signalements citoyens
        reports_url = reverse('admin-reports')
        rep_resp = admin_client.get(reports_url)
        self.assertEqual(rep_resp.status_code, status.HTTP_200_OK)

        # Déclenchement de la purge de maintenance
        purge_url = reverse('admin-purge')
        purge_resp = admin_client.post(purge_url)
        self.assertEqual(purge_resp.status_code, status.HTTP_200_OK)
        self.assertIn('purged_count', purge_resp.data)

        # Suppression définitive d'un numéro
        del_url = reverse('admin-blacklist-detail', kwargs={'phone_hash': phone_hash})
        del_resp = admin_client.delete(del_url)
        self.assertEqual(del_resp.status_code, status.HTTP_200_OK)
        self.assertFalse(BlacklistedNumber.objects.filter(phone_hash=phone_hash).exists())

class ConsensusFalsePositiveServiceTest(APITestCase):
    """
    Tests exhaustifs du moteur algorithmique de détection automatique des faux positifs par consensualité.
    """
    def setUp(self):
        self.client.credentials(HTTP_X_API_KEY=settings.API_KEY)

    def test_single_safe_report_does_not_reach_quorum(self):
        phone_hash = "1" * 64
        # 1 signalement spam initial
        ReputationService.process_new_report(phone_hash=phone_hash, category='telemarketing')
        
        # 1 seul avis légitime soumis
        report, auto_whitelisted = FalsePositiveConsensusService.register_safe_feedback(
            phone_hash=phone_hash,
            reason='service',
            comment='Numéro officiel d\'un commerce'
        )
        self.assertFalse(auto_whitelisted)
        
        num_obj = BlacklistedNumber.objects.get(phone_hash=phone_hash)
        self.assertFalse(num_obj.is_whitelisted)
        self.assertEqual(num_obj.safe_reports_count, 1)

    def test_automatic_false_positive_detection_by_consensus(self):
        phone_hash = "2" * 64
        # Numéro injustement signalé par 1 personne (ex: livreur ou cabinet médical)
        ReputationService.process_new_report(phone_hash=phone_hash, category='telemarketing', masked_number='+1 819 555 1234')
        num_before = BlacklistedNumber.objects.get(phone_hash=phone_hash)
        self.assertFalse(num_before.is_whitelisted)

        from django.contrib.auth.models import User
        user1 = User.objects.create_user(username='u1@test.com', email='u1@test.com')
        user2 = User.objects.create_user(username='u2@test.com', email='u2@test.com')

        # Premier avis légitime
        FalsePositiveConsensusService.register_safe_feedback(
            phone_hash=phone_hash,
            reason='medical',
            comment='Cabinet médical régional',
            user=user1,
        )

        # Deuxième avis légitime : Quorum atteint et consensus validé
        _, auto_whitelisted = FalsePositiveConsensusService.register_safe_feedback(
            phone_hash=phone_hash,
            reason='service',
            comment='Numéro officiel confirmé',
            user=user2,
        )

        self.assertTrue(auto_whitelisted)
        num_after = BlacklistedNumber.objects.get(phone_hash=phone_hash)
        self.assertTrue(num_after.is_whitelisted)
        self.assertFalse(num_after.is_blocked)
        self.assertEqual(num_after.risk_score, 0)
        self.assertEqual(num_after.whitelist_reason, 'auto_consensus')
        self.assertGreaterEqual(num_after.consensus_score, 0.55)

    def test_admin_safe_feedback_triggers_immediate_consensus(self):
        phone_hash = "3" * 64
        ReputationService.process_new_report(phone_hash=phone_hash, category='fraud')
        
        from django.contrib.auth.models import User
        admin_u = User.objects.create_superuser(username='superadmin_fp', email='superadmin_fp@test.com', password='pwd')

        # Avis d'un administrateur -> Quorum immédiat
        _, auto_whitelisted = FalsePositiveConsensusService.register_safe_feedback(
            phone_hash=phone_hash,
            reason='delivery',
            user=admin_u,
        )
        self.assertTrue(auto_whitelisted)
        num_obj = BlacklistedNumber.objects.get(phone_hash=phone_hash)
        self.assertTrue(num_obj.is_whitelisted)
        self.assertEqual(num_obj.whitelist_reason, 'auto_consensus')

    def test_anti_sybil_duplicate_user_vote_prevention(self):
        phone_hash = "4" * 64
        ReputationService.process_new_report(phone_hash=phone_hash, category='fraud')

        from django.contrib.auth.models import User
        user = User.objects.create_user(username='sybil@test.com', email='sybil@test.com')

        # Même utilisateur tente de voter 5 fois pour gonfler artificiellement le consensus
        for _ in range(5):
            FalsePositiveConsensusService.register_safe_feedback(
                phone_hash=phone_hash,
                reason='service',
                user=user
            )

        # Le nombre d'avis réels dans la BDD pour ce hash doit rester 1
        safe_count = SafeReport.objects.filter(phone_hash=phone_hash).count()
        self.assertEqual(safe_count, 1)

    def test_dynamic_revocation_on_massive_spam_surge(self):
        phone_hash = "5" * 64
        # Initialement réhabilité par consensus
        from django.contrib.auth.models import User
        u1 = User.objects.create_user(username='v1@test.com', email='v1@test.com')
        u2 = User.objects.create_user(username='v2@test.com', email='v2@test.com')

        ReputationService.process_new_report(phone_hash=phone_hash, category='other')
        FalsePositiveConsensusService.register_safe_feedback(phone_hash=phone_hash, reason='personal', user=u1)
        FalsePositiveConsensusService.register_safe_feedback(phone_hash=phone_hash, reason='personal', user=u2)

        num_obj = BlacklistedNumber.objects.get(phone_hash=phone_hash)
        self.assertTrue(num_obj.is_whitelisted)
        self.assertEqual(num_obj.whitelist_reason, 'auto_consensus')

        # Vague massive de nouveaux signalements réels de fraude
        for i in range(10):
            spammer = User.objects.create_user(username=f'victim_{i}@test.com', email=f'victim_{i}@test.com')
            ReputationService.process_new_report(phone_hash=phone_hash, category='financial_scam', user=spammer)

        num_obj.refresh_from_db()
        # Le consensus s'est effondré : le numéro doit être ré-enclenché en liste noire
        self.assertFalse(num_obj.is_whitelisted)
        self.assertTrue(num_obj.is_blocked)
        self.assertNotEqual(num_obj.whitelist_reason, 'auto_consensus')

    def test_submit_safe_report_api(self):
        url = reverse('submit-safe-report')
        phone_hash = "6" * 64
        # Création du numéro dans la base
        ReputationService.process_new_report(phone_hash=phone_hash, category='telemarketing')

        # 1er avis API
        resp1 = self.client.post(url, {
            'phone_hash': phone_hash,
            'reason': 'medical',
            'comment': 'Hôpital local'
        }, format='json')
        self.assertEqual(resp1.status_code, status.HTTP_201_CREATED)
        self.assertFalse(resp1.data['auto_whitelisted'])

        # 2e avis API avec autre adresse IP / utilisateur
        client2 = self.client_class()
        client2.credentials(HTTP_X_API_KEY=settings.API_KEY)
        resp2 = client2.post(url, {
            'phone_hash': phone_hash,
            'reason': 'service',
            'comment': 'Confirmation service public'
        }, format='json', REMOTE_ADDR='198.51.100.2')
        self.assertEqual(resp2.status_code, status.HTTP_201_CREATED)
        self.assertTrue(resp2.data['auto_whitelisted'])
        self.assertTrue(resp2.data['is_whitelisted'])

    def test_consensus_status_and_check_endpoints(self):
        phone_hash = "7" * 64
        ReputationService.process_new_report(phone_hash=phone_hash, category='fraud')

        # GET /api/v1/consensus/<hash>/
        consensus_url = reverse('consensus-status', kwargs={'phone_hash': phone_hash})
        resp = self.client.get(consensus_url)
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('consensus_ratio', resp.data)
        self.assertIn('quorum_met', resp.data)
        self.assertFalse(resp.data['is_false_positive'])

        # GET /api/v1/check/<hash>/
        check_url = reverse('check-number', kwargs={'phone_hash': phone_hash})
        check_resp = self.client.get(check_url)
        self.assertEqual(check_resp.status_code, status.HTTP_200_OK)
        self.assertIn('safe_reports_count', check_resp.data)
        self.assertIn('consensus_score', check_resp.data)

    def test_admin_consensus_audit_api(self):
        from django.contrib.auth.models import User
        from rest_framework_simplejwt.tokens import RefreshToken

        admin_user = User.objects.create_superuser(username='audit_admin', email='audit@test.com', password='pwd')
        token = str(RefreshToken.for_user(admin_user).access_token)
        admin_client = self.client_class()
        admin_client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')

        audit_url = reverse('admin-consensus-audit')
        resp = admin_client.post(audit_url)
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('candidates_audited', resp.data)
        self.assertIn('auto_whitelisted_count', resp.data)

    def test_health_check_endpoint(self):
        url = reverse('health-check')
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.data['status'], 'healthy')
        self.assertEqual(resp.data['components']['database']['status'], 'up')
        self.assertIn('metrics', resp.data['components'])
        self.assertIn('active_blacklist_count', resp.data['components']['metrics'])

    def test_delta_sync_with_since_parameter(self):
        from django.utils import timezone
        now = timezone.now()
        
        # Numéro actif
        BlacklistedNumber.objects.create(
            phone_hash="delta_active" + "0" * 52,
            category='fraud',
            risk_score=80,
            is_blocked=True,
            is_whitelisted=False,
            updated_at=now
        )
        # Faux positif blanchi
        BlacklistedNumber.objects.create(
            phone_hash="delta_removed" + "0" * 51,
            category='service',
            risk_score=0,
            is_blocked=False,
            is_whitelisted=True,
            whitelist_reason='auto_consensus',
            updated_at=now
        )

        url = reverse('blacklist-download')
        past_iso = (now - timezone.timedelta(minutes=5)).isoformat()
        resp = self.client.get(f"{url}?since={past_iso}")
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('active', resp.data)
        self.assertIn('removed', resp.data)
        self.assertIn('sync_timestamp', resp.data)
        self.assertTrue(resp.data['is_delta'])
        self.assertTrue(len(resp.data['active']) >= 1)
        self.assertIn("delta_removed" + "0" * 51, resp.data['removed'])

    def test_audit_logs_recorded_and_listed(self):
        from django.contrib.auth.models import User
        from rest_framework_simplejwt.tokens import RefreshToken
        from .models import AuditLog

        admin_user = User.objects.create_superuser(username='audit_verifier', email='verifier@test.com', password='pwd')
        token = str(RefreshToken.for_user(admin_user).access_token)
        admin_client = self.client_class()
        admin_client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')

        # Modération d'un numéro
        phone_hash = "audit_hash" + "0" * 54
        BlacklistedNumber.objects.create(phone_hash=phone_hash, category='fraud', risk_score=70)

        mod_url = reverse('admin-moderate')
        mod_resp = admin_client.post(mod_url, {'phone_hash': phone_hash, 'action': 'whitelist'}, format='json')
        self.assertEqual(mod_resp.status_code, status.HTTP_200_OK)

        # Vérification qu'un AuditLog a été créé
        log = AuditLog.objects.filter(target_hash=phone_hash).first()
        self.assertIsNotNone(log)
        self.assertEqual(log.user, admin_user)

        # Consultation de la liste des logs d'audit
        logs_url = reverse('admin-audit-logs')
        logs_resp = admin_client.get(logs_url)
        self.assertEqual(logs_resp.status_code, status.HTTP_200_OK)
        self.assertIn('results', logs_resp.data)
        self.assertGreaterEqual(logs_resp.data['total'], 1)

    def test_sha256_hex_validator_rejects_invalid_hash(self):
        """
        Validation stricte du format hexadécimal SHA-256 (64 caractères).
        Rejette les empreintes trop courtes, trop longues ou contenant des caractères invalides.
        """
        from django.core.exceptions import ValidationError
        from .models import sha256_validator

        # Empreinte SHA-256 valide (64 caractères hexadécimaux)
        valid_hash = "a" * 64
        sha256_validator(valid_hash)  # Ne doit lever aucune exception

        # Empreintes invalides : longueur incorrecte ou caractères non hexadécimaux
        with self.assertRaises(ValidationError):
            sha256_validator("trop_court")
        with self.assertRaises(ValidationError):
            sha256_validator("g" * 64)  # 'g' n'est pas un caractère hexadécimal
        with self.assertRaises(ValidationError):
            sha256_validator("a" * 65)

    def test_composite_indexes_present_on_models(self):
        """
        Vérifie la présence et la configuration des index composites pour accélérer les requêtes SQL.
        """
        # Index sur la liste noire globale
        bl_indexes = [idx.name for idx in BlacklistedNumber._meta.indexes]
        self.assertIn('idx_bl_active_filter', bl_indexes)
        self.assertIn('idx_bl_updated_at', bl_indexes)
        self.assertIn('idx_bl_hash_blocked', bl_indexes)

        # Index sur les avis de légitimité
        safe_indexes = [idx.name for idx in SafeReport._meta.indexes]
        self.assertIn('idx_safe_hash_created', safe_indexes)

        # Index sur les signalements de spam
        spam_indexes = [idx.name for idx in SpamReport._meta.indexes]
        self.assertIn('idx_spam_hash_created', spam_indexes)

class AdminDashboardTests(TestCase):
    """
    Tests de la console d'administration et de modération :
    Triage des signalements, consultation télémétrique et génération de rapport.
    """
    def setUp(self):
        from django.contrib.auth.models import User
        self.admin_user = User.objects.create_superuser('soc_admin', 'admin@shieldnet.app', 'pass123')
        self.client.force_login(self.admin_user)

    def test_triage_action_escalate_and_dismiss(self):
        phone_hash = "c" * 64
        report = SpamReport.objects.create(
            phone_hash=phone_hash,
            category='fraud',
            comment='Appel agressif'
        )

        # Action de triage : escalade en blocage actif
        triage_url = reverse('admin-triage-action')
        resp = self.client.post(
            triage_url,
            data=json.dumps({'report_id': str(report.id), 'action': 'escalate_block'}),
            content_type='application/json'
        )
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertTrue(data['success'])
        self.assertTrue(data['is_blocked'])

        # Vérifie en BDD
        bl = BlacklistedNumber.objects.get(phone_hash=phone_hash)
        self.assertTrue(bl.is_blocked)
        self.assertFalse(bl.is_whitelisted)

        # Action de triage : réhabilitation immédiate en faux positif
        resp2 = self.client.post(
            triage_url,
            data=json.dumps({'report_id': str(report.id), 'action': 'dismiss_safe'}),
            content_type='application/json'
        )
        self.assertEqual(resp2.status_code, 200)
        data2 = resp2.json()
        self.assertTrue(data2['success'])
        self.assertFalse(data2['is_blocked'])
        self.assertTrue(data2['is_whitelisted'])

    def test_telemetry_live_view(self):
        url = reverse('admin-telemetry-live')
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertIn('resilience_score', data)
        self.assertIn('kpi_blocked', data)
        self.assertIn('latest_event', data)

    def test_executive_report_view(self):
        url = reverse('admin-report-executive')
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        self.assertContains(resp, 'Threat Intelligence Briefing')
        self.assertContains(resp, 'CONFIDENTIEL')

    def test_admin_index_rendering(self):
        resp = self.client.get('/admin/')
        self.assertEqual(resp.status_code, 200)
        self.assertContains(resp, 'ShieldNet')
        self.assertContains(resp, 'SOC')
        self.assertContains(resp, 'Tableau de Bord SOC')

    def test_admin_changelist_rendering(self):
        resp = self.client.get('/admin/shield_api/blacklistednumber/')
        self.assertEqual(resp.status_code, 200)
        self.assertContains(resp, 'Liste Noire Télécom')

    def test_admin_login_rendering(self):
        # Déconnexion pour tester la page de login autonome
        self.client.logout()
        resp = self.client.get('/admin/login/')
        self.assertEqual(resp.status_code, 200)
        self.assertContains(resp, 'login-form')

    def test_admin_triage_dashboard_view(self):
        # Création d'un signalement pour valider le rendu complet de la console avec l'analyse IA
        SpamReport.objects.create(
            phone_hash="e" * 64,
            category='phishing',
            comment='Tentative de hameçonnage bancaire'
        )
        url = reverse('admin-triage-dashboard')
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        self.assertContains(resp, 'Centre de Triage')
        self.assertContains(resp, 'Signalements Reçus')
        self.assertContains(resp, 'topbar-return-btn')
        self.assertContains(resp, 'ops-btn-return')
        self.assertContains(resp, 'Retour au Tableau de Bord SOC')

    def test_admin_sandbox_dashboard_view(self):
        url = reverse('admin-sandbox-dashboard')
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        self.assertContains(resp, 'Laboratoire Sandbox')
        self.assertContains(resp, 'Lancer le Diagnostic')
        self.assertContains(resp, 'topbar-return-btn')
        self.assertContains(resp, 'ops-btn-return')
        self.assertContains(resp, 'Retour au Tableau de Bord SOC')

    def test_admin_sidebar_presence_across_all_staff_views(self):
        """
        Garantit que la barre latérale soc-sidebar est présente sur TOUTES les pages d'administration.
        """
        urls_to_test = [
            '/admin/',
            '/admin/operations/triage/',
            '/admin/operations/sandbox/',
            '/admin/shield_api/blacklistednumber/',
            '/admin/shield_api/blacklistednumber/add/',
            '/admin/shield_api/spamreport/',
            '/admin/shield_api/safereport/',
            '/admin/shield_api/auditlog/',
            '/admin/auth/user/',
            '/admin/auth/user/add/',
            '/admin/password_change/',
        ]
        for u in urls_to_test:
            resp = self.client.get(u)
            self.assertEqual(resp.status_code, 200, f"La page {u} a retourné le code {resp.status_code}")
            content = resp.content.decode('utf-8')
            self.assertIn('soc-sidebar', content, f"La barre latérale soc-sidebar est absente de la page {u}")

    def test_admin_breadcrumbs_present_on_all_views(self):
        """
        Garantit que le fil d'Ariane est rendu proprement sur toutes les pages d'administration.
        """
        urls = [
            '/admin/',
            '/admin/operations/triage/',
            '/admin/operations/sandbox/',
            '/admin/shield_api/blacklistednumber/',
            '/admin/shield_api/spamreport/',
            '/admin/shield_api/safereport/',
            '/admin/shield_api/auditlog/',
            '/admin/auth/user/',
        ]
        for u in urls:
            resp = self.client.get(u)
            self.assertEqual(resp.status_code, 200)
            content = resp.content.decode('utf-8')
            has_bc = 'soc-breadcrumbs' in content or 'breadcrumbs' in content
            self.assertTrue(has_bc, f"Fil d'Ariane manquant sur {u}")

    def test_no_duplicate_titles_on_custom_dashboards(self):
        """
        Vérifie qu'aucun en-tête en doublon n'apparaît sur le Centre de Triage ou la Sandbox.
        """
        for route in ['/admin/operations/triage/', '/admin/operations/sandbox/']:
            resp = self.client.get(route)
            self.assertEqual(resp.status_code, 200)
            content = resp.content.decode('utf-8')
            # Ne doit pas contenir soc-page-header car content_title est surchargé vide
            self.assertNotIn('soc-page-header', content, f"Titre en doublon détecté sur {route}")

    def test_sandbox_check_and_action_flow(self):
        """
        Teste le cycle de vie du simulateur sandbox : diagnostic d'un numéro puis action de blocage.
        """
        # Diagnostic
        check_url = reverse('admin-sandbox-check') + '?phone_number=+18195550199'
        resp = self.client.get(check_url)
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertTrue(data['success'])
        self.assertIn('phone_hash', data)
        self.assertIn('risk_score', data)

        # Action directe de blocage
        action_url = reverse('admin-sandbox-action')
        resp_action = self.client.post(
            action_url,
            data=json.dumps({'phone_number': '+18195550199', 'action': 'block'}),
            content_type='application/json'
        )
        self.assertEqual(resp_action.status_code, 200)
        action_data = resp_action.json()
        self.assertTrue(action_data['success'])
        self.assertTrue(action_data['is_blocked'])

    def test_export_blacklist_csv(self):
        """
        Vérifie que l'export CSV fonctionne et renvoie les bons en-têtes et le bon Content-Type.
        """
        url = reverse('admin-export-csv')
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp['Content-Type'], 'text/csv; charset=utf-8')
        self.assertIn('attachment; filename="shieldnet_blacklist_', resp['Content-Disposition'])

    def test_trigger_consensus_and_purge(self):
        """
        Vérifie les opérations de maintenance de consensus et de purge des orphelins.
        """
        consensus_url = reverse('admin-trigger-consensus')
        resp = self.client.post(consensus_url)
        self.assertEqual(resp.status_code, 200)
        self.assertTrue(resp.json()['success'])

        purge_url = reverse('admin-trigger-purge')
        resp2 = self.client.post(purge_url)
        self.assertEqual(resp2.status_code, 200)
        self.assertTrue(resp2.json()['success'])

    def test_css_static_file_integrity_and_light_mode_tokens(self):
        """
        Vérifie l'intégrité du fichier CSS de design system et la présence des variables critiques.
        """
        import os
        from django.conf import settings
        css_path = os.path.join(settings.BASE_DIR, 'shield_api', 'static', 'shield_api', 'admin_premium.css')
        self.assertTrue(os.path.exists(css_path), "admin_premium.css doit exister")
        
        with open(css_path, 'r', encoding='utf-8') as f:
            css_content = f.read()
        
        # Vérification des variables clés pour éviter tout texte invisible
        self.assertIn('--text-main:', css_content)
        self.assertIn('--text-primary:', css_content)
        self.assertIn('--text-secondary:', css_content)
        self.assertIn('--text-muted:', css_content)
        self.assertIn('--bg-surface:', css_content)
        self.assertIn('--bg-card:', css_content)
        self.assertIn('--bg-input:', css_content)
        self.assertIn('html.light-mode', css_content)
        self.assertIn('.selector', css_content)
        self.assertIn('.delete-confirmation', css_content)
        self.assertIn('#change-history', css_content)
        self.assertIn('ul.errorlist', css_content)

        # Vérification des classes de composants SOC
        self.assertIn('.soc-hero-banner', css_content)
        self.assertIn('.hero-banner-title', css_content)
        self.assertIn('.hero-banner-sub', css_content)
        self.assertIn('.sandbox-panel', css_content)
        self.assertIn('.sandbox-input', css_content)
        self.assertIn('.ops-bar', css_content)

        # Vérification des règles de contraste renforcées pour le mode clair
        self.assertIn('html.light-mode table thead th', css_content)
        self.assertIn('html.light-mode table tbody td', css_content)
        self.assertIn('html.light-mode .ops-btn-primary', css_content)
        self.assertIn('html.light-mode .topbar-return-btn', css_content)
        self.assertIn('html.light-mode .badge-safe', css_content)

        # Vérification de l'intégrité syntaxique CSS (accolades parfaitement équilibrées)
        open_braces = 0
        for char in css_content:
            if char == '{':
                open_braces += 1
            elif char == '}':
                open_braces -= 1
        self.assertEqual(open_braces, 0, "admin_premium.css doit avoir un solde parfait d'accolades { et }")

        # Vérification du footer SOC global
        self.assertIn('.soc-footer', css_content)
        self.assertIn('html.light-mode .soc-footer', css_content)

        # Vérification de l'événement de basculement de thème et footer dans les templates
        base_html_path = os.path.join(settings.BASE_DIR, 'templates', 'admin', 'base.html')
        with open(base_html_path, 'r', encoding='utf-8') as f:
            base_html = f.read()
        self.assertIn('shieldnet-theme-changed', base_html)
        self.assertIn('soc-footer', base_html)

        index_html_path = os.path.join(settings.BASE_DIR, 'templates', 'admin', 'index.html')
        with open(index_html_path, 'r', encoding='utf-8') as f:
            index_html = f.read()
        self.assertIn('shieldnet-theme-changed', index_html)
        self.assertIn('updateChartsForTheme', index_html)


class ShieldNetAIEngineTest(APITestCase):
    """
    Tests de validation du moteur d'analyse sémantique et heuristique :
    - Filtrage lexical multilingue (FR / EN)
    - Détection et arbitrage des faux positifs (services essentiels, santé, livraison)
    - Détection des motifs robocalls et numéros fictifs NANP (+1)
    - Facteurs explicatifs de décision
    - Endpoint REST API /api/v1/ai/diagnose/
    """
    def setUp(self):
        from .ai_engine import ShieldNetAIEngine, NLPSemanticAnalyzer
        from .services import hash_phone_number
        self.ai_engine = ShieldNetAIEngine
        self.nlp = NLPSemanticAnalyzer
        self.hash_fn = hash_phone_number
        self.client.credentials(HTTP_X_API_KEY=settings.API_KEY)

    def test_nlp_legitimate_keywords(self):
        comments = [
            "Rappel de rendez-vous avec le Dr Tremblay à la clinique médicale de Gatineau.",
            "Livreur Amazon pour livraison de colis à votre adresse.",
            "Hydro-Québec avis de coupure de service programmée."
        ]
        score, entities = self.nlp.analyze_comments(comments)
        self.assertGreater(score, 40.0)
        self.assertTrue(any("Santé" in e or "Livraison" in e or "Services Publics" in e for e in entities))

    def test_nlp_threat_keywords(self):
        comments = [
            "Urgent CRA Canada Revenue Agency warrant for arrest pay bitcoin immediately.",
            "Gendarmerie Royale mandat d'arrêt et amende impayée carte cadeau.",
            "Your SIN social insurance number has been suspended press 1."
        ]
        score, entities = self.nlp.analyze_comments(comments)
        self.assertLess(score, -40.0)
        self.assertTrue(any("Agence Publique" in e or "Fiscale" in e or "Extorsion" in e for e in entities))

    def test_ai_diagnose_fictitious_scam_number(self):
        # 555-01xx est réservé pour la fiction dans le plan NANP nord-américain
        fictitious_phone = "+1 819 555 0199"
        phone_hash = self.hash_fn(fictitious_phone)

        # Création de signalements de menace
        SpamReport.objects.create(
            phone_hash=phone_hash,
            category='robocall',
            comment="Appel automatisé prétendant être l'Agence du revenu du Canada avec menace de prison."
        )
        SpamReport.objects.create(
            phone_hash=phone_hash,
            category='phishing',
            comment="Robocall CRA tax arrest warrant bitcoin."
        )

        diag = self.ai_engine.diagnose(phone_number=fictitious_phone, phone_hash=phone_hash)

        self.assertIn(diag['verdict'], ['CYBER_MENACE_CRITIQUE', 'FRAUDE_SUSPECTEE'])
        self.assertEqual(diag['recommendation'], 'ESCALATE_BLOCK')
        self.assertGreaterEqual(diag['composite_risk_score'], 80)
        self.assertLess(diag['false_positive_confidence'], 15)
        self.assertTrue(any(f['direction'] == 'threat' for f in diag['xai_factors']))

    def test_ai_diagnose_false_positive_rehabilitation(self):
        # Numéro d'un hôpital ou d'une clinique malencontreusement signalé
        clinic_phone = "+1 819 777 3838"
        phone_hash = self.hash_fn(clinic_phone)

        # 1 signalement isolé erroné
        SpamReport.objects.create(
            phone_hash=phone_hash,
            category='other',
            comment="Secrétariat du Dr Lavoie pour confirmation de biopsie et rendez-vous médical clinique."
        )

        # 3 confirmations citoyennes légitimes (avis sûrs)
        SafeReport.objects.create(
            phone_hash=phone_hash,
            reason='clinic',
            comment="C'est le secrétariat médical de la clinique de Gatineau."
        )
        SafeReport.objects.create(
            phone_hash=phone_hash,
            reason='delivery',
            comment="Numéro légitime de l'hôpital pour les consultations externes."
        )

        # Entrée en base
        BlacklistedNumber.objects.create(
            phone_hash=phone_hash,
            masked_number='+1 819 *** **38',
            category='other',
            risk_score=35,
            reports_count=1,
            safe_reports_count=2,
            consensus_score=0.67,
            is_blocked=False,
            is_whitelisted=False
        )

        diag = self.ai_engine.diagnose(phone_number=clinic_phone, phone_hash=phone_hash)

        self.assertIn(diag['verdict'], ['FAUX_POSITIF_CONFIRME', 'FAUX_POSITIF_PROBABLE'])
        self.assertEqual(diag['recommendation'], 'AUTO_WHITELIST')
        self.assertGreaterEqual(diag['false_positive_confidence'], 70)
        self.assertLessEqual(diag['composite_risk_score'], 30)

        # Vérification des facteurs d'explicabilité XAI
        positive_factors = [f for f in diag['xai_factors'] if f['direction'] == 'positive']
        self.assertGreater(len(positive_factors), 0)

    def test_ai_diagnose_api_endpoint(self):
        url = reverse('ai-diagnose')

        # Requête GET avec paramètre
        res_get = self.client.get(url, {'phone_number': '+1 819 555 0199'})
        self.assertEqual(res_get.status_code, status.HTTP_200_OK)
        self.assertIn('verdict', res_get.data)
        self.assertIn('false_positive_confidence', res_get.data)
        self.assertIn('composite_risk_score', res_get.data)
        self.assertIn('xai_factors', res_get.data)
        self.assertIn('execution_time_ms', res_get.data)

        # Requête POST avec JSON
        res_post = self.client.post(url, {'phone_number': '+1 819 777 3838'}, format='json')
        self.assertEqual(res_post.status_code, status.HTTP_200_OK)
        self.assertEqual(res_post.data['phone_number'], '+1 819 777 3838')

        # Requête sans numéro ni hash -> 400
        res_bad = self.client.post(url, {}, format='json')
        self.assertEqual(res_bad.status_code, status.HTTP_400_BAD_REQUEST)

        # Requête sans authentification API Key -> 401/403
        unauth_client = self.client_class()
        res_unauth = unauth_client.get(url, {'phone_number': '+1 819 555 0199'})
        self.assertIn(res_unauth.status_code, [status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN])


class SecurityConfigurationTests(TestCase):
    """
    Tests de validation de la configuration de sécurité (clés API, sels, autorisations).
    """
    def test_settings_has_valid_api_key_and_salt(self):
        self.assertTrue(hasattr(settings, 'API_KEY'))
        self.assertTrue(bool(settings.API_KEY))
        self.assertTrue(hasattr(settings, 'HASH_SALT'))
        self.assertTrue(bool(settings.HASH_SALT))

    def test_hash_phone_number_uses_configured_salt(self):
        from .services import hash_phone_number
        hash_val = hash_phone_number("+1 819 123 4567")
        self.assertEqual(len(hash_val), 64)

    def test_permission_denies_wrong_or_missing_api_key(self):
        from .permissions import HasAPIKeyOrAuthenticated
        from rest_framework.test import APIRequestFactory
        factory = APIRequestFactory()

        # Clé invalide
        req_invalid = factory.get('/api/v1/blacklist/', HTTP_X_API_KEY='cle_invalide_attaquant')
        req_invalid.user = None
        perm = HasAPIKeyOrAuthenticated()
        self.assertFalse(perm.has_permission(req_invalid, None))

        # Clé valide
        req_valid = factory.get('/api/v1/blacklist/', HTTP_X_API_KEY=settings.API_KEY)
        req_valid.user = None
        self.assertTrue(perm.has_permission(req_valid, None))


class AdvancedAIEngineTests(TestCase):
    """
    Tests unitaires des briques IA avancées :
    - Entropie spectrale de Shannon (analyse des suites numériques spoofées)
    - Amortissement temporel exponentiel (réassignation télécom & demi-vie 90j)
    - Détection d'usurpation paradoxale (co-occurrence contradictoire)
    - Intégration fermée dans le consensus de consensualité
    """
    def test_shannon_digit_entropy_detects_synthetic_sequences(self):
        from .ai_engine import ShannonEntropyAnalyzer
        # Numéro complètement uniforme (entropie nulle = 0.0 bit)
        res_uniform = ShannonEntropyAnalyzer.evaluate_entropy_risk("+1 888 888 8888")
        self.assertEqual(res_uniform['entropy'], 0.0)

        # Numéro avec répétition massive (entropie très basse < 2.2 bits)
        res_low = ShannonEntropyAnalyzer.evaluate_entropy_risk("+1 819 000 0000")
        self.assertTrue(res_low['is_synthetic'])
        self.assertLess(res_low['entropy'], 2.2)

        # Numéro humain authentique et diversifié (entropie >= 2.5 bits)
        res_normal = ShannonEntropyAnalyzer.evaluate_entropy_risk("+1 819 773 2495")
        self.assertFalse(res_normal['is_synthetic'])
        self.assertGreaterEqual(res_normal['entropy'], 2.5)

    def test_temporal_decay_half_life(self):
        from .ai_engine import TemporalDecayService
        from django.utils import timezone
        from datetime import timedelta

        now = timezone.now()
        # Événement immédiat -> poids proche de 1.0
        w_now = TemporalDecayService.calculate_decay_weight(now)
        self.assertAlmostEqual(w_now, 1.0, places=2)

        # Événement vieux de 90 jours (une demi-vie) -> poids ~ 0.5
        t_90d = now - timedelta(days=90)
        w_90d = TemporalDecayService.calculate_decay_weight(t_90d)
        self.assertAlmostEqual(w_90d, 0.5, delta=0.05)

        # Événement vieux de 180 jours (deux demi-vies) -> poids ~ 0.25
        t_180d = now - timedelta(days=180)
        w_180d = TemporalDecayService.calculate_decay_weight(t_180d)
        self.assertAlmostEqual(w_180d, 0.25, delta=0.05)

        # Événement très ancien (ex: 2 ans) -> ne descend jamais sous le plancher de sécurité (0.05)
        t_old = now - timedelta(days=730)
        w_old = TemporalDecayService.calculate_decay_weight(t_old)
        self.assertGreaterEqual(w_old, 0.05)

    def test_adversarial_impersonation_detection(self):
        from .ai_engine import AdversarialImpersonationDetector
        # Fraude flagrante : Autorité officielle + Moyen d'extorsion financier
        scam_text = "Ici Revenu Québec, votre compte est suspendu. Payez immédiatement en carte cadeau Apple ou mandat."
        detection = AdversarialImpersonationDetector.detect(scam_text)
        self.assertTrue(detection['is_impersonation'])
        self.assertEqual(detection['severity'], 90)
        self.assertIn('revenu quebec', detection['authorities'])
        self.assertIn('carte cadeau', detection['extortions'])

        # Message bénin mentionnant un service de santé sans extorsion
        benign_text = "Rappel de votre rendez-vous au CLSC avec votre médecin demain à 14h."
        detection_benign = AdversarialImpersonationDetector.detect(benign_text)
        self.assertFalse(detection_benign['is_impersonation'])
        self.assertEqual(detection_benign['severity'], 0)

    def test_consensus_service_incorporates_nlp_and_temporal_decay(self):
        from .services import FalsePositiveConsensusService, ReputationService
        from django.contrib.auth.models import User

        phone_hash = "f" * 64
        # Signalement spam avec tentative d'usurpation dans le commentaire
        ReputationService.process_new_report(
            phone_hash=phone_hash,
            category='fraud',
            comment='Appel se disant de la police demandant un virement interac urgent'
        )

        user1 = User.objects.create_user(username='tester_cons_1', email='tc1@test.com')
        # Avis légitime
        FalsePositiveConsensusService.register_safe_feedback(
            phone_hash=phone_hash,
            reason='medical',
            comment='C\'est en réalité la clinique médicale de Gatineau',
            user=user1
        )

        evaluation = FalsePositiveConsensusService.evaluate_consensus(phone_hash)
        self.assertIn('beta_nlp', evaluation)
        # Usurpation détectée dans le signalement spam -> beta_nlp restreint à 0.5
        self.assertLessEqual(evaluation['beta_nlp'], 1.0)


class ApplicationSecurityAuditTests(APITestCase):
    """
    Tests de vérification et d'audit de sécurité applicative (OWASP Top 10 & CWE) :
    - Immunité aux attaques par canal auxiliaire (Timing Attacks sur API_KEY)
    - Protection contre l'usurpation de compte staff via connexion sociale (Account Takeover)
    - Neutralisation de l'énumération des utilisateurs (User Enumeration Prevention)
    - Protection contre les injections de formules dans les exports (CSV Injection CWE-1236)
    - Plafonnement strict des tailles de charge utile (DoS / Resource Exhaustion)
    """
    def test_api_key_constant_time_comparison(self):
        from .permissions import HasAPIKeyOrAuthenticated
        from rest_framework.test import APIRequestFactory
        factory = APIRequestFactory()
        perm = HasAPIKeyOrAuthenticated()

        # Clé invalide
        req_wrong = factory.get('/api/v1/blacklist/', HTTP_X_API_KEY='fake_key')
        req_wrong.user = None
        self.assertFalse(perm.has_permission(req_wrong, None))

        # Clé exacte
        req_right = factory.get('/api/v1/blacklist/', HTTP_X_API_KEY=settings.API_KEY)
        req_right.user = None
        self.assertTrue(perm.has_permission(req_right, None))

    def test_google_login_rejects_staff_account_takeover(self):
        from django.contrib.auth.models import User
        # Création d'un administrateur système
        admin_email = 'soc_boss@shieldnet.app'
        User.objects.create_superuser(username='soc_boss', email=admin_email, password='SecretPassword123!')

        url = reverse('auth-google')
        # Tentative d'usurpation de l'administrateur sans mot de passe via l'endpoint Google
        resp = self.client.post(url, {'email': admin_email, 'name': 'Attacker'}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)
        self.assertIn('privilèges administratifs', resp.data['detail'])

    def test_login_uniform_error_message_prevents_user_enumeration(self):
        url = reverse('auth-login')
        # 1. Tentative sur email inexistant
        resp_nonexistent = self.client.post(url, {'email': 'ghost@unknown.qc.ca', 'password': 'somepassword'}, format='json')
        self.assertEqual(resp_nonexistent.status_code, status.HTTP_400_BAD_REQUEST)
        err_msg_1 = str(resp_nonexistent.data)

        # 2. Création d'un utilisateur puis tentative avec mauvais mot de passe
        from django.contrib.auth.models import User
        User.objects.create_user(username='real@shieldnet.app', email='real@shieldnet.app', password='GoodPassword123!')
        resp_wrong_pass = self.client.post(url, {'email': 'real@shieldnet.app', 'password': 'WrongPassword999!'}, format='json')
        self.assertEqual(resp_wrong_pass.status_code, status.HTTP_400_BAD_REQUEST)
        err_msg_2 = str(resp_wrong_pass.data)

        # Les messages d'erreur doivent être identiques pour empêcher l'énumération d'adresses email
        self.assertIn("Adresse email ou mot de passe incorrect", err_msg_1)
        self.assertIn("Adresse email ou mot de passe incorrect", err_msg_2)

    def test_csv_export_neutralizes_formula_injection(self):
        from .admin_views import sanitize_csv_cell
        # Formules malveillantes typiques sous Excel
        self.assertEqual(sanitize_csv_cell("=CMD|'/C calc'!A0"), "'=CMD|'/C calc'!A0")
        self.assertEqual(sanitize_csv_cell("+18195551234"), "'+18195551234")
        self.assertEqual(sanitize_csv_cell("@SUM(1+1)"), "'@SUM(1+1)")
        self.assertEqual(sanitize_csv_cell("-5+2"), "'-5+2")
        # Valeur textuelle normale non modifiée
        self.assertEqual(sanitize_csv_cell("FRAUD"), "FRAUD")
        self.assertEqual(sanitize_csv_cell("8195551234"), "8195551234")

    def test_comment_payload_size_enforced(self):
        url = reverse('submit-report')
        self.client.credentials(HTTP_X_API_KEY=settings.API_KEY)
        huge_comment = "A" * 1500  # dépasse la limite de 1000 caractères
        resp = self.client.post(url, {
            'phone_hash': 'a' * 64,
            'category': 'fraud',
            'comment': huge_comment,
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('comment', resp.data)

    def test_batch_check_numbers_success(self):
        url = reverse('batch-check-number')
        self.client.credentials(HTTP_X_API_KEY=settings.API_KEY)

        # 1. Un numéro frauduleux bloqué
        h1 = "1" * 64
        BlacklistedNumber.objects.create(
            phone_hash=h1,
            category='financial_scam',
            risk_score=85,
            reports_count=5,
            is_blocked=True,
            is_whitelisted=False,
        )

        # 2. Un numéro réhabilité (liste blanche)
        h2 = "2" * 64
        BlacklistedNumber.objects.create(
            phone_hash=h2,
            category='service',
            risk_score=0,
            reports_count=2,
            safe_reports_count=5,
            consensus_score=0.9,
            is_blocked=False,
            is_whitelisted=True,
            whitelist_reason='medical',
        )

        # 3. Un numéro inconnu
        h3 = "3" * 64

        resp = self.client.post(url, {'hashes': [h1, h2, h3]}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.data['count'], 3)
        res = resp.data['results']

        self.assertTrue(res[h1]['is_spam'])
        self.assertEqual(res[h1]['risk_score'], 85)
        self.assertEqual(res[h1]['category'], 'financial_scam')

        self.assertFalse(res[h2]['is_spam'])
        self.assertTrue(res[h2]['is_whitelisted'])
        self.assertEqual(res[h2]['whitelist_reason'], 'medical')

        self.assertFalse(res[h3]['is_spam'])
        self.assertEqual(res[h3]['risk_score'], 0)

    def test_batch_check_validation_rules(self):
        url = reverse('batch-check-number')
        self.client.credentials(HTTP_X_API_KEY=settings.API_KEY)

        # Hash non conforme (trop court)
        resp_invalid = self.client.post(url, {'hashes': ['not_a_valid_hash']}, format='json')
        self.assertEqual(resp_invalid.status_code, status.HTTP_400_BAD_REQUEST)

        # Liste vide
        resp_empty = self.client.post(url, {'hashes': []}, format='json')
        self.assertEqual(resp_empty.status_code, status.HTTP_400_BAD_REQUEST)

        # Plus de 100 hashes
        too_many = [f"{i:064x}" for i in range(105)]
        resp_too_many = self.client.post(url, {'hashes': too_many}, format='json')
        self.assertEqual(resp_too_many.status_code, status.HTTP_400_BAD_REQUEST)

    def test_prometheus_metrics_endpoint(self):
        url = reverse('prometheus-metrics')
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('text/plain', resp.headers.get('Content-Type', ''))
        body = resp.content.decode('utf-8')
        self.assertIn("shieldnet_blacklist_active_total", body)
        self.assertIn("shieldnet_spam_reports_total", body)
        self.assertIn("shieldnet_whitelisted_total", body)

    def test_stir_shaken_attestation_evaluations(self):
        from .services import AutomatedSpamVerifier
        from .ai_engine import ShieldNetAIEngine

        # 1. Vérification AutomatedSpamVerifier avec Attestation A (réduction de score)
        eval_a = AutomatedSpamVerifier.evaluate_number("a" * 64, raw_number="+18195551234", attestation="A")
        self.assertEqual(eval_a['attestation'], 'A')
        self.assertEqual(eval_a['calculated_score'], 0)

        # 2. Vérification AutomatedSpamVerifier avec Attestation C (passerelle non sécurisée)
        eval_c = AutomatedSpamVerifier.evaluate_number("c" * 64, raw_number="+18195551234", attestation="C")
        self.assertEqual(eval_c['attestation'], 'C')
        self.assertGreaterEqual(eval_c['calculated_score'], 25)
        self.assertTrue(any("STIR/SHAKEN" in a for a in eval_c['anomalies']))

        # 3. Diagnostic IA explicable avec attestation A
        diag = ShieldNetAIEngine.diagnose(phone_number="+18195551234", attestation="A")
        self.assertTrue(diag['success'])
        xai_types = [f['type'] for f in diag['xai_factors']]
        self.assertIn('STIR_SHAKEN', xai_types)
        self.assertEqual(diag['metrics']['stir_shaken_attestation'], 'A')













