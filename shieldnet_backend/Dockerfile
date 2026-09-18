# Image officielle Python légère
FROM python:3.12-slim

# Empêcher Python d'écrire des fichiers .pyc et forcer l'affichage immédiat des logs
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Répertoire de travail
WORKDIR /app

# Installation des dépendances système requises (notamment pour PostgreSQL)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copie et installation des dépendances Python
COPY requirements.txt /app/
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copie du reste du code source
COPY . /app/

# Port exposé
EXPOSE 8000

# Commande de démarrage par défaut (migrations automatiques + création admin + lancement Gunicorn)
CMD ["sh", "-c", "python manage.py migrate && python manage.py ensure_admin && gunicorn shieldnet_backend.wsgi:application --bind 0.0.0.0:8000 --workers 3"]
