# 🛠️ Manuel d'Exploitation & Guide d'Administration (Runbook) — ShieldNet Backend

Ce document constitue le **manuel technique d'exploitation opérationnelle** (Runbook / Operations Guide) du serveur backend **ShieldNet**. Il est destiné aux administrateurs systèmes, ingénieurs DevOps et évaluateurs académiques pour le déploiement, la maintenance, la surveillance et la sécurisation de l'infrastructure centrale.

---

## 1. Architecture & Stack Technique de Production

| Composant | Technologie | Rôle en Production |
|---|---|---|
| **Framework Web** | Django 4.2 LTS / Django REST Framework (DRF) | API REST sécurisée, ORM, Système de Permissions |
| **Serveur d'Applications** | Gunicorn (Green Unicorn) / Uvicorn (ASGI) | Serveur WSGI multi-workers haute concurrence |
| **Reverse Proxy & TLS** | Nginx / Caddy | Terminaison HTTPS (TLS 1.3), Compression Gzip, Cache statique |
| **Base de Données** | PostgreSQL 15+ (Production) / SQLite (Développement) | Persistance ACID, indexation rapide sur les hashes HMAC |
| **Sécurité & Rate Limiting** | Django-Ratelimit / Redis | Protection anti-bruteforce et anti-DDoS sur `/api/v1/` |
| **Authentification** | SimpleJWT (JSON Web Tokens) | Émission de jetons courts (15 min) + Refresh (7 jours) |

---

## 2. Configuration des Variables d'Environnement (.env)

Toutes les données de configuration sensibles doivent être renseignées dans le fichier `.env` à la racine du projet backend (`shieldnet_backend/.env`) :

```ini
# --- Environnement Général ---
DEBUG=False
SECRET_KEY=votre_cle_django_aleatoire_tres_longue_de_minimum_50_caracteres
ALLOWED_HOSTS=api.shieldnet.uqo.ca,127.0.0.1,localhost

# --- Base de Données (PostgreSQL en Production) ---
DB_ENGINE=django.db.backends.postgresql
DB_NAME=shieldnet_prod
DB_USER=shieldnet_admin
DB_PASSWORD=mot_de_passe_robuste_postgresql
DB_HOST=127.0.0.1
DB_PORT=5432

# --- Sécurité Cryptographique ShieldNet ---
# Sel HMAC partagé avec l'application mobile pour le hachage des numéros
HMAC_SECRET_SALT=ShieldNet_Secret_Token_UQO_2026

# --- Sécurité JWT ---
JWT_ACCESS_TOKEN_LIFETIME_MINUTES=15
JWT_REFRESH_TOKEN_LIFETIME_DAYS=7

# --- Politique de Sécurité HTTPS & CORS ---
SECURE_SSL_REDIRECT=True
SESSION_COOKIE_SECURE=True
CSRF_COOKIE_SECURE=True
SECURE_HSTS_SECONDS=31536000
CORS_ALLOWED_ORIGINS=https://admin.shieldnet.uqo.ca
```

---

## 3. Procédure de Déploiement

### Option A : Déploiement Docker (Recommandé en Production)

1. **Construction de l'image de production :**
   ```bash
   docker build -t shieldnet-backend:latest .
   ```

2. **Lancement de la stack via Docker Compose :**
   ```bash
   docker-compose up -d --build
   ```

3. **Exécution automatique des migrations et collecte des fichiers statiques :**
   ```bash
   docker-compose exec web python manage.py migrate --noinput
   docker-compose exec web python manage.py collectstatic --noinput
   ```

---

### Option B : Déploiement Standard sur Serveur Linux (Ubuntu/Debian)

1. **Prérequis système :**
   ```bash
   sudo apt update && sudo apt install -y python3-venv python3-pip postgresql nginx certbot python3-certbot-nginx
   ```

2. **Création du Virtualenv & Installation des dépendances :**
   ```bash
   cd /var/www/shieldnet_backend
   python3 -m venv venv
   source venv/bin/activate
   pip install --upgrade pip
   pip install -r requirements.txt
   ```

3. **Application du Schéma de Base de Données :**
   ```bash
   python manage.py migrate
   python manage.py collectstatic --noinput
   ```

4. **Configuration du Service Systemd (`/etc/systemd/system/shieldnet.service`) :**
   ```ini
   [Unit]
   Description=ShieldNet Gunicorn Daemon
   After=network.target postgresql.service

   [Service]
   User=www-data
   Group=www-data
   WorkingDirectory=/var/www/shieldnet_backend
   ExecStart=/var/www/shieldnet_backend/venv/bin/gunicorn \
             --workers 3 \
             --bind 127.0.0.1:8000 \
             --access-logfile /var/log/shieldnet/access.log \
             --error-logfile /var/log/shieldnet/error.log \
             shieldnet_backend.wsgi:application

   Restart=always

   [Install]
   WantedBy=multi-user.target
   ```

5. **Activation et Démarrage du Service :**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable shieldnet
   sudo systemctl start shieldnet
   sudo systemctl status shieldnet
   ```

6. **Configuration Nginx Reverse Proxy (`/etc/nginx/sites-available/shieldnet`) :**
   ```nginx
   server {
       server_name api.shieldnet.uqo.ca;

       location /static/ {
           alias /var/www/shieldnet_backend/staticfiles/;
       }

       location / {
           proxy_pass http://127.0.0.1:8000;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
   }
   ```

---

## 4. Guide des Commandes Administratives & Maintenance

### Création d'un Compte Super-Administrateur
Pour accéder à l'interface d'administration Django (`/admin/`) et à l'onglet Console Admin de l'application mobile :
```bash
python manage.py createsuperuser
```

### Surveillance de l'État de Santé (Healthcheck)
Pour vérifier instantanément l'état opérationnel du serveur et de sa base :
```bash
curl -I http://127.0.0.1:8000/api/v1/sync/status/
```
Réponse attendue : `HTTP/1.1 200 OK` avec les métriques actives.

### Purge Périodique des Données Obsolètes
Pour maintenir des performances optimales sur SQLite / PostgreSQL, exécuter la commande de maintenance planifiée :
```bash
# Purge des signalements inactifs de plus de 90 jours
python manage.py purge_stale_reports --days=90

# Déclenchement de l'évaluation du consensus anti-fraude
python manage.py run_consensus_engine
```

---

## 5. Journal d'Audit & Conformité Légale (Traçabilité)

Le système implémente une table immuable `AuditLog` stockant :
- L'horodatage exact UTC (`timestamp`)
- L'identifiant de l'administrateur ou du processus automatique (`performed_by`)
- La nature de l'action (`BLACKLIST_ADD`, `WHITELIST_UNBLOCK`, `CONSENSUS_AUDIT`, `PURGE`)
- L'adresse IP de provenance (hashée ou tronquée selon la RGPD / Loi 25 du Québec)
- Le payload JSON décrivant la modification.

Cette traçabilité garantit qu'aucune suppression frauduleuse ou ajout malveillant en liste noire ne peut avoir lieu à l'insu de l'équipe de sécurité.

---

## 6. Plan de Continuité & de Reprise d'Activité (PCA / PRA)

1. **Sauvegarde Quotidienne de la Base de Données :**
   ```bash
   pg_dump -U shieldnet_admin shieldnet_prod | gzip > /backups/shieldnet_$(date +%Y%m%d_%H%M%S).sql.gz
   ```
2. **Tolérance aux Pannes Mobiles :**  
   Grâce à l'architecture locale SQLite sur les smartphones Android (`shieldnet.db`), **même en cas de panne totale du serveur backend**, les téléphones continuent à bloquer les appels malveillants à 100% en local sans aucune dégradation de service.
