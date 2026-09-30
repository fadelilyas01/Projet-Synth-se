# ShieldNet Backend — API REST, Moteur d'Arbitrage & Administration (Django)

Serveur central de la plateforme **ShieldNet**, fournissant l'API REST consommée par les clients mobiles, le moteur d'arbitrage des signalements pour la prévention des faux positifs et la console web d'administration pour les opérateurs de sécurité.

Développé avec **Python 3.12**, **Django 5.x** et **Django REST Framework (DRF)**.

---

## 1. Rôle & Responsabilités

Le serveur remplit quatre fonctions clés dans l'architecture :

1. **Distribution Incrémentale des Données de Réputation** : Synchronisation différentielle par delta et horodatage (`/api/v1/sync/delta` et `/api/v1/blacklist/?since=...`) permettant aux terminaux mobiles de ne télécharger que les modifications récentes (ajouts, suppressions, réhabilitations), minimisant la consommation réseau et batterie.
2. **Collecte Anonymisée des Signalements & Contestations** : Traitement des empreintes **HMAC-SHA256**. Aucun numéro en clair n'est transmis par les clients ni persisté en base de données.
3. **Moteur d'Arbitrage & Consensus Citoyen** : Évaluation contextuelle bilingue (FR/EN) des motifs de signalement, vérification de conformité NANP, prise en compte des niveaux d'attestation télécom **STIR/SHAKEN** et application d'un algorithme de quorum pour réhabiliter automatiquement les services légitimes contestés.
4. **Contrôle d'Accès Basé sur les Rôles (RBAC)** : Cloisonnement strict entre les administrateurs système (accès complet aux paramètres et journaux) et les gestionnaires de modération (accès limité à l'examen des signalements et contestations).

```text
[ Client Mobile Flutter ]
            │
            ├── Signalement de spam anonymisé (POST /api/v1/reports/)
            ├── Contestation d'un numéro légitime (POST /api/v1/reports/safe/)
            ├── Synchronisation différentielle Delta (GET /api/v1/sync/delta?since=...)
            ├── Vérification unitaire ou par lot (GET /check/<hash>/ ou POST /check/batch/)
            └── Diagnostic avec explications lisibles (GET /api/v1/ai/diagnose/)
            │
            ▼
[ Moteur d'Arbitrage & Modération (shield_api/ai_engine.py & services.py) ]
            │
            ├── Analyse sémantique contextuelle bilingue (santé, services publics, banques vs fraude)
            ├── Détection des plages de numéros fictifs 555-01xx (usurpation CLI)
            ├── Traitement des attestations STIR/SHAKEN (niveaux A, B, C)
            └── Algorithme de consensus : quorum de signalements légitimes pour réhabilitation
            │
            ▼
[ Console Web d'Administration (Django) & Base PostgreSQL / SQLite ]
            │
            ├── Triage et traitement des signalements en temps réel
            ├── Bac à sable d'évaluation de numéros (Sandbox)
            ├── Métriques d'observabilité Prometheus (/api/v1/metrics/)
            └── Journal d'audit immuable traçant chaque décision (AuditLog)
```

---

## 2. Moteur d'Arbitrage & Prévention des Faux Positifs

Situé dans `shield_api/ai_engine.py`, le moteur résout le problème classique des signalements erronés ciblant des numéros institutionnels ou de livraison :

* **Analyse Contextuelle Bilingue (FR / EN)** : Détection des termes associés aux services légitimes (CLSC, hôpitaux, cliniques, pharmacies, coursiers, institutions financières) par rapport aux marqueurs d'escroqueries (menaces d'arrestation, mandats fictifs, transferts de fonds d'urgence).
* **Détection d'Usurpation d'Identité (Spoofing)** : Les tranches réservées du plan NANP (`555-0100` à `555-0199`) ne sont jamais allouées à des abonnés réels. Toute tentative d'appel émanant de ces tranches est immédiatement catégorisée à risque élevé.
* **Standard STIR/SHAKEN** : Si l'opérateur fournit une attestation de niveau A (numéro certifié par le réseau d'origine), le risque est minoré. En présence d'un niveau C (passerelle internationale non authentifiée), la pondération est accrue.
* **Performances** : Algorithme purement déterministe en Python sans dépendance de modèles externes lourds, s'exécutant en **moins de 1 milliseconde**.

---

## 3. Spécification des Endpoints d'API (`/api/v1/`)

Toutes les requêtes de l'application cliente sont authentifiées par l'en-tête `X-API-Key` ou par jeton JWT :

### Endpoints Clients Mobiles
| Méthode | Endpoint | Description |
|---|---|---|
| `GET` | `/api/v1/blacklist/?since=<iso>` | Liste noire incrémentale ou complète |
| `GET` | `/api/v1/sync/delta?since_version=<v>` | Synchronisation différentielle optimisée |
| `POST` | `/api/v1/reports/` | Soumission d'un signalement de spam anonymisé |
| `POST` | `/api/v1/reports/safe/` | Soumission d'une contestation citoyenne |
| `GET` | `/api/v1/check/<hash>/` | Vérification unitaire du score d'un hash |
| `POST` | `/api/v1/check/batch/` | Vérification groupée (jusqu'à 100 numéros par lot) |
| `GET` | `/api/v1/ai/diagnose/?phone_number=...` | Analyse détaillée et explications pour l'utilisateur |
| `GET` | `/api/v1/health/` | Sonde de santé de l'API et de la base de données |
| `GET` | `/api/v1/metrics/` | Télémétrie au format OpenMetrics pour Prometheus |

### Endpoints d'Administration & Exploitation (Staff / RBAC)
| Méthode | Endpoint | Description |
|---|---|---|
| `GET` | `/api/v1/admin/stats/` | Indicateurs globaux d'activité et volumétrie |
| `GET` | `/api/v1/admin/reports/` | File d'attente des signalements nécessitant une révision |
| `POST` | `/api/v1/admin/consensus-audit/` | Déclenchement de l'audit automatique de consensus |
| `POST` | `/api/v1/admin/purge/` | Purge réglementaire des signalements de plus de 90 jours |
| `GET` | `/api/v1/admin/audit-logs/` | Consultation du journal d'audit des actions de modération |

---

## 4. Installation & Exploitation Locale

### 1. Préparation de l'Environnement
```bash
python -m venv venv

# Windows :
.\venv\Scripts\Activate.ps1
# Linux / macOS :
source venv/bin/activate

pip install -r requirements.txt
```

### 2. Configuration & Migrations
```bash
# Application du schéma de base de données
python manage.py migrate

# Initialisation des comptes avec rôles RBAC
python manage.py ensure_admin    # Compte Administrateur Système (SOC)
python manage.py ensure_manager  # Compte Gestionnaire de Modération
```

### 3. Exécution des Tests Unitaires & d'Intégration
```bash
python manage.py test shield_api
```
*Couverture : 64 tests automatisés (100% de réussite), incluant la validation des règles de consensus, de la synchronisation delta, du durcissement OWASP et de la détection STIR/SHAKEN.*

### 4. Démarrage du Serveur de Développement
```bash
python manage.py runserver 0.0.0.0:8000
```
- Interface d'Administration : `http://127.0.0.1:8000/admin/`
- Documentation Interactive Swagger : `http://127.0.0.1:8000/api/v1/docs/`
- Métriques Prometheus : `http://127.0.0.1:8000/api/v1/metrics/`