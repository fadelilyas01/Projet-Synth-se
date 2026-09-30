# ShieldNet Mobile — Client Android & Module Natif

Client mobile de protection contre le démarchage et les fraudes téléphoniques, conçu selon les principes de confidentialité dès la conception (*Privacy by Design*, conformité Loi 25 et LPRPDE). 

L'application intercepte les appels indésirables en temps réel et analyse les SMS frauduleux directement sur l'appareil, sans jamais extraire le carnet d'adresses ni stocker de numéros en clair sur des serveurs distants.

---

## 1. Architecture d'Interception Télécom

L'interception repose sur l'API native Android `CallScreeningService` implémentée en Kotlin, combinée à une base de données embarquée haute performance et un filtre probabiliste en mémoire vive.

```text
[ Appel Entrant ]
       │
       ▼
[ Android Telecom Framework ]
       │
       ▼
[ ShieldNetCallScreeningService (Kotlin) ]
       │
       ├── 1. Normalisation E.164 (+1) & Hachage HMAC-SHA256 (< 0.2 ms)
       ├── 2. Fast-Path : Vérification Filtre de Bloom en RAM (< 0.02 ms)
       │         └── Si absent du filtre -> Appel autorisé immédiatement
       │
       ├── 3. Requête SQLite locale indexée en mode WAL (< 1.5 ms)
       │         └── Table local_blacklist (score, seuil de blocage, statut)
       │
       ▼
[ Décision (< 2 ms au total) ]
  ├── Numéro Malveillant (Score >= Seuil) ──> Rejet silencieux (CallResponse.Builder.setDisallowCall)
  └── Numéro Légitime ou d'Urgence         ──> Sonnerie normale prioritaire
```

### Contraintes Temps Réel
Android impose une réponse du `CallScreeningService` dans une fenêtre stricte (< 100 ms). L'utilisation conjointe de HMAC-SHA256 pré-calculé, du mode WAL (*Write-Ahead Logging*) sur SQLite et du filtre de Bloom assure un temps de traitement inférieur à 2 ms, sans dépendance réseau au moment de l'appel.

---

## 2. Organisation du Code Source (Clean Architecture)

Le projet Dart est structuré selon les principes de la *Clean Architecture* avec gestion d'état réactive via **Riverpod** :

```text
ShieldNet/
├── android/
│   └── app/src/main/kotlin/.../
│       ├── ShieldNetCallScreeningService.kt   # Interception système des appels
│       ├── ShieldNetDatabaseHelper.kt         # Accès SQLite natif bas niveau
│       ├── ShieldNetAppWidgetProvider.kt      # Widget d'écran d'accueil
│       └── MainActivity.kt                    # Pont EventChannel / MethodChannel
│
├── lib/
│   ├── core/
│   │   ├── config/             # Environnement (.env) et constantes réseau
│   │   ├── database/           # SQLite local, migrations, mode WAL et transactions
│   │   ├── network/            # Client Dio durci (SSL Pinning, retry, rate limit)
│   │   ├── providers/          # Conteneurs d'injection de dépendances Riverpod
│   │   ├── security/           # HMAC-SHA256, normalisation E.164, détection de Root
│   │   ├── services/           # Synchronisation d'arrière-plan, file d'attente hors-ligne
│   │   └── theme/              # Thèmes clair et sombre, contrastes WCAG AAA
│   │
│   ├── features/
│   │   ├── call_filtering/     # Tableau de bord, historique d'appels, contestations
│   │   ├── onboarding/         # Parcours d'initialisation et explications réglementaires
│   │   ├── settings/           # Préférences, diagnostic, console d'administration
│   │   └── sms_inspector/      # Analyseur heuristique local de SMS suspects
│   │
│   ├── l10n/                   # Ressources localisées bilingues (app_fr.arb, app_en.arb)
│   └── main.dart               # Point d'entrée de l'application
│
└── test/                       # 86 tests unitaires, widgets et d'intégration
```

---

## 3. Fonctionnalités Principales

### Protection Téléphonique & Filtrage
- **Interception Locale Autonome** : Blocage silencieux avant sonnerie, fonctionnel même hors-ligne.
- **Immunité Absolue des Urgences** : Les services d'urgence nationaux (911, 811, 988, 211, 311, 511, 112) et les contacts favoris définis par l'utilisateur bénéficient d'une immunité totale non modifiable par la liste de blocage.
- **Filtre de Bloom en Mémoire Vive** : Évaluation O(1) pour les numéros vérifiés permettant d'éviter les accès disques superflus.
- **Radar des Menaces Régionales & Détection de Spoofing** : Surveillance en temps réel des vagues d'appels frauduleux ciblant les indicatifs canadiens (819, 514, 438, 418, 450, 613).
- **Mode « Contacts Uniquement »** : Filtrage strict des numéros inconnus pour les utilisateurs recevant un volume élevé de démarchage ciblé.
- **Bouclier Nocturne** : Plage horaire programmable pour l'atténuation automatique des sollicitations durant le sommeil.

### Résilience & Qualité d'Expérience
- **File d'Attente Hors-Ligne (Offline Queue)** : Les signalements et contestations émis sans connexion sont persistés localement et synchronisés automatiquement dès le rétablissement du réseau.
- **Contestation et Arbitrage Citoyen** : Tout numéro bloqué peut être contesté directement depuis l'historique d'activité pour transmission au moteur de consensus.
- **Audit Groupé d'Appels Récents (Batch Check)** : Analyse en une seule requête SQL/API des 50 derniers appels de l'historique Android.
- **Mode Interface Simplifiée (Seniors)** : Ergonomie adaptée avec typographie agrandie, contrastes renforcés et zones tactiles étendues.
- **Inspecteur de SMS Local** : Détection heuristique des liens bancaires factices et tentatives d'hameçonnage par colis sans aucun transfert de texte vers un serveur tiers.

---

## 4. Configuration & Démarrage

### 1. Variables d'Environnement
Créer un fichier `.env` à la racine du dossier `ShieldNet/` (modèle fourni dans `.env.example`) :

```env
API_BASE_URL=http://127.0.0.1:8000/api/v1  # Utiliser 10.0.2.2 pour l'émulateur standard Android
API_KEY=votre_cle_api_partagee
HASH_SALT=votre_sel_cryptographique_hmac
OFFLINE_CACHE_TTL_HOURS=24
ENABLE_AUTO_BLOCKING=true
```

### 2. Commandes Utiles

```bash
# Récupération des dépendances Flutter
flutter pub get

# Génération des fichiers de localisation bilingues
flutter gen-l10n

# Exécution de la suite de tests (86 tests unitaires et widgets)
flutter test

# Analyse statique du code (linter Dart officiel)
flutter analyze

# Lancement de l'application sur appareil connecté ou émulateur
flutter run
```

---

## 5. Intégrité & Sécurité

- **Protection Mémoire & Clés** : Les empreintes téléphoniques sont calculées via HMAC-SHA256 avec sel cryptographique injecté à la compilation ou via environnement sécurisé.
- **Détection d'Élévation de Privilèges** : Contrôle au démarrage de la présence de binaires `su` ou de mécanismes de rootage pouvant compromettre le bac à sable applicatif Android.
- **Épinglage de Certificat (SSL/TLS Pinning)** : Vérification de l'empreinte SHA-256 du certificat serveur sur les connexions réseau sortantes.
- **Zéro Télémétrie Invasive** : Aucun identifiant publicitaire, traceur analytique externe ou donnée personnelle n'est intégré au binaire.
