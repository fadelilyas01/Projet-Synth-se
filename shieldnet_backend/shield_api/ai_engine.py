"""
Module d'arbitrage et de détection des faux positifs pour ShieldNet.
Analyse multimodale : sémantique NLP bayésienne, détection d'usurpation paradoxale,
analyse d'entropie spectrale des chiffres et amortissement temporel exponentiel.
"""

import re
import math
import unicodedata
from datetime import timedelta
from django.utils import timezone
from .models import BlacklistedNumber, SpamReport, SafeReport
from .services import hash_phone_number, mask_phone_number, AutomatedSpamVerifier

def normalize_text(text: str) -> str:
    """Normalise une chaîne de caractères (minuscules, sans accents ni ponctuation)."""
    if not text:
        return ""
    text = unicodedata.normalize('NFKD', text)
    text = "".join([c for c in text if not unicodedata.combining(c)])
    text = text.lower()
    text = re.sub(r'[^a-z0-9\s]', ' ', text)
    return re.sub(r'\s+', ' ', text).strip()


class ShannonEntropyAnalyzer:
    """
    Analyse de la distribution d'entropie des chiffres d'un numéro de téléphone.
    H(X) = - sum(p_i * log2(p_i))
    Permet de discriminer les numéros humains normaux (entropie 2.5 à 3.32 bits)
    des numéros synthétiques spoofés ou générés par composeur automatique (entropie < 2.2).
    """
    @classmethod
    def calculate_digit_entropy(cls, raw_number: str) -> float:
        digits = re.sub(r'\D', '', raw_number or '')
        if not digits:
            return 0.0
        # On extrait les 10 chiffres nationaux (sans l'indicatif international +1)
        if len(digits) == 11 and digits.startswith('1'):
            digits = digits[1:]
        if not digits:
            return 0.0
        n = len(digits)
        counts = {}
        for d in digits:
            counts[d] = counts.get(d, 0) + 1
        entropy = 0.0
        for count in counts.values():
            p = count / n
            entropy -= p * math.log2(p)
        return round(entropy, 3)

    @classmethod
    def evaluate_entropy_risk(cls, raw_number: str) -> dict:
        entropy = cls.calculate_digit_entropy(raw_number)
        is_synthetic = 0.0 < entropy < 2.2
        return {
            'entropy': entropy,
            'is_synthetic': is_synthetic,
            'description': (
                f"Entropie de Shannon anormale ({entropy} bits) indiquant une séquence VoIP synthétique."
                if is_synthetic else f"Entropie spectrale conforme ({entropy} bits)."
            )
        }


class TemporalDecayService:
    """
    Amortissement temporel exponentiel des signalements télécoms.
    Modélise la demi-vie des signalements (90 jours) pour permettre
    la réhabilitation naturelle et progressive des numéros réassignés ou recyclés.
    w(t) = exp(- lambda * delta_t_jours) avec lambda = ln(2) / 90
    """
    HALF_LIFE_DAYS = 90.0
    LAMBDA = math.log(2) / HALF_LIFE_DAYS

    @classmethod
    def calculate_decay_weight(cls, report_timestamp) -> float:
        if not report_timestamp:
            return 1.0
        now = timezone.now()
        delta = (now - report_timestamp).total_seconds() / 86400.0
        if delta <= 0:
            return 1.0
        weight = math.exp(-cls.LAMBDA * delta)
        return max(0.05, round(weight, 4))


class AdversarialImpersonationDetector:
    """
    Détection d'usurpation institutionnelle par co-occurrence paradoxale.
    Repère les fraudes où un criminel invoque une autorité reconnue (Hôpital, Police, Revenu Québec, Banque)
    tout en formulant une exigence financière illégitime (cartes cadeaux, virement urgent, cryptomonnaie).
    """
    AUTHORITY_KEYWORDS = {
        'revenu quebec', 'arc', 'cra', 'impot', 'police', 'grc', 'rcmp', 'sq', 'opp',
        'tribunal', 'service canada', 'douane', 'cbsa', 'desjardins', 'hydro quebec',
        'clsc', 'hopital', 'gendarmerie royale'
    }

    EXTORTION_KEYWORDS = {
        'carte cadeau', 'gift card', 'itunes', 'apple card', 'bitcoin', 'crypto',
        'cryptomonnaie', 'virement interac', 'arrestation', 'arrest', 'mandat d arret',
        'mandat', 'compte bloque', 'argent immediat', 'frais urgents', 'amende impayee'
    }

    @classmethod
    def detect(cls, text: str) -> dict:
        normalized = normalize_text(text)
        found_authorities = [k for k in cls.AUTHORITY_KEYWORDS if k in normalized]
        found_extortions = [k for k in cls.EXTORTION_KEYWORDS if k in normalized]

        is_impersonation = bool(found_authorities and found_extortions)
        return {
            'is_impersonation': is_impersonation,
            'authorities': found_authorities,
            'extortions': found_extortions,
            'severity': 90 if is_impersonation else 0
        }


class NLPSemanticAnalyzer:
    """
    Analyse sémantique hybride (Bayésienne & TF-IDF) des commentaires d'utilisateurs (FR / EN).
    Identifie les services légitimes, les motifs d'escroquerie et les attaques par usurpation.
    """

    # Mots-clés associés aux services légitimes (priorité accordée aux urgences et à la santé)
    LEGITIMATE_LEXICON = {
        'SANTE_MEDICAL': {
            'weight': 3.5,
            'label': 'Service Médical ou Urgence Santé',
            'keywords': [
                'hopital', 'hospital', 'clinique', 'clinic', 'medecin', 'doctor', 'docteur',
                'sante', 'health', 'pharmacie', 'pharmacy', 'dentiste', 'dentist', 'infirmiere',
                'nurse', 'clsc', 'chsld', 'pediatre', 'rendez vous', 'appointment', 'rappel rdv',
                'laboratoire', 'analyse sanguine', 'vaccination', 'urgence 811', 'jean coutu',
                'familiprix', 'pharmaprix', 'uniprix', 'consultations externes', 'biopsie',
                'secretariat medical'
            ]
        },
        'LIVRAISON_MESSAGERIE': {
            'weight': 2.8,
            'label': 'Transporteur & Livraison Légitime',
            'keywords': [
                'livraison', 'delivery', 'livreur', 'courier', 'doordash', 'uber eats', 'ubereats',
                'skip', 'skipthedishes', 'fedex', 'ups', 'dhl', 'purolator', 'postes canada',
                'canada post', 'amazon', 'colis a la porte', 'chauffeur', 'suivi colis'
            ]
        },
        'BANQUE_SERVICES_PUBLICS': {
            'weight': 3.0,
            'label': 'Institution Bancaire ou Service Public Reconnu',
            'keywords': [
                'hydro quebec', 'hydroquebec', 'hydro', 'desjardins', 'caisse populaire', 'rbc',
                'td', 'bmo', 'scotia', 'cibc', 'banque nationale', 'assurance', 'insurance',
                'ecole', 'school', 'universite', 'university', 'uqo', 'cegep', 'garderie',
                'daycare', 'ville de gatineau', 'ville d ottawa', 'municipalite', 'employeur',
                'coupure de service'
            ]
        },
        'ATTESTATION_CITOYENNE': {
            'weight': 2.0,
            'label': 'Attestation Citoyenne Positive',
            'keywords': [
                'bon numero', 'vrai numero', 'personne reelle', 'aucun probleme', 'pas un spam',
                'legit', 'legitime', 'ami', 'famille', 'collegue', 'travail', 'client'
            ]
        }
    }

    # Mots-clés caractéristiques de fraudes et d'usurpations
    THREAT_LEXICON = {
        'USURPATION_GOUVERNEMENTALE': {
            'weight': 4.0,
            'label': 'Agence Publique / Fiscale Usurpée',
            'keywords': [
                'agence du revenu', 'revenu canada', 'arc', 'cra', 'impot', 'taxes', 'police',
                'grc', 'rcmp', 'sq', 'opp', 'arrestation', 'arrest', 'mandat d arret', 'warrant',
                'tribunal', 'court', 'service canada', 'douane', 'frontiere', 'cbsa', 'immigration',
                'gendarmerie royale'
            ]
        },
        'EXTORSION_FINANCIERE': {
            'weight': 3.8,
            'label': 'Extorsion Financière & Vol d\'Identité',
            'keywords': [
                'carte cadeau', 'gift card', 'itunes', 'apple card', 'bitcoin', 'crypto',
                'cryptomonnaie', 'virement interac', 'wire transfer', 'western union', 'dette',
                'huissier', 'compte suspendu', 'compte bloque', 'nas', 'sin', 'assurance sociale',
                'social insurance', 'frais non payes', 'amende impayee'
            ]
        },
        'HAME CONNAGE_PHISHING': {
            'weight': 3.2,
            'label': 'Hameçonnage / Phishing Télécom & SMS',
            'keywords': [
                'colis bloque', 'frais de douane', 'cliquez ici', 'click here', 'lien suspect',
                'remboursement interac', 'e transfer', 'etransfer', 'gain loterie', 'gagne un prix',
                'pret rapide', 'fast cash', 'taux d interet', 'reduction de dette'
            ]
        },
        'ROBOCALL_AUTOMATISE': {
            'weight': 2.6,
            'label': 'Appel Automatisé Massif (Robocall)',
            'keywords': [
                'message automatique', 'automated message', 'voix robotique', 'robotic voice',
                'robocall', 'chinois', 'chinese embassy', 'ambassade de chine', 'demarchage agressif',
                'conduit d aeration', 'nettoyage de conduits', 'press 1'
            ]
        }
    }

    @classmethod
    def analyze(cls, spam_comments: list[str], safe_comments: list[str]) -> dict:
        """
        Analyse sémantique croisée avec détection d'usurpation paradoxale et pondération TF-IDF.
        """
        all_safe_text = " ".join([normalize_text(c) for c in safe_comments if c])
        all_spam_text = " ".join([normalize_text(c) for c in spam_comments if c])
        combined_text = f"{all_safe_text} {all_spam_text}".strip()

        legitimacy_score = 0.0
        threat_score = 0.0
        detected_entities = []
        xai_factors = []

        # 1. Détection d'usurpation paradoxale (Adversarial Impersonation)
        impersonation = AdversarialImpersonationDetector.detect(combined_text)
        is_impersonation = impersonation['is_impersonation']

        # 2. Analyse des expressions de légitimité
        for domain_key, domain_data in cls.LEGITIMATE_LEXICON.items():
            matches = [kw for kw in domain_data['keywords'] if kw in combined_text]
            if matches:
                # Term Frequency avec atténuation logarithmique
                tf_factor = 1.0 + math.log(len(matches))
                weight = domain_data['weight'] * tf_factor

                # Un avis dans un SafeReport confirme directement la légitimité
                in_safe = [kw for kw in domain_data['keywords'] if kw in all_safe_text]
                if in_safe:
                    weight *= 1.8

                # Si tentative d'usurpation détectée dans un commentaire de spam, neutraliser la légitimité
                if is_impersonation and not in_safe:
                    weight = 0.0

                if weight > 0:
                    legitimacy_score += weight
                    entity_label = f"{domain_data['label']} ({', '.join(matches[:2])})"
                    if entity_label not in detected_entities:
                        detected_entities.append(entity_label)
                    xai_factors.append({
                        'type': 'LEGITIMACY',
                        'impact': 'POSITIVE',
                        'weight': min(45, int(weight * 5)),
                        'description': f"Sémantique de service légitime identifiée : {domain_data['label']}"
                    })

        # 3. Analyse des expressions de menace ou fraude
        for domain_key, domain_data in cls.THREAT_LEXICON.items():
            matches = [kw for kw in domain_data['keywords'] if kw in all_spam_text or kw in combined_text]
            if matches:
                tf_factor = 1.0 + math.log(len(matches))
                weight = domain_data['weight'] * tf_factor
                threat_score += weight
                entity_label = f"{domain_data['label']} ({', '.join(matches[:2])})"
                if entity_label not in detected_entities:
                    detected_entities.append(entity_label)
                xai_factors.append({
                    'type': 'THREAT',
                    'impact': 'NEGATIVE',
                    'weight': min(50, int(weight * 6)),
                    'description': f"Sémantique de fraude/usurpation détectée : {domain_data['label']}"
                })

        # 4. Pénalité d'usurpation paradoxale
        if is_impersonation:
            threat_score += 45.0
            xai_factors.append({
                'type': 'ADVERSARIAL_IMPERSONATION',
                'impact': 'NEGATIVE',
                'weight': 50,
                'description': "Scénario d'usurpation : invocation d'un organisme officiel associée à une extorsion financière."
            })

        # Normalisation des scores sur [0, 100]
        norm_legitimacy = min(100.0, round(legitimacy_score * 4.5, 1))
        norm_threat = min(100.0, round(threat_score * 5.0, 1))

        return {
            'legitimacy_score': norm_legitimacy,
            'threat_score': norm_threat,
            'is_impersonation': is_impersonation,
            'detected_entities': detected_entities[:4],
            'xai_factors': xai_factors
        }

    @classmethod
    def analyze_comments(cls, comments: list[str]) -> tuple[float, list[str]]:
        """
        Méthode utilitaire d'analyse directe d'une liste de commentaires.
        Retourne (score, entités) : score > 0 pour légitimité, score < 0 pour menace.
        """
        res = cls.analyze(spam_comments=comments, safe_comments=[])
        net_score = res['legitimacy_score'] - res['threat_score']
        return net_score, res['detected_entities']


class ShieldNetAIEngine:
    """
    Moteur de diagnostic et d'arbitrage multimodal.
    Combine l'analyse sémantique TF-IDF, la détection d'usurpation, l'entropie de Shannon des chiffres,
    l'amortissement temporel (demi-vie 90j) et la réputation pour une prise de décision explicable.
    """

    NANP_PATTERN = re.compile(r'^\+1[2-9]\d{2}[2-9]\d{6}$')
    NANP_FICTITIOUS_555 = re.compile(r'^\+1\d{3}55501\d{2}$') # +1-xxx-555-0100 to 0199

    @classmethod
    def diagnose(cls, phone_number: str = None, phone_hash: str = None, attestation: str = None) -> dict:
        """
        Génère une évaluation détaillée et explicable pour un numéro ou une empreinte donnée.
        """
        import time
        start_time = time.perf_counter()

        if phone_number and not phone_hash:
            phone_hash = hash_phone_number(phone_number)
        elif not phone_hash:
            return {'error': "Aucun numéro ou empreinte fourni."}

        # Récupération des données associées au numéro en base
        number_obj = BlacklistedNumber.objects.filter(phone_hash=phone_hash).first()
        spam_reports = list(SpamReport.objects.filter(phone_hash=phone_hash).order_by('-created_at'))
        safe_reports = list(SafeReport.objects.filter(phone_hash=phone_hash).order_by('-created_at'))

        spam_comments = [s.comment for s in spam_reports if s.comment]
        safe_comments = [r.comment for r in safe_reports if r.comment]
        masked = number_obj.masked_number if number_obj and number_obj.masked_number else (
            mask_phone_number(phone_number) if phone_number else '***'
        )

        # 1. Analyse sémantique NLP avec détection d'usurpation
        nlp_res = NLPSemanticAnalyzer.analyze(spam_comments, safe_comments)
        legit_score = nlp_res['legitimacy_score']
        threat_score = nlp_res['threat_score']
        is_impersonation = nlp_res.get('is_impersonation', False)
        xai_factors = list(nlp_res['xai_factors'])

        # 2. Amortissement temporel exponentiel (Demi-vie de 90 jours pour numéros recyclés)
        decayed_spam_weight = sum(
            TemporalDecayService.calculate_decay_weight(s.created_at) for s in spam_reports
        )
        decayed_safe_weight = sum(
            TemporalDecayService.calculate_decay_weight(r.created_at) for r in safe_reports
        )

        spam_count = len(spam_reports)
        safe_count = len(safe_reports)
        total_interactions = spam_count + safe_count
        safe_ratio = (safe_count / total_interactions) if total_interactions > 0 else 0.0

        # Vélocité horaire (signalements récents reçus au cours des 2 dernières heures)
        two_hours_ago = timezone.now() - timedelta(hours=2)
        recent_spam = sum(1 for s in spam_reports if s.created_at and s.created_at >= two_hours_ago)
        velocity_risk = min(100.0, recent_spam * 25.0)
        if recent_spam >= 2:
            xai_factors.append({
                'type': 'VELOCITY',
                'impact': 'NEGATIVE',
                'weight': min(35, recent_spam * 15),
                'description': f"Pic d'activité suspect : {recent_spam} signalement(s) en moins de 2 heures."
            })

        # Pureté catégorielle des infractions signalées
        categories = [s.category for s in spam_reports]
        high_risk_categories = sum(1 for c in categories if c in ['fraud', 'financial_scam', 'phishing', 'robocall'])
        high_risk_ratio = (high_risk_categories / spam_count) if spam_count > 0 else 0.0
        if high_risk_ratio >= 0.75 and spam_count >= 2:
            threat_score = min(100.0, threat_score + 25.0)
            xai_factors.append({
                'type': 'CATEGORY_PURITY',
                'impact': 'NEGATIVE',
                'weight': 20,
                'description': f"Forte convergence citoyenne vers des infractions criminelles ({int(high_risk_ratio * 100)}% de fraude/phishing)."
            })

        # 3. Analyse d'entropie spectrale de Shannon et structure NANP
        is_fictitious_555 = False
        entropy_eval = {'entropy': 0.0, 'is_synthetic': False}
        if phone_number:
            raw_clean = re.sub(r'\D', '', phone_number)
            norm_num = f"+{raw_clean}" if phone_number.startswith('+') else (f"+1{raw_clean}" if len(raw_clean) == 10 else f"+{raw_clean}")

            entropy_eval = ShannonEntropyAnalyzer.evaluate_entropy_risk(phone_number)
            if entropy_eval['is_synthetic']:
                threat_score = min(100.0, threat_score + 30.0)
                xai_factors.append({
                    'type': 'ENTROPY_ANOMALY',
                    'impact': 'NEGATIVE',
                    'weight': 30,
                    'description': entropy_eval['description']
                })

            if cls.NANP_FICTITIOUS_555.match(norm_num):
                is_fictitious_555 = True
                xai_factors.append({
                    'type': 'TELECOM_STRUCTURE',
                    'impact': 'NEGATIVE',
                    'weight': 35,
                    'description': "Numéro appartenant à la plage fictive 555-01xx réservée aux tests/cinéma."
                })
                threat_score = max(threat_score, 85.0)
            elif not cls.NANP_PATTERN.match(norm_num):
                xai_factors.append({
                    'type': 'TELECOM_STRUCTURE',
                    'impact': 'NEGATIVE',
                    'weight': 25,
                    'description': "Format ou indicatif non standard dans le plan de numérotation nord-américain."
                })

        # Facteur positif de consensus communautaire
        if safe_count > 0:
            xai_factors.append({
                'type': 'COMMUNITY_CONSENSUS',
                'impact': 'POSITIVE',
                'weight': min(40, safe_count * 15),
                'description': f"Présence de {safe_count} avis légitimes / contestations citoyennes favorables."
            })

        # Prise en compte du protocole STIR/SHAKEN (FCC / CRTC)
        clean_attestation = (attestation or '').strip().upper()
        if clean_attestation == 'A':
            legit_score += 25.0
            threat_score = max(0.0, threat_score - 20.0)
            xai_factors.append({
                'type': 'STIR_SHAKEN',
                'impact': 'POSITIVE',
                'weight': 30,
                'description': "Attestation STIR/SHAKEN Niveau A (Signature cryptographique pleine par l'opérateur source)."
            })
        elif clean_attestation == 'C':
            threat_score = min(100.0, threat_score + 25.0)
            xai_factors.append({
                'type': 'STIR_SHAKEN',
                'impact': 'NEGATIVE',
                'weight': 25,
                'description': "Attestation STIR/SHAKEN Niveau C (Appel acheminé via passerelle VoIP sans validation d'origine)."
            })
        elif clean_attestation == 'B':
            xai_factors.append({
                'type': 'STIR_SHAKEN',
                'impact': 'NEGATIVE',
                'weight': 10,
                'description': "Attestation STIR/SHAKEN Niveau B (Authenticité partielle du trunk SIP d'entreprise)."
            })

        # 4. Calcul du score de risque composite ajusté temporellement
        raw_composite_risk = (
            (threat_score * 0.40) +
            (velocity_risk * 0.25) +
            (min(100, decayed_spam_weight * 18) * 0.25) -
            (legit_score * 0.50) -
            (safe_ratio * 40.0)
        )

        if is_fictitious_555 and spam_count >= 1:
            raw_composite_risk = max(raw_composite_risk, 88.0)

        ai_risk_score = max(0, min(100, int(round(raw_composite_risk))))

        # Décision administrative humaine souveraine
        if number_obj and number_obj.is_whitelisted:
            ai_risk_score = 0
            xai_factors.insert(0, {
                'type': 'ADMIN_DECISION',
                'impact': 'POSITIVE',
                'weight': 100,
                'description': "Numéro officiellement réhabilité et blanchi par l'administration SOC."
            })
        elif number_obj and number_obj.is_blocked and number_obj.risk_score >= 80:
            ai_risk_score = max(ai_risk_score, 85)

        # 5. Indice de confiance de Faux-Positif (0 à 100%)
        if not is_impersonation and (legit_score > 20 or safe_ratio >= 0.35 or safe_count >= 1):
            raw_fp_confidence = (legit_score * 0.55) + (safe_ratio * 45.0) - (threat_score * 0.20)
            fp_confidence = max(15.0, min(98.5, round(raw_fp_confidence, 1)))
        else:
            fp_confidence = max(0.0, min(20.0, round(10.0 - (ai_risk_score * 0.1), 1)))

        # 6. Décision algorithmique finale et recommandation
        if number_obj and number_obj.is_whitelisted:
            verdict = "REHABILITE_BLANCHI"
            verdict_label = "Blanchi & Réhabilité"
            recommendation = "NONE"
            recommendation_label = "Aucune action nécessaire"
            confidence_level = 100.0
            badge_class = "badge-safe"
        elif fp_confidence >= 65.0 and ai_risk_score <= 45:
            verdict = "FAUX_POSITIF_CONFIRME"
            verdict_label = "Faux-Positif Confirmé (Service Essentiel)"
            recommendation = "AUTO_WHITELIST"
            recommendation_label = "Blanchir Immédiatement (Recommandé)"
            confidence_level = fp_confidence
            badge_class = "badge-safe"
        elif ai_risk_score >= 70:
            verdict = "CYBER_MENACE_CRITIQUE"
            verdict_label = "Menace Télécom Critique Confirmée"
            recommendation = "ESCALATE_BLOCK"
            recommendation_label = "Bloquer sur Tout le Réseau"
            confidence_level = round(min(99.0, 50.0 + (ai_risk_score * 0.49)), 1)
            badge_class = "badge-critical"
        elif ai_risk_score >= 35:
            verdict = "SUSPECT_SURVEILLANCE"
            verdict_label = "Activité Suspecte sous Surveillance"
            recommendation = "MONITOR"
            recommendation_label = "Surveiller les Prochains Appels"
            confidence_level = 65.0
            badge_class = "badge-warning"
        else:
            verdict = "SAIN_NEUTRE"
            verdict_label = "Numéro Réputé Sain"
            recommendation = "NONE"
            recommendation_label = "Conforme aux Normes Télécom"
            confidence_level = 92.0
            badge_class = "badge-safe"

        # Synthèse explicative
        if verdict == "FAUX_POSITIF_CONFIRME":
            summary = (
                f"Probabilité élevée de faux-positif ({fp_confidence}%). "
                f"L'analyse des commentaires indique un service légitime "
                f"({', '.join(nlp_res['detected_entities']) or 'service vérifié'}) et les avis positifs "
                f"sont supérieurs aux signalements négatifs."
            )
        elif verdict == "CYBER_MENACE_CRITIQUE":
            summary = (
                f"Numéro identifié comme menace indésirable (Score {ai_risk_score}/100). "
                f"Des motifs d'escroquerie ont été détectés "
                f"({', '.join(nlp_res['detected_entities']) or 'signalements récents'})."
            )
        elif verdict == "SUSPECT_SURVEILLANCE":
            summary = (
                f"Numéro à risque modéré ({ai_risk_score}/100). Signalements encore limités, "
                f"placé sous surveillance active."
            )
        else:
            summary = "Aucune anomalie ou motif d'arnaque identifié pour ce numéro."

        elapsed_ms = (time.perf_counter() - start_time) * 1000.0

        # Normalisation des facteurs d'explicabilité XAI
        formatted_xai = []
        for factor in xai_factors:
            is_pos = factor.get('impact') == 'POSITIVE' or factor.get('direction') == 'positive'
            desc = factor.get('description') or factor.get('factor') or ''
            formatted_xai.append({
                'type': factor.get('type', 'GENERAL'),
                'impact': 'POSITIVE' if is_pos else 'NEGATIVE',
                'direction': 'positive' if is_pos else 'threat',
                'weight': factor.get('weight', 0),
                'description': desc,
                'factor': desc,
            })

        return {
            'success': True,
            'phone_number': phone_number or masked,
            'phone_hash': phone_hash,
            'masked_number': masked,
            'ai_risk_score': ai_risk_score,
            'composite_risk_score': ai_risk_score,
            'false_positive_confidence': fp_confidence,
            'confidence_level': confidence_level,
            'verdict': verdict,
            'verdict_label': verdict_label,
            'badge_class': badge_class,
            'recommendation': recommendation,
            'recommendation_label': recommendation_label,
            'detected_entities': nlp_res['detected_entities'],
            'extracted_entities': nlp_res['detected_entities'],
            'xai_factors': formatted_xai,
            'diagnostic_summary': summary,
            'verdict_description': summary,
            'execution_time_ms': round(max(0.1, elapsed_ms), 2),
            'metrics': {
                'spam_reports': spam_count,
                'decayed_spam_weight': round(decayed_spam_weight, 2),
                'safe_reports': safe_count,
                'decayed_safe_weight': round(decayed_safe_weight, 2),
                'safe_ratio_pct': round(safe_ratio * 100, 1),
                'velocity_recent_2h': recent_spam,
                'digit_entropy': entropy_eval['entropy'],
                'is_synthetic_entropy': entropy_eval['is_synthetic'],
                'is_impersonation_attack': is_impersonation,
                'nlp_legitimacy_score': legit_score,
                'nlp_threat_score': threat_score,
                'stir_shaken_attestation': clean_attestation if clean_attestation in ('A', 'B', 'C') else None,
            }
        }
