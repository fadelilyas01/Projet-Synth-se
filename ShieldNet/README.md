# ShieldNet Mobile — Client Android (Flutter)

Bienvenue dans le sous-projet mobile de **ShieldNet**. Il s'agit de l'application cliente développée avec **Flutter (Dart)** et un composant natif Android écrit en **Kotlin**.

L'application permet d'intercepter les appels indésirables en temps réel et d'analyser les SMS suspects, tout en garantissant qu'aucun contact personnel n'est aspiré ni transmis sur Internet.

---

## 1. Comment fonctionne l'interception sur le téléphone ?

Sur Android, le système d'exploitation fournit une interface dédiée nommée **`CallScreeningService`**.

Quand un appel entrant arrive sur l'appareil :
1. Android réveille notre service natif Kotlin [`ShieldNetCallScreeningService`](file:///C:/Projet/Projet%20synthese/ShieldNet/android/app/src/main/kotlin/ca/uqo/shieldnet/ShieldNetCallScreeningService.kt) avant de faire sonner l'appareil.
2. Le service normalise le numéro (au format nord-américain E.164, ex: `+18195550199`) et calcule son empreinte **HMAC-SHA256**.
3. Il effectue une requête immédiate dans la base de données locale **SQLite** (`shieldnet.db`), configurée en mode **WAL** (*Write-Ahead Logging*).
4. Si le numéro est répertorié comme malveillant et non blanchi, l'appel est rejeté silencieusement, sans que le téléphone ne vibre ni ne sonne.
5. **Vitesse d'exécution** : Toute cette chaîne prend **moins de 2 millisecondes**, bien en deçà de la limite maximale imposée par Android (~100 ms).

```text
[ Appel Entrant ] ──> [ Android Telecom ] ──> [ CallScreeningService (Kotlin) ]
                                                            │
                                        Calcul HMAC (< 0.2 ms) + Requête SQLite WAL (< 1.5 ms)
                                                            │
                            ┌───────────────────────────────┴───────────────────────────────┐
                            ▼                                                               ▼
                  [ Numéro Malveillant ]                                          [ Numéro Légitime / Urgence ]
                  Rejet silencieux immédiat                                       Sonnerie normale prioritaire
```

---

## 2. Organisation du Code (Clean Architecture)

Le code Dart dans `lib/` est organisé par couches de responsabilités selon les principes de la *Clean Architecture* et géré avec **Riverpod** :

```text
lib/
├── core/
│   ├── config/             # Paramètres d'environnement (.env) et timeouts
│   ├── database/           # Gestionnaire SQLite local (mode WAL, index sur les hashes)
│   ├── network/            # Client Dio pour les échanges avec le backend Django
│   ├── providers/          # Injection de dépendances globale (Riverpod)
│   ├── security/           # Hachage HMAC-SHA256 et normalisation des numéros (+1)
│   ├── services/           # Synchronisation d'arrière-plan et inspecteur SMS
│   └── theme/              # Thème visuel (modes clair et sombre)
├── features/
│   ├── call_filtering/     # Écrans principaux : tableau de bord, historique, contestations
│   ├── onboarding/         # Présentation du projet et explication de la Loi 25
│   └── settings/           # Préférences, diagnostic technique et console administrateur
├── l10n/                   # Traductions bilingues (français et anglais)
└── main.dart               # Initialisation de l'application
```

---

## 3. Ce que l'utilisateur peut faire avec l'application

* **Tableau de bord de protection** : Permet de vérifier l'état du bouclier, de voir le nombre de menaces filtrées et de tester la réputation d'un numéro manuellement.
* **Radar des Menaces Régionales & Détection de Spoofing** : Surveillance en temps réel des vagues d'appels frauduleux ciblant les indicatifs canadiens (819, 514, 438, 418, 450, 613, etc.) avec alertes visuelles interactives.
* **Mode Interface Simplifiée (Aînés / Seniors)** : Interface haute lisibilité avec typographie agrandie, contrastes renforcés et boutons tactiles élargis pour une accessibilité maximale face aux arnaques ciblant les personnes vulnérables.
* **File d'Attente Hors-Ligne Résiliente (Offline Queue)** : Permet de signaler des numéros ou de contester des faux-positifs même sans connexion Internet. Les signalements sont stockés localement en SQLite et synchronisés automatiquement dès reconnexion.
* **Filtre de Bloom en Mémoire Vive (O(1) Fast-Path)** : Évaluation probabiliste instantanée (< 0.02 ms) éliminant les accès disque SQLite pour les numéros vérifiés non suspects, garantissant zéro faux négatif.
* **Vérification d'Intégrité Matérielle & Détection de Root** : Contrôle automatique de la présence de binaires d'élévation de privilèges (`su`, Magisk) pour avertir des risques pesant sur les secrets locaux.
* **Épinglage SSL (SSL/TLS Pinning)** : Durcissement du client HTTP Dio avec vérification d'empreinte SHA-256 du certificat serveur pour contrer les attaques de type *Man-in-the-Middle*.
* **Synchronisation Widget d'Accueil Android** : Passerelle SharedPreferences alimentant le composant AppWidget de l'écran d'accueil avec les statistiques de protection en temps réel.
* **Audit rapide des appels récents** : Dans l'onglet *Activité*, un bouton permet d'analyser les 50 derniers appels reçus en interrogeant le Cloud ShieldNet en une seule requête groupée (*batch check*).
* **Contester un faux positif** : Si un numéro légitime (clinique médicale, pharmacie, livreur) a été bloqué par erreur, toucher le numéro ouvre une fiche permettant d'envoyer un avis favorable. Plusieurs avis concordants permettent au consensus de le réhabiliter automatiquement.
* **Protection absolue des urgences** : Les numéros de secours (911, 811, 988) et vos contacts d'urgence personnels ne peuvent jamais être bloqués par l'application.
* **Mode « Contacts uniquement »** : Bloque automatiquement tout appel provenant d'un numéro absent du carnet d'adresses (recommandé pour les personnes âgées ciblées par le télémarketing).
* **Bouclier nocturne** : Permet de filtrer silencieusement les appels inconnus pendant que vous dormez.
* **Inspecteur de SMS** : Vous copiez un message douteux dans le presse-papier, et l'application analyse le texte localement (sans l'envoyer nulle part) pour vous alerter sur d'éventuels faux liens bancaires ou arnaques de colis.
* **Console d'administration intégrée** : Si vous vous connectez avec un compte ayant le statut `is_staff`, un onglet supplémentaire permet de modérer les signalements directement depuis le téléphone.

---

## 4. Démarrage de l'Application

### 1. Fichier d'environnement (`.env`)
Créez un fichier `.env` à la racine de `ShieldNet/` à partir de `.env.example` :

```env
API_BASE_URL=http://127.0.0.1:8000/api/v1  # Utilisez 10.0.2.2 si vous testez sur l'émulateur Android
API_KEY=votre_jeton_api_partage
HASH_SALT=votre_sel_cryptographique_hmac
OFFLINE_CACHE_TTL_HOURS=24
ENABLE_AUTO_BLOCKING=true
```

### 2. Commandes de lancement
```bash
# Télécharger les dépendances Flutter
flutter pub get

# Lancer la suite de tests (86 tests unitaires et widgets Flutter)
flutter test

# Lancer la suite de tests Django backend (64 tests unitaires et d'intégration)
python manage.py test shield_api

# Vérifier la qualité du code avec l'analyseur
flutter analyze

# Démarrer l'application sur votre appareil ou émulateur
flutter run
```

---

## 5. Documentation Technique Complémentaire

Pour les détails d'architecture logicielle et de sécurité, consultez les documents dans le dossier [`docs/`](file:///C:/Projet/Projet%20synthese/docs/) :

* [**Architecture & Modélisation UML**](file:///C:/Projet/Projet%20synthese/docs/ARCHITECTURE_ET_CONCEPTION.md) : Modèle de classes UML et diagramme de séquence de l'interception d'appel.
* [**Modèle de Menace & Sécurité Cryptographique**](file:///C:/Projet/Projet%20synthese/docs/SECURITY_AND_THREAT_MODEL.md) : Justification du hachage HMAC-SHA256 face au budget temps réel Android et conformité Loi 25.
* [**Guide de Déploiement & Pipeline CI/CD**](file:///C:/Projet/Projet%20synthese/docs/DEPLOIEMENT_ET_CI_CD.md) : Compilation automatisée de l'APK via le pipeline Jenkins.
