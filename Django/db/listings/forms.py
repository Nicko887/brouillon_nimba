# listings/forms.py
from django import forms
from django.contrib.auth.forms import UserCreationForm
from django.contrib.auth.models import User
from django.core.exceptions import ValidationError
from .models import Listing, Category, UserProfile, Message, UserRating, Tag
import re

class CustomUserCreationForm(UserCreationForm):
    """Formulaire d'inscription étendu"""
    email = forms.EmailField(required=True)
    first_name = forms.CharField(max_length=30, required=True)
    last_name = forms.CharField(max_length=30, required=True)
    phone = forms.CharField(max_length=20, required=False)
    location = forms.CharField(max_length=255, required=False)
    
    class Meta:
        model = User
        fields = ("username", "first_name", "last_name", "email", "password1", "password2")
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        for field_name, field in self.fields.items():
            field.widget.attrs['class'] = 'form-control'
        
        self.fields['username'].help_text = "Uniquement des lettres, chiffres et @/./+/-/_"
        self.fields['password1'].help_text = "Au moins 8 caractères"
    
    def save(self, commit=True):
        user = super().save(commit=False)
        user.email = self.cleaned_data["email"]
        user.first_name = self.cleaned_data["first_name"]
        user.last_name = self.cleaned_data["last_name"]
        
        if commit:
            user.save()
            # Créer ou mettre à jour le profil
            profile, created = UserProfile.objects.get_or_create(user=user)
            profile.phone = self.cleaned_data.get("phone", "")
            profile.location = self.cleaned_data.get("location", "")
            profile.save()
        
        return user

class UserProfileForm(forms.ModelForm):
    """Formulaire de modification du profil"""
    first_name = forms.CharField(max_length=30, required=False)
    last_name = forms.CharField(max_length=30, required=False)
    email = forms.EmailField(required=True)
    
    class Meta:
        model = UserProfile
        fields = ['phone', 'bio', 'location', 'avatar']
        widgets = {
            'bio': forms.Textarea(attrs={'rows': 4, 'class': 'form-control'}),
            'phone': forms.TextInput(attrs={'class': 'form-control'}),
            'location': forms.TextInput(attrs={'class': 'form-control'}),
            'avatar': forms.FileInput(attrs={'class': 'form-control'}),
        }
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if self.instance and self.instance.user:
            self.fields['first_name'].initial = self.instance.user.first_name
            self.fields['last_name'].initial = self.instance.user.last_name
            self.fields['email'].initial = self.instance.user.email
    
    def save(self, commit=True):
        profile = super().save(commit=False)
        
        # Mettre à jour les champs User
        if commit:
            user = profile.user
            user.first_name = self.cleaned_data['first_name']
            user.last_name = self.cleaned_data['last_name']
            user.email = self.cleaned_data['email']
            user.save()
            profile.save()
        
        return profile

class ListingForm(forms.ModelForm):
    """Formulaire de création/modification d'annonce"""
    tags_input = forms.CharField(
        max_length=500, 
        required=False,
        help_text="Séparez les tags par des virgules (ex: neuf, urgent, livraison)",
        widget=forms.TextInput(attrs={
            'class': 'form-control',
            'placeholder': 'Tags séparés par des virgules'
        })
    )
    
    price_euros = forms.DecimalField(
        max_digits=10, 
        decimal_places=2, 
        required=False,
        help_text="Prix en euros (sera converti automatiquement)",
        widget=forms.NumberInput(attrs={
            'class': 'form-control',
            'step': '0.01',
            'placeholder': '0.00'
        })
    )
    
    class Meta:
        model = Listing
        fields = [
            'title', 'category', 'description', 'price_euros', 'currency',
            'is_negotiable', 'condition', 'location', 'latitude', 'longitude',
            'meta_title', 'meta_description', 'tags_input'
        ]
        widgets = {
            'title': forms.TextInput(attrs={'class': 'form-control', 'maxlength': 255}),
            'category': forms.Select(attrs={'class': 'form-control'}),
            'description': forms.Textarea(attrs={'class': 'form-control', 'rows': 6}),
            'currency': forms.Select(attrs={'class': 'form-control'}),
            'condition': forms.Select(attrs={'class': 'form-control'}),
            'location': forms.TextInput(attrs={'class': 'form-control'}),
            'latitude': forms.HiddenInput(),
            'longitude': forms.HiddenInput(),
            'meta_title': forms.TextInput(attrs={'class': 'form-control'}),
            'meta_description': forms.Textarea(attrs={'class': 'form-control', 'rows': 3}),
            'is_negotiable': forms.CheckboxInput(attrs={'class': 'form-check-input'}),
        }
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        
        # Organiser les catégories par hiérarchie
        categories = Category.objects.filter(is_active=True).select_related('parent')
        choices = [('', '---------')]
        
        # Grouper par catégorie parent
        for category in categories.filter(parent__isnull=True):
            choices.append((category.id, category.name))
            for subcategory in categories.filter(parent=category):
                choices.append((subcategory.id, f"  └─ {subcategory.name}"))
                for subsubcategory in categories.filter(parent=subcategory):
                    choices.append((subsubcategory.id, f"     └─ {subsubcategory.name}"))
        
        self.fields['category'].choices = choices
        
        # Pré-remplir les tags si on modifie une annonce existante
        if self.instance.pk:
            current_tags = self.instance.tags.all()
            if current_tags:
                self.fields['tags_input'].initial = ', '.join([tag.name for tag in current_tags])
            
            # Afficher le prix en euros
            if self.instance.price_cents:
                self.fields['price_euros'].initial = self.instance.price_cents / 100
    
    def clean_title(self):
        title = self.cleaned_data['title']
        if len(title) < 5:
            raise ValidationError("Le titre doit contenir au moins 5 caractères.")
        return title
    
    def clean_description(self):
        description = self.cleaned_data['description']
        if len(description) < 20:
            raise ValidationError("La description doit contenir au moins 20 caractères.")
        return description
    
    def clean_tags_input(self):
        tags_input = self.cleaned_data.get('tags_input', '')
        if tags_input:
            tags = [tag.strip() for tag in tags_input.split(',')]
            tags = [tag for tag in tags if tag]  # Supprimer les tags vides
            
            if len(tags) > 10:
                raise ValidationError("Maximum 10 tags autorisés.")
            
            for tag in tags:
                if len(tag) > 50:
                    raise ValidationError(f"Le tag '{tag}' est trop long (max 50 caractères).")
                if not re.match(r'^[a-zA-Z0-9àâäéèêëïîôöùûüÿç\s\-]+$', tag):
                    raise ValidationError(f"Le tag '{tag}' contient des caractères non autorisés.")
        
        return tags_input
    
    def save(self, commit=True):
        listing = super().save(commit=False)
        
        # Convertir le prix en centimes
        price_euros = self.cleaned_data.get('price_euros')
        if price_euros:
            listing.price_cents = int(price_euros * 100)
        else:
            listing.price_cents = None
        
        if commit:
            listing.save()
            
            # Gérer les tags
            tags_input = self.cleaned_data.get('tags_input', '')
            if tags_input:
                tag_names = [tag.strip() for tag in tags_input.split(',')]
                tag_names = [tag for tag in tag_names if tag]
                
                # Supprimer les anciens tags
                listing.tags.clear()
                
                # Ajouter les nouveaux tags
                for tag_name in tag_names:
                    tag, created = Tag.objects.get_or_create(name=tag_name)
                    listing.tags.add(tag)
        
        return listing

class ListingSearchForm(forms.Form):
    """Formulaire de recherche d'annonces"""
    SORT_CHOICES = [
        ('-created_at', 'Plus récentes'),
        ('price_cents', 'Prix croissant'),
        ('-price_cents', 'Prix décroissant'),
        ('-view_count', 'Plus vues'),
        ('title', 'Alphabétique'),
    ]
    
    query = forms.CharField(
        max_length=200, 
        required=False,
        widget=forms.TextInput(attrs={
            'class': 'form-control',
            'placeholder': 'Rechercher...'
        })
    )
    
    category = forms.ModelChoiceField(
        queryset=Category.objects.filter(is_active=True),
        required=False,
        empty_label="Toutes les catégories",
        widget=forms.Select(attrs={'class': 'form-control'})
    )
    
    min_price = forms.DecimalField(
        max_digits=10, 
        decimal_places=2, 
        required=False,
        widget=forms.NumberInput(attrs={
            'class': 'form-control',
            'placeholder': 'Prix min.'
        })
    )
    
    max_price = forms.DecimalField(
        max_digits=10, 
        decimal_places=2, 
        required=False,
        widget=forms.NumberInput(attrs={
            'class': 'form-control',
            'placeholder': 'Prix max.'
        })
    )
    
    condition = forms.MultipleChoiceField(
        choices=Listing.CONDITION_CHOICES,
        required=False,
        widget=forms.CheckboxSelectMultiple(attrs={'class': 'form-check-input'})
    )
    
    location = forms.CharField(
        max_length=255, 
        required=False,
        widget=forms.TextInput(attrs={
            'class': 'form-control',
            'placeholder': 'Ville ou région'
        })
    )
    
    radius = forms.IntegerField(
        min_value=1,
        max_value=500,
        initial=50,
        required=False,
        widget=forms.NumberInput(attrs={
            'class': 'form-control',
            'placeholder': 'Rayon (km)'
        })
    )
    
    sort_by = forms.ChoiceField(
        choices=SORT_CHOICES,
        initial='-created_at',
        required=False,
        widget=forms.Select(attrs={'class': 'form-control'})
    )

class MessageForm(forms.ModelForm):
    """Formulaire d'envoi de message"""
    class Meta:
        model = Message
        fields = ['content']
        widgets = {
            'content': forms.Textarea(attrs={
                'class': 'form-control',
                'rows': 4,
                'placeholder': 'Votre message...'
            })
        }
    
    def clean_content(self):
        content = self.cleaned_data['content']
        if len(content) < 5:
            raise ValidationError("Le message doit contenir au moins 5 caractères.")
        return content

class UserRatingForm(forms.ModelForm):
    """Formulaire d'évaluation d'un utilisateur"""
    class Meta:
        model = UserRating
        fields = ['rating', 'comment']
        widgets = {
            'rating': forms.RadioSelect(choices=[(i, f"{i} étoile{'s' if i > 1 else ''}") for i in range(1, 6)]),
            'comment': forms.Textarea(attrs={
                'class': 'form-control',
                'rows': 4,
                'placeholder': 'Votre commentaire (optionnel)...'
            })
        }
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields['rating'].widget.attrs['class'] = 'form-check-input'

class ContactSellerForm(forms.Form):
    """Formulaire de contact rapide avec le vendeur"""
    message = forms.CharField(
        widget=forms.Textarea(attrs={
            'class': 'form-control',
            'rows': 4,
            'placeholder': 'Votre message...'
        }),
        max_length=1000
    )
    
    phone = forms.CharField(
        max_length=20,
        required=False,
        widget=forms.TextInput(attrs={
            'class': 'form-control',
            'placeholder': 'Votre téléphone (optionnel)'
        })
    )
    
    def clean_message(self):
        message = self.cleaned_data['message']
        if len(message) < 10:
            raise ValidationError("Le message doit contenir au moins 10 caractères.")
        return message