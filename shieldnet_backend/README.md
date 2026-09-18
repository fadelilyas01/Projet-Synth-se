# 🛡️ ShieldNet Backend — API REST & Console d'Administration (Django)

[![Django](https://img.shields.io/badge/Django-5.x-092E20?logo=django)](https://www.djangoproject.com)
[![DRF](https://img.shields.io/badge/Django%20REST-Framework-red)](https://www.django-rest-framework.org)
[![OpenAPI](https://img.shields.io/badge/OpenAPI-3.0%20(Swagger)-85EA2D?logo=swagger)](http://127.0.0.1:8000/api/v1/docs/)
[![Tests](https://img.shields.io/badge/Tests-25%2F25%20Pass-success.svg)]()

Backend officiel du **Projet de Synthèse ShieldNet** — Université du Québec en Outaouais (UQO).  
Conçu et développé avec **Django**, **Django REST Framework (DRF)**, **SimpleJWT**, et documentation interactive **OpenAPI 3.0 (drf-spectacular)**.

---

## 🏛️ Architecture & Logique Métier

Le backend orchestre la gouvernance collaborative entre les clients mobiles et les équipes de modération :

```text
[Application Mobile (Utilisateur)]
         │
         ├── 1. Soumission d'un signalement spam anonymisé (POST /api/v1/reports/)
         ├── 2. Soumission d'avis de légitimité / contestation (POST /api/v1/reports/safe/)
         ├── 3. Téléchargement de la liste noire certifiée (GET /api/v1/blacklist/)
         ├── 4. Vérification d'un numéro et score de consensualité (GET /api/v1/check/<hash>/)
         └── 5. Audit de consensualité en temps réel (GET /api/v1/consensus/<hash>/)
         │
         ▼
[Moteur de Consensualité Décentralisé (FalsePositiveConsensusService)]
         │
         ├── Calcul de la masse négative (M_spam) et favorable (M_safe)
         ├── Pondération de confiance par émetteur (Admin: 5.0x, Inscrit: 1.5x, Anonyme: 1.0x)
         ├── Facteur de normalité structurelle NANP (+1) via AutomatedSpamVerifier
         ├── Quorum & Seuil de consensualité : C(h) >= 55%
         └── ⚡ DÉTECTION ET RÉHABILITATION AUTOMATIQUE DES FAUX POSITIFS :
               Si le consensus est atteint -> is_whitelisted=True, is_blocked=False,
               risk_score=0, whitelist_reason='auto_consensus'.
         │
         ▼
[Serveur Django & Console d'Administration]
         │
         ├── Actions Administrateur :
         │     ├── 'Approuver et Bloquer' : Confirme un numéro malveillant
         │     ├── 'Débloquer et Blanchir' : Décision manuelle souveraine (manual_admin)
         │     └── 'Réévaluer la consensualité' : Audit et réévaluation automatique des faux positifs
         └── Purge sécurisée des signalements orphelins et des faux positifs
```

---

## ⚡ Moteur Algorithmique de Consensualité (Faux Positifs)

Afin d'éviter qu'un numéro légitime (médecin, école, livreur, contact personnel) ne reste bloqué à cause de signalements isolés, erronés ou malveillants, le backend intègre la **détection automatique par consensualité** :

1. **Quorum & Masse pondérée** :
   - Requiert au moins $Q = 2$ avis favorables indépendants (ou 1 avis administrateur).
   - $C(h) = \frac{M_{safe} \times \alpha}{M_{safe} \times \alpha + M_{spam}}$ où $\alpha$ favorise les structures de numéros conformes.
2. **Réhabilitation instantanée** :
   - Dès que le consensus légitime est validé ($C(h) \ge 55\%$), le numéro est immédiatement blanchi et retiré de la liste noire mobile sans intervention humaine requise.
3. **Protection anti-Sybil & Équilibre dynamique** :
   - Un utilisateur connecté ne peut voter qu'une seule fois par numéro.
   - Throttling strict par adresse IP pour les votes anonymes.
   - Si un numéro auto-consensuel subit ultérieurement une vague avérée de spams réels ($C(h) < 40\%$), le consensus est révoqué automatiquement.

---

## 📡 Endpoints REST API v1

Tous les points d'accès mobiles sont protégés par le contrôle d'en-tête `X-API-Key` :

### Endpoints Publics & Mobiles
* `GET /api/v1/blacklist/` : Liste noire active (score >= 30, non blanchis) pour le cache SQLite local.
* `POST /api/v1/reports/` : Enregistrement d'un signalement spam avec limitation de débit.
* `POST /api/v1/reports/safe/` : **Soumission d'un avis favorable / contestation avec détection automatique de faux positif par consensus.**
* `GET /api/v1/check/<phone_hash>/` : Vérification du statut d'un numéro (score de risque, volume, consensualité, statut).
* `GET /api/v1/consensus/<phone_hash>/` : **Détail en temps réel de l'évaluation algorithmique de consensualité.**
* `POST /api/v1/auth/login/` : Authentification utilisateur et administrateur via JWT.
* `POST /api/v1/auth/register/` : Inscription d'un nouvel utilisateur.
* `GET /api/v1/auth/me/` : Informations sur l'utilisateur connecté.
* `GET /api/v1/docs/` : Interface interactive Swagger OpenAPI 3.0.

### Endpoints Console d'Administration (Protégés par JWT Admin)
* `GET /api/v1/admin/stats/` : Métriques globales (utilisateurs, signalements, faux positifs auto-consensuels, etc.).
* `GET /api/v1/admin/blacklist/` : Gestion de la liste noire avec pagination, recherche et filtrage.
* `POST /api/v1/admin/blacklist/` : Ajout manuel d'un numéro par un administrateur.
* `DELETE /api/v1/admin/blacklist/<hash>/` : Suppression d'un numéro de la liste noire.
* `GET /api/v1/admin/reports/` : Liste complète des signalements pour modération.
* `GET /api/v1/admin/safe-reports/` : **Consultation de tous les avis légitimes et contestations communautaires.**
* `POST /api/v1/admin/consensus-audit/` : **Déclenchement d'un balayage complet de la base pour réhabilitation consensuelle automatique.**
* `GET /api/v1/admin/users/` : Consultation des utilisateurs enregistrés et de leurs rôles.
* `POST /api/v1/admin/purge/` : Purge des signalements orphelins et des entrées obsolètes.

---

## 🚀 Guide de Démarrage Rapide

### 1. Installation des dépendances
```bash
pip install -r requirements.txt
```

### 2. Exécution des migrations de base de données
```bash
python manage.py migrate
```

### 3. Compte Administrateur par défaut
Un compte administrateur dédié est configuré :
- **Courriel** : admin@shieldnet.app (ou identifiant admin)
- **Mot de passe** : admin123 *(configurable via la variable ADMIN_PASSWORD)*

### 4. Lancement des tests automatisés (100% de réussite)
```bash
python manage.py test shield_api
```

### 5. Démarrage du serveur local
```bash
python manage.py runserver 0.0.0.0:8000
```
