# listings/views.py
from django.shortcuts import render, get_object_or_404, redirect
from django.contrib.auth.decorators import login_required
from django.contrib.auth import login
from django.contrib import messages
from django.core.paginator import Paginator
from django.db.models import Q, F
from django.db import connection
from django.http import JsonResponse, Http404
from django.urls import reverse
from django.views.decorators.http import require_POST
from django.contrib.postgres.search import SearchVector, SearchQuery
from django.utils import timezone
from .models import (
    Listing, Category, UserProfile, UserFavorite, 
    Conversation, Message, UserRating, Tag
)
from .forms import (
    ListingForm, ListingSearchForm, CustomUserCreationForm, 
    UserProfileForm, MessageForm, UserRatingForm, ContactSellerForm
)
import json

def home(request):
    """Page d'accueil avec annonces récentes et catégories"""
    # Annonces mises en avant
    featured_listings = Listing.objects.featured()[:6]
    
    # Annonces récentes
    recent_listings = Listing.objects.active().select_related(
        'category', 'user__profile'
    ).prefetch_related('images')[:12]
    
    # Catégories principales
    main_categories = Category.objects.filter(
        parent__isnull=True, 
        is_active=True
    ).order_by('sort_order')
    
    # Statistiques
    stats = {
        'total_listings': Listing.objects.active().count(),
        'total_users': UserProfile.objects.filter(status='active').count(),
        'total_categories': Category.objects.filter(is_active=True).count(),
    }
    
    context = {
        'featured_listings': featured_listings,
        'recent_listings': recent_listings,
        'main_categories': main_categories,
        'stats': stats,
    }
    
    return render(request, 'listings/home.html', context)

def listing_list(request):
    """Liste des annonces avec recherche et filtres"""
    form = ListingSearchForm(request.GET)
    listings = Listing.objects.active().select_related(
        'category', 'user__profile'
    ).prefetch_related('images')
    
    if form.is_valid():
        # Recherche textuelle
        query = form.cleaned_data.get('query')
        if query:
            listings = listings.filter(
                Q(title__icontains=query) | 
                Q(description__icontains=query) |
                Q(category__name__icontains=query)
            )
        
        # Filtre par catégorie
        category = form.cleaned_data.get('category')
        if category:
            # Inclure les sous-catégories
            subcategories = category.get_descendants()
            category_ids = [category.id] + [cat.id for cat in subcategories]
            listings = listings.filter(category_id__in=category_ids)
        
        # Filtre par prix
        min_price = form.cleaned_data.get('min_price')
        max_price = form.cleaned_data.get('max_price')
        if min_price:
            listings = listings.filter(price_cents__gte=int(min_price * 100))
        if max_price:
            listings = listings.filter(price_cents__lte=int(max_price * 100))
        
        # Filtre par état
        condition = form.cleaned_data.get('condition')
        if condition:
            listings = listings.filter(condition__in=condition)
        
        # Filtre par localisation
        location = form.cleaned_data.get('location')
        if location:
            listings = listings.filter(location__icontains=location)
        
        # Tri
        sort_by = form.cleaned_data.get('sort_by', '-created_at')
        listings = listings.order_by(sort_by)
    
    # Pagination
    paginator = Paginator(listings, 20)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    context = {
        'form': form,
        'page_obj': page_obj,
        'listings_count': paginator.count,
    }
    
    return render(request, 'listings/listing_list.html', context)

def listing_detail(request, slug):
    """Détail d'une annonce"""
    listing = get_object_or_404(
        Listing.objects.select_related('category', 'user__profile')
        .prefetch_related('images', 'tags'),
        slug=slug,
        status='active'
    )
    
    # Incrémenter le compteur de vues
    listing.increment_view_count()
    
    # Annonces similaires
    related_listings = listing.get_related_listings()
    
    # Vérifie si en favori
    is_favorited = listing.is_favorited_by(request.user)
    
    # Formulaire de contact
    contact_form = ContactSellerForm()
    
    # Conversation existante si utilisateur connecté
    conversation = None
    if request.user.is_authenticated and request.user != listing.user:
        conversation = Conversation.objects.filter(
            listing=listing,
            buyer=request.user,
            seller=listing.user
        ).first()
    
    context = {
        'listing': listing,
        'related_listings': related_listings,
        'is_favorited': is_favorited,
        'contact_form': contact_form,
        'conversation': conversation,
    }
    
    return render(request, 'listings/listing_detail.html', context)

@login_required
def listing_create(request):
    """Création d'une nouvelle annonce"""
    if request.method == 'POST':
        form = ListingForm(request.POST, request.FILES)
        if form.is_valid():
            listing = form.save(commit=False)
            listing.user = request.user
            listing.save()
            form.save_m2m()  # Pour les tags
            
            messages.success(request, 'Votre annonce a été créée avec succès!')
            return redirect('listing_detail', slug=listing.slug)
    else:
        form = ListingForm()
    
    return render(request, 'listings/listing_form.html', {
        'form': form,
        'title': 'Créer une annonce',
    })

@login_required
def listing_edit(request, slug):
    """Modification d'une annonce"""
    listing = get_object_or_404(Listing, slug=slug, user=request.user)
    
    if request.method == 'POST':
        form = ListingForm(request.POST, request.FILES, instance=listing)
        if form.is_valid():
            listing = form.save()
            messages.success(request, 'Votre annonce a été modifiée avec succès!')
            return redirect('listing_detail', slug=listing.slug)
    else:
        form = ListingForm(instance=listing)
    
    return render(request, 'listings/listing_form.html', {
        'form': form,
        'listing': listing,
        'title': 'Modifier l\'annonce',
    })

@login_required
def listing_delete(request, slug):
    """Suppression d'une annonce"""
    listing = get_object_or_404(Listing, slug=slug, user=request.user)
    
    if request.method == 'POST':
        listing.status = 'deleted'
        listing.save()
        messages.success(request, 'Votre annonce a été supprimée.')
        return redirect('user_listings')
    
    return render(request, 'listings/listing_confirm_delete.html', {
        'listing': listing,
    })

def category_detail(request, slug):
    """Annonces d'une catégorie"""
    category = get_object_or_404(Category, slug=slug, is_active=True)
    
    # Inclure les sous-catégories
    subcategories = category.get_descendants()
    category_ids = [category.id] + [cat.id for cat in subcategories]
    
    listings = Listing.objects.active().filter(
        category_id__in=category_ids
    ).select_related('category', 'user__profile').prefetch_related('images')
    
    # Pagination
    paginator = Paginator(listings, 20)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    # Statistiques de la catégorie
    with connection.cursor() as cursor:
        cursor.execute("SELECT * FROM get_category_stats(%s)", [category.id])
        stats = cursor.fetchone()
    
    context = {
        'category': category,
        'subcategories': category.children.filter(is_active=True),
        'page_obj': page_obj,
        'breadcrumb': category.get_breadcrumb(),
        'stats': {
            'total_listings': stats[0] if stats else 0,
            'active_listings': stats[1] if stats else 0,
            'avg_price': stats[2] if stats else 0,
            'min_price': stats[3] if stats else 0,
            'max_price': stats[4] if stats else 0,
        } if stats else None,
    }
    
    return render(request, 'listings/category_detail.html', context)

@login_required
@require_POST
def toggle_favorite(request, slug):
    """Ajouter/retirer des favoris (AJAX)"""
    listing = get_object_or_404(Listing, slug=slug, status='active')
    
    favorite, created = UserFavorite.objects.get_or_create(
        user=request.user,
        listing=listing
    )
    
    if not created:
        favorite.delete()
        is_favorited = False
        action = 'removed'
    else:
        is_favorited = True
        action = 'added'
    
    # Mettre à jour le compteur
    favorite_count = listing.favorites.count()
    listing.favorite_count = favorite_count
    listing.save(update_fields=['favorite_count'])
    
    return JsonResponse({
        'is_favorited': is_favorited,
        'action': action,
        'favorite_count': favorite_count,
    })

@login_required
def user_favorites(request):
    """Favoris de l'utilisateur"""
    favorites = UserFavorite.objects.filter(
        user=request.user
    ).select_related(
        'listing__category', 'listing__user__profile'
    ).prefetch_related('listing__images')
    
    paginator = Paginator(favorites, 20)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    return render(request, 'listings/user_favorites.html', {
        'page_obj': page_obj,
    })

@login_required
def user_listings(request):
    """Annonces de l'utilisateur"""
    listings = Listing.objects.filter(
        user=request.user
    ).exclude(status='deleted').select_related('category').prefetch_related('images')
    
    paginator = Paginator(listings, 20)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    return render(request, 'listings/user_listings.html', {
        'page_obj': page_obj,
    })

@login_required
def user_profile(request):
    """Profil de l'utilisateur"""
    profile = request.user.profile
    
    if request.method == 'POST':
        form = UserProfileForm(request.POST, request.FILES, instance=profile)
        if form.is_valid():
            form.save()
            messages.success(request, 'Votre profil a été mis à jour!')
            return redirect('user_profile')
    else:
        form = UserProfileForm(instance=profile)
    
    return render(request, 'listings/user_profile.html', {
        'form': form,
        'profile': profile,
    })

def user_public_profile(request, username):
    """Profil public d'un utilisateur"""
    user = get_object_or_404(User, username=username)
    profile = user.profile
    
    if profile.status != 'active':
        raise Http404("Profil non disponible")
    
    # Annonces actives de l'utilisateur
    listings = Listing.objects.active().filter(
        user=user
    ).select_related('category').prefetch_related('images')[:12]
    
    # Évaluations reçues
    ratings = UserRating.objects.filter(
        rated=user
    ).select_related('rater').order_by('-created_at')[:10]
    
    context = {
        'profile_user': user,
        'profile': profile,
        'listings': listings,
        'ratings': ratings,
        'listings_count': Listing.objects.active().filter(user=user).count(),
    }
    
    return render(request, 'listings/user_public_profile.html', context)

@login_required
def contact_seller(request, slug):
    """Contacter le vendeur"""
    listing = get_object_or_404(Listing, slug=slug, status='active')
    
    if request.user == listing.user:
        messages.error(request, "Vous ne pouvez pas vous contacter vous-même!")
        return redirect('listing_detail', slug=slug)
    
    if request.method == 'POST':
        form = ContactSellerForm(request.POST)
        if form.is_valid():
            # Créer ou récupérer la conversation
            conversation, created = Conversation.objects.get_or_create(
                listing=listing,
                buyer=request.user,
                seller=listing.user,
                defaults={'is_active': True}
            )
            
            # Créer le message
            message = Message.objects.create(
                conversation=conversation,
                sender=request.user,
                content=form.cleaned_data['message']
            )
            
            # Mettre à jour la conversation
            conversation.last_message_at = timezone.now()
            conversation.save()
            
            # Incrémenter le compteur de contacts
            listing.contact_count = F('contact_count') + 1
            listing.save(update_fields=['contact_count'])
            
            messages.success(request, 'Votre message a été envoyé!')
            return redirect('conversation_detail', pk=conversation.pk)
    else:
        form = ContactSellerForm()
    
    return render(request, 'listings/contact_seller.html', {
        'form': form,
        'listing': listing,
    })

@login_required
def conversation_list(request):
    """Liste des conversations de l'utilisateur"""
    conversations = Conversation.objects.filter(
        Q(buyer=request.user) | Q(seller=request.user),
        is_active=True
    ).select_related(
        'listing', 'buyer__profile', 'seller__profile'
    ).prefetch_related('messages').order_by('-last_message_at')
    
    return render(request, 'listings/conversation_list.html', {
        'conversations': conversations,
    })

@login_required
def conversation_detail(request, pk):
    """Détail d'une conversation avec messages"""
    conversation = get_object_or_404(
        Conversation.objects.select_related(
            'listing', 'buyer__profile', 'seller__profile'
        ),
        pk=pk
    )
    
    # Vérifier que l'utilisateur est participant
    if request.user not in [conversation.buyer, conversation.seller]:
        raise Http404("Conversation non trouvée")
    
    messages_list = conversation.messages.select_related('sender').order_by('created_at')
    
    # Marquer les messages comme lus
    unread_messages = messages_list.filter(
        read_at__isnull=True
    ).exclude(sender=request.user)
    unread_messages.update(
        read_at=timezone.now(),
        status='read'
    )
    
    if request.method == 'POST':
        form = MessageForm(request.POST)
        if form.is_valid():
            message = form.save(commit=False)
            message.conversation = conversation
            message.sender = request.user
            message.save()
            
            # Mettre à jour la conversation
            conversation.last_message_at = timezone.now()
            conversation.save()
            
            return redirect('conversation_detail', pk=conversation.pk)
    else:
        form = MessageForm()
    
    # Déterminer l'autre participant
    other_user = conversation.seller if request.user == conversation.buyer else conversation.buyer
    
    context = {
        'conversation': conversation,
        'messages': messages_list,
        'form': form,
        'other_user': other_user,
    }
    
    return render(request, 'listings/conversation_detail.html', context)

def register(request):
    """Inscription d'un nouvel utilisateur"""
    if request.method == 'POST':
        form = CustomUserCreationForm(request.POST)
        if form.is_valid():
            user = form.save()
            login(request, user)
            messages.success(request, 'Inscription réussie! Bienvenue!')
            return redirect('home')
    else:
        form = CustomUserCreationForm()
    
    return render(request, 'registration/register.html', {
        'form': form,
    })

def search_ajax(request):
    """Recherche AJAX pour l'autocomplétion"""
    query = request.GET.get('q', '').strip()
    if len(query) < 2:
        return JsonResponse({'results': []})
    
    # Recherche dans les titres d'annonces
    listings = Listing.objects.active().filter(
        title__icontains=query
    ).values('title', 'slug')[:10]
    
    # Recherche dans les catégories
    categories = Category.objects.filter(
        name__icontains=query,
        is_active=True
    ).values('name', 'slug')[:5]
    
    results = {
        'listings': list(listings),
        'categories': list(categories),
    }
    
    return JsonResponse(results)