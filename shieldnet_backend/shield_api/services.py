import re
import hmac
import hashlib
from datetime import timedelta
from django.conf import settings
from django.utils import timezone
from django.db import transaction
from .models import BlacklistedNumber, SpamReport, SafeReport, SafeReasonChoices

def hash_phone_number(phone_number: str) -> str:
    cleaned = phone_number.strip()
    digits = re.sub(r'\D', '', cleaned)
    if not digits:
        return ""
    has_plus = cleaned.startswith('+')
    normalized = f"+{digits}" if has_plus else (f"+1{digits}" if len(digits) == 10 else f"+{digits}")
    salt = getattr(settings, 'HASH_SALT', '')
    if not salt:
        raise ValueError("Paramètre de sécurité HASH_SALT manquant dans la configuration.")
    return hmac.new(salt.encode('utf-8'), normalized.encode('utf-8'), hashlib.sha256).hexdigest()

def mask_phone_number(phone_number: str) -> str:
    cleaned = phone_number.strip()
    if len(cleaned) < 6:
        return '***'
    return f"{cleaned[:5]} *** **{cleaned[-2:]}"

class DatabaseSanitizerService:
    """
    Nettoyage et maintenance de la base de données.
    """

    @classmethod
    def purge_obsolete_and_unverified_junk(cls) -> int:
        """
        Supprime les signalements isolés non confirmés de plus de 30 jours.
        """
        thirty_days_ago = timezone.now() - timedelta(days=30)
        
        # Supprimer les numéros à faible risque qui n'ont reçu qu'un seul signalement ancien
        junk_numbers = BlacklistedNumber.objects.filter(
            reports_count=1,
            risk_score__lt=30,
            updated_at__lt=thirty_days_ago
        )
        
        count = junk_numbers.count()
        junk_numbers.delete()
        return count

class AutomatedSpamVerifier:
    """
    Évaluation heuristique automatique des numéros.
    """
    
    NANP_PATTERN = re.compile(r'^\+1[2-9]\d{2}[2-9]\d{6}$')

    @classmethod
    def evaluate_number(cls, phone_hash: str, raw_number: str = None, attestation: str = None) -> dict:
        score = 0
        anomalies = []

        if raw_number:
            cleaned = raw_number.strip()
            digits = re.sub(r'\D', '', cleaned)
            has_plus = cleaned.startswith('+')

            normalized = f"+{digits}" if has_plus else (f"+1{digits}" if len(digits) == 10 else f"+{digits}")

            if not normalized.startswith('+1'):
                score += 55
                anomalies.append("Origine géographique internationale hors Amérique du Nord (+1)")

            if not cls.NANP_PATTERN.match(normalized):
                score += 65
                anomalies.append("Structure de numéro générée ou non conforme au format NANP")

            national_part = digits[1:] if len(digits) == 11 else digits
            if re.search(r'(\d)\1{6,}', national_part) or national_part in ['1234567890', '9876543210']:
                score += 70
                anomalies.append("Séquence de chiffres générée artificiellement")

        # Évaluation du standard télécom STIR/SHAKEN (FCC / CRTC)
        attestation_clean = (attestation or '').strip().upper()
        if attestation_clean == 'A':
            # Attestation A : Identité de l'appelant et droit d'usage certifiés par l'opérateur
            score = max(0, score - 30)
        elif attestation_clean == 'C':
            # Attestation C : Passerelle VoIP non sécurisée sans validation d'identité
            score += 25
            anomalies.append("Attestation STIR/SHAKEN niveau C : Passerelle non authentifiée")

        return {
            'calculated_score': min(100, max(0, score)),
            'is_verified_spam': score >= 40 or len(anomalies) > 0,
            'anomalies': anomalies,
            'attestation': attestation_clean if attestation_clean in ('A', 'B', 'C') else None,
        }

class FalsePositiveConsensusService:
    """
    Gestion du consensus communautaire et réhabilitation des faux positifs.
    Compare les signalements de spam aux avis légitimes déposés par les utilisateurs
    et réhabilite automatiquement un numéro si le quorum et le ratio pondéré sont atteints.
    """
    QUORUM_MINIMUM_DEFAULT = 2         # Au moins 2 avis favorables distincts pour initier le consensus
    CONSENSUS_THRESHOLD_DEFAULT = 0.55    # Au moins 55% de masse favorable pondérée

    REASON_WEIGHTS = {
        'medical': 2.0,      # Priorité absolue : urgences / santé
        'delivery': 1.6,     # Services de messagerie / transporteurs
        'service': 1.4,      # Entreprises et services certifiés
        'personal': 1.3,     # Contacts personnels
        'mistake': 1.2,      # Erreur reconnue de signalement
        'other': 1.0,
    }

    SPAM_CATEGORY_WEIGHTS = {
        'fraud': 1.5,
        'financial_scam': 1.6,
        'phishing': 1.5,
        'robocall': 1.1,
        'telemarketing': 0.9,
        'other': 0.8,
    }

    @classmethod
    def calculate_reporter_weight(cls, user, ip_address=None) -> float:
        """Pondère la fiabilité du votant : admin (5.0), utilisateur inscrit (1.5), anonyme (1.0)."""
        if not user:
            return 1.0
        if getattr(user, 'is_staff', False) or getattr(user, 'is_superuser', False):
            return 5.0
        return 1.5

    @classmethod
    def evaluate_consensus(cls, phone_hash: str) -> dict:
        """
        Calcule l'indice de consensualité C(h) = (M_safe * alpha) / (M_safe * alpha + M_spam).
        Retourne les métriques détaillées et le verdict de détection de faux positif.
        """
        number_obj = BlacklistedNumber.objects.filter(phone_hash=phone_hash).first()
        spam_reports = list(SpamReport.objects.filter(phone_hash=phone_hash).select_related('reporter'))
        safe_reports = list(SafeReport.objects.filter(phone_hash=phone_hash).select_related('reporter'))

        from .ai_engine import TemporalDecayService, NLPSemanticAnalyzer

        # Calcul de la masse pondérée des signalements négatifs avec amortissement temporel
        m_spam = 0.0
        spam_comments = []
        for s in spam_reports:
            w_cat = cls.SPAM_CATEGORY_WEIGHTS.get(s.category, 1.0)
            w_user = cls.calculate_reporter_weight(s.reporter)
            w_decay = TemporalDecayService.calculate_decay_weight(s.created_at)
            m_spam += (w_cat * w_user * w_decay)
            if s.comment:
                spam_comments.append(s.comment)

        # Calcul de la masse pondérée des avis favorables légitimes avec amortissement temporel
        m_safe = 0.0
        safe_comments = []
        for r in safe_reports:
            w_reason = cls.REASON_WEIGHTS.get(r.reason, 1.0)
            w_user = cls.calculate_reporter_weight(r.reporter, r.ip_address)
            w_decay = TemporalDecayService.calculate_decay_weight(r.created_at)
            m_safe += (w_reason * w_user * w_decay)
            if r.comment:
                safe_comments.append(r.comment)

        # Analyse sémantique NLP et détection d'usurpation contradictoire
        nlp_res = NLPSemanticAnalyzer.analyze(spam_comments=spam_comments, safe_comments=safe_comments)

        # Coefficient correcteur selon la conformité du format télécom
        raw_num = number_obj.masked_number if number_obj else None
        eval_algo = AutomatedSpamVerifier.evaluate_number(phone_hash, raw_num)
        alpha = 0.7 if eval_algo.get('is_verified_spam', False) else 1.25

        # Modulation bayésienne sémantique :
        # - En cas d'usurpation paradoxale détectée, la force de réhabilitation est fortement réduite (0.5)
        # - En cas de confirmation sémantique de légitimité (santé, rdv...), bonus modéré
        if nlp_res.get('is_impersonation', False):
            beta_nlp = 0.5
        elif nlp_res.get('legitimacy_score', 0) > 15:
            beta_nlp = min(1.35, 1.0 + (nlp_res['legitimacy_score'] / 300.0))
        else:
            beta_nlp = 1.0

        weighted_safe = m_safe * alpha * beta_nlp
        total_mass = weighted_safe + m_spam

        consensus_ratio = (weighted_safe / total_mass) if total_mass > 0 else 0.0
        unique_safe_count = len(safe_reports)

        has_admin_safe = any(
            r.reporter and (r.reporter.is_staff or r.reporter.is_superuser)
            for r in safe_reports
        )
        quorum_met = (unique_safe_count >= cls.QUORUM_MINIMUM_DEFAULT) or has_admin_safe
        ratio_met = consensus_ratio >= cls.CONSENSUS_THRESHOLD_DEFAULT
        mass_met = weighted_safe >= m_spam

        is_false_positive = quorum_met and ratio_met and mass_met

        return {
            'phone_hash': phone_hash,
            'spam_count': len(spam_reports),
            'safe_count': unique_safe_count,
            'm_spam': round(m_spam, 2),
            'm_safe': round(m_safe, 2),
            'alpha': alpha,
            'beta_nlp': round(beta_nlp, 2),
            'consensus_ratio': round(consensus_ratio, 3),
            'quorum_met': quorum_met,
            'is_false_positive': is_false_positive,
            'details': (
                f"Consensus légitime atteint ({round(consensus_ratio * 100, 1)}%) avec {unique_safe_count} avis."
                if is_false_positive else
                f"Consensus insuffisant ({round(consensus_ratio * 100, 1)}% favorable, {unique_safe_count}/{cls.QUORUM_MINIMUM_DEFAULT} avis requis)."
            )
        }

    @classmethod
    @transaction.atomic
    def apply_consensus_decision(cls, phone_hash: str) -> bool:
        """
        Applique automatiquement la décision de consensualité sur la base de données
        avec verrouillage transactionnel strict (ACID / Concurrency-safe).
        Si faux positif avéré :
          - is_whitelisted = True
          - is_blocked = False
          - risk_score = 0
          - whitelist_reason = 'auto_consensus'
        Retourne True si le numéro est réhabilité comme faux positif.
        """
        analysis = cls.evaluate_consensus(phone_hash)
        number_obj = BlacklistedNumber.objects.select_for_update().filter(phone_hash=phone_hash).first()
        if not number_obj:
            return False

        number_obj.safe_reports_count = analysis['safe_count']
        number_obj.consensus_score = analysis['consensus_ratio']

        # Si déjà blanchi (manuellement ou préexistant hors auto_consensus), conserver la décision
        if number_obj.is_whitelisted and number_obj.whitelist_reason != 'auto_consensus':
            number_obj.save()
            return False

        if analysis['is_false_positive']:
            number_obj.is_whitelisted = True
            number_obj.is_blocked = False
            number_obj.risk_score = 0
            number_obj.whitelist_reason = 'auto_consensus'
            number_obj.save()
            return True
        else:
            # Révocation dynamique si un numéro auto-consensuel subit une vague massive de nouveaux spams
            if number_obj.whitelist_reason == 'auto_consensus' and analysis['consensus_ratio'] < 0.40:
                number_obj.is_whitelisted = False
                number_obj.is_blocked = True
                number_obj.whitelist_reason = ''
                number_obj.risk_score = min(100, int(analysis['m_spam'] * 15))
                number_obj.save()
            else:
                number_obj.save()
            return False

    @classmethod
    @transaction.atomic
    def register_safe_feedback(
        cls,
        phone_hash: str,
        reason: str = 'service',
        comment: str = '',
        user=None,
        ip_address=None,
        masked_number: str = None
    ) -> tuple[SafeReport, bool]:
        """
        Enregistre un avis favorable / contestation avec protection anti-Sybil,
        puis exécute immédiatement l'analyse et la réhabilitation consensuelle automatique.
        """
        # Anti-Sybil : Un même utilisateur connecté ne vote qu'une fois par numéro
        if user and user.is_authenticated:
            existing = SafeReport.objects.filter(reporter=user, phone_hash=phone_hash).first()
            if existing:
                existing.reason = reason
                if comment:
                    existing.comment = comment
                existing.save()
                auto_whitelisted = cls.apply_consensus_decision(phone_hash)
                return existing, auto_whitelisted

        # Anti-Flood par IP pour les utilisateurs non connectés (1 vote par IP / 2h sur le même numéro)
        if ip_address:
            two_hours_ago = timezone.now() - timedelta(hours=2)
            existing_ip = SafeReport.objects.filter(
                phone_hash=phone_hash,
                ip_address=ip_address,
                created_at__gte=two_hours_ago
            ).first()
            if existing_ip:
                auto_whitelisted = cls.apply_consensus_decision(phone_hash)
                return existing_ip, auto_whitelisted

        report = SafeReport.objects.create(
            reporter=user if (user and user.is_authenticated) else None,
            phone_hash=phone_hash,
            reason=reason,
            comment=comment,
            ip_address=ip_address,
        )

        number_obj, _ = BlacklistedNumber.objects.get_or_create(
            phone_hash=phone_hash,
            defaults={
                'masked_number': masked_number,
                'category': 'other',
                'risk_score': 0,
                'reports_count': 0,
                'is_blocked': False,
                'is_whitelisted': False,
            }
        )
        if masked_number and not number_obj.masked_number:
            number_obj.masked_number = masked_number

        auto_whitelisted = cls.apply_consensus_decision(phone_hash)
        return report, auto_whitelisted

    @classmethod
    def run_consensus_audit(cls) -> dict:
        """
        Audit et réévaluation globale des faux positifs par consensualité
        sur l'intégralité de la base de données.
        """
        candidates = BlacklistedNumber.objects.filter(safe_reports_count__gte=1)
        auto_whitelisted_hashes = []

        for num in candidates:
            if cls.apply_consensus_decision(num.phone_hash):
                auto_whitelisted_hashes.append(num.phone_hash)

        return {
            'candidates_audited': candidates.count(),
            'auto_whitelisted_count': len(auto_whitelisted_hashes),
            'auto_whitelisted_hashes': auto_whitelisted_hashes,
        }

class ReputationService:
    """
    Algorithme de calcul de réputation et modération anti-pollution.
    """
    
    CATEGORY_WEIGHTS = {
        'fraud': 35,
        'financial_scam': 40,
        'phishing': 35,
        'robocall': 25,
        'telemarketing': 20,
        'other': 15,
    }

    @classmethod
    @transaction.atomic
    def process_new_report(cls, phone_hash: str, category: str, masked_number: str = None, user = None, comment: str = None) -> SpamReport:
        """
        Traite un nouveau signalement et exécute les vérifications anti-pollution
        avec garantie d'intégrité transactionnelle ACID.
        """
        # Déduplication : ignorer les signalements identiques rapprochés (< 1h) par le même utilisateur
        one_hour_ago = timezone.now() - timedelta(hours=1)
        if user and SpamReport.objects.filter(reporter=user, phone_hash=phone_hash, created_at__gte=one_hour_ago).exists():
            return SpamReport.objects.filter(reporter=user, phone_hash=phone_hash).first()

        # Plafond anti-saturation par hash (max 50 signalements archivés)
        if SpamReport.objects.filter(phone_hash=phone_hash).count() > 50:
            return SpamReport.objects.filter(phone_hash=phone_hash).first()

        report = SpamReport.objects.create(
            reporter=user,
            phone_hash=phone_hash,
            category=category,
            comment=comment,
        )

        number_obj = BlacklistedNumber.objects.select_for_update().filter(phone_hash=phone_hash).first()
        if not number_obj:
            number_obj = BlacklistedNumber.objects.create(
                phone_hash=phone_hash,
                category=category,
                masked_number=masked_number,
                reports_count=1,
                risk_score=cls.CATEGORY_WEIGHTS.get(category, 20),
                is_blocked=True,
            )
            created = True
        else:
            created = False

        if not created:
            number_obj.reports_count += 1

            # Si le numéro a été blanchi (manuellement ou préexistant hors auto_consensus),
            # on préserve la décision souveraine.
            if number_obj.is_whitelisted and number_obj.whitelist_reason != 'auto_consensus':
                pass
            # Si le numéro a été auto-blanchi par consensus, on ré-évalue immédiatement
            elif number_obj.is_whitelisted and number_obj.whitelist_reason == 'auto_consensus':
                FalsePositiveConsensusService.apply_consensus_decision(phone_hash)
            else:
                weight = cls.CATEGORY_WEIGHTS.get(category, 20)
                calculated_score = weight + (number_obj.reports_count * 15)
                number_obj.risk_score = min(100, calculated_score)
                number_obj.category = category
                
                if number_obj.risk_score >= 40:
                    number_obj.is_blocked = True

            if masked_number and not number_obj.masked_number:
                number_obj.masked_number = masked_number

            number_obj.save()

            # Mise à jour du score de consensualité en temps réel
            FalsePositiveConsensusService.apply_consensus_decision(phone_hash)

        return report
