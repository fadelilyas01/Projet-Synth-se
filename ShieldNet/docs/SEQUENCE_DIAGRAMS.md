# ⏱️ Diagrammes de Séquence des Flux Critiques — ShieldNet

Ce document détaille les flux temporels et décisionnels des 4 processus critiques du système **ShieldNet**. Chaque diagramme illustre les interactions chronologiques entre l'utilisateur, l'OS Android, le runtime Flutter, le module natif Kotlin et le backend central Django.

---

## Scénario 1 : Interception d'Appel Entrant en Temps Réel (< 2 ms)

Ce flux représente l'exigence de performance la plus stricte du projet : évaluer l'appel et répondre à l'OS Android avant le premier son de sonnerie, avec la garantie absolue de ne jamais bloquer une urgence.

```mermaid
sequenceDiagram
    autonumber
    actor Caller as 📞 Appelant
    participant AndroidOS as 📱 Android Telecom Framework
    participant NativeService as ⚙️ ShieldNetCallScreeningService (Kotlin)
    participant NativeDB as 🗄️ ShieldNetDatabaseHelper (SQLite)
    actor Recipient as 👤 Utilisateur

    Caller->>AndroidOS: Appel entrant émis (ex: +1 514-999-0000)
    Note over AndroidOS,NativeService: Déclenchement de onScreenCall(details)
    AndroidOS->>NativeService: onScreenCall(callDetails)
    
    %% Étape 0 : Contrôle d'Urgence Immédiat
    Note over NativeService,NativeDB: Étape 0 : Contrôle d'urgence (0 faux positif)
    NativeService->>NativeDB: isEmergencyNumber(rawNumber)
    alt Est un numéro d'urgence (911, 811, 988, Contact Whitelist)
        NativeDB-->>NativeService: return TRUE
        NativeService->>AndroidOS: respondToCall(ALLOW, silence=false, skipCallLog=false)
        AndroidOS->>Recipient: Sonnerie prioritaire immédiate 🚨
    else Pas un numéro d'urgence
        NativeDB-->>NativeService: return FALSE
        
        %% Étape 1 : Normalisation et Hachage
        Note over NativeService: Normalisation E.164 + HMAC-SHA256
        NativeService->>NativeDB: isNumberBlocked(phoneHash)
        
        alt Numéro présent dans la Liste Noire
            NativeDB-->>NativeService: return TRUE (Spam confirmé)
            NativeService->>AndroidOS: respondToCall(DISALLOW, reject=true, skipNotification=true)
            Note over AndroidOS: Appel rejeté sans sonnerie (< 2 ms) 🚫
            NativeService->>NativeDB: logBlockedCallEvent(phoneHash, timestamp)
        else Numéro absent de la Liste Noire
            NativeDB-->>NativeService: return FALSE
            
            alt Mode "Bouclier Strict" Actif & Numéro Inconnu du Carnet
                NativeService->>AndroidOS: respondToCall(DISALLOW / SILENCE)
                Note over AndroidOS: Appel silencé / boîte vocale 🌙
            else Mode Standard
                NativeService->>AndroidOS: respondToCall(ALLOW)
                AndroidOS->>Recipient: Sonnerie normale 🔔
            end
        end
    end
```

---

## Scénario 2 : Synchronisation Différentielle (Delta Sync) & Purge Locale

Ce flux illustre la synchronisation d'arrière-plan périodique pilotée par `Workmanager` et `BackgroundSyncService`. Il démontre l'optimisation réseau (téléchargement uniquement des deltas temporels) et la purge automatique des faux-positifs débloqués par les administrateurs.

```mermaid
sequenceDiagram
    autonumber
    participant Workmanager as ⏰ Android WorkManager
    participant SyncService as 🔄 BackgroundSyncService (Dart)
    participant ApiService as 🌐 ApiService (Dio)
    participant DjangoAPI as ☁️ Backend Django (/api/v1/blacklist/)
    participant CentralDB as 🏢 PostgreSQL Central
    participant LocalDB as 🗄️ DatabaseHelper (SQLite Locale)

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

## Scénario 3 : Analyse & Détection de Phishing SMS (Inspecteur SMS)

Ce flux décrit le traitement sécurisé et asynchrone d'un SMS copié par l'utilisateur ou détecté dans le presse-papier, implémentant le use case `AnalyzeSmsUseCase`.

```mermaid
sequenceDiagram
    autonumber
    actor User as 👤 Utilisateur
    participant UI as 📱 SmsInspectorPage / ClipboardBanner
    participant UseCase as 🧠 AnalyzeSmsUseCase
    participant Detector as 🛡️ SmsPhishingDetector (Core)
    participant ApiService as 🌐 ApiService (Reputation Check)
    participant Backend as ☁️ Backend Django (/api/v1/check-url/)

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

## Scénario 4 : Signalement Collaboratif & Algorithme de Consensus Anti-Fraude

Ce flux détaille la modération communautaire décentralisée : comment un numéro suspect signalé par plusieurs utilisateurs indépendants est automatiquement promu en liste noire globale par consensus sans risque de manipulation par un acteur malveillant unique.

```mermaid
sequenceDiagram
    autonumber
    actor Victim as 👤 Utilisateur (Victime de démarchage)
    participant App as 📱 Application ShieldNet
    participant Crypto as 🔐 CryptoUtils
    participant Backend as ☁️ Backend Django (/api/v1/reports/)
    participant Consensus as ⚖️ Moteur de Consensus (Automatique)
    participant Admin as 🛡️ Console d'Administration

    Victim->>App: Signale un appel frauduleux (sélectionne motif: "Arnaque Fausse Banque")
    App->>Crypto: computeHmacSha256(phoneNumber, clientSalt)
    Crypto-->>App: Hash HMAC (aucune fuite du numéro réel)
    
    App->>Backend: POST /api/v1/reports/ { phone_hash: h, category: "SCAM" }
    Backend->>Backend: Enregistre le signalement avec IP hashée et user_id
    Backend-->>App: 201 Created ("Signalement pris en compte")

    %% Moteur de Consensus périodique
    Note over Consensus: Évaluation périodique des seuils de confiance
    Consensus->>Consensus: COUNT(DISTINCT users) WHERE phone_hash = h AND created_at > NOW - 7 jours
    
    alt Signalements >= Seuil de Consensus (ex: >= 5 utilisateurs distincts)
        Consensus->>Consensus: Auto-Promotion en Liste Noire Globale (Status: AUTO_BLOCKED)
        Consensus->>Backend: Création entrée d'AuditLog (action: "AUTO_CONSENSUS_BAN")
        Note over Backend: Le hash sera distribué à tous les clients lors du prochain Delta Sync
    else Signalements < Seuil
        Consensus->>Consensus: Statut reste en OBSERVATION (Flagged)
    end
    
    Admin->>Backend: GET /api/v1/admin/reports/
    Backend-->>Admin: Affiche les statistiques de consensus et alertes de modération
```
