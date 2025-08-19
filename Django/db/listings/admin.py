# listings/admin.py
from django.contrib import admin
from django.utils.html import format_html
from django.urls import reverse
from django.utils import timezone
from django.db.models import Count
from .models import (
    Category, Listing, ListingImage, Tag, UserProfile, 
    UserFavorite, Conversation, Message, UserRating, 
    CategoryRelation, SavedSearch
)

@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ['user', 'get_full_name', 'phone', 'location', 'status', 'rating_average', 'rating_count']
    list_filter = ['status', 'email_verified', 'phone_verified', 'created_at']
    search_fields = ['user__username', 'user__email', 'user__first_name', 'user__last_name', 'phone']
    readonly_fields = ['rating_average', 'rating_count', 'created_at', 'updated_at']
    
    fieldsets = (
        ('Utilisateur', {
            'fields': ('user', 'status')
        }),
        ('Informations personnelles', {
            'fields': ('phone', 'bio', 'location', 'avatar')
        }),
        ('Géolocalisation', {
            'fields': ('latitude', 'longitude'),
            'classes': ('collapse',)
        }),
        ('Vérifications', {
            'fields': ('email_verified', 'phone_verified')
        }),
        ('Statistiques', {
            'fields': ('rating_average', 'rating_count'),
            'classes': ('collapse',)
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        })
    )
    
    def get_full_name(self, obj):
        return obj.get_full_name()
    get_full_name.short_description = 'Nom complet'

class CategoryRelationInline(admin.TabularInline):
    model = CategoryRelation
    fk_name = 'source_category'
    extra = 0

@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'parent', 'kind', 'depth', 'listing_count', 'is_active', 'sort_order']
    list_filter = ['kind', 'is_active', 'depth', 'created_at']
    search_fields = ['name', 'description']
    prepopulated_fields = {'slug': ('name',)}
    readonly_fields = ['depth', 'listing_count', 'created_at', 'updated_at']
    inlines = [CategoryRelationInline]
    
    fieldsets = (
        ('Informations principales', {
            'fields': ('parent', 'name', 'slug', 'kind', 'description')
        }),
        ('Apparence', {
            'fields': ('icon', 'image', 'sort_order')
        }),
        ('Statut', {
            'fields': ('is_active',)
        }),
        ('Métadonnées', {
            'fields': ('depth', 'listing_count', 'created_at', 'updated_at'),
            'classes': ('collapse',)
        })
    )
    
    def get_queryset(self, request):
        return super().get_queryset(request).select_related('parent')

class ListingImageInline(admin.TabularInline):
    model = ListingImage
    extra = 0
    fields = ['image', 'alt_text', 'is_primary', 'sort_order']
    readonly_fields = ['created_at']

@admin.register(Listing)
class ListingAdmin(admin.ModelAdmin):
    list_display = [
        'title', 'user', 'category', 'price_display_admin', 'status', 
        'view_count', 'favorite_count', 'created_at'
    ]
    list_filter = [
        'status', 'condition', 'category__kind', 'is_negotiable', 
        'created_at', 'expires_at'
    ]
    search_fields = ['title', 'description', 'user__username', 'location']
    prepopulated_fields = {'slug': ('title',)}
    readonly_fields = [
        'view_count', 'favorite_count', 'contact_count', 
        'search_vector', 'created_at', 'updated_at'
    ]
    inlines = [ListingImageInline]
    date_hierarchy = 'created_at'
    
    fieldsets = (
        ('Informations principales', {
            'fields': ('user', 'category', 'title', 'slug', 'description', 'status')
        }),
        ('Prix et conditions', {
            'fields': ('price_cents', 'currency', 'is_negotiable', 'condition')
        }),
        ('Géolocalisation', {
            'fields': ('location', 'latitude', 'longitude'),
            'classes': ('collapse',)
        }),
        ('SEO et recherche', {
            'fields': ('meta_title', 'meta_description', 'search_vector'),
            'classes': ('collapse',)
        }),
        ('Dates importantes', {
            'fields': ('expires_at', 'featured_until', 'sold_at')
        }),
        ('Statistiques', {
            'fields': ('view_count', 'favorite_count', 'contact_count'),
            'classes': ('collapse',)
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        })
    )
    
    def price_display_admin(self, obj):
        if obj.price_cents:
            return f"{obj.price_cents / 100:,.0f} {obj.currency}"
        return "Prix non spécifié"
    price_display_admin.short_description = 'Prix'
    
    def get_queryset(self, request):
        return super().get_queryset(request).select_related('user', 'category')
    
    actions = ['mark_as_active', 'mark_as_suspended', 'mark_as_expired']
    
    def mark_as_active(self, request, queryset):
        updated = queryset.update(status='active')
        self.message_user(request, f'{updated} annonces marquées comme actives.')
    mark_as_active.short_description = "Marquer comme active"
    
    def mark_as_suspended(self, request, queryset):
        updated = queryset.update(status='suspended')
        self.message_user(request, f'{updated} annonces suspendues.')
    mark_as_suspended.short_description = "Suspendre"
    
    def mark_as_expired(self, request, queryset):
        updated = queryset.update(status='expired')
        self.message_user(request, f'{updated} annonces expirées.')
    mark_as_expired.short_description = "Marquer comme expirées"

@admin.register(ListingImage)
class ListingImageAdmin(admin.ModelAdmin):
    list_display = ['listing', 'image_preview', 'alt_text', 'is_primary', 'sort_order']
    list_filter = ['is_primary', 'created_at']
    search_fields = ['listing__title', 'alt_text']
    
    def image_preview(self, obj):
        if obj.image:
            return format_html(
                '<img src="{}" style="width: 50px; height: 50px; object-fit: cover;" />',
                obj.image.url
            )
        return "Pas d'image"
    image_preview.short_description = 'Aperçu'

@admin.register(Tag)
class TagAdmin(admin.ModelAdmin):
    list_display = ['name', 'slug', 'usage_count', 'created_at']
    search_fields = ['name']
    prepopulated_fields = {'slug': ('name',)}
    readonly_fields = ['usage_count', 'created_at']
    ordering = ['-usage_count', 'name']

@admin.register(UserFavorite)
class UserFavoriteAdmin(admin.ModelAdmin):
    list_display = ['user', 'listing', 'created_at']
    list_filter = ['created_at']
    search_fields = ['user__username', 'listing__title']
    
    def get_queryset(self, request):
        return super().get_queryset(request).select_related('user', 'listing')

@admin.register(Conversation)
class ConversationAdmin(admin.ModelAdmin):
    list_display = ['listing', 'buyer', 'seller', 'last_message_at', 'is_active']
    list_filter = ['is_active', 'created_at', 'last_message_at']
    search_fields = ['listing__title', 'buyer__username', 'seller__username']
    readonly_fields = ['created_at', 'updated_at']
    
    def get_queryset(self, request):
        return super().get_queryset(request).select_related('listing', 'buyer', 'seller')

@admin.register(Message)
class MessageAdmin(admin.ModelAdmin):
    list_display = ['conversation', 'sender', 'content_preview', 'status', 'created_at']
    list_filter = ['status', 'created_at']
    search_fields = ['conversation__listing__title', 'sender__username', 'content']
    readonly_fields = ['created_at']
    
    def content_preview(self, obj):
        return obj.content[:50] + '...' if len(obj.content) > 50 else obj.content
    content_preview.short_description = 'Contenu'
    
    def get_queryset(self, request):
        return super().get_queryset(request).select_related('conversation__listing', 'sender')

@admin.register(UserRating)
class UserRatingAdmin(admin.ModelAdmin):
    list_display = ['rater', 'rated', 'rating', 'listing', 'created_at']
    list_filter = ['rating', 'created_at']
    search_fields = ['rater__username', 'rated__username', 'listing__title', 'comment']
    readonly_fields = ['created_at']
    
    def get_queryset(self, request):
        return super().get_queryset(request).select_related('rater', 'rated', 'listing')

@admin.register(CategoryRelation)
class CategoryRelationAdmin(admin.ModelAdmin):
    list_display = ['source_category', 'target_category', 'relation_type', 'created_at']
    list_filter = ['relation_type', 'created_at']
    search_fields = ['source_category__name', 'target_category__name']
    
    def get_queryset(self, request):
        return super().get_queryset(request).select_related('source_category', 'target_category')

@admin.register(SavedSearch)
class SavedSearchAdmin(admin.ModelAdmin):
    list_display = ['user', 'name', 'email_alerts', 'created_at']
    list_filter = ['email_alerts', 'created_at']
    search_fields = ['user__username', 'name']
    readonly_fields = ['query_params', 'created_at', 'updated_at']
    
    def get_queryset(self, request):
        return super().get_queryset(request).select_related('user')

# Configuration de l'admin Django
admin.site.site_header = "Administration Petites Annonces"
admin.site.site_title = "Admin Petites Annonces"
admin.site.index_title = "Tableau de bord"

# Ajout de statistiques dans l'admin
class AdminStats:
    """Classe pour afficher des statistiques dans l'admin"""
    
    @staticmethod
    def get_stats():
        from django.db.models import Count, Avg
        from datetime import timedelta
        
        now = timezone.now()
        last_week = now - timedelta(days=7)
        last_month = now - timedelta(days=30)
        
        stats = {
            'total_listings': Listing.objects.count(),
            'active_listings': Listing.objects.filter(status='active').count(),
            'total_users': UserProfile.objects.count(),
            'active_users': UserProfile.objects.filter(status='active').count(),
            'new_listings_week': Listing.objects.filter(created_at__gte=last_week).count(),
            'new_users_week': UserProfile.objects.filter(created_at__gte=last_week).count(),
            'categories_count': Category.objects.filter(is_active=True).count(),
            'conversations_count': Conversation.objects.filter(is_active=True).count(),
        }
        
        return stats

# Personnalisation de la page d'accueil de l'admin
def admin_index_view(request):
    """Vue personnalisée pour la page d'accueil de l'admin"""
    from django.contrib.admin.views.main import ChangeList
    from django.shortcuts import render
    
    stats = AdminStats.get_stats()
    
    context = {
        'stats': stats,
        'title': 'Tableau de bord',
    }
    
    return render(request, 'admin/custom_index.html', context)