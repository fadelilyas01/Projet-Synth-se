# ShieldNet — Solution Collaborative de Filtrage & Anti-Spam (Mobile Flutter & Android)

[![Flutter](https://img.shields.io/badge/Flutter-3.27.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20(Natif%20CallScreening)%20%7C%20iOS-green.svg)]()
[![Propriété](https://img.shields.io/badge/Propriété-UQO%20(Université%20du%20Québec%20en%20Outaouais)-004f9e.svg)](https://uqo.ca)
[![Tests](https://img.shields.io/badge/Tests%20Mobile-69%2F69%20Pass%20(100%25)-success.svg)]()
[![Linter](https://img.shields.io/badge/Linter-0%20Avertissement-brightgreen.svg)]()

**ShieldNet** est une application mobile native et multiplateforme de pointe dédiée à l'interception, au filtrage et à la neutralisation des appels et SMS indésirables (démarchage agressif, usurpations gouvernementales, arnaques financières et robocalls).  
Conçu et développé dans le cadre du **Projet de Synthèse en Informatique à l'Université du Québec en Outaouais (UQO)**, le système protège spécifiquement le plan de numérotation nord-américain (**indicatif `+1` pour le Canada et les États-Unis**).

---

## Architecture Modulaire & Clean Architecture

L'application mobile respecte scrupuleusement les principes de **Clean Architecture**, orchestrée par **Riverpod** pour une gestion d'état réactive, testable et découplée :

```text
lib/
├── core/
│   ├── config/             # Configuration centralisée (.env, timeouts, constantes)
│   ├── database/           # Cache SQLite local ultra-rapide (WAL mode, index B-Tree)
│   ├── error/              # Gestion typée des échecs (Failures & Exceptions)
│   ├── network/            # Client Dio REST API (authentification X-API-Key, Batch Check, interceptors)
│   ├── providers/          # Injection de dépendances et état global (Riverpod)
│   ├── security/           # Anonymisation HMAC-SHA256, validation NANP (+1), heuristique
│   ├── services/           # Intégration native Android (Telecom CallScreeningService, BackgroundSync)
│   ├── theme/              # Design System moderne (modes Clair / Sombre, HSL dynamiques)
│   ├── utils/              # AppLogger structuré et monitoring Sentry
│   └── widgets/            # Composants UI atomiques et réutilisables
├── features/
│   ├── call_filtering/     # Dashboard "Zen", historique d'appels, audit batch et contestation
│   │   ├── domain/         # Entités et cas d'utilisation métier
│   │   ├── data/           # Répertoires et sources de données (local SQLite + remote API)
│   │   └── presentation/   # Écrans (DashboardPage, ActivityPage avec audit & contestation, ReportPage)
│   ├── onboarding/         # Parcours d'accueil, pédagogie RGPD et demande de permissions
│   └── settings/           # Paramètres de sécurité, diagnostics et Console Administrateur
│       └── presentation/
│           ├── widgets/auth_bottom_sheet.dart  # Formulaire de connexion/inscription avec bascule œil
│           └── SettingsPage, AdminConsolePage, DeveloperDiagnosticPage
├── l10n/                   # Internationalisation bilingue (Français / Anglais)
└── main.dart               # Point d'entrée, initialisation Sentry, SQLite et injection
```

---

## Sécurité, Confidentialité & Conformité RGPD / Loi 25

1. **Anonymisation stricte HMAC-SHA256 (`crypto_utils.dart`)** :
   - Aucun numéro de téléphone en clair ne transite sur le réseau ni n'est persisté côté serveur.
   - Hachage cryptographique **HMAC-SHA256** combiné à un sel secret partagé, strictement déterministe et identique entre Dart, Kotlin (`ShieldNetCallScreeningService`) et Django.
   - Déport des calculs intensifs dans un **Isolate d'arrière-plan (`compute`)** pour garantir 60 FPS constants.
2. **Cache Local Haute Performance (`database_helper.dart`)** :
   - SQLite configuré en mode **Write-Ahead Logging (WAL)** avec index composites.
   - Temps d'interception d'un appel entrant **inférieur à 2 ms**, opérationnel hors-ligne ou en mode avion.
   - Masquage automatique des numéros affichés (`+1 819 *** **67`).
3. **Filtrage Natif Temps Réel (`CallScreeningService`)** :
   - Intégration directe au sous-système Télécom Android pour rejeter silencieusement les fraudeurs avant toute sonnerie.

---

## Fonctionnalités Majeures

* **Audit de Sécurité du Journal d'Appels (Fast Batch Scan)** : Analyse instantanée des appels récents de l'appareil via `ApiService.checkNumbersBatch`, interrogeant le Cloud ShieldNet en une seule requête pour alerter immédiatement sur les menaces potentielles.
* **Fiche et Contestation Interactive des Faux-Positifs** : Toucher n'importe quel numéro dans la liste des numéros bloqués ouvre une fiche détaillée (risque, catégorie, consensus) avec formulaire de contestation citoyenne (santé, livraison, proche, service, erreur).
* **Bascule de Visibilité du Mot de Passe (Icône Œil)** : Formulaire d'authentification (`auth_bottom_sheet.dart`) avec bouton intuitif permettant de vérifier ou masquer le mot de passe saisi sans compromettre la sécurité.
* **Tableau de Bord « Zen »** : Visualisation en temps réel de l'état de veille du bouclier, pulsation d'activité et testeur rapide de numéro.
* **Score de Sérénité & Impact Citoyen** : Valorisation chiffrée de la tranquillité d'esprit (appels bloqués, minutes préservées, signalements utiles).
* **Liste Blanche d'Urgence (Emergency Whitelist)** : Immunité absolue garantie pour les services de secours (911, 811, 988) et les contacts personnels favoris.
* **Mode « Bouclier Strict (Contacts Uniquement) »** : Blocage préventif de tout appel ne figurant pas dans le carnet d'adresses de l'appareil.
* **Bouclier Nocturne Programmé (Night Shield)** : Protection silencieuse automatique selon des plages horaires définies.
* **Inspecteur de Phishing SMS (Durci ReDoS)** : Analyseur heuristique sur l'appareil détectant les messages frauduleux (liens suspects, usurpations bancaires ou colis) avec regex non-chevauchantes.
* **Console d'Administration Mobile Intégrée (5 Onglets)** : Déverrouillée pour les comptes avec privilèges `is_staff` (`admin@shieldnet.app`), offrant la supervision en direct, la gestion de la liste noire, le traitement des signalements, la gestion des utilisateurs et les journaux d'audit.
* **Ergonomie Responsive & Zéro Débordement** : Interface certifiée sans aucun débordement (`0 RenderFlex overflow`) sur les écrans étroits de 320 px.
* **Synchronisation d'Arrière-Plan Robuste (`BackgroundSyncService`)** : Rafraîchissement périodique configurable de la liste noire certifiée.

---

## Guide de Démarrage Rapide

### 1. Configuration de l'environnement (`.env`)
À la racine de `ShieldNet/`, configurez `.env` :

```env
API_BASE_URL=http://127.0.0.1:8000/api/v1  # Ou 10.0.2.2 pour émulateur Android
API_KEY=ShieldNet_Secret_Token_UQO_2026
HASH_SALT=ShieldNet_Secure_Salt_2026_UQO
CRYPTO_SALT=ShieldNet_Secure_Salt_2026_UQO
OFFLINE_CACHE_TTL_HOURS=24
ENABLE_AUTO_BLOCKING=true
```

### 2. Installation & Exécution
```bash
# 1. Télécharger les paquets
flutter pub get

# 2. Exécuter la suite complète de tests (69 tests — 100% de réussite)
flutter test

# 3. Vérifier la qualité du code (0 avertissement)
flutter analyze

# 4. Lancer l'application
flutter run
```

---

## Mentions Légales
© 2026 Université du Québec en Outaouais (UQO) — Tous droits réservés.
