# Architecture Logicielle, Modélisation UML & Spécifications d'Ingénierie — ShieldNet

Spécification technique de l'architecture logicielle, des flux de données critiques et des interactions entre les composants du système **ShieldNet**.

---

## 1. Principes d'Architecture (Clean Architecture & Séparation des Responsabilités)

ShieldNet intègre trois environnements d'exécution distincts répondant à des contraintes opérationnelles différentes :

1. **Client Mobile (Flutter / Dart)** : Interface utilisateur réactive, gestion d'état déclarative via Riverpod et communication réseau résiliente (Dio avec gestion hors-ligne).
2. **Module Natif Android (Kotlin)** : Service d'arrière-plan de niveau système d'exploitation (`CallScreeningService`) soumis à une contrainte de latence stricte (< 100 ms) pour l'interception temps réel.
3. **Serveur Backend (Django / Python)** : API REST distribuée, moteur d'arbitrage contextuel, gestion des droits RBAC et journal d'audit immuable.

Pour assurer la maintenabilité et l'indépendance vis-à-vis des bibliothèques externes, le code client adopte les préceptes de la **Clean Architecture** :

```mermaid
graph TD
    subgraph Presentation_Layer ["Couche Présentation (lib/features/*/presentation)"]
        UI_Pages["Pages (Dashboard, Settings, SmsInspector, AdminConsole)"]
        UI_Widgets["Widgets Réutilisables (Cartes, Boutons, Onglets)"]
        Controllers["Gestion d'état (Riverpod Notifiers)"]
    end

    subgraph Domain_Layer ["Couche Domaine (lib/features/*/domain) - Purement Dart"]
        UseCases["Cas d'Utilisation (AnalyzeSmsUseCase, CheckNumberUseCase)"]
        Entities["Entités Métier (AdminStats, AuditLogEntry, PhishingResult)"]
        RepoInterfaces["Contrats d'Interfaces (AdminRepository, BlacklistRepository)"]
    end

    subgraph Data_Layer ["Couche Données (lib/features/*/data)"]
        RepoImpl["Implémentations (AdminRepositoryImpl, BlacklistRepositoryImpl)"]
        DataSources["Sources de Données (ApiService, DatabaseHelper)"]
        DTOs["Modèles de Données (BlacklistedNumber)"]
    end

    subgraph Core_Layer ["Socle Commun (lib/core)"]
        Crypto["Cryptographie (HMAC-SHA256, masquage E.164)"]
        Network["Client HTTP (Dio, SSL Pinning, intercepteurs)"]
        Database["Gestionnaire SQLite (DatabaseHelper en mode WAL)"]
        Services["Services d'Arrière-Plan & File Hors-Ligne (OfflineSyncService)"]
    end

    subgraph Native_Android ["Module Natif Android (android/app/src/main/kotlin)"]
        CallScreening["ShieldNetCallScreeningService (Interception Telecom)"]
        NativeDB["ShieldNetDatabaseHelper (Lecture SQLite directe)"]
    end

    subgraph Backend_Django ["Serveur Backend (Django REST Framework)"]
        DjangoAPI["API REST (/api/v1/sync/delta, /check, /reports)"]
        DjangoDB["Base de Données (PostgreSQL / SQLite)"]
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

### Avantages de la Découplage
- **Isolement des Règles Métier** : La logique de calcul du score de sérénité, de détection de phishing ou d'arbitrage ne dépend d'aucun framework graphique ou pilote de base de données.
- **Testabilité Exhaustive** : Remplacement aisé des sources de données par des simulacres (*mocks*) dans la suite de 86 tests automatisés Flutter.

---

## 2. Diagramme de Composants Système

Le système est conçu pour fonctionner de manière autonome en mode déconnecté (*Offline-First*), tout en maintenant une synchronisation différentielle efficace avec l'infrastructure centrale :

```mermaid
componentDiagram
    package "Terminel Mobile Android (Utilisateur)" {
        [Android Telecom Framework] as Telecom
        component "Module Natif Kotlin" {
            [ShieldNetCallScreeningService] as ScreenService
            [Pont SQLite Natif] as NativeDB
        }
        database "Base Locale (shieldnet.db WAL)" as LocalDB
        
        component "Application Client Flutter" {
            [Gestionnaire d'État Riverpod] as StateMgr
            [Interface Utilisateur] as UI
            [Moteur Cryptographique HMAC] as CryptoEngine
            [File Hors-Ligne & Sync] as OfflineQueue
        }
    }

    package "Infrastructure Serveur ShieldNet" {
        component "API Django REST" {
            [Authentification JWT & RBAC] as AuthAPI
            [Moteur de Sync Différentielle] as DeltaAPI
            [Moteur de Consensus Communautaire] as ConsensusAPI
            [Journal d'Audit Immuable] as AuditAPI
            [Moteur d'Arbitrage & Explicabilité] as AIEngine
        }
        database "Base de Données Centrale" as CentralDB
    }

    Telecom --> ScreenService : Appel entrant détecté
    ScreenService --> NativeDB : Vérification du hash (< 2 ms)
    NativeDB --> LocalDB : Consultation index B-Tree
    LocalDB <-- StateMgr : Mise à jour des règles (Dart)
    
    UI --> StateMgr : Action utilisateur
    StateMgr --> CryptoEngine : Hachage normalisé du numéro
    OfflineQueue --> DeltaAPI : GET /sync/delta?since_version=v (périodique)
    DeltaAPI --> CentralDB : Lecture des deltas et tombstones
    ConsensusAPI --> CentralDB : Quorum de réhabilitation
    AuditAPI --> CentralDB : Traçabilité des décisions
    AIEngine --> CentralDB : Scoring contextuel et STIR/SHAKEN
```

---

## 3. Diagramme de Classes UML (Client Mobile)

Structure des classes et interfaces principales du client mobile :

```mermaid
classDiagram
    %% Couche Domaine
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

    %% Couche Données
    class AdminRepositoryImpl {
        -ApiService _apiService
        +getStats() Future~AdminStats~
        +getAuditLogs(page, limit) Future~List~AuditLogEntry~~
        +purgeInactiveEntries(days) Future~int~
        +runConsensusAudit() Future~Map~String, dynamic~~
    }

    %% Socle Technique
    class ApiService {
        -Dio _dio
        -DatabaseHelper _dbHelper
        +syncBlacklistWithBackend(delta: bool) Future~int~
        +reportSpamNumber(hash, reason) Future~bool~
        +submitSafeReport(hash, category, notes) Future~bool~
        +checkNumbersBatch(hashes) Future~Map~String, dynamic~~
        +checkNumberReputation(hash) Future~Map~
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
        <<utilitaire>>
        +normalizePhoneNumber(raw) String
        +computeHmacSha256(phone, salt) String
        +maskPhoneNumber(phone) String
    }

    %% Composants Android Natifs
    class ShieldNetCallScreeningService {
        +onScreenCall(CallDetails) void
        -evaluateIncomingCall(number) CallResponse
    }

    class ShieldNetDatabaseHelper {
        +isNumberBlocked(hash) Boolean
        +isEmergencyNumber(rawNumber) Boolean
    }

    %% Relations
    AdminRepository <|.. AdminRepositoryImpl : implémente
    AdminRepositoryImpl --> ApiService : délègue à
    AdminRepository --> AdminStats : produit
    AdminRepository --> AuditLogEntry : produit
    AnalyzeSmsUseCase --> PhishingResult : produit
    ApiService --> DatabaseHelper : synchronise
    ApiService --> CryptoUtils : hache les numéros
    ShieldNetCallScreeningService --> ShieldNetDatabaseHelper : interroge
    ShieldNetDatabaseHelper ..> DatabaseHelper : partage shieldnet.db
```

---

## 4. Application des Principes d'Ingénierie SOLID

L'ensemble de la base de code applique rigoureusement les principes de conception orientée objet :

| Principe | Application concrète dans ShieldNet |
|---|---|
| **Responsabilité Unique (SRP)** | Chaque composant assume un rôle unique. `CryptoUtils` se consacre exclusivement aux transformations cryptographiques, tandis que `AnalyzeSmsUseCase` isole l'évaluation heuristique des messages sans dépendance UI. |
| **Ouvert / Fermé (OCP)** | Le système de filtrage accepte de nouvelles règles d'arbitrage (ex: seuils STIR/SHAKEN, plages régionales) par extension de stratégies sans altérer le schéma SQLite sous-jacent. |
| **Substitution de Liskov (LSP)** | Les abstractions de référentiel (`AdminRepository`, `BlacklistRepository`) sont interchangeables avec des doubles de test (`MockAdminRepository`) sans modifier le comportement des contrôleurs d'affichage. |
| **Ségrégation des Interfaces (ISP)** | Les interfaces client sont modulées par domaine fonctionnel (administration, filtrage d'appels, analyse SMS) évitant les contrats monolithiques. |
| **Inversion des Dépendances (DIP)** | Les contrôleurs d'état consomment des abstractions de cas d'utilisation injectées par Riverpod, éliminant tout couplage direct avec les pilotes HTTP ou disques. |

---

## 5. Flux Opérationnels Critiques

### 5.1. Interception d'un Appel Entrant (< 2 ms)
Contrainte de latence absolue pour garantir la non-interruption du service télécom et l'immunité intégrale des numéros d'urgence :

```mermaid
sequenceDiagram
    autonumber
    actor Appelant as Appelant
    participant AndroidOS as Téléphonie Android (Telecom)
    participant NativeService as ShieldNetCallScreeningService (Kotlin)
    participant NativeDB as Base SQLite Locale (shieldnet.db)
    actor Utilisateur as Destinataire

    Appelant->>AndroidOS: Appel entrant (+1 514-555-0199)
    AndroidOS->>NativeService: onScreenCall(callDetails)
    
    %% Étape 0 : Contrôle d'urgence prioritaire
    Note over NativeService,NativeDB: Contrôle d'immunité prioritaire (911, 811, 988, favoris)
    NativeService->>NativeDB: isEmergencyNumber(rawNumber)
    alt Numéro d'urgence ou contact prioritaire
        NativeDB-->>NativeService: VRAI
        NativeService->>AndroidOS: respondToCall(ALLOW)
        AndroidOS->>Utilisateur: Sonnerie normale prioritaire
    else Numéro standard
        NativeDB-->>NativeService: FAUX
        
        %% Étape 1 : Normalisation & Hachage
        Note over NativeService: Normalisation E.164 + HMAC-SHA256 (< 0.2 ms)
        NativeService->>NativeDB: isNumberBlocked(phoneHash)
        
        alt Présent en liste de blocage active
            NativeDB-->>NativeService: VRAI (Menace confirmée)
            NativeService->>AndroidOS: respondToCall(DISALLOW, rejet silencieux)
            Note over AndroidOS: Appel rejeté sans sonnerie (< 2 ms)
            NativeService->>NativeDB: logBlockedCallEvent(phoneHash, date)
        else Absent de la liste de blocage
            NativeDB-->>NativeService: FAUX
            
            alt Mode "Contacts Uniquement" activé & numéro inconnu
                NativeService->>AndroidOS: respondToCall(SILENCE, boîte vocale)
            else Mode Standard
                NativeService->>AndroidOS: respondToCall(ALLOW)
                AndroidOS->>Utilisateur: Sonnerie normale
            end
        end
    end
```

---

### 5.2. Synchronisation Différentielle (Delta Sync)
Minimisation de la bande passante et des écritures disques par transmission exclusive des deltas et des suppressions (tombstones) :

```mermaid
sequenceDiagram
    autonumber
    participant Scheduler as Tâche d'Arrière-Plan (WorkManager)
    participant SyncService as BackgroundSyncService
    participant ApiService as Client HTTP Dio
    participant DjangoAPI as API Backend (/api/v1/sync/delta)
    participant LocalDB as Base SQLite Locale

    Scheduler->>SyncService: Déclenchement périodique
    SyncService->>LocalDB: Lecture version locale courante (sync_version)
    LocalDB-->>SyncService: version = 142
    
    SyncService->>ApiService: syncDelta(since_version: 142)
    ApiService->>DjangoAPI: GET /api/v1/sync/delta?since_version=142
    DjangoAPI-->>ApiService: 200 OK { new_version: 145, active: [h1, h2], removed: [h3] }
    
    Note over ApiService,LocalDB: Transaction atomique SQLite
    ApiService->>LocalDB: beginTransaction()
    ApiService->>LocalDB: Insertion / mise à jour (h1, h2)
    ApiService->>LocalDB: Purge des numéros réhabilités (h3)
    ApiService->>LocalDB: Mise à jour sync_version = 145
    ApiService->>LocalDB: commitTransaction()
    
    ApiService-->>SyncService: Synchronisation complétée (+2 actifs, -1 réhabilité)
    SyncService-->>Scheduler: Succès
```

---

### 5.3. Analyse Heuristique de SMS dans l'Inspecteur
Évaluation locale du contenu textuel sans exfiltration de données personnelles :

```mermaid
sequenceDiagram
    autonumber
    actor Utilisateur as Utilisateur
    participant UI as Page SmsInspector
    participant UseCase as AnalyzeSmsUseCase
    participant Detector as SmsPhishingDetector (Heuristique & Regex)
    participant ApiService as Client HTTP
    participant Backend as API Django

    Utilisateur->>UI: Analyse du texte collé
    UI->>UseCase: call(smsText)
    
    UseCase->>Detector: analyzeText(smsText)
    Note over Detector: Détection des motifs d'urgence, fiscalité, colis et faux liens
    Detector-->>UseCase: Résultat préliminaire (Risque: 75%, URL extraite)
    
    opt Si URL présente dans le SMS
        UseCase->>ApiService: checkUrlReputation(url)
        ApiService->>Backend: POST /api/v1/check-url/
        Backend-->>ApiService: { is_malicious: true, category: "PHISHING" }
        ApiService-->>UseCase: Confirmation de menace URL
    end
    
    UseCase-->>UI: Résultat consolidé (Niveau de risque, marqueurs identifiés, conseils)
    UI->>Utilisateur: Affichage du rapport d'analyse
```

---

### 5.4. Signalement Collaboratif & Réhabilitation par Consensus
Gestion décentralisée de la réputation évitant les abus et protégeant les services essentiels :

```mermaid
sequenceDiagram
    autonumber
    actor Citoyen as Utilisateur
    participant App as Application ShieldNet
    participant Crypto as Module HMAC-SHA256
    participant Backend as API Django (/api/v1/reports/)
    participant Consensus as Moteur de Consensus
    participant Admin as Console Web de Modération

    Citoyen->>App: Soumission (Signalement de spam ou Contestation)
    App->>Crypto: Calcul de l'empreinte normalisée avec sel
    Crypto-->>App: Hash HMAC-SHA256 (aucun numéro en clair)
    
    alt Signalement de Spam
        App->>Backend: POST /api/v1/reports/ { phone_hash: h, category: "FRAUD" }
        Backend-->>App: Signalement consigné
        
        Consensus->>Consensus: Évaluation du quorum (utilisateurs distincts)
        alt Quorum atteint (>= 3 signalements indépendants)
            Consensus->>Backend: Blocage automatique et enregistrement AuditLog
        else Quorum non atteint
            Consensus->>Backend: Conservation sous surveillance
        end
    else Contestation Légitime (Service médical, livraison)
        App->>Backend: POST /api/v1/reports/safe/ { phone_hash: h, category: "HEALTH" }
        Consensus->>Consensus: Examen du ratio contestations / signalements
        Consensus->>Backend: Réhabilitation (is_whitelisted = True)
        Consensus->>Backend: Journalisation (AUTO_WHITELIST)
        Backend-->>App: Contestation validée
    end
    
    Admin->>Backend: Supervision des décisions via la console de modération
```