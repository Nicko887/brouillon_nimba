# listings/signals.py
from django.db.models.signals import post_save, post_delete, m2m_changed
from django.dispatch import receiver
from django.contrib.auth.models import User
from .models import UserProfile, Listing, Category, UserRating, ListingTag, Tag

@receiver(post_save, sender=User)
def create_user_profile(sender, instance, created, **kwargs):
    """Créer automatiquement un profil utilisateur"""
    if created:
        UserProfile.objects.create(user=instance)

@receiver(post_save, sender=User)
def save_user_profile(sender, instance, **kwargs):
    """Sauvegarder le profil utilisateur"""
    if hasattr(instance, 'profile'):
        instance.profile.save()

@receiver(post_save, sender=Listing)
def update_category_listing_count_on_create(sender, instance, created, **kwargs):
    """Mettre à jour le compteur d'annonces de la catégorie lors de la création"""
    if created and instance.status == 'active':
        Category.objects.filter(id=instance.category_id).update(
            listing_count=models.F('listing_count') + 1
        )

@receiver(post_save, sender=Listing)
def update_category_listing_count_on_update(sender, instance, created, **kwargs):
    """Mettre à jour le compteur lors de la modification du statut"""
    if not created:
        # Récupérer l'ancien état depuis la base
        try:
            old_instance = Listing.objects.get(pk=instance.pk)
            
            # Si le statut change de/vers active
            if old_instance.status != instance.status:
                if old_instance.status == 'active' and instance.status != 'active':
                    # Retirer une annonce active
                    Category.objects.filter(id=instance.category_id).update(
                        listing_count=models.F('listing_count') - 1
                    )
                elif old_instance.status != 'active' and instance.status == 'active':
                    # Ajouter une annonce active
                    Category.objects.filter(id=instance.category_id).update(
                        listing_count=models.F('listing_count') + 1
                    )
            
            # Si la catégorie change
            if old_instance.category_id != instance.category_id:
                if old_instance.status == 'active':
                    # Retirer de l'ancienne catégorie
                    Category.objects.filter(id=old_instance.category_id).update(
                        listing_count=models.F('listing_count') - 1
                    )
                if instance.status == 'active':
                    # Ajouter à la nouvelle catégorie
                    Category.objects.filter(id=instance.category_id).update(
                        listing_count=models.F('listing_count') + 1
                    )
        except Listing.DoesNotExist:
            pass

@receiver(post_delete, sender=Listing)
def update_category_listing_count_on_delete(sender, instance, **kwargs):
    """Mettre à jour le compteur lors de la suppression"""
    if instance.status == 'active':
        Category.objects.filter(id=instance.category_id).update(
            listing_count=models.F('listing_count') - 1
        )

@receiver(post_save, sender=UserRating)
def update_user_rating_on_create(sender, instance, created, **kwargs):
    """Mettre à jour la note moyenne lors d'une nouvelle évaluation"""
    if created:
        instance.rated.profile.update_rating()

@receiver(post_delete, sender=UserRating)
def update_user_rating_on_delete(sender, instance, **kwargs):
    """Mettre à jour la note moyenne lors de la suppression d'une évaluation"""
    instance.rated.profile.update_rating()

@receiver(m2m_changed, sender=ListingTag)
def update_tag_usage_count(sender, instance, action, pk_set, **kwargs):
    """Mettre à jour le compteur d'usage des tags"""
    if action == "post_add":
        # Augmenter le compteur pour les tags ajoutés
        Tag.objects.filter(pk__in=pk_set).update(
            usage_count=models.F('usage_count') + 1
        )
    elif action == "post_remove":
        # Diminuer le compteur pour les tags supprimés
        Tag.objects.filter(pk__in=pk_set).update(
            usage_count=models.F('usage_count') - 1
        )
    elif action == "post_clear":
        # Diminuer le compteur pour tous les tags de l'annonce
        current_tags = instance.tags.all()
        Tag.objects.filter(pk__in=[tag.pk for tag in current_tags]).update(
            usage_count=models.F('usage_count') - 1
        )