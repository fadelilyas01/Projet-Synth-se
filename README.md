# ShieldNet — Filtrage d'appels indésirables et respect de la vie privée

ShieldNet est un projet de synthèse en génie logiciel dédié à la protection des utilisateurs contre les appels indésirables, les tentatives de fraude téléphonique et le démarchage automatisé (*robocalls*), principalement sur le plan de numérotation nord-américain (+1, Québec, Canada et États-Unis).

Contrairement à la majorité des applications commerciales qui aspirent le carnet de contacts vers des serveurs distants, ShieldNet a été pensé selon le principe de **protection de la vie privée dès la conception** (*Privacy by Design*). Les décisions de blocage sont prises localement sur le téléphone et aucune donnée personnelle en clair n'est transmise ou stockée sur le serveur, en conformité avec la **Loi 25 du Québec** et la **LPRPDE** canadienne.

---

## 1. Principes de fonctionnement

1. **Aucune collecte de carnet d'adresses** : Les contacts personnels restent strictement dans la mémoire du téléphone. Aucun contact n'est extrait, transmis ou indexé sur un serveur.
2. **Données anonymisées par empreinte (HMAC-SHA256)** : Les numéros signalés ne transitent jamais en clair. Ils sont convertis en empreintes cryptographiques avec un sel d'infrastructure avant tout échange réseau.
3. **Interception locale instantanée** : Sur Android, le filtrage s'appuie sur le service système `CallScreeningService` et une base SQLite locale. La vérification prend moins de 2 millisecondes, ce qui permet de bloquer l'appel avant même qu'il ne commence à sonner.
4. **Prévention des faux positifs** : Pour éviter de bloquer des numéros légitimes (hôpitaux, cliniques médicales, pharmacies, livreurs), le système combine les avis favorables de la communauté et les attestations télécom STIR/SHAKEN.
5. **Immunité absolue des urgences** : Les numéros d'urgence (911, 811, 988, etc.) ainsi que les contacts favoris de l'utilisateur sont protégés et ne peuvent jamais être filtrés.

---

## 2. Structure du projet

Le projet est divisé en deux grandes parties complémentaires :

```text
Projet synthese/
├── ShieldNet/                # Application mobile Android (Flutter / Kotlin)
│   ├── android/              # Service natif d'interception (CallScreeningService)
│   ├── lib/                  # Code source Flutter (Clean Architecture, Riverpod)
│   ├── l10n/                 # Fichiers de localisation bilingues (français / anglais)
│   └── test/                 # Tests automatisés unitaires et d'intégration (35 tests)
│
├── shieldnet_backend/        # Serveur d'API et console de modération (Django)
│   ├── shield_api/           # API REST, modèles, services de modération et consensus
│   ├── shieldnet_backend/    # Configuration générale et routage Django
│   ├── templates/            # Gabarits HTML de la console d'administration
│   └── test/                 # Tests automatisés du backend (74 tests)
│
├── docs/                     # Documentation technique détaillée
│   ├── ARCHITECTURE_ET_CONCEPTION.md
│   ├── DEPLOIEMENT_ET_CI_CD.md
│   └── SECURITY_AND_THREAT_MODEL.md
│
├── start-dev.ps1             # Script de démarrage de l'environnement de développement
└── test-all.ps1              # Script pour exécuter l'ensemble des 109 tests
```

---

## 3. Guide de démarrage rapide

### Prérequis
- **Python 3.10 ou supérieur** (testé avec Python 3.12)
- **Flutter SDK 3.27 ou supérieur**
- **Android Studio** avec un émulateur configuré (API 29+) ou un appareil Android en mode débogage

---

### Étape 1 : Lancement du serveur backend (Django)

Dans un premier terminal :

```powershell
cd shieldnet_backend

# Créer et activer l'environnement virtuel
python -m venv venv
.\venv\Scripts\Activate.ps1

# Installer les dépendances
pip install -r requirements.txt

# Appliquer les migrations de base de données
python manage.py migrate

# Initialiser les comptes administrateur et modérateur
python manage.py ensure_admin
python manage.py ensure_manager

# Démarrer le serveur
python manage.py runserver 0.0.0.0:8000
```

Une fois le serveur en ligne :
- **Console d'administration** : [http://127.0.0.1:8000/admin/](http://127.0.0.1:8000/admin/)
  - Administrateur : `admin` / `admin123`
  - Gestionnaire : `manager` / `manager123`
- **Documentation de l'API (Swagger)** : [http://127.0.0.1:8000/api/v1/docs/](http://127.0.0.1:8000/api/v1/docs/)
- **Centre d'aide public** : [http://127.0.0.1:8000/help/](http://127.0.0.1:8000/help/)

---

### Étape 2 : Lancement de l'application mobile (Flutter)

Dans un second terminal :

```powershell
cd ShieldNet

# Télécharger les paquets Flutter et générer les traductions
flutter pub get
flutter gen-l10n

# Lancer l'application
flutter run
```

*Note : si vous utilisez l'émulateur standard Android, l'adresse de votre machine hôte est automatiquement configurée sur `10.0.2.2:8000`.*

---

## 4. Tests automatisés et qualité du code

Le projet comprend **109 tests automatisés** qui valident le bon fonctionnement de l'ensemble de la solution :

- **74 tests côté backend (Django)** : couvrent l'API REST, l'authentification JWT, les calculs de consensus citoyen, le filtrage par indicatif régional et les fonctionnalités de modération.
- **35 tests côté mobile (Flutter)** : valident la logique de filtrage d'appels, la normalisation E.164, le masquage des numéros, la gestion du stockage sécurisé et les requêtes réseau.

Pour exécuter tous les tests d'un seul coup :
```powershell
.\test-all.ps1
```

Pour les lancer séparément :
```powershell
# Tests du backend
cd shieldnet_backend
python manage.py test

# Tests du client mobile
cd ..\ShieldNet
flutter test
```

L'analyse statique du code Dart peut être vérifiée avec :
```powershell
flutter analyze
```

---

## 5. Choix technologiques et justification

- **Flutter et Kotlin** : Flutter permet de construire une interface réactive et moderne. Le module natif Kotlin est quant à lui indispensable pour communiquer avec l'API Android `CallScreeningService`, la seule capable d'intercepter les appels système au niveau du système d'exploitation.
- **Django et Django REST Framework** : Offre une architecture solide, un système d'authentification robuste et une interface d'administration prête à l'emploi pour les modérateurs.
- **SQLite local en mode WAL** : Sur le téléphone, SQLite en mode *Write-Ahead Logging* permet des lectures concurrentes extrêmement rapides (< 2 ms), garantissant une décision de filtrage instantanée sans figer l'interface.
- **HMAC-SHA256 avec sel** : Choisi pour son ratio optimal entre sécurité et rapidité d'exécution sur mobile (~0.15 ms), là où des algorithmes comme Argon2id prendraient plusieurs centaines de millisecondes et feraient échouer le délai d'interception imposé par Android.