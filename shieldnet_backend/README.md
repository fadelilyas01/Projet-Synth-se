# 🛡️ ShieldNet Backend — API REST, Moteur d'IA & Console SOC (Django)

[![Django](https://img.shields.io/badge/Django-5.x-092E20?logo=django)](https://www.djangoproject.com)
[![DRF](https://img.shields.io/badge/Django%20REST-Framework-red)](https://www.django-rest-framework.org)
[![OpenAPI](https://img.shields.io/badge/OpenAPI-3.0%20(Swagger)-85EA2D?logo=swagger)](http://127.0.0.1:8000/api/v1/docs/)
[![Tests](https://img.shields.io/badge/Tests%20Backend-45%2F45%20Pass%20(100%25)-success.svg)]()
[![Propriété](https://img.shields.io/badge/Propriété-UQO-004f9e.svg)](https://uqo.ca)

Backend officiel du **Projet de Synthèse ShieldNet** — Université du Québec en Outaouais (UQO).  
Conçu et développé avec **Python 3.12**, **Django 5**, **Django REST Framework (DRF)**, **SimpleJWT**, **drf-spectacular (OpenAPI 3.0)** et un **Moteur d'IA Sémantique & XAI natif**.

---

## 🏛️ Architecture & Logique Métier

Le backend orchestre la gouvernance de sécurité entre les clients mobiles et les équipes SOC :

```text
[Application Mobile (Utilisateur)]
         │
         ├── 1. Signalement de spam anonymisé HMAC-SHA256 (POST /api/v1/reports/)
         ├── 2. Soumission d'avis de légitimité / contestation (POST /api/v1/reports/safe/)
         ├── 3. Téléchargement de la liste noire certifiée (GET /api/v1/blacklist/)
         ├── 4. Vérification d'un numéro et score de consensualité (GET /api/v1/check/<hash>/)
         ├── 5. Audit de consensualité en temps réel (GET /api/v1/consensus/<hash>/)
         └── 6. Diagnostic d'arbitrage prédictif IA (GET ou POST /api/v1/ai/diagnose/)
         │
         ▼
[Moteur d'Intelligence Artificielle ShieldNet (ShieldNetAIEngine & NLPSemanticAnalyzer)]
         │
         ├── Analyse NLP bilingue (FR/EN) des intentions et motifs de signalements
         ├── Protection et réhabilitation automatique des services essentiels (Santé, Livraison, Banques, Services Publics)
         ├── Détection structurelle des numéros fictifs NANP (+1) et spoofing CLI (plages 555-01xx)
         ├── Indice de confiance de faux-positif (0 à 100%) et score de risque composite (0 à 100)
         └── Facteurs d'attribution causale transparents (XAI - Explainable AI)
         │
         ▼
[Serveur Django & Console Web SOC]
         │
         ├── Laboratoire Sandbox (/admin/operations/sandbox/) avec testeur IA en direct
         ├── Centre de Triage Rapide (/admin/operations/triage/) avec pastilles IA
         ├── Rapport Exécutif de Sécurité (/admin/operations/report/executive/)
         ├── Télémétrie en Direct (/admin/operations/telemetry/live/)
         ├── Export CSV universel PBX/Asterisk (/admin/operations/export/csv/)
         └── Actions Administrateur :
               ├── 'Approuver et Bloquer' : Confirme un numéro malveillant (is_blocked=True)
               ├── 'Débloquer et Blanchir' : Décision manuelle souveraine (is_whitelisted=True)
               └── 'Audit Consensus' : Réhabilitation globale automatique des faux positifs
```

---

## 🧠 Moteur d'Intelligence Artificielle & Arbitrage des Faux Positifs

Le module [`shield_api/ai_engine.py`](file:///C:/Projet/Projet%20synthese/shieldnet_backend/shield_api/ai_engine.py) apporte une solution concrète et robuste au problème des faux positifs :

1. **`NLPSemanticAnalyzer` (Bilingue FR / EN)** :
   - **Services protégés** : Hôpitaux, cliniques, CLSC, CHSLD, médecins, dentistes, pharmacies, transporteurs de colis (Amazon, Postes Canada, FedEx, UPS, UberEats), institutions financières et services publics (Hydro-Québec, universités, UQO, villes).
   - **Signaux de cybermenaces** : Usurpation gouvernementale (ARC/CRA, GRC/RCMP, mandats d'arrêt), extorsion financière (cartes cadeaux, bitcoins, suspension de NAS/SIN), hameçonnage SMS/VoIP et robocalls.
2. **`ShieldNetAIEngine` (Moteur Prédictif & XAI)** :
   - **Formule de risque composite** intégrant sémantique NLP, ratio d'avis légitimes (*SafeReports*), vélocité horaire (pics sur 2h) et structure NANP.
   - **Détection des plages fictives NANP** : Les numéros `555-01xx` sont mathématiquement impossibles à assigner dans le plan nord-américain et sont détectés instantanément comme des usurpations CLI criminelles (`Score >= 88/100`).
   - **Recommandations actionnables** : `AUTO_WHITELIST` (réhabilitation immédiate), `ESCALATE_BLOCK` (blocage réseau d'urgence), `MONITOR` (surveillance) ou `SAFE_REPUTATION`.
   - **Facteurs causaux XAI** quantifiés en pourcentage pour guider l'opérateur SOC.
   - **Latence d'inférence ultra-rapide** : Inférence en **$< 1\text{ ms}$** sur processeur standard (pure-Python sans dépendance lourde).

---

## 📡 Endpoints REST API v1

Tous les points d'accès mobiles sont protégés par le contrôle d'en-tête `X-API-Key` ou par jeton JWT :

### Endpoints Publics, Mobiles & Moteur d'IA
* **`POST /api/v1/ai/diagnose/` & `GET /api/v1/ai/diagnose/`** : **Diagnostic complet d'intelligence artificielle, arbitrage de faux positif et facteurs XAI.**
* `GET /api/v1/health/` : Sonde de disponibilité et santé système (Liveness & Readiness probe).
* `GET /api/v1/sync/status/` : Vérification ultra-rapide de l'état de synchronisation de la liste noire.
* `GET /api/v1/blacklist/` : Liste noire active (score $\ge 30$, non blanchis) pour le cache SQLite mobile.
* `POST /api/v1/reports/` : Enregistrement d'un signalement spam avec limitation de débit.
* `POST /api/v1/reports/safe/` : Soumission d'un avis favorable / contestation avec arbitrage automatique.
* `GET /api/v1/check/<phone_hash>/` : Vérification instantanée du statut et du score de risque d'un numéro.
* `GET /api/v1/consensus/<phone_hash>/` : Consultation des métriques de consensus et quorum.
* `POST /api/v1/auth/login/` : Authentification utilisateur et administrateur via JWT.
* `POST /api/v1/auth/register/` : Inscription d'un nouvel utilisateur.
* `GET /api/v1/auth/me/` : Informations sur l'utilisateur connecté.
* `GET /api/v1/docs/` : Interface interactive Swagger OpenAPI 3.0.

### Endpoints Console d'Administration Web & Mobile (`is_staff=True`)
* `GET /api/v1/admin/stats/` : Métriques globales de supervision.
* `GET /api/v1/admin/blacklist/` : Gestion de la liste noire avec pagination, recherche et filtrage.
* `POST /api/v1/admin/blacklist/` : Ajout manuel d'un numéro en liste noire.
* `DELETE /api/v1/admin/blacklist/<hash>/` : Suppression d'un numéro de la liste noire.
* `GET /api/v1/admin/reports/` : Liste complète des signalements pour modération.
* `GET /api/v1/admin/safe-reports/` : Consultation des avis de légitimité et contestations.
* `POST /api/v1/admin/consensus-audit/` : Balayage algorithmique global pour réhabilitation automatique.
* `GET /api/v1/admin/users/` : Consultation des utilisateurs et des rôles RBAC.
* `POST /api/v1/admin/purge/` : Purge sécurisée des signalements orphelins et obsolètes (> 30 jours).
* `GET /api/v1/admin/audit-logs/` : Journal d'audit inaltérable de toutes les opérations administratives.

---

## 🚀 Guide de Démarrage Rapide

### 1. Installation des dépendances
```bash
pip install -r requirements.txt
```

### 2. Application des migrations de base de données
```bash
python manage.py migrate
```

### 3. Initialisation du Compte Administrateur Unifié (Web & Mobile)
```bash
python manage.py ensure_admin
```
- **Courriel** : `admin@shieldnet.app` (ou identifiant `admin`)
- **Mot de passe par défaut** : `admin123` *(personnalisable via `ADMIN_PASSWORD` dans `.env`)*
- **Accès Web SOC** : [http://127.0.0.1:8000/admin/](http://127.0.0.1:8000/admin/)
- **Documentation OpenAPI** : [http://127.0.0.1:8000/api/v1/docs/](http://127.0.0.1:8000/api/v1/docs/)

### 4. Lancement de la Suite de Tests (45/45 — 100% de réussite)
```bash
python manage.py test shield_api
```

### 5. Démarrage du serveur local
```bash
python manage.py runserver 0.0.0.0:8000
```

---

## 🏛️ Mentions Légales
© 2026 Université du Québec en Outaouais (UQO) — Tous droits réservés.
