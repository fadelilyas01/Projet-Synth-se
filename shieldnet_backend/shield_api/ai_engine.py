"""
ShieldNet Enterprise — Moteur d'Intelligence Artificielle & d'Arbitrage des Faux-Positifs (2026)
Architecture Hybride : NLP Sémantique Multilingue (FR/EN) + Modèle Comportemental & XAI (Explainable AI)
Laboratoire de Cybersécurité & Télécommunications — Université du Québec en Outaouais (UQO)
"""

import re
import math
import unicodedata
from datetime import timedelta
from django.utils import timezone
from .models import BlacklistedNumber, SpamReport, SafeReport
from .services import hash_phone_number, mask_phone_number, AutomatedSpamVerifier

def normalize_text(text: str) -> str:
    """Normalise une chaîne de caractères (minuscules, suppression des accents et ponctuation)."""
    if not text:
        return ""
    text = unicodedata.normalize('NFKD', text)
    text = "".join([c for c in text if not unicodedata.combining(c)])
    text = text.lower()
    text = re.sub(r'[^a-z0-9\s]', ' ', text)
    return re.sub(r'\s+', ' ', text).strip()


class NLPSemanticAnalyzer:
    """
    Classificateur sémantique de traitement du langage naturel (NLP).
    Analyse les commentaires citoyens libres (FR & EN) pour identifier les intentions réelles,
    distinguer les faux-positifs (services essentiels) des véritables attaques cyber-télécoms.
    """

    # Marqueurs sémantiques de légitimité institutionnelle et de services essentiels
    LEGITIMATE_LEXICON = {
        'SANTE_MEDICAL': {
            'weight': 3.5,
            'label': 'Service Médical ou Urgence Santé',
            'keywords': [
                'hopital', 'hospital', 'clinique', 'clinic', 'medecin', 'doctor', 'docteur',
                'sante', 'health', 'pharmacie', 'pharmacy', 'dentiste', 'dentist', 'infirmiere',
                'nurse', 'clsc', 'chsld', 'pediatre', 'rendez vous', 'appointment', 'rappel rdv',
                'laboratoire', 'analyse sanguine', 'vaccination', 'urgence 811', 'jean coutu',
                'familiprix', 'pharmaprix', 'uniprix'
            ]
        },
        'LIVRAISON_MESSAGERIE': {
            'weight': 2.8,
            'label': 'Transporteur & Livraison Légitime',
            'keywords': [
                'livraison', 'delivery', 'livreur', 'courier', 'doordash', 'uber eats', 'ubereats',
                'skip', 'skipthedishes', 'fedex', 'ups', 'dhl', 'purolator', 'postes canada',
                'canada post', 'amazon', 'colis a la porte', 'chauffeur'
            ]
        },
        'BANQUE_SERVICES_PUBLICS': {
            'weight': 3.0,
            'label': 'Institution Bancaire ou Service Public Reconnu',
            'keywords': [
                'hydro quebec', 'hydroquebec', 'hydro', 'desjardins', 'caisse populaire', 'rbc',
                'td', 'bmo', 'scotia', 'cibc', 'banque nationale', 'assurance', 'insurance',
                'ecole', 'school', 'universite', 'university', 'uqo', 'cegep', 'garderie',
                'daycare', 'ville de gatineau', 'ville d ottawa', 'municipalite', 'employeur'
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

    # Marqueurs sémantiques de cybermenace, extorsion et arnaque avérée
    THREAT_LEXICON = {
        'USURPATION_GOUVERNEMENTALE': {
            'weight': 4.0,
            'label': 'Usurpation d\'Identité Gouvernementale / Légale',
            'keywords': [
                'agence du revenu', 'revenu canada', 'arc', 'cra', 'impot', 'taxes', 'police',
                'grc', 'rcmp', 'sq', 'opp', 'arrestation', 'arrest', 'mandat d arret', 'warrant',
                'tribunal', 'court', 'service canada', 'douane', 'frontiere', 'cbsa', 'immigration'
            ]
        },
        'EXTORSION_FINANCIERE': {
            'weight': 3.8,
            'label': 'Extorsion Financière & Vol d\'Identité',
            'keywords': [
                'carte cadeau', 'gift card', 'itunes', 'apple card', 'bitcoin', 'crypto',
                'cryptomonnaie', 'virement interac', 'wire transfer', 'western union', 'dette',
                'huissier', 'compte suspendu', 'compte bloque', 'nas', 'sin', 'assurance sociale',
                'social insurance', 'frais non payes'
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
                'conduit d aeration', 'nettoyage de conduits'
            ]
        }
    }

    @classmethod
    def analyze(cls, spam_comments: list[str], safe_comments: list[str]) -> dict:
        """
        Analyse sémantique croisée de l'ensemble des commentaires citoyens d'un numéro.
        """
        all_safe_text = " ".join([normalize_text(c) for c in safe_comments if c])
        all_spam_text = " ".join([normalize_text(c) for c in spam_comments if c])

        legitimacy_score = 0.0
        threat_score = 0.0
        detected_entities = []
        xai_factors = []

        # 1. Évaluation des signaux de légitimité
        combined_text = f"{all_safe_text} {all_spam_text}".strip()
        
        for domain_key, domain_data in cls.LEGITIMATE_LEXICON.items():
            matches = [kw for kw in domain_data['keywords'] if kw in combined_text]
            if matches:
                weight = domain_data['weight'] * len(matches)
                # Un avis dans un SafeReport compte double
                in_safe = [kw for kw in domain_data['keywords'] if kw in all_safe_text]
                if in_safe:
                    weight *= 1.8

                legitimacy_score += weight
                detected_entities.append(f"{domain_data['label']} ({', '.join(matches[:2])})")
                xai_factors.append({
                    'type': 'LEGITIMACY',
                    'impact': 'POSITIVE',
                    'weight': min(45, int(weight * 5)),
                    'description': f"Sémantique de service légitime identifiée : {domain_data['label']}"
                })

        # 2. Évaluation des signaux de menace cyber
        for domain_key, domain_data in cls.THREAT_LEXICON.items():
            matches = [kw for kw in domain_data['keywords'] if kw in all_spam_text]
            if matches:
                weight = domain_data['weight'] * len(matches)
                threat_score += weight
                detected_entities.append(f"{domain_data['label']} ({', '.join(matches[:2])})")
                xai_factors.append({
                    'type': 'THREAT',
                    'impact': 'NEGATIVE',
                    'weight': min(50, int(weight * 6)),
                    'description': f"Sémantique de fraude/usurpation détectée : {domain_data['label']}"
                })

        # Normalisation des scores sur [0, 100]
        norm_legitimacy = min(100.0, round(legitimacy_score * 4.5, 1))
        norm_threat = min(100.0, round(threat_score * 5.0, 1))

        return {
            'legitimacy_score': norm_legitimacy,
            'threat_score': norm_threat,
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
    Moteur Décisionnel d'Intelligence Artificielle & de Réconciliation Hybride.
    Combine l'analyse NLP des textes, la télémétrie de vélocité et les structures NANP (+1)
    pour produire un diagnostic prédictif de pointe et expliquer chaque décision au SOC.
    """

    NANP_PATTERN = re.compile(r'^\+1[2-9]\d{2}[2-9]\d{6}$')
    NANP_FICTITIOUS_555 = re.compile(r'^\+1\d{3}55501\d{2}$') # +1-xxx-555-0100 to 0199

    @classmethod
    def diagnose(cls, phone_number: str = None, phone_hash: str = None) -> dict:
        """
        Génère le diagnostic complet d'intelligence artificielle pour un numéro.
        """
        import time
        start_time = time.perf_counter()

        if phone_number and not phone_hash:
            phone_hash = hash_phone_number(phone_number)
        elif not phone_hash:
            return {'error': "Aucun numéro ou empreinte fourni."}

        # 1. Extraction des données BDD
        number_obj = BlacklistedNumber.objects.filter(phone_hash=phone_hash).first()
        spam_reports = list(SpamReport.objects.filter(phone_hash=phone_hash).order_by('-created_at'))
        safe_reports = list(SafeReport.objects.filter(phone_hash=phone_hash).order_by('-created_at'))

        spam_comments = [s.comment for s in spam_reports if s.comment]
        safe_comments = [r.comment for r in safe_reports if r.comment]
        masked = number_obj.masked_number if number_obj and number_obj.masked_number else (
            mask_phone_number(phone_number) if phone_number else '***'
        )

        # 2. Analyse Sémantique NLP
        nlp_res = NLPSemanticAnalyzer.analyze(spam_comments, safe_comments)
        legit_score = nlp_res['legitimacy_score']
        threat_score = nlp_res['threat_score']
        xai_factors = list(nlp_res['xai_factors'])

        # 3. Analyse Comportementale & Télémétrie Télécom
        spam_count = len(spam_reports)
        safe_count = len(safe_reports)
        total_interactions = spam_count + safe_count
        safe_ratio = (safe_count / total_interactions) if total_interactions > 0 else 0.0

        # Vélocité horaire (signalements reçus au cours des 2 dernières heures)
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

        # Pureté catégorielle des menaces (consensus de gravité)
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

        # Analyse structurelle NANP
        is_fictitious_555 = False
        if phone_number:
            raw_clean = re.sub(r'\D', '', phone_number)
            norm_num = f"+{raw_clean}" if phone_number.startswith('+') else (f"+1{raw_clean}" if len(raw_clean) == 10 else f"+{raw_clean}")
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

        # Pondération des avis sûrs (Safe Reports)
        if safe_count > 0:
            xai_factors.append({
                'type': 'COMMUNITY_CONSENSUS',
                'impact': 'POSITIVE',
                'weight': min(40, safe_count * 15),
                'description': f"Présence de {safe_count} avis légitimes / contestations citoyennes favorables."
            })

        # 4. Calcul Composite du Score de Risque IA & Confiance de Faux-Positif
        raw_composite_risk = (
            (threat_score * 0.40) +
            (velocity_risk * 0.25) +
            (min(100, spam_count * 18) * 0.25) -
            (legit_score * 0.50) -
            (safe_ratio * 40.0)
        )
        # Numéro fictif NANP avéré avec signalements -> usurpation technique confirmée
        if is_fictitious_555 and spam_count >= 1:
            raw_composite_risk = max(raw_composite_risk, 88.0)

        ai_risk_score = max(0, min(100, int(round(raw_composite_risk))))

        # Préservation de décision administrative humaine
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

        # Calcul de la Confiance de Faux-Positif (0 à 100%)
        if legit_score > 20 or safe_ratio >= 0.35 or safe_count >= 1:
            raw_fp_confidence = (legit_score * 0.55) + (safe_ratio * 45.0) - (threat_score * 0.20)
            fp_confidence = max(15.0, min(98.5, round(raw_fp_confidence, 1)))
        else:
            fp_confidence = max(0.0, min(20.0, round(10.0 - (ai_risk_score * 0.1), 1)))

        # 5. Détermination du Verdict et Recommandation Actionnable
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

        # Résumé explicatif causal (XAI Summary)
        if verdict == "FAUX_POSITIF_CONFIRME":
            summary = (
                f"Ce numéro présente une forte probabilité de faux-positif ({fp_confidence}%). "
                f"L'analyse NLP a identifié des signaux de services essentiels légitimes "
                f"({', '.join(nlp_res['detected_entities']) or 'service régulier'}) et les contestations citoyennes "
                f"surpassent les signalements spams isolés."
            )
        elif verdict == "CYBER_MENACE_CRITIQUE":
            summary = (
                f"Ce numéro est évalué comme une cybermenace critique (Score {ai_risk_score}/100). "
                f"L'algorithme a détecté des patterns de fraude caractérisée "
                f"({', '.join(nlp_res['detected_entities']) or 'campagne agressive'}) avec une vélocité élevée."
            )
        elif verdict == "SUSPECT_SURVEILLANCE":
            summary = (
                f"Numéro à risque modéré ({ai_risk_score}/100). Le volume de signalements est encore insuffisant "
                f"pour confirmer une campagne criminelle sans risque de faux-positif."
            )
        else:
            summary = "Aucune signature malveillante ou anomalie télécom détectée à ce jour pour ce numéro."

        elapsed_ms = (time.perf_counter() - start_time) * 1000.0

        # Normalisation universelle des facteurs explicatifs XAI (FR/EN)
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
                'safe_reports': safe_count,
                'safe_ratio_pct': round(safe_ratio * 100, 1),
                'velocity_recent_2h': recent_spam,
                'nlp_legitimacy_score': legit_score,
                'nlp_threat_score': threat_score,
            }
        }
