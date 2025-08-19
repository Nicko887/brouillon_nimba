# listings/apps.py
from django.apps import AppConfig

class ListingsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'listings'
    verbose_name = 'Petites Annonces'
    
    def ready(self):
        """Appelé quand l'application est prête"""
        # Importer les signaux pour qu'ils soient enregistrés
        import listings.signals

# __init__.py pour l'application listings
# listings/__init__.py
default_app_config = 'listings.apps.ListingsConfig'

# management/commands/setup_categories.py
# listings/management/commands/setup_categories.py
from django.core.management.base import BaseCommand
from django.db import connection
import os

class Command(BaseCommand):
    help = 'Initialise les catégories et données de base'
    
    def add_arguments(self, parser):
        parser.add_argument(
            '--reset',
            action='store_true',
            help='Supprime toutes les données existantes avant l\'import',
        )
    
    def handle(self, *args, **options):
        if options['reset']:
            self.stdout.write(
                self.style.WARNING('Suppression des données existantes...')
            )
            # Supprimer les données existantes
            from listings.models import Category, Tag
            Category.objects.all().delete()
            Tag.objects.all().delete()
        
        # Exécuter le script SQL de données
        sql_file = os.path.join(
            os.path.dirname(__file__), 
            '..', '..', '..', 
            'sql', 'seed_data_django.sql'
        )
        
        if os.path.exists(sql_file):
            with open(sql_file, 'r', encoding='utf-8') as f:
                sql_content = f.read()
            
            with connection.cursor() as cursor:
                cursor.execute(sql_content)
            
            self.stdout.write(
                self.style.SUCCESS('Données importées avec succès!')
            )
        else:
            self.stdout.write(
                self.style.ERROR(f'Fichier SQL non trouvé: {sql_file}')
            )

# management/commands/update_search_vectors.py
# listings/management/commands/update_search_vectors.py
from django.core.management.base import BaseCommand
from django.db import connection
from listings.models import Listing

class Command(BaseCommand):
    help = 'Met à jour les vecteurs de recherche pour toutes les annonces'
    
    def handle(self, *args, **options):
        listings = Listing.objects.all()
        total = listings.count()
        
        self.stdout.write(f'Mise à jour de {total} annonces...')
        
        for i, listing in enumerate(listings, 1):
            listing.update_search_vector()
            
            if i % 100 == 0:
                self.stdout.write(f'Traité {i}/{total} annonces')
        
        self.stdout.write(
            self.style.SUCCESS(f'Mise à jour terminée pour {total} annonces!')
        )

# management/commands/cleanup_expired.py
# listings/management/commands/cleanup_expired.py
from django.core.management.base import BaseCommand
from django.utils import timezone
from listings.models import Listing

class Command(BaseCommand):
    help = 'Marque les annonces expirées comme expired'
    
    def handle(self, *args, **options):
        now = timezone.now()
        
        expired_listings = Listing.objects.filter(
            status='active',
            expires_at__lt=now
        )
        
        count = expired_listings.count()
        expired_listings.update(status='expired')
        
        self.stdout.write(
            self.style.SUCCESS(f'{count} annonces marquées comme expirées.')
        )

# requirements.txt pour le projet
"""
Django==4.2.7
psycopg2-binary==2.9.9
Pillow==10.0.1
django-extensions==3.2.3
django-debug-toolbar==4.2.0
django-crispy-forms==2.0
crispy-bootstrap5==0.7
redis==5.0.1
celery==5.3.4
python-decouple==3.8
"""

# .env.example pour les variables d'environnement
"""
# Configuration de base
SECRET_KEY=your-secret-key-here
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1

# Base de données PostgreSQL
DB_NAME=petites_annonces_django
DB_USER=postgres
DB_PASSWORD=your_password
DB_HOST=localhost
DB_PORT=5432

# Email configuration
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
EMAIL_USE_TLS=True

# Redis pour le cache et Celery
REDIS_URL=redis://localhost:6379/1

# Configuration du site
SITE_NAME=Petites Annonces Guinée
SITE_DOMAIN=localhost:8000
"""

# manage.py customisé
"""
#!/usr/bin/env python
import os
import sys

if __name__ == '__main__':
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'petites_annonces.settings')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed and "
            "available on your PYTHONPATH environment variable? Did you "
            "forget to activate a virtual environment?"
        ) from exc
    execute_from_command_line(sys.argv)
"""