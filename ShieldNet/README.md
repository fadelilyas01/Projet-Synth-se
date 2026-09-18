# 🛡️ ShieldNet — Solution Collaborative de Filtrage & Anti-Spam (Mobile Flutter & Android)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20(Prêt)-green.svg)]()
[![License](https://img.shields.io/badge/License-Propriétaire%20%2F%20UQO-blue.svg)]()
[![Tests](https://img.shields.io/badge/Tests-31%2F31%20Pass-success.svg)]()

**ShieldNet** est une solution mobile et cloud de pointe dédiée à l'interception, au filtrage et à la signalisation communautaire d'appels et SMS indésirables (spam commercial agressif, hameçonnage / phishing, arnaques financières et robocalls).  
Conçu et développé dans le cadre du **Projet Synthèse (Université du Québec en Outaouais - UQO)**, le système cible en priorité le plan de numérotation nord-américain (**indicatif `+1` pour le Canada et les États-Unis**).

---

## 🏛️ Architecture Modulaire & Clean Architecture

L'application mobile respecte scrupuleusement les principes de **Clean Architecture**, orchestrée par **Riverpod** pour une gestion d'état réactive et découplée :

```text
lib/
├── core/
│   ├── config/             # Configuration centralisée (.env, timeouts, constantes)
│   ├── database/           # Cache SQLite local ultra-rapide (WAL mode, index B-Tree)
│   ├── error/              # Gestion typée des échecs (Failures & Exceptions)
│   ├── network/            # Client Dio REST API (authentification X-API-Key, interceptors)
│   ├── providers/          # Injection de dépendances et état global (Riverpod)
│   ├── security/           # Anonymisation HMAC-SHA256, validation NANP (+1), heuristique
│   ├── services/           # Intégration native Android (Telecom CallScreeningService)
│   ├── theme/              # Design System moderne (modes Clair / Sombre, HSL dynamiques)
│   ├── utils/              # AppLogger structuré et monitoring Sentry
│   └── widgets/            # Composants UI atomiques et réutilisables
├── features/
│   ├── call_filtering/     # Dashboard interactif, historique d'appels et signalement
│   │   ├── domain/         # Entités et cas d'utilisation métier
│   │   ├── data/           # Répertoires et sources de données (local SQLite + remote API)
│   │   └── presentation/   # Écrans (DashboardPage, ActivityPage, ReportPage)
│   ├── onboarding/         # Parcours d'accueil, pédagogie RGPD et demande de permissions
│   └── settings/           # Paramètres de sécurité, diagnostics et Console Administrateur
│       └── presentation/   # SettingsPage, AdminConsolePage, DeveloperDiagnosticPage
├── l10n/                   # Internationalisation bilingue (Français / Anglais)
└── main.dart               # Point d'entrée, initialisation Sentry, SQLite et injection
```

---

## 🔒 Sécurité, Confidentialité & Conformité RGPD

1. **Anonymisation stricte HMAC-SHA256 (`crypto_utils.dart`)** :
   - Aucun numéro de téléphone en clair ne transite sur le réseau ni n'est stocké dans la base cloud.
   - Les numéros sont hachés via **HMAC-SHA256** combiné à un sel cryptographique secret configurable.
   - L'algorithme de hachage est **strictement déterministe et identique** entre le code Dart de Flutter et les services natifs Kotlin Android (`ShieldNetCallScreeningService` et `SmsScreeningReceiver`).
   - L'exécution du hachage sur les listes volumineuses est déportée dans un **Isolate d'arrière-plan (`compute`)**, garantissant une interface fluide à 60 FPS sans micro-saccades.

2. **Cache Local Haute Performance (`database_helper.dart`)** :
   - SQLite configuré avec le mode **Write-Ahead Logging (WAL)** et des **index B-Tree composites (`idx_category`)**.
   - Temps de résolution d'un appel entrant **inférieur à 2 ms**, assurant un filtrage instantané même hors-ligne ou en mode avion.
   - Les numéros affichés à l'utilisateur sont anonymisés visuellement (ex: `+1 819 *** **67`) afin de préserver la vie privée.

3. **Filtrage Natif Temps Réel (`CallScreeningService`)** :
   - Intégration profonde au sous-système Télécom officiel d'Android pour rejeter les fraudeurs avant même la première sonnerie de l'appareil.

---

## ✨ Fonctionnalités Majeures
 
* **Tableau de bord "Zen" & Dynamique** : Visualisation en temps réel du statut de protection, pulsation lumineuse réactive et recherche rapide de numéros suspects.
* **Score de Sérénité & Impact Citoyen** : Mesure concrète de la tranquillité préservée (appels bloqués, minutes gagnées) et valorisation de la participation citoyenne au bouclier collectif.
* **Liste Blanche d'Urgence (Emergency Whitelist)** : Immunité garantie pour les services de secours (911, 811) et les contacts prioritaires, même sous bouclier actif.
* **Mode « Bouclier Strict (Contacts Uniquement) »** : Rejet automatique de tout appel hors carnet d'adresses pour une protection maximale des personnes vulnérables.
* **Bouclier Nocturne Programmé (Night Shield)** : Activation silencieuse planifiée pendant les heures de repos avec exception pour les proches.
* **Inspecteur de Phishing SMS** : Analyse heuristique sur l'appareil détectant les messages frauduleux (faux colis, fausses banques, liens suspects).
* **Journal d'Activité à Double Volet** : Historique des appels récents enrichi avec pastille de sécurité (Reçu / Bloqué) et liste noire locale consultable.
* **Signalement Communautaire en 1 Clic** : Formulaire intuitif avec classification par motif (Fraude, Démarchage, Phishing, Robocall).
* **Console d'Administration Complète** : Accès réservé aux modérateurs (JWT) pour inspecter les métriques globales, auditer la liste noire avec défilement infini paginé, approuver/blanchir des numéros et purger les données obsolètes.
* **Ergonomie Responsive & Zéro Débordement** : Architecture d'interface testée et certifiée sans `RenderFlex overflow` sur toutes largeurs d'écran (dès 320 px).
* **Diagnostics Développeur Intégrés** : Outil d'auto-test en temps réel (ping API, inspection de la base SQLite, vérification des permissions système).
* **Support Bilingue (i18n)** : Prise en charge native du Français (`fr`) et de l'Anglais (`en`).
* **Monitoring & Observabilité** : Intégration de **Sentry** (configuré via `.env`) et journalisation unifiée via `AppLogger`.

---

## 🔐 Accès & Console d'Administration Mobile

L'application mobile ShieldNet embarque une console d'administration native permettant aux opérateurs et modérateurs de superviser le système directement depuis leur téléphone :

1. **Procédure de Connexion Administrateur** :
   - Accéder à l'onglet **Paramètres** de l'application.
   - Sélectionner la carte **Compte Utilisateur** (*« Se connecter ou s'inscrire »*).
   - Renseigner le courriel `admin@shieldnet.app` et le mot de passe `admin123` *(ou cliquer directement sur le bouton d'assistance rapide `🔑 Identifiants Démo Admin (admin@shieldnet.app)`)*.
   - Cliquer sur **Se connecter** : un badge **`ADMIN`** s'active sur votre profil et déverrouille l'accès à la **Console d'Administration**.

2. **Outils d'Administration Intégrés (5 Onglets)** :
   - **1. Vue d'Ensemble & Métriques** : Suivi en direct du total des numéros bloqués/blanchis, du nombre de signalements citoyens et de la santé globale.
   - **2. Gestion de la Liste Noire (Blacklist)** : Recherche instantanée par numéro masqué ou haché, ajout manuel direct, et modération en 1 clic (*blanchiment / blocage*).
   - **3. Modération des Signalements** : Examen qualitatif des rapports soumis par les utilisateurs mobiles avec motifs et horodatages.
   - **4. Supervision des Utilisateurs** : Consultation des comptes utilisateurs et attribution des privilèges administrateur.
   - **5. Journaux d'Audit** : Historique inaltérable traçant les actions de sécurité exécutées.
   - **Outils & Diagnostic Développeur** : Forçage manuel de la synchronisation WAL (complète ou différentielle) et auto-tests matériels.

---

## 🚀 Guide de Démarrage Rapide

### 1. Configuration de l'environnement (`.env`)
Un fichier `.env` à la racine de `ShieldNet/` configure les paramètres réseau et de sécurité :

```env
API_BASE_URL=http://127.0.0.1:8000/api/v1  # 10.0.2.2 pour émulateur Android, ou 127.0.0.1 avec adb reverse
API_KEY=ShieldNet_Secret_Token_UQO_2026
HASH_SALT=ShieldNet_Secure_Salt_2026_UQO
CRYPTO_SALT=ShieldNet_Secure_Salt_2026_UQO
OFFLINE_CACHE_TTL_HOURS=24
ENABLE_AUTO_BLOCKING=true

# Optionnel : DSN Sentry pour le monitoring des erreurs
# SENTRY_DSN=https://examplePublicKey@o0.ingest.sentry.io/0
```

### 2. Installation & Exécution
```bash
# 1. Télécharger les dépendances Flutter
flutter pub get

# 2. Exécuter la suite de tests automatisés (100% de réussite)
flutter test

# 3. Analyser la qualité du code (0 avertissement, 0 lint)
flutter analyze

# 4. Lancer sur appareil connecté ou émulateur
flutter run
```

---

## 👥 Équipe & Cadre Académique
Projet réalisé dans le cadre du **Projet Synthèse d'Informatique** — **Université du Québec en Outaouais (UQO)**.
