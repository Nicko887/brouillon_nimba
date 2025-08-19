# listings/urls.py
from django.urls import path
from . import views

urlpatterns = [
    # Pages principales
    path('', views.home, name='home'),
    path('annonces/', views.listing_list, name='listing_list'),
    path('annonces/creer/', views.listing_create, name='listing_create'),
    path('annonces/<slug:slug>/', views.listing_detail, name='listing_detail'),
    path('annonces/<slug:slug>/modifier/', views.listing_edit, name='listing_edit'),
    path('annonces/<slug:slug>/supprimer/', views.listing_delete, name='listing_delete'),
    path('annonces/<slug:slug>/contacter/', views.contact_seller, name='contact_seller'),
    
    # Catégories
    path('categories/<slug:slug>/', views.category_detail, name='category_detail'),
    
    # Favoris
    path('annonces/<slug:slug>/favori/', views.toggle_favorite, name='toggle_favorite'),
    path('mes-favoris/', views.user_favorites, name='user_favorites'),
    
    # Profil utilisateur
    path('profil/', views.user_profile, name='user_profile'),
    path('mes-annonces/', views.user_listings, name='user_listings'),
    path('utilisateur/<str:username>/', views.user_public_profile, name='user_public_profile'),
    
    # Conversations
    path('conversations/', views.conversation_list, name='conversation_list'),
    path('conversations/<int:pk>/', views.conversation_detail, name='conversation_detail'),
    
    # AJAX
    path('ajax/search/', views.search_ajax, name='search_ajax'),
    
    # Inscription
    path('inscription/', views.register, name='register'),
]

# urls.py principal du projet
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('listings.urls')),
    path('accounts/', include('django.contrib.auth.urls')),  # Login/logout
]

# Servir les fichiers média en développement
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)