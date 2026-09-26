# Architecture Logicielle, Spécification UML & Flux Critiques — ShieldNet

> **Document de Référence Technique & Académique**  
> **Projet de Synthèse en Informatique** — Université du Québec en Outaouais (UQO)  
> **Composant** : Spécification d'Architecture, Modélisation UML & Diagrammes de Séquence  
> **Auteur** : Équipe ShieldNet  
> **Date** : 2026

---

## 1. Vue d'Ensemble des Couches (Clean Architecture)

Le système **ShieldNet** applique une séparation stricte des responsabilités selon le patron architectural **Clean Architecture** (Robert C. Martin / Uncle Bob), adapté à la fois au client Flutter/Dart, aux modules natifs Android (Kotlin) et au backend sécurisé Django REST Framework :

```mermaid
graph TD
    subgraph Presentation_Layer ["Couche Présentation (lib/features/*/presentation)"]
        UI_Pages["Pages (Dashboard, Settings, SmsInspector, AdminConsole)"]
        UI_Widgets["Widgets Modulaires (ZenShieldCard, ActionHub, Tabs)"]
        Controllers["Contrôleurs d'État / Notifiers (Riverpod)"]
    end

    subgraph Domain_Layer ["Couche Domaine (lib/features/*/domain) - Pure Dart"]
        UseCases["Use Cases (AnalyzeSmsUseCase, CheckNumberUseCase)"]
        Entities["Entités Métier (AdminStats, AuditLogEntry, PhishingResult)"]
        RepoInterfaces["Interfaces Abstraites (AdminRepository)"]
    end

    subgraph Data_Layer ["Couche Données (lib/features/*/data)"]
        RepoImpl["Implémentations Référentielles (AdminRepositoryImpl)"]
        DataSources["Sources de Données (ApiService, DatabaseHelper)"]
        DTOs["Modèles de Transfert de Données (BlacklistedNumber)"]
    end

    subgraph Core_Layer ["Socle Transverse (lib/core)"]
        Crypto["Sécurité (CryptoUtils HMAC-SHA256)"]
        Network["Réseau (Dio, ApiClient, AuthInterceptor)"]
        Database["Base SQLite Locale (DatabaseHelper)"]
        Services["Services d'Arrière-Plan (BackgroundSyncService)"]
    end

    subgraph Native_Android ["Module Natif Android (android/app/src/main/kotlin)"]
        CallScreening["ShieldNetCallScreeningService (Telecom OS < 2ms)"]
        NativeDB["ShieldNetDatabaseHelper (SQLite Partagé)"]
    end

    subgraph Backend_Django ["Serveur Cloud Sécurisé (Django REST Framework)"]
        DjangoAPI["Endpoints REST (/api/v1/blacklist, /check, /auth)"]
        DjangoDB["PostgreSQL / SQLite (Modération, Consensus, AuditLog)"]
    end

    UI_Widgets --> UI_Pages
    UI_Pages --> Controllers
    Controllers --> UseCases
    UseCases --> RepoInterfaces
    UseCases --> Entities
    RepoImpl ..|> RepoInterfaces
    RepoImpl --> DataSources
    DataSources --> Core_Layer
    Core_Layer -. Partage SQLite .-> Native_Android
    DataSources -. HTTPS + HMAC .-> Backend_Django
```

---

## 2. Diagramme de Composants Système

Le découpage matériel et logique garantit que l'interception téléphonique critique s'exécute à **100% hors-ligne et en temps réel (< 2 ms)** sans jamais bloquer le fil d'exécution de l'interface utilisateur Flutter.

```mermaid
componentDiagram
    package "Périphérique Mobile Android" {
        [Android Telecom Framework] as Telecom
        component "Moteur Natif Kotlin" {
            [ShieldNetCallScreeningService] as ScreenService
            [Native SQLite Helper] as NativeDB
        }
        database "SQLite Database (shieldnet.db)" as LocalDB
        
        component "Application Flutter" {
            [Riverpod State Management] as StateMgr
            [Dashboard & UI Views] as UI
            [Crypto Engine (HMAC-SHA256)] as CryptoEngine
            [BackgroundSyncService] as SyncMgr
        }
    }

    package "Serveur Central ShieldNet" {
        component "Django REST Backend" {
            [Authentication & JWT] as AuthAPI
            [Blacklist Delta Engine] as DeltaAPI
            [Community Consensus Engine] as ConsensusAPI
            [Audit Trail Manager] as AuditAPI
            [ShieldNet AI Engine / XAI] as AIEngine
        }
        database "Base Centrale (PostgreSQL)" as CentralDB
    }

    Telecom --> ScreenService : Incoming Call Intent
    ScreenService --> NativeDB : Query Hash (< 2ms)
    NativeDB --> LocalDB : Read Index (WAL mode)
    LocalDB <-- DatabaseHelper : Write/Sync (Dart)
    
    UI --> StateMgr : User Action
    StateMgr --> CryptoEngine : Hash Number
    SyncMgr --> DeltaAPI : GET /blacklist/?since=t (Background)
    DeltaAPI --> CentralDB : Query Updates
    ConsensusAPI --> CentralDB : Update Reputation
    AuditAPI --> CentralDB : Immutable Logging
    AIEngine --> CentralDB : Explainable Diagnostics
```

---

## 3. Diagramme de Classes UML (Modèle Métier & Architecture)

Ce diagramme décrit les relations d'héritage, d'implémentation et de dépendance entre les principaux éléments du domaine, des données et de l'infrastructure :

```mermaid
classDiagram
    %% Clean Architecture - Domain Layer
    class AdminRepository {
        <<interface>>
        +getStats() Future~AdminStats~
        +getAuditLogs(page, limit) Future~List~AuditLogEntry~~
        +purgeInactiveEntries(days) Future~int~
        +runConsensusAudit() Future~Map~String, dynamic~~
    }

    class AdminStats {
        +int totalBlacklisted
        +int verifiedSpam
        +int activeCommunityReports
        +int totalProtectedUsers
        +DateTime lastSyncTimestamp
        +fromMap(Map) AdminStats
    }

    class AuditLogEntry {
        +String id
        +String action
        +String performedBy
        +DateTime timestamp
        +String details
        +String ipAddress
        +fromMap(Map) AuditLogEntry
    }

    class AnalyzeSmsUseCase {
        -SmsPhishingDetector _detector
        +call(String text) PhishingResult
        +extractUrls(String text) List~String~
    }

    class PhishingResult {
        +bool isSuspicious
        +double riskScore
        +List~String~ detectedKeywords
        +List~String~ suspiciousUrls
        +String recommendation
    }

    %% Clean Architecture - Data Layer
    class AdminRepositoryImpl {
        -ApiService _apiService
        +getStats() Future~AdminStats~
        +getAuditLogs(page, limit) Future~List~AuditLogEntry~~
        +purgeInactiveEntries(days) Future~int~
        +runConsensusAudit() Future~Map~String, dynamic~~
    }

    %% Core Services
    class ApiService {
        -Dio _dio
        -DatabaseHelper _dbHelper
        +syncBlacklistWithBackend(delta: bool) Future~int~
        +reportSpamNumber(hash, reason) Future~bool~
        +submitSafeReport(hash, category, notes) Future~bool~
        +checkNumbersBatch(hashes) Future~Map~String, dynamic~~
        +checkNumberReputation(hash) Future~Map~
    }

    class AuthService {
        -Dio _dio
        -FlutterSecureStorage _storage
        +login(email, password) Future~UserSession~
        +register(email, password) Future~UserSession~
        +refreshToken() Future~bool~
        +logout() Future~void~
    }

    class DatabaseHelper {
        <<singleton>>
        -Database _database
        +instance DatabaseHelper
        +insertBlacklistBatch(List) Future~int~
        +isNumberBlocked(hash) Future~bool~
        +isEmergencyNumber(number) Future~bool~
        +getAllEmergencyContacts() Future~List~
    }

    class CryptoUtils {
        <<static utility>>
        +normalizePhoneNumber(raw) String
        +computeHmacSha256(phone, salt) String
        +maskPhoneNumber(phone) String
    }

    %% Native Android
    class ShieldNetCallScreeningService {
        +onScreenCall(CallDetails) void
        -evaluateIncomingCall(number) CallResponse
    }

    class ShieldNetDatabaseHelper {
        +isNumberBlocked(hash) Boolean
        +isEmergencyNumber(rawNumber) Boolean
    }

    %% Relations
    AdminRepository <|.. AdminRepositoryImpl : implements
    AdminRepositoryImpl --> ApiService : delegates to
    AdminRepository --> AdminStats : produces
    AdminRepository --> AuditLogEntry : produces
    AnalyzeSmsUseCase --> PhishingResult : produces
    ApiService --> DatabaseHelper : updates local cache
    ApiService --> CryptoUtils : hashes numbers
    ShieldNetCallScreeningService --> ShieldNetDatabaseHelper : queries
    ShieldNetDatabaseHelper ..> DatabaseHelper : shares shieldnet.db
```

---

## 4. Justification des Choix Architecturaux (SOLID & Cybersécurité)

| Principe | Application Concrète dans ShieldNet |
|---|---|
| **Single Responsibility (SRP)** | Découpage des écrans monolithiques en composants autonomes (`ZenShieldCard`, `ActionHubRow`, `AdminAuditTab`) et des Use Cases unitaires (`AnalyzeSmsUseCase`). |
| **Open/Closed (OCP)** | Système de règles d'interception modulaire : l'ajout d'une règle (ex: filtrage IA local, détection STIR/SHAKEN ou whitelist contacts) se fait sans modifier le cœur de la base de données. |
| **Liskov Substitution (LSP)** | L'interface `AdminRepository` peut être substituée par une implémentation mock (`MockAdminRepository`) dans les tests automatisés sans modifier aucun composant UI. |
| **Interface Segregation (ISP)** | Séparation des interfaces de gestion : `AdminRepository` ne contient aucune méthode d'authentification ou d'inspection SMS. |
| **Dependency Inversion (DIP)** | Les StateNotifiers et Use Cases dépendent des abstractions (`AdminRepository`), injectées via les providers Riverpod. |
| **Privacy by Design** | Le hachage cryptographique **HMAC-SHA256** est appliqué avant toute sortie du terminal mobile ; aucune métadonnée personnelle (numéro de téléphone, nom) n'est jamais stockée ou transmise en clair. |

---

## 5. Diagrammes de Séquence des Flux Critiques

### Scénario 1 : Interception d'Appel Entrant en Temps Réel (< 2 ms)

Ce flux représente l'exigence de performance la plus stricte du projet : évaluer l'appel et répondre à l'OS Android avant le premier son de sonnerie, avec la garantie absolue de ne jamais bloquer une urgence.

```mermaid
sequenceDiagram
    autonumber
    actor Caller as Appelant
    participant AndroidOS as Android Telecom Framework
    participant NativeService as ShieldNetCallScreeningService (Kotlin)
    participant NativeDB as ShieldNetDatabaseHelper (SQLite)
    actor Recipient as Utilisateur

    Caller->>AndroidOS: Appel entrant émis (ex: +1 514-999-0000)
    Note over AndroidOS,NativeService: Déclenchement de onScreenCall(details)
    AndroidOS->>NativeService: onScreenCall(callDetails)
    
    %% Étape 0 : Contrôle d'Urgence Immédiat
    Note over NativeService,NativeDB: Étape 0 : Contrôle d'urgence (0 faux positif)
    NativeService->>NativeDB: isEmergencyNumber(rawNumber)
    alt Est un numéro d'urgence (911, 811, 988, Contact Whitelist)
        NativeDB-->>NativeService: return TRUE
        NativeService->>AndroidOS: respondToCall(ALLOW, silence=false, skipCallLog=false)
        AndroidOS->>Recipient: Sonnerie prioritaire immédiate
    else Pas un numéro d'urgence
        NativeDB-->>NativeService: return FALSE
        
        %% Étape 1 : Normalisation et Hachage
        Note over NativeService: Normalisation E.164 + HMAC-SHA256
        NativeService->>NativeDB: isNumberBlocked(phoneHash)
        
        alt Numéro présent dans la Liste Noire
            NativeDB-->>NativeService: return TRUE (Spam confirmé)
            NativeService->>AndroidOS: respondToCall(DISALLOW, reject=true, skipNotification=true)
            Note over AndroidOS: Appel rejeté sans sonnerie (< 2 ms)
            NativeService->>NativeDB: logBlockedCallEvent(phoneHash, timestamp)
        else Numéro absent de la Liste Noire
            NativeDB-->>NativeService: return FALSE
            
            alt Mode "Bouclier Strict" Actif & Numéro Inconnu du Carnet
                NativeService->>AndroidOS: respondToCall(DISALLOW / SILENCE)
                Note over AndroidOS: Appel silencé / boîte vocale
            else Mode Standard
                NativeService->>AndroidOS: respondToCall(ALLOW)
                AndroidOS->>Recipient: Sonnerie normale
            end
        end
    end
```

---

### Scénario 2 : Synchronisation Différentielle (Delta Sync) & Purge Locale

Ce flux illustre la synchronisation d'arrière-plan périodique pilotée par `Workmanager` et `BackgroundSyncService`. Il démontre l'optimisation réseau (téléchargement uniquement des deltas temporels) et la purge automatique des faux-positifs débloqués par les administrateurs.

```mermaid
sequenceDiagram
    autonumber
    participant Workmanager as Android WorkManager
    participant SyncService as BackgroundSyncService (Dart)
    participant ApiService as ApiService (Dio)
    participant DjangoAPI as Backend Django (/api/v1/blacklist/)
    participant CentralDB as PostgreSQL Central
    participant LocalDB as DatabaseHelper (SQLite Locale)

    Workmanager->>SyncService: Exécution tâche périodique programmée
    SyncService->>LocalDB: getLastSyncTimestamp()
    LocalDB-->>SyncService: return '2026-09-20T14:30:00Z'
    
    SyncService->>ApiService: syncBlacklistWithBackend(delta: true, since: '2026-09-20T14:30:00Z')
    ApiService->>DjangoAPI: GET /api/v1/blacklist/?since=2026-09-20T14:30:00Z
    DjangoAPI->>CentralDB: SELECT active, removed WHERE updated_at > since
    CentralDB-->>DjangoAPI: { active: [h1, h2], removed: [h3_false_positive] }
    DjangoAPI-->>ApiService: 200 OK + Payload JSON Delta
    
    %% Transaction locale SQLite
    Note over ApiService,LocalDB: Transaction atomique SQLite
    ApiService->>LocalDB: beginTransaction()
    ApiService->>LocalDB: insertBlacklistBatch(activeList)
    ApiService->>LocalDB: deleteBlacklistByHashes(removedList)
    LocalDB-->>ApiService: return deletedCount (ex: 1 débloqué)
    ApiService->>LocalDB: setLastSyncTimestamp(NOW)
    ApiService->>LocalDB: commitTransaction()
    
    ApiService-->>SyncService: Synchronisation réussie (+2 ajoutés, -1 purgé)
    SyncService-->>Workmanager: Result.success()
```

---

### Scénario 3 : Analyse & Détection de Phishing SMS (Inspecteur SMS)

Ce flux décrit le traitement sécurisé et asynchrone d'un SMS copié par l'utilisateur ou détecté dans le presse-papier, implémentant le use case `AnalyzeSmsUseCase`.

```mermaid
sequenceDiagram
    autonumber
    actor User as Utilisateur
    participant UI as SmsInspectorPage / ClipboardBanner
    participant UseCase as AnalyzeSmsUseCase
    participant Detector as SmsPhishingDetector (Core)
    participant ApiService as ApiService (Reputation Check)
    participant Backend as Backend Django (/api/v1/check-url/)

    User->>UI: Ouvre l'inspecteur ou clique sur "Vérifier le SMS copié"
    UI->>UseCase: call(smsContent)
    
    %% Analyse locale heuristique
    UseCase->>Detector: analyzeText(smsContent)
    Note over Detector: Détection mots-clés d'urgence (Interac, Impôts, Colis, Banque...)
    Note over Detector: Extraction regex des URLs et domaines raccourcis (bit.ly, tinyurl)
    
    Detector-->>UseCase: PhishingResult(heuristicsRisk: 75%, urls: ['http://evil-bank.co'])
    
    %% Vérification réputation en ligne optionnelle
    opt Présence d'URL suspecte
        UseCase->>ApiService: checkUrlReputation('http://evil-bank.co')
        ApiService->>Backend: POST /api/v1/check-url/ { url_hash: sha256(...) }
        Backend-->>ApiService: { is_malicious: true, threat_type: "credential_harvesting" }
        ApiService-->>UseCase: URL confirmée malveillante
    end
    
    UseCase-->>UI: PhishingResult (Risk: 95%, DANGER CRITIQUE, Recommandation: "Ne pas cliquer")
    UI->>User: Rendu visuel d'alerte rouge + Conseils de neutralisation
```

---

### Scénario 4 : Signalement Collaboratif, Modération & Consensus Anti-Fraude

Ce flux détaille la modération communautaire décentralisée : comment un numéro suspect signalé par plusieurs utilisateurs indépendants est automatiquement promu en liste noire globale par consensus sans risque de manipulation par un acteur malveillant unique, et comment les contestations citoyennes permettent de réhabiliter les services légitimes.

```mermaid
sequenceDiagram
    autonumber
    actor Citizen as Utilisateur / Citoyen
    participant App as Application ShieldNet (Flutter)
    participant Crypto as CryptoUtils (HMAC-SHA256)
    participant Backend as Backend Django (/api/v1/reports/)
    participant Consensus as Moteur de Consensus (Auto-Quorum)
    participant AI as ShieldNet AI Engine (XAI)
    participant Admin as Console SOC Web / Mobile

    Citizen->>App: Signale un appel frauduleux ou soumet une contestation
    App->>Crypto: computeHmacSha256(phoneNumber, secretSalt)
    Crypto-->>App: Hash HMAC (aucune fuite du numéro réel)
    
    alt Signalement Spam (Arnaque, Impôts, Démarchage)
        App->>Backend: POST /api/v1/reports/ { phone_hash: h, category: "SCAM", comments: "..." }
        Backend->>Backend: Enregistre le signalement avec IP hashée et user_id
        Backend-->>App: 201 Created ("Signalement enregistré")
        
        %% Moteur de Consensus
        Note over Consensus: Évaluation dynamique des seuils
        Consensus->>Consensus: COUNT(DISTINCT users) WHERE phone_hash = h
        alt Signalements >= Seuil de Quorum (ex: >= 3 utilisateurs distincts)
            Consensus->>Backend: Auto-Promotion en Liste Noire (is_blocked=True)
            Consensus->>Backend: Création AuditLog (action: "AUTO_CONSENSUS_BAN")
        else Signalements < Seuil
            Consensus->>Backend: Maintien en surveillance (Score intermédiaire)
        end
    else Contestation Faux Positif (Santé, Livraison, Proche)
        App->>Backend: POST /api/v1/reports/safe/ { phone_hash: h, category: "HEALTH", notes: "Clinique" }
        Backend->>AI: diagnose(phone_hash, comments)
        AI-->>Backend: Verdict: AUTO_WHITELIST (Confiance FP >= 70%)
        Backend->>Backend: Auto-Blanchiment (is_whitelisted=True)
        Backend->>Backend: Création AuditLog (action: "AUTO_WHITELIST_CONSENSUS")
        Backend-->>App: 200 OK ("Numéro réhabilité avec succès")
    end
    
    Admin->>Backend: GET /admin/operations/triage/
    Backend-->>Admin: Affiche les alertes, diagnostics IA et journaux d'audit inaltérables
```
