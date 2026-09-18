from django.test import TestCase
from django.urls import reverse
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
        self.client.credentials(HTTP_X_API_KEY='ShieldNet_Secret_Token_UQO_2026')

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
        # 1. Inscription avec email
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

        # 2. Connexion avec email
        login_url = reverse('auth-login')
        login_data = {
            'email': 'utilisateur@shieldnet.app',
            'password': 'Password123!'
        }
        login_resp = self.client.post(login_url, login_data, format='json')
        self.assertEqual(login_resp.status_code, status.HTTP_200_OK)
        access_token = login_resp.data['tokens']['access']
        self.assertIsNotNone(access_token)

        # 3. Accès au profil /me avec le token JWT
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
        # 1. Premier appel : compte inexistant -> création auto
        resp1 = self.client.post(url, google_data, format='json')
        self.assertEqual(resp1.status_code, status.HTTP_200_OK)
        self.assertEqual(resp1.data['user']['email'], 'google.user@shieldnet.app')
        self.assertIn('tokens', resp1.data)
        self.assertIsNotNone(resp1.data['tokens']['access'])

        # 2. Deuxième appel : compte existant -> connexion directe immédiate
        resp2 = self.client.post(url, google_data, format='json')
        self.assertEqual(resp2.status_code, status.HTTP_200_OK)
        self.assertEqual(resp2.data['user']['email'], 'google.user@shieldnet.app')
        self.assertIn('tokens', resp2.data)

    def test_admin_stats_and_moderation(self):
        from django.contrib.auth.models import User
        # 1. Création utilisateur standard et utilisateur admin
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

        # 2. Utilisateur standard refusé
        std_client = self.client_class()
        std_client.credentials(HTTP_AUTHORIZATION=f'Bearer {std_token}')
        stats_url = reverse('admin-stats')
        resp_std = std_client.get(stats_url)
        self.assertEqual(resp_std.status_code, status.HTTP_403_FORBIDDEN)

        # 3. Administrateur autorisé avec métriques globales
        admin_client = self.client_class()
        admin_client.credentials(HTTP_AUTHORIZATION=f'Bearer {admin_token}')
        resp_admin = admin_client.get(stats_url)
        self.assertEqual(resp_admin.status_code, status.HTTP_200_OK)
        self.assertIn('total_blacklisted', resp_admin.data)
        self.assertIn('total_blocked', resp_admin.data)
        self.assertIn('recent_reports', resp_admin.data)

        # 4. Modération admin : blanchiment d'un numéro
        mod_url = reverse('admin-moderate')
        mod_resp = admin_client.post(mod_url, {'phone_hash': phone_hash, 'action': 'whitelist'}, format='json')
        self.assertEqual(mod_resp.status_code, status.HTTP_200_OK)

        num_refreshed = BlacklistedNumber.objects.get(phone_hash=phone_hash)
        self.assertTrue(num_refreshed.is_whitelisted)
        self.assertFalse(num_refreshed.is_blocked)

    def test_dedicated_admin_email_login_web_and_mobile(self):
        from django.contrib.auth.models import User
        from django.contrib.auth import authenticate

        # 1. Création du compte administrateur dédié
        admin_email = 'admin@shieldnet.app'
        admin_pass = 'AdminPassword2026!'
        User.objects.create_superuser(
            username='admin_dedicated',
            email=admin_email,
            password=admin_pass
        )

        # 2. Vérification de la connexion Web Admin (/admin/) via son courriel dédié
        web_user = authenticate(username=admin_email, password=admin_pass)
        self.assertIsNotNone(web_user)
        self.assertEqual(web_user.email, admin_email)
        self.assertTrue(web_user.is_staff)
        self.assertTrue(web_user.is_superuser)

        # 3. Vérification de la connexion Mobile (/api/v1/auth/login/) via son courriel dédié
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

        # 1. Ajout direct d'un numéro à la blacklist par l'admin (avec raw phone number)
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

        # 2. Consultation de la blacklist
        list_resp = admin_client.get(add_url)
        self.assertEqual(list_resp.status_code, status.HTTP_200_OK)
        self.assertTrue(len(list_resp.data) >= 1)

        # 3. Consultation de la liste des utilisateurs
        users_url = reverse('admin-users')
        users_resp = admin_client.get(users_url)
        self.assertEqual(users_resp.status_code, status.HTTP_200_OK)
        self.assertTrue(len(users_resp.data) >= 1)

        # 4. Consultation des signalements
        reports_url = reverse('admin-reports')
        rep_resp = admin_client.get(reports_url)
        self.assertEqual(rep_resp.status_code, status.HTTP_200_OK)

        # 5. Purge de la base
        purge_url = reverse('admin-purge')
        purge_resp = admin_client.post(purge_url)
        self.assertEqual(purge_resp.status_code, status.HTTP_200_OK)
        self.assertIn('purged_count', purge_resp.data)

        # 6. Suppression définitive du numéro
        del_url = reverse('admin-blacklist-detail', kwargs={'phone_hash': phone_hash})
        del_resp = admin_client.delete(del_url)
        self.assertEqual(del_resp.status_code, status.HTTP_200_OK)
        self.assertFalse(BlacklistedNumber.objects.filter(phone_hash=phone_hash).exists())

class ConsensusFalsePositiveServiceTest(APITestCase):
    """
    Tests exhaustifs du moteur algorithmique de détection automatique des faux positifs par consensualité.
    """
    def setUp(self):
        self.client.credentials(HTTP_X_API_KEY='ShieldNet_Secret_Token_UQO_2026')

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
        client2.credentials(HTTP_X_API_KEY='ShieldNet_Secret_Token_UQO_2026')
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






