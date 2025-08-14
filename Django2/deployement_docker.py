# Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Installer les dépendances système
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    gdal-bin \
    libgdal-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copier les requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copier le code
COPY . .

# Collecter les fichiers statiques
RUN python manage.py collectstatic --noinput

# Exposer le port
EXPOSE 8000

# Command par défaut
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "petites_annonces.wsgi:application"]

# docker-compose.yml
version: '3.8'

services:
  web:
    build: .
    ports:
      - "8000:8000"
    environment:
      - DEBUG=False
      - DATABASE_URL=postgresql://postgres:password@db:5432/petites_annonces
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - db
      - redis
    volumes:
      - media_volume:/app/media
      - static_volume:/app/staticfiles

  db:
    image: postgres:15
    environment:
      - POSTGRES_DB=petites_annonces
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  celery:
    build: .
    command: celery -A petites_annonces worker --loglevel=info
    environment:
      - DATABASE_URL=postgresql://postgres:password@db:5432/petites_annonces
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - db
      - redis
    volumes:
      - media_volume:/app/media

  celery-beat:
    build: .
    command: celery -A petites_annonces beat --loglevel=info
    environment:
      - DATABASE_URL=postgresql://postgres:password@db:5432/petites_annonces
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - db
      - redis

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - media_volume:/app/media
      - static_volume:/app/staticfiles
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - web

volumes:
  postgres_data:
  media_volume:
  static_volume:

# nginx.conf
events {
    worker_connections 1024;
}

http {
    upstream web {
        server web:8000;
    }

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";

    server {
        listen 80;
        server_name petites-annonces.com www.petites-annonces.com;
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name petites-annonces.com www.petites-annonces.com;

        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;

        client_max_body_size 20M;

        # Serve static files
        location /static/ {
            alias /app/staticfiles/;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # Serve media files
        location /media/ {
            alias /app/media/;
            expires 1m;
        }

        # Proxy to Django
        location / {
            proxy_pass http://web;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}

# tests/test_models.py
from django.test import TestCase
from django.contrib.auth.models import User
from django.core.exceptions import ValidationError
from annonces.models import *

class AnnonceModelTest(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='testpass123'
        )
        self.categorie = Categorie.objects.create(
            nom='Test Catégorie',
            emoji='🧪'
        )

    def test_creation_annonce(self):
        """Test de création d'une annonce"""
        annonce = Annonce.objects.create(
            titre='Test Annonce',
            description='Description de test',
            prix=100.00,
            categorie=self.categorie,
            vendeur=self.user,
            ville='Paris',
            code_postal='75001'
        )
        self.assertEqual(annonce.titre, 'Test Annonce')
        self.assertEqual(annonce.vendeur, self.user)
        self.assertTrue(annonce.active)

    def test_validation_prix(self):
        """Test de validation du prix"""
        with self.assertRaises(ValidationError):
            annonce = Annonce(
                titre='Test',
                description='Test',
                prix=-10,  # Prix négatif
                categorie=self.categorie,
                vendeur=self.user,
                ville='Paris'
            )
            annonce.full_clean()

    def test_increment_vues(self):
        """Test d'incrémentation des vues"""
        annonce = Annonce.objects.create(
            titre='Test',
            description='Test',
            prix=100,
            categorie=self.categorie,
            vendeur=self.user,
            ville='Paris'
        )
        initial_vues = annonce.vues_count
        annonce.incrementer_vues()
        annonce.refresh_from_db()
        self.assertEqual(annonce.vues_count, initial_vues + 1)

    def test_photo_principale(self):
        """Test de la propriété photo_principale"""
        annonce = Annonce.objects.create(
            titre='Test',
            description='Test',
            prix=100,
            categorie=self.categorie,
            vendeur=self.user,
            ville='Paris'
        )
        self.assertIsNone(annonce.photo_principale)

class FavoriModelTest(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='testuser', password='test')
        self.categorie = Categorie.objects.create(nom='Test', emoji='🧪')
        self.annonce = Annonce.objects.create(
            titre='Test',
            description='Test',
            prix=100,
            categorie=self.categorie,
            vendeur=self.user,
            ville='Paris'
        )

    def test_favori_unique(self):
        """Test de l'unicité des favoris"""
        Favori.objects.create(utilisateur=self.user, annonce=self.annonce)
        
        with self.assertRaises(Exception):
            Favori.objects.create(utilisateur=self.user, annonce=self.annonce)

# tests/test_views.py
from django.test import TestCase, Client
from django.contrib.auth.models import User
from django.urls import reverse
from annonces.models import *

class AnnonceViewsTest(TestCase):
    def setUp(self):
        self.client = Client()
        self.user = User.objects.create_user(
            username='testuser',
            password='testpass123'
        )
        self.categorie = Categorie.objects.create(
            nom='Test Catégorie',
            emoji='🧪'
        )
        self.annonce = Annonce.objects.create(
            titre='Test Annonce',
            description='Description de test',
            prix=100.00,
            categorie=self.categorie,
            vendeur=self.user,
            ville='Paris',
            code_postal='75001'
        )

    def test_liste_annonces(self):
        """Test de la vue liste des annonces"""
        response = self.client.get(reverse('annonces:liste'))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, self.annonce.titre)

    def test_detail_annonce(self):
        """Test de la vue détail d'annonce"""
        response = self.client.get(
            reverse('annonces:detail', kwargs={'pk': self.annonce.pk})
        )
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, self.annonce.titre)

    def test_creation_annonce_anonyme(self):
        """Test que seuls les utilisateurs connectés peuvent créer des annonces"""
        response = self.client.get(reverse('annonces:creer'))
        self.assertEqual(response.status_code, 302)  # Redirection vers login

    def test_creation_annonce_connecte(self):
        """Test de création d'annonce par utilisateur connecté"""
        self.client.login(username='testuser', password='testpass123')
        response = self.client.get(reverse('annonces:creer'))
        self.assertEqual(response.status_code, 200)

    def test_post_creation_annonce(self):
        """Test de création d'annonce via POST"""
        self.client.login(username='testuser', password='testpass123')
        data = {
            'titre': 'Nouvelle annonce',
            'description': 'Description test',
            'prix': 150.00,
            'categorie': self.categorie.pk,
            'etat': 'bon_etat',
            'ville': 'Lyon',
            'code_postal': '69000',
            'urgent': False
        }
        response = self.client.post(reverse('annonces:creer'), data)
        self.assertEqual(response.status_code, 302)  # Redirection après création
        self.assertTrue(
            Annonce.objects.filter(titre='Nouvelle annonce').exists()
        )

    def test_recherche(self):
        """Test de la fonction de recherche"""
        response = self.client.get(reverse('annonces:liste'), {'q': 'Test'})
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, self.annonce.titre)

    def test_filtre_categorie(self):
        """Test du filtrage par catégorie"""
        response = self.client.get(
            reverse('annonces:liste'),
            {'categorie': self.categorie.slug}
        )
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, self.annonce.titre)

    def test_toggle_favori(self):
        """Test d'ajout/suppression de favori"""
        self.client.login(username='testuser', password='testpass123')
        response = self.client.post(
            reverse('annonces:toggle_favori', kwargs={'annonce_id': self.annonce.pk})
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertTrue(data['is_favorite'])

# tests/test_api.py
from rest_framework.test import APITestCase
from rest_framework import status
from django.contrib.auth.models import User
from annonces.models import *

class AnnonceAPITest(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            password='testpass123'
        )
        self.categorie = Categorie.objects.create(
            nom='Test Catégorie',
            emoji='🧪'
        )

    def test_liste_annonces_api(self):
        """Test de l'API liste des annonces"""
        response = self.client.get('/api/annonces/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_creation_annonce_api_non_authentifie(self):
        """Test que la création d'annonce nécessite une authentification"""
        data = {
            'titre': 'Test API',
            'description': 'Test',
            'prix': 100,
            'categorie': self.categorie.pk,
            'ville': 'Paris'
        }
        response = self.client.post('/api/annonces/', data)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_creation_annonce_api_authentifie(self):
        """Test de création d'annonce via API"""
        self.client.force_authenticate(user=self.user)
        data = {
            'titre': 'Test API',
            'description': 'Test description',
            'prix': 100,
            'categorie': self.categorie.pk,
            'etat': 'bon_etat',
            'ville': 'Paris',
            'code_postal': '75001'
        }
        response = self.client.post('/api/annonces/', data)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

# tests/test_performance.py
from django.test import TestCase
from django.test.utils import override_settings
from django.core.cache import cache
from django.contrib.auth.models import User
from annonces.models import *
import time

class PerformanceTest(TestCase):
    def setUp(self):
        # Créer des données de test
        self.user = User.objects.create_user(username='test', password='test')
        self.categorie = Categorie.objects.create(nom='Test', emoji='🧪')
        
        # Créer plusieurs annonces pour tester les performances
        for i in range(100):
            Annonce.objects.create(
                titre=f'Annonce {i}',
                description='Description test',
                prix=100,
                categorie=self.categorie,
                vendeur=self.user,
                ville='Paris'
            )

    def test_performance_liste_annonces(self):
        """Test de performance de la liste des annonces"""
        start_time = time.time()
        response = self.client.get('/annonces/')
        end_time = time.time()
        
        self.assertEqual(response.status_code, 200)
        self.assertLess(end_time - start_time, 1.0)  # Moins d'1 seconde

    @override_settings(USE_CACHE=True)
    def test_cache_annonces(self):
        """Test du cache des annonces"""
        cache.clear()
        
        # Premier appel (mise en cache)
        start_time = time.time()
        response1 = self.client.get('/annonces/')
        first_call_time = time.time() - start_time
        
        # Deuxième appel (depuis le cache)
        start_time = time.time()
        response2 = self.client.get('/annonces/')
        second_call_time = time.time() - start_time
        
        self.assertEqual(response1.status_code, 200)
        self.assertEqual(response2.status_code, 200)
        # Le deuxième appel devrait être plus rapide
        self.assertLess(second_call_time, first_call_time)

# management/commands/optimiser_images.py
from django.core.management.base import BaseCommand
from PIL import Image
import os
from annonces.models import PhotoAnnonce

class Command(BaseCommand):
    help = 'Optimise les images existantes'

    def add_arguments(self, parser):
        parser.add_argument(
            '--quality',
            type=int,
            default=85,
            help='Qualité de compression (1-100)'
        )
        parser.add_argument(
            '--max-width',
            type=int,
            default=1200,
            help='Largeur maximale'
        )

    def handle(self, *args, **options):
        photos = PhotoAnnonce.objects.all()
        optimized_count = 0

        for photo in photos:
            try:
                if photo.image and os.path.exists(photo.image.path):
                    with Image.open(photo.image.path) as img:
                        # Convertir en RGB si nécessaire
                        if img.mode in ('RGBA', 'LA', 'P'):
                            img = img.convert('RGB')
                        
                        # Redimensionner si nécessaire
                        if img.width > options['max_width']:
                            ratio = options['max_width'] / img.width
                            new_height = int(img.height * ratio)
                            img = img.resize((options['max_width'], new_height), Image.Resampling.LANCZOS)
                        
                        # Sauvegarder avec compression
                        img.save(
                            photo.image.path,
                            'JPEG',
                            quality=options['quality'],
                            optimize=True
                        )
                        optimized_count += 1

            except Exception as e:
                self.stdout.write(
                    self.style.ERROR(f'Erreur avec {photo.image.name}: {e}')
                )

        self.stdout.write(
            self.style.SUCCESS(f'{optimized_count} images optimisées')
        )

# settings/production.py
from .base import *
import os
import dj_database_url

DEBUG = False

ALLOWED_HOSTS = [
    'petites-annonces.com',
    'www.petites-annonces.com',
    'your-domain.com'
]

# Base de données en production
DATABASES = {
    'default': dj_database_url.config(
        default=os.environ.get('DATABASE_URL')
    )
}

# Sécurité
SECURE_SSL_REDIRECT = True
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True

# Stockage des fichiers statiques
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# Stockage des médias (avec AWS S3 par exemple)
DEFAULT_FILE_STORAGE = 'storages.backends.s3boto3.S3Boto3Storage'
AWS_ACCESS_KEY_ID = os.environ.get('AWS_ACCESS_KEY_ID')
AWS_SECRET_ACCESS_KEY = os.environ.get('AWS_SECRET_ACCESS_KEY')
AWS_STORAGE_BUCKET_NAME = os.environ.get('AWS_STORAGE_BUCKET_NAME')
AWS_S3_REGION_NAME = os.environ.get('AWS_S3_REGION_NAME', 'eu-west-3')
AWS_S3_CUSTOM_DOMAIN = f'{AWS_STORAGE_BUCKET_NAME}.s3.amazonaws.com'
AWS_DEFAULT_ACL = 'public-read'

# Logs
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {process:d} {thread:d} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'file': {
            'level': 'INFO',
            'class': 'logging.FileHandler',
            'filename': '/var/log/django/petites_annonces.log',
            'formatter': 'verbose',
        },
        'console': {
            'level': 'INFO',
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
    },
    'root': {
        'handlers': ['file', 'console'],
        'level': 'INFO',
    },
    'loggers': {
        'django': {
            'handlers': ['file', 'console'],
            'level': 'INFO',
            'propagate': False,
        },
        'annonces': {
            'handlers': ['file', 'console'],
            'level': 'DEBUG',
            'propagate': False,
        },
    },
}

# Monitoring et métriques
INSTALLED_APPS += [
    'django_prometheus',
]

MIDDLEWARE = [
    'django_prometheus.middleware.PrometheusBeforeMiddleware',
] + MIDDLEWARE + [
    'django_prometheus.middleware.PrometheusAfterMiddleware',
]

# Cache en production
CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': os.environ.get('REDIS_URL', 'redis://127.0.0.1:6379/1'),
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
            'CONNECTION_POOL_KWARGS': {
                'max_connections': 20,
                'retry_on_timeout': True,
            },
        },
    }
}

# Email en production
EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = os.environ.get('EMAIL_HOST')
EMAIL_PORT = int(os.environ.get('EMAIL_PORT', 587))
EMAIL_USE_TLS = True
EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER')
EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD')

# Sentry pour le monitoring d'erreurs
import sentry_sdk
from sentry_sdk.integrations.django import DjangoIntegration
from sentry_sdk.integrations.celery import CeleryIntegration

sentry_sdk.init(
    dsn=os.environ.get('SENTRY_DSN'),
    integrations=[
        DjangoIntegration(),
        CeleryIntegration(),
    ],
    traces_sample_rate=0.1,
    send_default_pii=True
)

# scripts/deploy.sh
#!/bin/bash

# Script de déploiement
set -e

echo "🚀 Début du déploiement..."

# Variables
REPO_URL="https://github.com/votre-username/petites-annonces.git"
PROJECT_DIR="/var/www/petites-annonces"
VENV_DIR="$PROJECT_DIR/venv"

# Mise à jour du code
cd $PROJECT_DIR
git pull origin main

# Activation de l'environnement virtuel
source $VENV_DIR/bin/activate

# Installation des dépendances
pip install -r requirements.txt

# Migrations
python manage.py migrate

# Collecte des fichiers statiques
python manage.py collectstatic --noinput

# Restart des services
sudo systemctl restart gunicorn
sudo systemctl restart nginx
sudo systemctl restart celery
sudo systemctl restart celery-beat

echo "✅ Déploiement terminé avec succès!"

# Vérification
curl -f http://localhost/health/ || {
    echo "❌ Erreur : l'application ne répond pas"
    exit 1
}

echo "🎉 Application déployée et fonctionnelle!"

# pytest.ini
[tool:pytest]
DJANGO_SETTINGS_MODULE = petites_annonces.settings.test
python_files = tests.py test_*.py *_tests.py
python_classes = Test*
python_functions = test_*
addopts = 
    --verbose
    --tb=short
    --cov=annonces
    --cov-report=html
    --cov-report=term-missing
    --cov-fail-under=80

# .github/workflows/ci.yml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: test_petites_annonces
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Python 3.11
      uses: actions/setup-python@v3
      with:
        python-version: 3.11
    
    - name: Cache dependencies
      uses: actions/cache@v3
      with:
        path: ~/.cache/pip
        key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements.txt') }}
    
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -r requirements.txt
        pip install pytest pytest-django pytest-cov
    
    - name: Run tests
      env:
        DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test_petites_annonces
        REDIS_URL: redis://localhost:6379/0
      run: |
        python manage.py test
        pytest
    
    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
    - name: Deploy to production
      run: |
        echo "Déploiement en production..."
        # Script de déploiement ici

# monitoring/healthcheck.py
from django.http import JsonResponse
from django.db import connection
from django.core.cache import cache
import redis

def health_check(request):
    """Endpoint de vérification de santé de l'application"""
    health_status = {
        'status': 'healthy',
        'database': 'unknown',
        'cache': 'unknown',
        'celery': 'unknown'
    }
    
    # Vérification base de données
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
        health_status['database'] = 'healthy'
    except Exception as e:
        health_status['database'] = f'error: {str(e)}'
        health_status['status'] = 'unhealthy'
    
    # Vérification cache Redis
    try:
        cache.set('health_check', 'ok', 10)
        if cache.get('health_check') == 'ok':
            health_status['cache'] = 'healthy'
        else:
            health_status['cache'] = 'error'
            health_status['status'] = 'unhealthy'
    except Exception as e:
        health_status['cache'] = f'error: {str(e)}'
        health_status['status'] = 'unhealthy'
    
    # Vérification Celery
    try:
        from celery import current_app
        inspect = current_app.control.inspect()
        active_workers = inspect.active()
        if active_workers:
            health_status['celery'] = 'healthy'
        else:
            health_status['celery'] = 'no_workers'
    except Exception as e:
        health_status['celery'] = f'error: {str(e)}'
    
    status_code = 200 if health_status['status'] == 'healthy' else 503
    return JsonResponse(health_status, status=status_code)

# monitoring/metrics.py
from django.http import HttpResponse
from django_prometheus.exports import ExportToDjangoView
from prometheus_client import Counter, Histogram, Gauge
import time

# Métriques personnalisées
annonce_creation_counter = Counter(
    'annonces_created_total',
    'Nombre total d\'annonces créées',
    ['category']
)

message_sent_counter = Counter(
    'messages_sent_total',
    'Nombre total de messages envoyés'
)

login_attempts_counter = Counter(
    'login_attempts_total',
    'Tentatives de connexion',
    ['status']
)

response_time_histogram = Histogram(
    'http_request_duration_seconds',
    'Temps de réponse HTTP',
    ['method', 'endpoint']
)

active_users_gauge = Gauge(
    'active_users',
    'Nombre d\'utilisateurs actifs'
)

class MetricsMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        start_time = time.time()
        response = self.get_response(request)
        
        # Enregistrer le temps de réponse
        duration = time.time() - start_time
        response_time_histogram.labels(
            method=request.method,
            endpoint=request.path
        ).observe(duration)
        
        return response