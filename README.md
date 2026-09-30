# ShieldNet — Plateforme de Filtrage Télécom & Protection de la Vie Privée

Solution d'ingénierie logicielle pour l'interception temps réel des appels indésirables et la détection des fraudes par SMS, conçue selon le principe de confidentialité dès la conception (*Privacy by Design*) en conformité avec la **Loi 25 du Québec** et la **LPRPDE canadienne**.

Le système cible le plan de numérotation nord-américain (**NANP**, indicatif `+1`) au format international **E.164**.

---

## 1. Vue d'Ensemble & Philosophie d'Ingénierie

La majorité des applications commerciales de filtrage d'appels (telles que Truecaller ou Hiya) reposent sur un modèle d'aspiration systématique des carnets d'adresses vers des serveurs centraux, créant des risques majeurs de fuite de données et des non-conformités réglementaires.

ShieldNet adopte une approche fondamentalement différente :

1. **Zéro Collecte de Contacts** : Le carnet d'adresses personnel reste strictement confiné à la mémoire locale de l'appareil. Aucun contact n'est extrait, transmis ou indexé.
2. **Zéro Numéro en Clair Côté Serveur** : Les signalements et synchronisations transitent exclusivement sous forme d'empreintes cryptographiques **HMAC-SHA256** calculées avec un sel d'infrastructure.
3. **Interception Locale Déterministe (< 2 ms)** : La décision de bloquer ou d'autoriser un appel entrant est exécutée par le sous-système Android `CallScreeningService` et une base SQLite embarquée en mode WAL (*Write-Ahead Logging*), avant le premier coup de sonnerie et sans dépendance réseau.
4. **Moteur d'Arbitrage des Faux Positifs** : Pour éviter l'interception injustifiée de services essentiels (hôpitaux, cliniques, services de livraison, pharmacies), la plateforme intègre un moteur de consensus démocratique et d'analyse contextuelle bilingue (FR/EN) prenant en compte les attestations télécom **STIR/SHAKEN**.

---

## 2. Architecture du Référentiel

```text
Projet synthese/
├── Jenkinsfile                       # Définition du pipeline d'intégration continue (150 tests et build APK)
├── README.md                         # Documentation générale de la plateforme (ce fichier)
├── docker-compose.yml                # Environnement conteneurisé (Django 5, PostgreSQL 16, Redis 7)
├── docker-compose.jenkins.yml        # Instance Jenkins CI locale conteneurisée
├── test-all.ps1                      # Automatisation de l'ensemble des suites de tests (backend et mobile)
├── start-dev.ps1                     # Script de lancement rapide de l'environnement de développement
│
├── docs/                             # Spécifications et documentation d'ingénierie :
│   ├── ARCHITECTURE_ET_CONCEPTION.md # Clean Architecture, diagrammes UML et séquences d'interception
│   ├── DEPLOIEMENT_ET_CI_CD.md       # Manuel d'exploitation, conteneurisation Docker et pipeline Jenkins
│   └── SECURITY_AND_THREAT_MODEL.md  # Analyse d'entropie NANP, modèle STRIDE et conformité Loi 25
│
├── ShieldNet/                        # Client mobile Android (Flutter / Kotlin)
│   ├── android/                      # Services natifs Android (CallScreeningService, AppWidget)
│   ├── lib/                          # Code Dart structuré en Clean Architecture (Riverpod 2.x)
│   ├── l10n/                         # Ressources de localisation bilingues (FR / EN)
│   ├── test/                         # Suite de 86 tests automatisés (unitaires, widgets, mocks)
│   └── README.md                     # Documentation technique du client mobile
│
└── shieldnet_backend/                # Serveur d'API & Console d'Administration (Django)
    ├── shield_api/                   # Applications DRF (modèles, vues, services d'arbitrage, métriques)
    ├── shieldnet_backend/            # Configuration générale, routage et sécurité WSGI/ASGI
    ├── templates/                    # Interfaces d'administration web personnalisées
    └── README.md                     # Documentation technique du serveur backend
```

---

## 3. Composants Techniques

### Client Mobile (ShieldNet)
- **Framework & Langage** : Flutter 3.27+ (Dart) et Android natif (Kotlin).
- **Interception Système** : `CallScreeningService` natif Android dialoguant directement avec la base SQLite locale.
- **Stockage Embarqué** : SQLite configuré en mode WAL, index B-Tree optimisé sur les empreintes hexadécimales SHA-256.
- **Fast-Path Mémoire** : Filtre de Bloom en mémoire vive pour évaluation en O(1) (< 0.02 ms).
- **Résilience Réseau** : File d'attente hors-ligne (`OfflineSyncService`) stockant les signalements émis sans réseau pour synchronisation différée.
- **Accessibilité & Ergonomie** : Mode Interface Simplifiée (Seniors), support bilingue complet, immunité inviolable des numéros d'urgence (911, 811, 988).

### Serveur Backend (shieldnet_backend)
- **Framework & Langage** : Python 3.12, Django 5.x et Django REST Framework.
- **Bases de Données** : PostgreSQL 16 (production) / SQLite (développement local).
- **Cache & Rate Limiting** : Redis 7 avec limitation stricte des requêtes par adresse IP.
- **Contrôle d'Accès Basé sur les Rôles (RBAC)** : Séparation étanche entre les privilèges administrateur système (SOC / Superuser) et gestionnaire de modération (Staff restreint).
- **Observabilité** : Endpoint `/api/v1/metrics/` conforme au standard OpenMetrics / Prometheus.

---

## 4. Sécurité & Modèle Cryptographique

### Justification du Choix HMAC-SHA256 vs Fonctions à Mémoire Lourde
L'espace combinatoire des numéros nord-américains assignables (NANP +1) représente environ 780 millions de combinaisons (entropie d'environ 30 bits). Un hachage simple sans sel serait vulnérable aux attaques par dictionnaire ou tables pré-calculées.

ShieldNet applique un **HMAC-SHA256** utilisant un sel secret d'infrastructure. Le recours à des algorithmes à coût mémoire élevé (comme Argon2id ou scrypt) a été écarté en raison du budget d'exécution temps réel strict imposé par Android :
- **HMAC-SHA256** : Exécution sur matériel mobile en **~0.15 ms**, permettant une décision globale d'interception en moins de 2 ms.
- **Argon2id** : Exécution requérant 300 à 800 ms sur processeur mobile standard, excédant la limite système et provoquant l'échec de l'interception.

### Mesures de Durcissement
- **Comparaison à Temps Constant** : Utilisation de `hmac.compare_digest` pour valider les jetons et clés d'API afin de prévenir les attaques par canal auxiliaire (*timing attacks*).
- **Protection contre l'Injection CSV** : Neutralisation systématique des caractères de formules (`=`, `+`, `-`, `@`) lors de l'export des journaux d'audit.
- **Validation Strictement Typée** : Contrôle systématique des formats E.164, assainissement des expressions régulières contre les dénis de service (ReDoS), et limitation de taille sur toutes les entrées utilisateur.

---

## 5. Démarrage Rapide

### Prérequis
- Python 3.10 ou supérieur
- Flutter SDK 3.27 ou supérieur
- Docker & Docker Compose (optionnel pour exécution conteneurisée)
- Android SDK (API 29+) pour les composants natifs

### Lancement du Backend

```bash
cd shieldnet_backend

# Création et activation de l'environnement virtuel
python -m venv venv
# Windows :
.\venv\Scripts\Activate.ps1
# Linux / macOS :
source venv/bin/activate

# Installation des dépendances et migration
pip install -r requirements.txt
python manage.py migrate

# Initialisation du compte administrateur et lancement
python manage.py ensure_admin
python manage.py runserver 0.0.0.0:8000
```

- Console d'administration : `http://127.0.0.1:8000/admin/`
- Documentation OpenAPI / Swagger : `http://127.0.0.1:8000/api/v1/docs/`

### Lancement de l'Application Mobile

```bash
cd ShieldNet

# Récupération des dépendances et génération i18n
flutter pub get
flutter gen-l10n

# Lancement de l'application
flutter run
```

---

## 6. Assurance Qualité & Validation des Tests (150 Tests, 100% Succès)

La robustesse opérationnelle est validée par une suite continue de **150 tests automatisés** :

| Domaine | Composant | Nombre de Tests | Statut |
|---|---|---|---|
| **Backend** | Modèles, API REST, RBAC, Consensus & STIR/SHAKEN | 64 tests | Succès (100%) |
| **Mobile** | SQLite WAL, Clean Architecture, Widgets & Cryptographie | 86 tests | Succès (100%) |
| **Total** | **Ensemble de la plateforme ShieldNet** | **150 tests** | **Succès (100%)** |

Pour exécuter l'ensemble des tests en une seule commande :
```powershell
.\test-all.ps1
```

---

## 7. Documentation d'Ingénierie Détaillée

Pour approfondir les aspects d'architecture et de sécurité, consultez les documents du répertoire `docs/` :

- [**Architecture & Modélisation UML**](docs/ARCHITECTURE_ET_CONCEPTION.md) : Diagrammes de classes, flux temporels d'interception et principes Clean Architecture.
- [**Modèle de Menace & Sécurité Cryptographique**](docs/SECURITY_AND_THREAT_MODEL.md) : Analyse combinatoire NANP, évaluation STRIDE et conformité Loi 25.
- [**Guide de Déploiement & Pipeline CI/CD**](docs/DEPLOIEMENT_ET_CI_CD.md) : Déploiement Docker en production, configuration Nginx/Gunicorn et pipeline Jenkins.