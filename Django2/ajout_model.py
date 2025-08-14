
# models.py (ajouts)
from django.contrib.auth.models import User
from django.db import models
from django.urls import reverse

# Modèles existants + ajouts :

class ProfilUtilisateur(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profil')
    telephone = models.CharField(max_length=20, blank=True)
    ville_defaut = models.CharField(max_length=100, blank=True)
    code_postal_defaut = models.CharField(max_length=10, blank=True)
    photo_profil = models.ImageField(upload_to='profils/', blank=True, null=True)
    description = models.TextField(blank=True)
    date_creation = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"Profil de {self.user.username}"

class Conversation(models.Model):
    annonce = models.ForeignKey(Annonce, on_delete=models.CASCADE, related_name='conversations')
    acheteur = models.ForeignKey(User, on_delete=models.CASCADE, related_name='conversations_acheteur')
    vendeur = models.ForeignKey(User, on_delete=models.CASCADE, related_name='conversations_vendeur')
    date_creation = models.DateTimeField(auto_now_add=True)
    active = models.BooleanField(default=True)
    
    class Meta:
        unique_together = ['annonce', 'acheteur', 'vendeur']
    
    def __str__(self):
        return f"Conversation: {self.annonce.titre}"

class Message(models.Model):
    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE, related_name='messages')
    expediteur = models.ForeignKey(User, on_delete=models.CASCADE)
    contenu = models.TextField()
    date_envoi = models.DateTimeField(auto_now_add=True)
    lu = models.BooleanField(default=False)
    
    class Meta:
        ordering = ['date_envoi']
    
    def __str__(self):
        return f"Message de {self.expediteur.username}"

# views.py (ajouts)
from django.shortcuts import render, get_object_or_404, redirect
from django.contrib.auth import login, authenticate
from django.contrib.auth.decorators import login_required
from django.contrib.auth.forms import UserCreationForm
from django.contrib import messages
from django.http import JsonResponse
from django.core.paginator import Paginator
from django.db.models import Q, Count
from .models import *
from .forms import *

# Vues d'authentification
def register_view(request):
    if request.method == 'POST':
        form = UserCreationForm(request.POST)
        if form.is_valid():
            user = form.save()
            # Créer le profil automatiquement
            ProfilUtilisateur.objects.create(user=user)
            username = form.cleaned_data.get('username')
            messages.success(request, f'Compte créé pour {username}!')
            login(request, user)
            return redirect('annonces:liste')
    else:
        form = UserCreationForm()
    return render(request, 'registration/register.html', {'form': form})

# Vues des annonces
@login_required
def creer_annonce(request):
    if request.method == 'POST':
        form = AnnonceForm(request.POST)
        photos_form = PhotoAnnonceFormSet(request.POST, request.FILES)
        
        if form.is_valid() and photos_form.is_valid():
            annonce = form.save(commit=False)
            annonce.vendeur = request.user
            annonce.save()
            
            # Sauvegarder les photos
            photos_form.instance = annonce
            photos_form.save()
            
            messages.success(request, 'Votre annonce a été créée avec succès!')
            return redirect('annonces:detail', pk=annonce.pk)
    else:
        form = AnnonceForm()
        photos_form = PhotoAnnonceFormSet()
    
    context = {
        'form': form,
        'photos_form': photos_form,
        'title': 'Créer une annonce'
    }
    return render(request, 'annonces/creer.html', context)

@login_required
def modifier_annonce(request, pk):
    annonce = get_object_or_404(Annonce, pk=pk, vendeur=request.user)
    
    if request.method == 'POST':
        form = AnnonceForm(request.POST, instance=annonce)
        photos_form = PhotoAnnonceFormSet(request.POST, request.FILES, instance=annonce)
        
        if form.is_valid() and photos_form.is_valid():
            form.save()
            photos_form.save()
            messages.success(request, 'Votre annonce a été modifiée avec succès!')
            return redirect('annonces:detail', pk=annonce.pk)
    else:
        form = AnnonceForm(instance=annonce)
        photos_form = PhotoAnnonceFormSet(instance=annonce)
    
    context = {
        'form': form,
        'photos_form': photos_form,
        'annonce': annonce,
        'title': 'Modifier l\'annonce'
    }
    return render(request, 'annonces/creer.html', context)

@login_required
def supprimer_annonce(request, pk):
    annonce = get_object_or_404(Annonce, pk=pk, vendeur=request.user)
    
    if request.method == 'POST':
        annonce.delete()
        messages.success(request, 'Votre annonce a été supprimée.')
        return redirect('annonces:mes_annonces')
    
    return render(request, 'annonces/supprimer.html', {'annonce': annonce})

@login_required
def mes_annonces(request):
    annonces = Annonce.objects.filter(vendeur=request.user).order_by('-date_creation')
    
    paginator = Paginator(annonces, 12)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    context = {
        'page_obj': page_obj,
        'title': 'Mes annonces'
    }
    return render(request, 'annonces/mes_annonces.html', context)

@login_required
def mes_favoris(request):
    favoris = Favori.objects.filter(utilisateur=request.user).select_related('annonce')
    annonces = [favori.annonce for favori in favoris]
    
    paginator = Paginator(annonces, 12)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    context = {
        'page_obj': page_obj,
        'title': 'Mes favoris'
    }
    return render(request, 'annonces/mes_favoris.html', context)

# Vues de profil
@login_required
def profil_view(request):
    profil, created = ProfilUtilisateur.objects.get_or_create(user=request.user)
    
    if request.method == 'POST':
        form = ProfilForm(request.POST, request.FILES, instance=profil)
        if form.is_valid():
            form.save()
            messages.success(request, 'Votre profil a été mis à jour!')
            return redirect('annonces:profil')
    else:
        form = ProfilForm(instance=profil)
    
    # Statistiques utilisateur
    stats = {
        'nb_annonces': Annonce.objects.filter(vendeur=request.user, active=True).count(),
        'nb_favoris': Favori.objects.filter(utilisateur=request.user).count(),
        'nb_messages': Message.objects.filter(expediteur=request.user).count(),
        'total_vues': Annonce.objects.filter(vendeur=request.user).aggregate(
            total=models.Sum('vues_count'))['total'] or 0
    }
    
    context = {
        'form': form,
        'profil': profil,
        'stats': stats
    }
    return render(request, 'annonces/profil.html', context)

# Vues de messagerie
@login_required
def contacter_vendeur(request, annonce_id):
    annonce = get_object_or_404(Annonce, pk=annonce_id)
    
    if request.user == annonce.vendeur:
        messages.error(request, 'Vous ne pouvez pas vous contacter vous-même!')
        return redirect('annonces:detail', pk=annonce_id)
    
    # Créer ou récupérer la conversation
    conversation, created = Conversation.objects.get_or_create(
        annonce=annonce,
        acheteur=request.user,
        vendeur=annonce.vendeur
    )
    
    if request.method == 'POST':
        contenu = request.POST.get('message')
        if contenu:
            Message.objects.create(
                conversation=conversation,
                expediteur=request.user,
                contenu=contenu
            )
            messages.success(request, 'Votre message a été envoyé!')
            return redirect('annonces:conversation', pk=conversation.pk)
    
    return render(request, 'annonces/contacter.html', {
        'annonce': annonce,
        'conversation': conversation
    })

@login_required
def conversation_view(request, pk):
    conversation = get_object_or_404(
        Conversation, 
        pk=pk,
        Q(acheteur=request.user) | Q(vendeur=request.user)
    )
    
    # Marquer les messages comme lus
    Message.objects.filter(
        conversation=conversation,
        lu=False
    ).exclude(expediteur=request.user).update(lu=True)
    
    if request.method == 'POST':
        contenu = request.POST.get('message')
        if contenu:
            Message.objects.create(
                conversation=conversation,
                expediteur=request.user,
                contenu=contenu
            )
            return redirect('annonces:conversation', pk=pk)
    
    messages_list = conversation.messages.all()
    
    context = {
        'conversation': conversation,
        'messages': messages_list
    }
    return render(request, 'annonces/conversation.html', context)

@login_required
def mes_messages(request):
    conversations = Conversation.objects.filter(
        Q(acheteur=request.user) | Q(vendeur=request.user),
        active=True
    ).select_related('annonce', 'acheteur', 'vendeur').prefetch_related('messages')
    
    # Ajouter le dernier message à chaque conversation
    for conv in conversations:
        conv.dernier_message = conv.messages.last()
        conv.nb_non_lus = conv.messages.filter(lu=False).exclude(expediteur=request.user).count()
    
    context = {
        'conversations': conversations
    }
    return render(request, 'annonces/mes_messages.html', context)

# forms.py (ajouts)
from django import forms
from django.forms import modelformset_factory, inlineformset_factory
from .models import *

class AnnonceForm(forms.ModelForm):
    class Meta:
        model = Annonce
        fields = ['titre', 'description', 'prix', 'categorie', 'etat', 'ville', 'code_postal', 'urgent']
        widgets = {
            'titre': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': 'Ex: iPhone 14 Pro Max 256Go'
            }),
            'description': forms.Textarea(attrs={
                'class': 'form-control',
                'rows': 6,
                'placeholder': 'Décrivez votre article en détail...'
            }),
            'prix': forms.NumberInput(attrs={
                'class': 'form-control',
                'step': '0.01',
                'min': '0'
            }),
            'categorie': forms.Select(attrs={'class': 'form-control'}),
            'etat': forms.Select(attrs={'class': 'form-control'}),
            'ville': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': 'Ville'
            }),
            'code_postal': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': 'Code postal'
            }),
            'urgent': forms.CheckboxInput(attrs={'class': 'form-check-input'}),
        }

class PhotoAnnonceForm(forms.ModelForm):
    class Meta:
        model = PhotoAnnonce
        fields = ['image', 'ordre']
        widgets = {
            'image': forms.ClearableFileInput(attrs={
                'class': 'form-control',
                'accept': 'image/*'
            }),
            'ordre': forms.NumberInput(attrs={'class': 'form-control'})
        }

PhotoAnnonceFormSet = inlineformset_factory(
    Annonce, PhotoAnnonce,
    form=PhotoAnnonceForm,
    extra=5,
    max_num=10,
    can_delete=True
)

class ProfilForm(forms.ModelForm):
    class Meta:
        model = ProfilUtilisateur
        fields = ['telephone', 'ville_defaut', 'code_postal_defaut', 'photo_profil', 'description']
        widgets = {
            'telephone': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': '06 12 34 56 78'
            }),
            'ville_defaut': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': 'Votre ville'
            }),
            'code_postal_defaut': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': 'Code postal'
            }),
            'photo_profil': forms.ClearableFileInput(attrs={
                'class': 'form-control',
                'accept': 'image/*'
            }),
            'description': forms.Textarea(attrs={
                'class': 'form-control',
                'rows': 3,
                'placeholder': 'Parlez-vous en quelques mots...'
            }),
        }

# urls.py (complet)
from django.urls import path
from django.contrib.auth import views as auth_views
from . import views

app_name = 'annonces'

urlpatterns = [
    # Pages principales
    path('', views.liste_annonces, name='liste'),
    path('annonce/<int:pk>/', views.detail_annonce, name='detail'),
    path('categorie/<slug:slug>/', views.categorie_view, name='categorie'),
    
    # Authentification
    path('register/', views.register_view, name='register'),
    path('login/', auth_views.LoginView.as_view(), name='login'),
    path('logout/', auth_views.LogoutView.as_view(), name='logout'),
    
    # Gestion des annonces
    path('creer/', views.creer_annonce, name='creer'),
    path('annonce/<int:pk>/modifier/', views.modifier_annonce, name='modifier'),
    path('annonce/<int:pk>/supprimer/', views.supprimer_annonce, name='supprimer'),
    path('mes-annonces/', views.mes_annonces, name='mes_annonces'),
    path('mes-favoris/', views.mes_favoris, name='mes_favoris'),
    
    # Profil
    path('profil/', views.profil_view, name='profil'),
    
    # Messagerie
    path('contacter/<int:annonce_id>/', views.contacter_vendeur, name='contacter'),
    path('conversation/<int:pk>/', views.conversation_view, name='conversation'),
    path('mes-messages/', views.mes_messages, name='mes_messages'),
    
    # AJAX
    path('favori/toggle/<int:annonce_id>/', views.toggle_favori, name='toggle_favori'),
]

# admin.py (ajouts)
from django.contrib import admin
from .models import *

@admin.register(ProfilUtilisateur)
class ProfilUtilisateurAdmin(admin.ModelAdmin):
    list_display = ['user', 'ville_defaut', 'telephone', 'date_creation']
    search_fields = ['user__username', 'ville_defaut']

class MessageInline(admin.TabularInline):
    model = Message
    extra = 0
    readonly_fields = ['date_envoi']

@admin.register(Conversation)
class ConversationAdmin(admin.ModelAdmin):
    list_display = ['annonce', 'acheteur', 'vendeur', 'date_creation', 'active']
    list_filter = ['active', 'date_creation']
    inlines = [MessageInline]

@admin.register(Message)
class MessageAdmin(admin.ModelAdmin):
    list_display = ['expediteur', 'conversation', 'date_envoi', 'lu']
    list_filter = ['lu', 'date_envoi']
    search_fields = ['contenu', 'expediteur__username']

# signals.py (création automatique du profil)
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth.models import User
from .models import ProfilUtilisateur

@receiver(post_save, sender=User)
def create_user_profile(sender, instance, created, **kwargs):
    if created:
        ProfilUtilisateur.objects.create(user=instance)

@receiver(post_save, sender=User)
def save_user_profile(sender, instance, **kwargs):
    if hasattr(instance, 'profil'):
        instance.profil.save()

# apps.py (pour activer les signals)
from django.apps import AppConfig

class AnnoncesConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'annonces'
    
    def ready(self):
        import annonces.signals

# settings.py (ajouts)
LOGIN_URL = '/login/'
LOGIN_REDIRECT_URL = '/'
LOGOUT_REDIRECT_URL = '/'

# Configuration email (pour les notifications)
EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'  # Pour dev
# EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'  # Pour prod

# Taille max des fichiers (10MB)
FILE_UPLOAD_MAX_MEMORY_SIZE = 10 * 1024 * 1024
DATA_UPLOAD_MAX_MEMORY_SIZE = 10 * 1024 * 1024