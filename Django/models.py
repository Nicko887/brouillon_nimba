# models.py
from django.db import models
from django.contrib.auth.models import User
from django.urls import reverse
from django.utils.text import slugify

class Categorie(models.Model):
    nom = models.CharField(max_length=100)
    slug = models.SlugField(unique=True, blank=True)
    emoji = models.CharField(max_length=10, default="📦")
    description = models.TextField(blank=True)
    ordre = models.IntegerField(default=0)
    
    class Meta:
        ordering = ['ordre', 'nom']
        verbose_name = "Catégorie"
        verbose_name_plural = "Catégories"
    
    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(self.nom)
        super().save(*args, **kwargs)
    
    def __str__(self):
        return self.nom

class Annonce(models.Model):
    ETAT_CHOICES = [
        ('neuf', 'Neuf'),
        ('comme_neuf', 'Comme neuf'),
        ('bon_etat', 'Bon état'),
        ('etat_correct', 'État correct'),
        ('mauvais_etat', 'Mauvais état'),
    ]
    
    titre = models.CharField(max_length=200)
    description = models.TextField()
    prix = models.DecimalField(max_digits=10, decimal_places=2)
    categorie = models.ForeignKey(Categorie, on_delete=models.CASCADE, related_name='annonces')
    etat = models.CharField(max_length=20, choices=ETAT_CHOICES, default='bon_etat')
    ville = models.CharField(max_length=100)
    code_postal = models.CharField(max_length=10)
    vendeur = models.ForeignKey(User, on_delete=models.CASCADE)
    urgent = models.BooleanField(default=False)
    vues_count = models.PositiveIntegerField(default=0)
    date_creation = models.DateTimeField(auto_now_add=True)
    date_modification = models.DateTimeField(auto_now=True)
    active = models.BooleanField(default=True)
    
    class Meta:
        ordering = ['-date_creation']
        verbose_name = "Annonce"
        verbose_name_plural = "Annonces"
    
    def __str__(self):
        return self.titre
    
    def get_absolute_url(self):
        return reverse('detail_annonce', kwargs={'pk': self.pk})
    
    @property
    def photo_principale(self):
        return self.photos.first()
    
    def incrementer_vues(self):
        self.vues_count += 1
        self.save(update_fields=['vues_count'])

class PhotoAnnonce(models.Model):
    annonce = models.ForeignKey(Annonce, on_delete=models.CASCADE, related_name='photos')
    image = models.ImageField(upload_to='annonces/photos/%Y/%m/')
    ordre = models.PositiveIntegerField(default=0)
    
    class Meta:
        ordering = ['ordre']

class Favori(models.Model):
    utilisateur = models.ForeignKey(User, on_delete=models.CASCADE)
    annonce = models.ForeignKey(Annonce, on_delete=models.CASCADE)
    date_ajout = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        unique_together = ['utilisateur', 'annonce']

# views.py
from django.shortcuts import render, get_object_or_404, redirect
from django.core.paginator import Paginator
from django.db.models import Q, Count
from django.contrib.auth.decorators import login_required
from django.http import JsonResponse
from django.views.decorators.http import require_http_methods
from collections import defaultdict, OrderedDict

def liste_annonces(request):
    # Récupérer les paramètres de recherche
    recherche = request.GET.get('q', '')
    categorie_slug = request.GET.get('categorie', '')
    prix_min = request.GET.get('prix_min', '')
    prix_max = request.GET.get('prix_max', '')
    ville = request.GET.get('ville', '')
    per_page = int(request.GET.get('per_page', 24))
    sort = request.GET.get('sort', 'date')
    
    # Base queryset
    annonces = Annonce.objects.filter(active=True).select_related('categorie', 'vendeur')
    
    # Filtres
    if recherche:
        annonces = annonces.filter(
            Q(titre__icontains=recherche) | 
            Q(description__icontains=recherche)
        )
    
    if categorie_slug:
        annonces = annonces.filter(categorie__slug=categorie_slug)
    
    if prix_min:
        annonces = annonces.filter(prix__gte=prix_min)
    
    if prix_max:
        annonces = annonces.filter(prix__lte=prix_max)
    
    if ville:
        annonces = annonces.filter(ville__icontains=ville)
    
    # Tri
    if sort == 'prix_asc':
        annonces = annonces.order_by('prix')
    elif sort == 'prix_desc':
        annonces = annonces.order_by('-prix')
    elif sort == 'vues':
        annonces = annonces.order_by('-vues_count')
    else:  # date par défaut
        annonces = annonces.order_by('-date_creation')
    
    # Pagination
    paginator = Paginator(annonces, per_page)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    # Grouper par catégorie pour l'affichage
    annonces_par_categorie = defaultdict(list)
    for annonce in page_obj:
        annonces_par_categorie[annonce.categorie].append(annonce)
    
    # Trier les catégories par nombre d'annonces
    annonces_par_categorie = OrderedDict(sorted(
        annonces_par_categorie.items(),
        key=lambda x: len(x[1]),
        reverse=True
    ))
    
    # Récupérer les favoris de l'utilisateur si connecté
    favoris = []
    if request.user.is_authenticated:
        favoris = Favori.objects.filter(
            utilisateur=request.user,
            annonce__in=page_obj
        ).values_list('annonce_id', flat=True)
    
    # Toutes les catégories pour les filtres
    categories = Categorie.objects.all()
    
    context = {
        'annonces_par_categorie': annonces_par_categorie,
        'page_obj': page_obj,
        'is_paginated': page_obj.has_other_pages(),
        'categories': categories,
        'favoris': favoris,
        'recherche': recherche,
        'per_page': per_page,
        'sort': sort,
        'categorie_slug': categorie_slug,
        'prix_min': prix_min,
        'prix_max': prix_max,
        'ville': ville,
    }
    return render(request, 'annonces/liste.html', context)

def detail_annonce(request, pk):
    annonce = get_object_or_404(Annonce, pk=pk, active=True)
    annonce.incrementer_vues()
    
    # Annonces similaires
    annonces_similaires = Annonce.objects.filter(
        categorie=annonce.categorie,
        active=True
    ).exclude(pk=annonce.pk)[:6]
    
    context = {
        'annonce': annonce,
        'annonces_similaires': annonces_similaires,
    }
    return render(request, 'annonces/detail.html', context)

@login_required
@require_http_methods(["POST"])
def toggle_favori(request, annonce_id):
    annonce = get_object_or_404(Annonce, pk=annonce_id)
    favori, created = Favori.objects.get_or_create(
        utilisateur=request.user,
        annonce=annonce
    )
    
    if not created:
        favori.delete()
        is_favorite = False
    else:
        is_favorite = True
    
    return JsonResponse({'is_favorite': is_favorite})

def categorie_view(request, slug):
    categorie = get_object_or_404(Categorie, slug=slug)
    request.GET = request.GET.copy()
    request.GET['categorie'] = slug
    return liste_annonces(request)

# urls.py
from django.urls import path
from . import views

app_name = 'annonces'

urlpatterns = [
    path('', views.liste_annonces, name='liste'),
    path('annonce/<int:pk>/', views.detail_annonce, name='detail'),
    path('categorie/<slug:slug>/', views.categorie_view, name='categorie'),
    path('favori/toggle/<int:annonce_id>/', views.toggle_favori, name='toggle_favori'),
]

# admin.py
from django.contrib import admin
from .models import Categorie, Annonce, PhotoAnnonce, Favori

class PhotoAnnonceInline(admin.TabularInline):
    model = PhotoAnnonce
    extra = 1

@admin.register(Categorie)
class CategorieAdmin(admin.ModelAdmin):
    list_display = ['nom', 'emoji', 'ordre']
    prepopulated_fields = {'slug': ('nom',)}

@admin.register(Annonce)
class AnnonceAdmin(admin.ModelAdmin):
    list_display = ['titre', 'prix', 'categorie', 'ville', 'vendeur', 'date_creation', 'active']
    list_filter = ['categorie', 'etat', 'urgent', 'active', 'date_creation']
    search_fields = ['titre', 'description', 'ville']
    inlines = [PhotoAnnonceInline]

# management/commands/create_categories.py
from django.core.management.base import BaseCommand
from annonces.models import Categorie

class Command(BaseCommand):
    help = 'Crée les catégories par défaut'

    def handle(self, *args, **options):
        categories_data = [
            {'nom': 'Immobilier', 'emoji': '🏠', 'ordre': 1},
            {'nom': 'Automobile', 'emoji': '🚗', 'ordre': 2},
            {'nom': 'Électroménager', 'emoji': '⚡', 'ordre': 3},
            {'nom': 'Mobilier', 'emoji': '🪑', 'ordre': 4},
            {'nom': 'Informatique', 'emoji': '💻', 'ordre': 5},
            {'nom': 'Sport & Loisirs', 'emoji': '⚽', 'ordre': 6},
            {'nom': 'Mode & Beauté', 'emoji': '👔', 'ordre': 7},
            {'nom': 'Emploi', 'emoji': '💼', 'ordre': 8},
            {'nom': 'Services', 'emoji': '🔧', 'ordre': 9},
        ]
        
        for cat_data in categories_data:
            categorie, created = Categorie.objects.get_or_create(
                nom=cat_data['nom'],
                defaults=cat_data
            )
            if created:
                self.stdout.write(f'Catégorie "{categorie.nom}" créée')
            else:
                self.stdout.write(f'Catégorie "{categorie.nom}" existe déjà')

# settings.py (ajouts nécessaires)
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'annonces',  # Votre app
]

MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

# urls.py (projet principal)
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('annonces.urls')),
]

# Servir les fichiers media en développement
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

# urls.py (app annonces) - version complète
from django.urls import path
from . import views

app_name = 'annonces'

urlpatterns = [
    path('', views.liste_annonces, name='liste'),
    path('annonce/<int:pk>/', views.detail_annonce, name='detail'),
    path('categorie/<slug:slug>/', views.categorie_view, name='categorie'),
    path('favori/toggle/<int:annonce_id>/', views.toggle_favori, name='toggle_favori'),
]

# forms.py (pour les formulaires)
from django import forms
from .models import Annonce, Categorie

class AnnonceForm(forms.ModelForm):
    class Meta:
        model = Annonce
        fields = ['titre', 'description', 'prix', 'categorie', 'etat', 'ville', 'code_postal', 'urgent']
        widgets = {
            'titre': forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'Titre de votre annonce'}),
            'description': forms.Textarea(attrs={'class': 'form-control', 'rows': 5, 'placeholder': 'Décrivez votre article...'}),
            'prix': forms.NumberInput(attrs={'class': 'form-control', 'step': '0.01'}),
            'categorie': forms.Select(attrs={'class': 'form-control'}),
            'etat': forms.Select(attrs={'class': 'form-control'}),
            'ville': forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'Ville'}),
            'code_postal': forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'Code postal'}),
            'urgent': forms.CheckboxInput(attrs={'class': 'form-check-input'}),
        }

class RechercheForm(forms.Form):
    q = forms.CharField(max_length=200, required=False, widget=forms.TextInput(attrs={'placeholder': 'Rechercher...'}))
    categorie = forms.ModelChoiceField(queryset=Categorie.objects.all(), required=False, empty_label="Toutes les catégories")
    prix_min = forms.DecimalField(max_digits=10, decimal_places=2, required=False, widget=forms.NumberInput(attrs={'placeholder': 'Prix min'}))
    prix_max = forms.DecimalField(max_digits=10, decimal_places=2, required=False, widget=forms.NumberInput(attrs={'placeholder': 'Prix max'}))
    ville = forms.CharField(max_length=100, required=False, widget=forms.TextInput(attrs={'placeholder': 'Ville'}))

# requirements.txt
"""
Django>=4.2.0
Pillow>=9.0.0
"""

# Instructions d'installation et utilisation

"""
INSTALLATION :

1. Créer un environnement virtuel :
   python -m venv venv
   source venv/bin/activate  # Linux/Mac
   venv\Scripts\activate     # Windows

2. Installer les dépendances :
   pip install Django>=4.2.0 Pillow>=9.0.0

3. Créer le projet Django :
   django-admin startproject petites_annonces
   cd petites_annonces
   django-admin startapp annonces

4. Ajouter le code ci-dessus dans les fichiers correspondants

5. Effectuer les migrations :
   python manage.py makemigrations
   python manage.py migrate

6. Créer les catégories par défaut :
   python manage.py create_categories

7. Créer un superutilisateur :
   python manage.py createsuperuser

8. Lancer le serveur :
   python manage.py runserver

STRUCTURE DES FICHIERS :
petites_annonces/
├── manage.py
├── petites_annonces/
│   ├── __init__.py
│   ├── settings.py
│   ├── urls.py
│   └── wsgi.py
├── annonces/
│   ├── __init__.py
│   ├── admin.py
│   ├── apps.py
│   ├── models.py
│   ├── views.py
│   ├── urls.py
│   ├── forms.py
│   ├── migrations/
│   ├── management/
│   │   └── commands/
│   │       └── create_categories.py
│   └── templates/
│       └── annonces/
│           ├── liste.html
│           └── detail.html
├── media/
└── static/

FONCTIONNALITÉS INCLUSES :
✅ Modèles complets (Annonce, Catégorie, Photo, Favori)
✅ Interface admin Django
✅ Système de catégories avec emojis
✅ Pagination avancée
✅ Recherche et filtres
✅ Système de favoris (AJAX)
✅ Upload de photos
✅ Design responsive inspiré LeBonCoin
✅ Scroll horizontal par catégorie
✅ Template de détail avec galerie photos
✅ Annonces similaires
✅ Compteur de vues
✅ Management command pour créer les catégories

PROCHAINES ÉTAPES POSSIBLES :
- Système d'authentification utilisateur
- Formulaire de création d'annonces
- Messagerie entre utilisateurs
- Géolocalisation avec cartes
- Notifications par email
- API REST avec Django REST Framework
- Cache Redis pour les performances
- Recherche avancée avec Elasticsearch
"""