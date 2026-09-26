# Architecture Logicielle, Modélisation UML & Flux Critiques — ShieldNet

**Projet de Synthèse en Informatique** — Université du Québec en Outaouais (UQO)  
**Équipe** : Projet ShieldNet  
**Session** : 2026  

---

## 1. Pourquoi cette architecture ? (Clean Architecture)

L'un des défis majeurs de ShieldNet était de faire communiquer harmonieusement trois environnements techniques distincts :
1. Une interface utilisateur réactive en **Flutter (Dart)**.
2. Un service natif **Android (Kotlin)** qui s'exécute au niveau du système d'exploitation pour intercepter les appels en moins de 2 millisecondes.
3. Une API serveur sécurisée en **Django REST Framework** pour la centralisation des signalements et la résolution des faux positifs.

Pour éviter que ces différentes parties ne s'emmêlent, nous avons adopté les principes de la **Clean Architecture** (Robert C. Martin). L'idée est simple : la logique métier ne doit jamais dépendre directement des détails techniques (que ce soit la base SQLite, le réseau HTTP Dio ou le framework Android).

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
        RepoImpl["Implémentations (AdminRepositoryImpl)"]
        DataSources["Sources de Données (ApiService, DatabaseHelper)"]
        DTOs["Modèles de Données (BlacklistedNumber)"]
    end

    subgraph Core_Layer ["Socle Commun (lib/core)"]
        Crypto["Cryptographie (HMAC-SHA256, masquage de numéros)"]
        Network["Client HTTP (Dio, intercepteurs de sécurité)"]
        Database["Gestionnaire SQLite (DatabaseHelper en mode WAL)"]
        Services["Services d'Arrière-Plan (BackgroundSyncService)"]
    end

    subgraph Native_Android ["Module Natif Android (android/app/src/main/kotlin)"]
        CallScreening["ShieldNetCallScreeningService (Interception Telecom)"]
        NativeDB["ShieldNetDatabaseHelper (Lecture SQLite directe)"]
    end

    subgraph Backend_Django ["Serveur Backend (Django REST Framework)"]
        DjangoAPI["API REST (/api/v1/blacklist, /check, /reports)"]
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

Grâce à cette séparation :
* Si nous voulons changer la bibliothèque HTTP ou la base de données, les cas d'utilisation métier ne changent pas d'une seule ligne.
* Pour les tests unitaires, nous pouvons remplacer n'importe quel dépôt par un faux (*mock*) sans jamais avoir besoin d'allumer le serveur backend.

---

## 2. Diagramme de Composants

Le diagramme ci-dessous illustre comment le téléphone et le serveur interagissent. La contrainte la plus importante était de garantir que le téléphone puisse filtrer les appels même s'il est en mode avion ou dans une zone sans réseau :

```mermaid
componentDiagram
    package "Téléphone Android de l'Utilisateur" {
        [Android Telecom Framework] as Telecom
        component "Service Natif Kotlin" {
            [ShieldNetCallScreeningService] as ScreenService
            [Pont SQLite Natif] as NativeDB
        }
        database "Base Locale (shieldnet.db en mode WAL)" as LocalDB
        
        component "Application Flutter" {
            [Gestionnaire d'État Riverpod] as StateMgr
            [Interface Utilisateur] as UI
            [Module Cryptographique HMAC] as CryptoEngine
            [Synchronisation d'Arrière-Plan] as SyncMgr
        }
    }

    package "Serveur Central ShieldNet" {
        component "API Django REST" {
            [Authentification JWT] as AuthAPI
            [Moteur de Synchronisation Delta] as DeltaAPI
            [Moteur de Consensus Communautaire] as ConsensusAPI
            [Journal d'Audit Immuable] as AuditAPI
            [Moteur d'Arbitrage & Explicabilité] as AIEngine
        }
        database "Base de Données Centrale" as CentralDB
    }

    Telecom --> ScreenService : Appel entrant détecté
    ScreenService --> NativeDB : Vérification du hash (< 2 ms)
    NativeDB --> LocalDB : Lecture de l'index B-Tree
    LocalDB <-- StateMgr : Mise à jour des règles (Dart)
    
    UI --> StateMgr : Action de l'utilisateur
    StateMgr --> CryptoEngine : Hachage du numéro
    SyncMgr --> DeltaAPI : GET /blacklist/?since=t (tâche périodique)
    DeltaAPI --> CentralDB : Lecture des nouveautés
    ConsensusAPI --> CentralDB : Réhabilitation des faux positifs
    AuditAPI --> CentralDB : Traçabilité des décisions
    AIEngine --> CentralDB : Diagnostics argumentés
```

---

## 3. Diagramme de Classes UML

Voici les classes principales qui structurent le client mobile et leurs relations :

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

    %% Services du socle technique
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
    ApiService --> DatabaseHelper : met à jour le cache
    ApiService --> CryptoUtils : hache les numéros
    ShieldNetCallScreeningService --> ShieldNetDatabaseHelper : interroge
    ShieldNetDatabaseHelper ..> DatabaseHelper : partage shieldnet.db
```

---

## 4. Application Concrète des Principes SOLID

Dans le cadre du cours de génie logiciel, nous avons tenu à appliquer rigoureusement les principes **SOLID** :

| Principe | Comment nous l'avons appliqué dans ShieldNet |
|---|---|
| **Responsabilité Unique (SRP)** | Chaque classe a un seul rôle. Par exemple, `CryptoUtils` ne s'occupe que de hacher et normaliser, tandis que `AnalyzeSmsUseCase` s'occupe uniquement d'analyser le texte des SMS sans se soucier de l'interface graphique. |
| **Ouvert / Fermé (OCP)** | Le système de filtrage est ouvert aux extensions : pour ajouter une nouvelle règle de filtrage (ex: vérification STIR/SHAKEN ou liste blanche d'urgence), nous n'avons pas besoin de modifier la logique de la base de données. |
| **Substitution de Liskov (LSP)** | L'interface abstraite `AdminRepository` peut être remplacée par `MockAdminRepository` dans nos tests unitaires sans qu'aucun widget d'affichage ne se rende compte de la différence. |
| **Ségrégation des Interfaces (ISP)** | Nous avons évité les interfaces « fourre-tout ». L'interface d'administration est séparée de celle de gestion des SMS ou de l'authentification. |
| **Inversion des Dépendances (DIP)** | Les contrôleurs d'affichage ne dépendent jamais directement de l'implémentation SQLite ou réseau. Ils dépendent uniquement d'abstractions injectées via les *providers* Riverpod. |

---

## 5. Les 4 Flux Critiques du Système

Voici le déroulement chronologique des quatre opérations clés de ShieldNet :

### Scénario 1 : Interception d'un appel entrant en moins de 2 ms

C'est l'exigence de performance la plus stricte du projet : nous devons décider quoi faire de l'appel avant que le téléphone ne sonne, tout en ayant l'assurance absolue de ne **jamais bloquer un appel d'urgence** :

```mermaid
sequenceDiagram
    autonumber
    actor Appelant as Appelant
    participant AndroidOS as Système Android (Telecom)
    participant NativeService as ShieldNetCallScreeningService (Kotlin)
    participant NativeDB as Base SQLite Locale (shieldnet.db)
    actor Utilisateur as Utilisateur

    Appelant->>AndroidOS: Appel entrant émis (+1 514-999-0000)
    Note over AndroidOS,NativeService: Déclenchement de onScreenCall()
    AndroidOS->>NativeService: onScreenCall(callDetails)
    
    %% Étape 0 : Contrôle d'urgence immédiat
    Note over NativeService,NativeDB: Étape 0 : Vérification des urgences (911, 811, contacts favoris)
    NativeService->>NativeDB: isEmergencyNumber(rawNumber)
    alt Numéro d'urgence ou contact d'urgence
        NativeDB-->>NativeService: VRAI
        NativeService->>AndroidOS: respondToCall(ALLOW, sonnerie prioritaire)
        AndroidOS->>Utilisateur: Sonnerie normale immédiate
    else Numéro ordinaire
        NativeDB-->>NativeService: FAUX
        
        %% Étape 1 : Hachage et vérification de la liste noire
        Note over NativeService: Normalisation E.164 + HMAC-SHA256 (< 0.2 ms)
        NativeService->>NativeDB: isNumberBlocked(phoneHash)
        
        alt Numéro présent dans la liste noire
            NativeDB-->>NativeService: VRAI (Spam confirmé)
            NativeService->>AndroidOS: respondToCall(DISALLOW, rejeter sans sonner)
            Note over AndroidOS: Appel coupé silencieusement (< 2 ms)
            NativeService->>NativeDB: logBlockedCallEvent(phoneHash, date)
        else Numéro absent de la liste noire
            NativeDB-->>NativeService: FAUX
            
            alt Mode "Contacts Uniquement" activé & numéro inconnu
                NativeService->>AndroidOS: respondToCall(SILENCE, envoyer vers la boîte vocale)
            else Mode Standard
                NativeService->>AndroidOS: respondToCall(ALLOW)
                AndroidOS->>Utilisateur: Sonnerie normale
            end
        end
    end
```

---

### Scénario 2 : Synchronisation incrémentale (Delta Sync)

Pour ne pas surcharger la connexion mobile de l'utilisateur, l'application ne télécharge pas l'intégralité de la base à chaque fois. Elle demande uniquement les modifications survenues depuis son dernier passage :

```mermaid
sequenceDiagram
    autonumber
    participant Workmanager as Gestionnaire de tâches Android
    participant SyncService as BackgroundSyncService (Dart)
    participant ApiService as Client HTTP (Dio)
    participant DjangoAPI as API Django (/api/v1/blacklist/)
    participant LocalDB as Base SQLite Locale

    Workmanager->>SyncService: Déclenchement périodique en arrière-plan
    SyncService->>LocalDB: Quelle est la date de dernière synchronisation ?
    LocalDB-->>SyncService: '2026-09-20 14:30:00'
    
    SyncService->>ApiService: syncBlacklistWithBackend(since: '2026-09-20 14:30:00')
    ApiService->>DjangoAPI: GET /api/v1/blacklist/?since=2026-09-20T14:30:00Z
    DjangoAPI-->>ApiService: 200 OK { ajouts: [h1, h2], retraits_faux_positifs: [h3] }
    
    Note over ApiService,LocalDB: Transaction atomique dans SQLite
    ApiService->>LocalDB: beginTransaction()
    ApiService->>LocalDB: Insérer les nouveaux numéros bloqués (h1, h2)
    ApiService->>LocalDB: Supprimer les faux positifs réhabilités (h3)
    ApiService->>LocalDB: Enregistrer la date actuelle comme nouvelle référence
    ApiService->>LocalDB: commitTransaction()
    
    ApiService-->>SyncService: Synchronisation terminée (+2 bloqués, -1 débloqué)
    SyncService-->>Workmanager: Succès
```

---

### Scénario 3 : Analyse d'un SMS suspect dans l'Inspecteur

Ce flux décrit ce qui se passe quand l'utilisateur copie un SMS douteux et ouvre l'inspecteur :

```mermaid
sequenceDiagram
    autonumber
    actor Utilisateur as Utilisateur
    participant UI as Page Inspecteur SMS
    participant UseCase as AnalyzeSmsUseCase
    participant Detector as Détecteur Lexical (Regex & Mots-clés)
    participant ApiService as Client HTTP (Vérification URL)
    participant Backend as Serveur Django

    Utilisateur->>UI: Clique sur "Analyser le SMS copié"
    UI->>UseCase: call(texteDuSms)
    
    UseCase->>Detector: analyzeText(texteDuSms)
    Note over Detector: Recherche de mots-clés d'urgence (Interac, Impôts, Colis, Banque...)
    Note over Detector: Extraction des URLs (bit.ly, domaines suspects)
    
    Detector-->>UseCase: Résultat local (Risque: 75%, URL détectée: 'http://evil-bank.co')
    
    opt Si une URL suspecte est trouvée
        UseCase->>ApiService: checkUrlReputation('http://evil-bank.co')
        ApiService->>Backend: POST /api/v1/check-url/
        Backend-->>ApiService: { is_malicious: true, motif: "hameçonnage" }
        ApiService-->>UseCase: URL malveillante confirmée
    end
    
    UseCase-->>UI: Verdict final (Risque: 95%, Alerte Rouge, Conseil: Ne pas ouvrir)
    UI->>Utilisateur: Affiche l'avertissement et les conseils de neutralisation
```

---

### Scénario 4 : Signalement citoyen et réhabilitation par consensus

Ce flux montre comment la communauté participe : comment plusieurs signalements permettent de bloquer automatiquement un spammeur sans intervention humaine, et comment les contestations permettent de débloquer un numéro légitime :

```mermaid
sequenceDiagram
    autonumber
    actor Citoyen as Utilisateur (Citoyen)
    participant App as Application ShieldNet
    participant Crypto as Module HMAC-SHA256
    participant Backend as API Django (/api/v1/reports/)
    participant Consensus as Moteur de Consensus
    participant Admin as Console Web d'Administration

    Citoyen->>App: Dépose un signalement (Spam ou Contestation)
    App->>Crypto: Hache le numéro avec le sel secret
    Crypto-->>App: Empreinte HMAC (le vrai numéro ne quitte jamais le téléphone)
    
    alt Cas 1 : Signalement d'un spam (Arnaque, Démarchage)
        App->>Backend: POST /api/v1/reports/ { phone_hash: h, categorie: "ARNAQUE" }
        Backend-->>App: Signalement enregistré
        
        Note over Consensus: Vérification du nombre d'usagers distincts
        Consensus->>Consensus: Combien d'usagers différents ont signalé ce hash ?
        alt Plus de 3 usagers distincts
            Consensus->>Backend: Bloquer automatiquement le numéro
            Consensus->>Backend: Ajouter une ligne au journal d'audit (AUTO_BAN)
            Note over Backend: Le numéro sera propagé à tous les téléphones au prochain sync
        else Moins de 3 usagers
            Consensus->>Backend: Conserver le numéro sous surveillance
        end
    else Cas 2 : Contestation citoyenne (Faux positif de clinique, livreur...)
        App->>Backend: POST /api/v1/reports/safe/ { phone_hash: h, categorie: "SANTE" }
        Note over Consensus: Évaluation de l'arbitrage
        Consensus->>Backend: Réhabilitation du numéro (is_whitelisted = True)
        Consensus->>Backend: Trace dans le journal d'audit (AUTO_WHITELIST)
        Backend-->>App: Numéro réhabilité avec succès
    end
    
    Admin->>Backend: Consulte le centre de triage pour superviser les décisions
```
