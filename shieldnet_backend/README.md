# ShieldNet Backend — API REST & Administration (Django)

Bienvenue dans la partie serveur de **ShieldNet**. Ce sous-projet regroupe l'API REST consommée par l'application mobile et l'interface web utilisée par les administrateurs pour modérer les signalements.

Il est développé avec **Python 3.12**, **Django 5** et **Django REST Framework (DRF)**.

---

## 1. Rôle du Backend

Le backend joue trois rôles principaux :

1. **Centraliser et distribuer la liste de réputation** : Les téléphones téléchargent la liste des numéros à bloquer et reçoivent uniquement les deltas (ajouts et retraits récents) lors des synchronisations périodiques.
2. **Collecter les signalements et contestations de manière anonyme** : Les clients envoient uniquement des empreintes cryptographiques **HMAC-SHA256**. Le serveur ne stocke aucun numéro en clair.
3. **Arbitrer les signalements pour éviter les faux positifs** : Quand un numéro est signalé, notre moteur vérifie le texte associé, contrôle la cohérence du numéro par rapport au plan téléphonique nord-américain (NANP), prend en compte les attestations STIR/SHAKEN et applique l'algorithme de consensus si des usagers indiquent qu'il s'agit d'un service légitime.

```text
[ Application Mobile Flutter ]
            │
            ├── Signalement de spam anonymisé HMAC (POST /api/v1/reports/)
            ├── Contestation d'un numéro légitime (POST /api/v1/reports/safe/)
            ├── Récupération incrémentale de la liste noire (GET /api/v1/blacklist/?since=...)
            ├── Vérification rapide unitaire ou par lot (GET /check/<hash>/ ou POST /check/batch/)
            └── Diagnostic avec explications (GET /api/v1/ai/diagnose/)
            │
            ▼
[ Moteur d'Arbitrage & Consensus (shield_api/ai_engine.py & services.py) ]
            │
            ├── Analyse sémantique bilingue (mots-clés santé, livraison, banques vs arnaques)
            ├── Détection des numéros fictifs 555-01xx (usurpation d'identité CLI)
            ├── Évaluation de l'attestation télécom STIR/SHAKEN (niveaux A, B, C)
            └── Algorithme de consensus : quorum de signalements sûrs pour réhabiliter un numéro
            │
            ▼
[ Console Web d'Administration (Django) & Base PostgreSQL / SQLite ]
            │
            ├── Triage en direct des signalements récents
            ├── Testeur de numéro interactif (Sandbox)
            ├── Métriques opérationnelles pour Prometheus (/api/v1/metrics/)
            └── Journal d'audit traçant chaque décision (AuditLog)
```

---

## 2. Le Moteur d'Arbitrage des Faux Positifs

Situé dans [`shield_api/ai_engine.py`](file:///C:/Projet/Projet%20synthese/shieldnet_backend/shield_api/ai_engine.py), ce module a été conçu pour résoudre le problème classique des usagers qui signalent leur médecin ou leur livreur par erreur :

* **Analyse de texte bilingue (FR / EN)** : Repère les termes fréquents liés aux services essentiels (hôpitaux, CLSC, pharmacies, livreurs, banques, universités) et les distingue des expressions typiques d'arnaques (menaces d'arrestation, faux mandats, réclamations de cartes-cadeaux ou de cryptomonnaie).
* **Détection du spoofing sur les plages réservées** : Les numéros `555-0100` à `0199` ne sont jamais attribués à de vrais abonnés en Amérique du Nord. Si un appel se présente avec un tel numéro, le moteur l'identifie immédiatement comme usurpé et augmente le niveau de risque.
* **Standard STIR/SHAKEN** : Si l'opérateur téléphonique fournit une attestation certifiée (niveau A), le risque est considérablement réduit. Si l'appel vient d'une passerelle non vérifiée (niveau C), le score est majoré.
* **Rapidité** : Le module est écrit en pur Python, sans modèles lourds externes, et s'exécute en **moins de 1 milliseconde**.

---

## 3. Principaux Endpoints de l'API (`/api/v1/`)

Toutes les requêtes de l'application mobile sont protégées par l'en-tête `X-API-Key` ou par un jeton d'authentification JWT :

### Pour l'application mobile
* `GET /api/v1/blacklist/?since=<timestamp>` : Téléchargement de la liste noire active (supporte le mode incrémental pour économiser la bande passante).
* `POST /api/v1/reports/` : Enregistrement d'un signalement de spam avec commentaire et catégorie.
* `POST /api/v1/reports/safe/` : Envoi d'une contestation citoyenne pour réhabiliter un numéro légitime.
* `GET /api/v1/check/<hash>/` : Vérification instantanée du statut et du score d'une empreinte téléphonique.
* `POST /api/v1/check/batch/` : Vérification groupée (jusqu'à 100 numéros en une seule requête SQL).
* `GET /api/v1/ai/diagnose/?phone_number=...` : Diagnostic complet avec explications lisibles pour l'utilisateur.
* `GET /api/v1/health/` : Sonde de disponibilité du serveur et de la base de données.
* `GET /api/v1/metrics/` : Métriques au format standard Prometheus / OpenMetrics.

### Pour l'administration (comptes avec statut `is_staff`)
* `GET /api/v1/admin/stats/` : Statistiques globales (signalements, numéros bloqués, utilisateurs).
* `GET /api/v1/admin/reports/` : Liste des signalements en attente de révision.
* `POST /api/v1/admin/consensus-audit/` : Déclenchement de l'audit automatique pour réhabiliter les numéros ayant atteint le quorum.
* `POST /api/v1/admin/purge/` : Nettoyage des signalements anciens de plus de 90 jours.
* `GET /api/v1/admin/audit-logs/` : Consultation du journal d'audit des actions administratives.

---

## 4. Démarrage en Développement

### 1. Installer les dépendances
```bash
pip install -r requirements.txt
```

### 2. Appliquer les migrations de base de données
```bash
python manage.py migrate
```

### 3. Créer le compte administrateur initial
```bash
python manage.py ensure_admin
```
* **Courriel** : `admin@shieldnet.app` (ou nom d'utilisateur `admin`)
* **Mot de passe** : défini via la variable `ADMIN_PASSWORD` dans votre fichier `.env` local

### 4. Lancer les tests unitaires (61 tests, 100% de succès)
```bash
python manage.py test shield_api
```

### 5. Démarrer le serveur local
```bash
python manage.py runserver 0.0.0.0:8000
```

* **Console web** : [http://127.0.0.1:8000/admin/](http://127.0.0.1:8000/admin/)
* **Documentation Swagger (OpenAPI)** : [http://127.0.0.1:8000/api/v1/docs/](http://127.0.0.1:8000/api/v1/docs/)

---

## 5. Documentation Technique Complémentaire

Pour plus de détails sur le déploiement ou l'architecture globale, consultez les dossiers techniques dans [`docs/`](file:///C:/Projet/Projet%20synthese/docs/) :

* [**Guide de Déploiement & Pipeline CI/CD**](file:///C:/Projet/Projet%20synthese/docs/DEPLOIEMENT_ET_CI_CD.md) : Déploiement avec Docker Compose, configuration Gunicorn / Nginx et automatisation Jenkins.
* [**Architecture & Conception Logicielle**](file:///C:/Projet/Projet%20synthese/docs/ARCHITECTURE_ET_CONCEPTION.md) : Diagrammes de classes UML et diagrammes de séquence des flux REST.
* [**Modèle de Menace & Sécurité Cryptographique**](file:///C:/Projet/Projet%20synthese/docs/SECURITY_AND_THREAT_MODEL.md) : Analyse de l'entropie des numéros nord-américains et conformité à la Loi 25 québécoise.
