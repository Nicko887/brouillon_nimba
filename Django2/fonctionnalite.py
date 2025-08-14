# requirements.txt (version étendue)
"""
Django>=4.2.0
Pillow>=9.0.0
djangorestframework>=3.14.0
django-cors-headers>=4.0.0
django-filter>=23.0
channels>=4.0.0
channels-redis>=4.1.0
redis>=4.5.0
celery>=5.3.0
django-extensions>=3.2.0
django-debug-toolbar>=4.1.0
gunicorn>=21.0.0
whitenoise>=6.5.0
psycopg2-binary>=2.9.0
"""

# models.py (ajouts pour fonctionnalités avancées)
from django.db import models
from django.contrib.auth.models import User
from django.contrib.gis.db import models as gis_models
from django.contrib.gis.geos import Point
from decimal import Decimal

# Modèles existants + ajouts :

class Notification(models.Model):
    TYPE_CHOICES = [
        ('message', 'Nouveau message'),
        ('favori', 'Annonce ajoutée aux favoris'),
        ('vue', 'Annonce consultée'),
        ('interesse', 'Intérêt pour une annonce'),
        ('vendue', 'Annonce vendue'),
        ('systeme', 'Notification système'),
    ]
    
    utilisateur = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notifications')
    type_notification = models.CharField(max_length=20, choices=TYPE_CHOICES)
    titre = models.CharField(max_length=200)
    message = models.TextField()
    annonce = models.ForeignKey(Annonce, on_delete=models.CASCADE, null=True, blank=True)
    expediteur = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='notifications_envoyees')
    lue = models.BooleanField(default=False)
    date_creation = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['-date_creation']
    
    def __str__(self):
        return f"{self.titre} - {self.utilisateur.username}"

class Evaluation(models.Model):
    evaluateur = models.ForeignKey(User, on_delete=models.CASCADE, related_name='evaluations_donnees')
    evalue = models.ForeignKey(User, on_delete=models.CASCADE, related_name='evaluations_recues')
    annonce = models.ForeignKey(Annonce, on_delete=models.CASCADE)
    note = models.PositiveIntegerField(choices=[(i, i) for i in range(1, 6)])  # 1 à 5 étoiles
    commentaire = models.TextField(blank=True)
    date_creation = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        unique_together = ['evaluateur', 'evalue', 'annonce']
    
    def __str__(self):
        return f"{self.note}/5 - {self.evalue.username}"

class Localisation(models.Model):
    annonce = models.OneToOneField(Annonce, on_delete=models.CASCADE, related_name='localisation')
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    adresse_complete = models.CharField(max_length=300, blank=True)
    
    def __str__(self):
        return f"Localisation de {self.annonce.titre}"
    
    @property
    def coordonnees(self):
        if self.latitude and self.longitude:
            return Point(float(self.longitude), float(self.latitude))
        return None

class Statistique(models.Model):
    annonce = models.OneToOneField(Annonce, on_delete=models.CASCADE, related_name='statistiques')
    vues_aujourd_hui = models.PositiveIntegerField(default=0)
    vues_cette_semaine = models.PositiveIntegerField(default=0)
    favoris_count = models.PositiveIntegerField(default=0)
    messages_count = models.PositiveIntegerField(default=0)
    date_derniere_vue = models.DateTimeField(null=True, blank=True)
    
    def __str__(self):
        return f"Stats - {self.annonce.titre}"

class Alerte(models.Model):
    utilisateur = models.ForeignKey(User, on_delete=models.CASCADE, related_name='alertes')
    nom_alerte = models.CharField(max_length=100)
    mots_cles = models.CharField(max_length=200)
    categorie = models.ForeignKey(Categorie, on_delete=models.CASCADE, null=True, blank=True)
    prix_min = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    prix_max = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    ville = models.CharField(max_length=100, blank=True)
    rayon_km = models.PositiveIntegerField(default=10)  # Rayon de recherche en km
    active = models.BooleanField(default=True)
    date_creation = models.DateTimeField(auto_now_add=True)
    derniere_verification = models.DateTimeField(null=True, blank=True)
    
    def __str__(self):
        return f"Alerte: {self.nom_alerte} - {self.utilisateur.username}"

# api/serializers.py (pour l'API REST)
from rest_framework import serializers
from django.contrib.auth.models import User
from ..models import *

class CategorieSerializer(serializers.ModelSerializer):
    class Meta:
        model = Categorie
        fields = '__all__'

class PhotoAnnonceSerializer(serializers.ModelSerializer):
    class Meta:
        model = PhotoAnnonce
        fields = ['id', 'image', 'ordre']

class VendeurSerializer(serializers.ModelSerializer):
    note_moyenne = serializers.SerializerMethodField()
    nb_evaluations = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = ['id', 'username', 'date_joined', 'note_moyenne', 'nb_evaluations']
    
    def get_note_moyenne(self, obj):
        evaluations = obj.evaluations_recues.all()
        if evaluations:
            return sum(e.note for e in evaluations) / len(evaluations)
        return None
    
    def get_nb_evaluations(self, obj):
        return obj.evaluations_recues.count()

class AnnonceSerializer(serializers.ModelSerializer):
    categorie = CategorieSerializer(read_only=True)
    photos = PhotoAnnonceSerializer(many=True, read_only=True)
    vendeur = VendeurSerializer(read_only=True)
    distance = serializers.SerializerMethodField()
    
    class Meta:
        model = Annonce
        fields = '__all__'
    
    def get_distance(self, obj):
        # Calculer la distance si coordonnées utilisateur fournies
        request = self.context.get('request')
        if request and hasattr(request, 'user_location') and hasattr(obj, 'localisation'):
            # Logique de calcul de distance
            return None
        return None

class AnnonceCreateSerializer(serializers.ModelSerializer):
    photos = serializers.ListField(
        child=serializers.ImageField(),
        write_only=True,
        required=False
    )
    
    class Meta:
        model = Annonce
        exclude = ['vendeur', 'vues_count', 'date_creation', 'date_modification']
    
    def create(self, validated_data):
        photos_data = validated_data.pop('photos', [])
        annonce = Annonce.objects.create(**validated_data)
        
        for index, photo in enumerate(photos_data):
            PhotoAnnonce.objects.create(annonce=annonce, image=photo, ordre=index)
        
        return annonce

class MessageSerializer(serializers.ModelSerializer):
    expediteur = serializers.StringRelatedField()
    
    class Meta:
        model = Message
        fields = '__all__'

class ConversationSerializer(serializers.ModelSerializer):
    messages = MessageSerializer(many=True, read_only=True)
    dernier_message = serializers.SerializerMethodField()
    
    class Meta:
        model = Conversation
        fields = '__all__'
    
    def get_dernier_message(self, obj):
        dernier = obj.messages.last()
        return MessageSerializer(dernier).data if dernier else None

class NotificationSerializer(serializers.ModelSerializer):
    annonce_titre = serializers.CharField(source='annonce.titre', read_only=True)
    expediteur_username = serializers.CharField(source='expediteur.username', read_only=True)
    
    class Meta:
        model = Notification
        fields = '__all__'

# api/views.py (API REST)
from rest_framework import generics, permissions, status, filters
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.pagination import PageNumberPagination
from django_filters.rest_framework import DjangoFilterBackend
from django.db.models import Q, Avg, Count
from .serializers import *

class AnnoncePagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100

class AnnonceFilter(filters.FilterSet):
    prix_min = filters.NumberFilter(field_name='prix', lookup_expr='gte')
    prix_max = filters.NumberFilter(field_name='prix', lookup_expr='lte')
    recherche = filters.CharFilter(method='filter_recherche')
    
    class Meta:
        model = Annonce
        fields = ['categorie', 'ville', 'etat', 'urgent']
    
    def filter_recherche(self, queryset, name, value):
        return queryset.filter(
            Q(titre__icontains=value) | Q(description__icontains=value)
        )

class AnnonceListCreateAPIView(generics.ListCreateAPIView):
    queryset = Annonce.objects.filter(active=True).select_related('categorie', 'vendeur')
    pagination_class = AnnoncePagination
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_class = AnnonceFilter
    search_fields = ['titre', 'description']
    ordering_fields = ['prix', 'date_creation', 'vues_count']
    ordering = ['-date_creation']
    
    def get_serializer_class(self):
        if self.request.method == 'POST':
            return AnnonceCreateSerializer
        return AnnonceSerializer
    
    def get_permissions(self):
        if self.request.method == 'POST':
            return [permissions.IsAuthenticated()]
        return [permissions.AllowAny()]
    
    def perform_create(self, serializer):
        serializer.save(vendeur=self.request.user)

class AnnonceDetailAPIView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Annonce.objects.filter(active=True)
    serializer_class = AnnonceSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]
    
    def get_object(self):
        obj = super().get_object()
        # Incrémenter les vues si c'est une consultation
        if self.request.method == 'GET':
            obj.incrementer_vues()
        return obj
    
    def check_object_permissions(self, request, obj):
        if request.method in ['PUT', 'PATCH', 'DELETE']:
            if obj.vendeur != request.user:
                self.permission_denied(request, "Vous ne pouvez modifier que vos propres annonces.")
        super().check_object_permissions(request, obj)

@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def toggle_favori_api(request, annonce_id):
    try:
        annonce = Annonce.objects.get(pk=annonce_id)
        favori, created = Favori.objects.get_or_create(
            utilisateur=request.user,
            annonce=annonce
        )
        
        if not created:
            favori.delete()
            is_favorite = False
        else:
            is_favorite = True
            # Créer notification
            if annonce.vendeur != request.user:
                Notification.objects.create(
                    utilisateur=annonce.vendeur,
                    type_notification='favori',
                    titre='Nouveau favori',
                    message=f'{request.user.username} a ajouté votre annonce "{annonce.titre}" à ses favoris',
                    annonce=annonce,
                    expediteur=request.user
                )
        
        return Response({'is_favorite': is_favorite})
    except Annonce.DoesNotExist:
        return Response({'error': 'Annonce non trouvée'}, status=404)

class MesAnnoncesAPIView(generics.ListAPIView):
    serializer_class = AnnonceSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = AnnoncePagination
    
    def get_queryset(self):
        return Annonce.objects.filter(vendeur=self.request.user).order_by('-date_creation')

class NotificationListAPIView(generics.ListAPIView):
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        return Notification.objects.filter(utilisateur=self.request.user)

@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def marquer_notification_lue(request, notification_id):
    try:
        notification = Notification.objects.get(
            pk=notification_id,
            utilisateur=request.user
        )
        notification.lue = True
        notification.save()
        return Response({'success': True})
    except Notification.DoesNotExist:
        return Response({'error': 'Notification non trouvée'}, status=404)

class RechercheAvanceeAPIView(generics.ListAPIView):
    serializer_class = AnnonceSerializer
    pagination_class = AnnoncePagination
    
    def get_queryset(self):
        queryset = Annonce.objects.filter(active=True)
        
        # Filtres géographiques
        lat = self.request.query_params.get('latitude')
        lng = self.request.query_params.get('longitude')
        rayon = self.request.query_params.get('rayon', 10)  # km
        
        if lat and lng:
            # Filtrer par rayon géographique
            # Implémentation avec PostGIS ou calcul de distance
            pass
        
        # Filtres avancés
        note_min = self.request.query_params.get('note_vendeur_min')
        if note_min:
            queryset = queryset.annotate(
                note_moyenne=Avg('vendeur__evaluations_recues__note')
            ).filter(note_moyenne__gte=note_min)
        
        return queryset

# tasks.py (Tâches Celery pour les traitements asynchrones)
from celery import shared_task
from django.core.mail import send_mail
from django.conf import settings
from django.contrib.auth.models import User
from .models import *

@shared_task
def envoyer_alerte_nouvelles_annonces():
    """Vérifier les alertes et envoyer des notifications"""
    alertes_actives = Alerte.objects.filter(active=True)
    
    for alerte in alertes_actives:
        # Construire la requête basée sur les critères de l'alerte
        queryset = Annonce.objects.filter(active=True)
        
        if alerte.mots_cles:
            queryset = queryset.filter(
                Q(titre__icontains=alerte.mots_cles) |
                Q(description__icontains=alerte.mots_cles)
            )
        
        if alerte.categorie:
            queryset = queryset.filter(categorie=alerte.categorie)
        
        if alerte.prix_min:
            queryset = queryset.filter(prix__gte=alerte.prix_min)
        
        if alerte.prix_max:
            queryset = queryset.filter(prix__lte=alerte.prix_max)
        
        if alerte.ville:
            queryset = queryset.filter(ville__icontains=alerte.ville)
        
        # Nouvelles annonces depuis la dernière vérification
        if alerte.derniere_verification:
            nouvelles_annonces = queryset.filter(
                date_creation__gt=alerte.derniere_verification
            )
        else:
            nouvelles_annonces = queryset[:5]  # Limiter pour le premier envoi
        
        if nouvelles_annonces.exists():
            # Créer notification
            Notification.objects.create(
                utilisateur=alerte.utilisateur,
                type_notification='systeme',
                titre=f'Nouvelle(s) annonce(s) pour "{alerte.nom_alerte}"',
                message=f'{nouvelles_annonces.count()} nouvelle(s) annonce(s) correspondent à votre alerte.'
            )
            
            # Envoyer email si configuré
            if alerte.utilisateur.email:
                send_mail(
                    subject=f'Alerte : {nouvelles_annonces.count()} nouvelle(s) annonce(s)',
                    message=f'Bonjour,\n\n{nouvelles_annonces.count()} nouvelle(s) annonce(s) correspondent à votre alerte "{alerte.nom_alerte}".',
                    from_email=settings.DEFAULT_FROM_EMAIL,
                    recipient_list=[alerte.utilisateur.email]
                )
        
        # Mettre à jour la date de dernière vérification
        alerte.derniere_verification = timezone.now()
        alerte.save()

@shared_task
def nettoyer_notifications_anciennes():
    """Supprimer les notifications de plus de 30 jours"""
    from datetime import timedelta
    limite = timezone.now() - timedelta(days=30)
    Notification.objects.filter(date_creation__lt=limite).delete()

@shared_task
def calculer_statistiques_annonces():
    """Calculer les statistiques des annonces"""
    for annonce in Annonce.objects.filter(active=True):
        stats, created = Statistique.objects.get_or_create(annonce=annonce)
        
        # Calculer favoris
        stats.favoris_count = annonce.favoris.count()
        
        # Calculer messages
        stats.messages_count = Message.objects.filter(
            conversation__annonce=annonce
        ).count()
        
        stats.save()

# consumers.py (WebSockets pour notifications temps réel)
import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth.models import User

class NotificationConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        if self.scope['user'].is_authenticated:
            self.user_id = self.scope['user'].id
            self.group_name = f'notifications_{self.user_id}'
            
            await self.channel_layer.group_add(
                self.group_name,
                self.channel_name
            )
            await self.accept()
        else:
            await self.close()
    
    async def disconnect(self, close_code):
        if hasattr(self, 'group_name'):
            await self.channel_layer.group_discard(
                self.group_name,
                self.channel_name
            )
    
    async def notification_message(self, event):
        await self.send(text_data=json.dumps({
            'type': 'notification',
            'data': event['data']
        }))

# utils.py (Utilitaires)
from django.contrib.gis.geos import Point
from django.contrib.gis.measure import Distance
import requests
from geopy.geocoders import Nominatim

def geocoder_adresse(adresse):
    """Géocoder une adresse en coordonnées"""
    try:
        geolocator = Nominatim(user_agent="petites_annonces")
        location = geolocator.geocode(adresse)
        if location:
            return {
                'latitude': location.latitude,
                'longitude': location.longitude,
                'adresse_complete': location.address
            }
    except:
        pass
    return None

def calculer_distance(point1, point2):
    """Calculer la distance entre deux points"""
    try:
        from geopy.distance import geodesic
        return geodesic(point1, point2).kilometers
    except:
        return None

def envoyer_notification_temps_reel(user_id, notification_data):
    """Envoyer une notification en temps réel via WebSocket"""
    from channels.layers import get_channel_layer
    from asgiref.sync import async_to_sync
    
    channel_layer = get_channel_layer()
    group_name = f'notifications_{user_id}'
    
    async_to_sync(channel_layer.group_send)(
        group_name,
        {
            'type': 'notification_message',
            'data': notification_data
        }
    )

# management/commands/import_donnees_test.py
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from annonces.models import *
import random
from datetime import datetime, timedelta

class Command(BaseCommand):
    help = 'Importe des données de test'

    def add_arguments(self, parser):
        parser.add_argument('--nb-users', type=int, default=50, help='Nombre d\'utilisateurs')
        parser.add_argument('--nb-annonces', type=int, default=200, help='Nombre d\'annonces')

    def handle(self, *args, **options):
        # Créer des utilisateurs de test
        for i in range(options['nb_users']):
            user = User.objects.create_user(
                username=f'user{i}',
                email=f'user{i}@example.com',
                password='testpass123'
            )
            ProfilUtilisateur.objects.create(
                user=user,
                ville_defaut=random.choice(['Paris', 'Lyon', 'Marseille', 'Toulouse']),
                telephone=f'06{random.randint(10000000, 99999999)}'
            )
        
        # Créer des annonces de test
        users = User.objects.all()
        categories = Categorie.objects.all()
        
        for i in range(options['nb_annonces']):
            annonce = Annonce.objects.create(
                titre=f'Annonce test {i}',
                description=f'Description détaillée de l\'annonce {i}',
                prix=random.randint(10, 5000),
                categorie=random.choice(categories),
                vendeur=random.choice(users),
                ville=random.choice(['Paris', 'Lyon', 'Marseille', 'Toulouse']),
                code_postal=f'{random.randint(10000, 99999)}',
                urgent=random.choice([True, False]),
                vues_count=random.randint(0, 100)
            )
            
            # Ajouter localisation
            coords = geocoder_adresse(f'{annonce.ville}, France')
            if coords:
                Localisation.objects.create(
                    annonce=annonce,
                    latitude=coords['latitude'],
                    longitude=coords['longitude'],
                    adresse_complete=coords['adresse_complete']
                )
        
        self.stdout.write(
            self.style.SUCCESS(
                f'Créé {options["nb_users"]} utilisateurs et {options["nb_annonces"]} annonces'
            )
        )

# settings.py (ajouts pour les nouvelles fonctionnalités)
"""
# API REST Framework
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.SessionAuthentication',
        'rest_framework.authentication.TokenAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticatedOrReadOnly',
    ],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
    'DEFAULT_FILTER_BACKENDS': [
        'django_filters.rest_framework.DjangoFilterBackend',
        'rest_framework.filters.SearchFilter',
        'rest_framework.filters.OrderingFilter',
    ],
}

# CORS (si frontend séparé)
CORS_ALLOWED_ORIGINS = [
    "http://localhost:3000",  # React
    "http://127.0.0.1:3000",
]

# Redis et Celery
CELERY_BROKER_URL = 'redis://localhost:6379/0'
CELERY_RESULT_BACKEND = 'redis://localhost:6379/0'
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_TIMEZONE = 'Europe/Paris'

# Cache Redis
CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': 'redis://127.0.0.1:6379/1',
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
        }
    }
}

# WebSockets (Channels)
ASGI_APPLICATION = 'petites_annonces.asgi.application'
CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels_redis.core.RedisChannelLayer',
        'CONFIG': {
            'hosts': [('127.0.0.1', 6379)],
        },
    },
}

# Email
EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = 'smtp.gmail.com'
EMAIL_PORT = 587
EMAIL_USE_TLS = True
EMAIL_HOST_USER = 'your-email@gmail.com'
EMAIL_HOST_PASSWORD = 'your-app-password'
DEFAULT_FROM_EMAIL = 'Petites Annonces <noreply@petites-annonces.com>'

# Géolocalisation
GEOIP_PATH = os.path.join(BASE_DIR, 'geoip')

# Optimisations
SESSION_ENGINE = 'django.contrib.sessions.backends.cache'
SESSION_CACHE_ALIAS = 'default'
"""