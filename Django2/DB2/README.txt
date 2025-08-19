Base de données – Petites Annonces (PostgreSQL + Django)
=======================================================

Ce dépôt fournit la couche base de données COMPLETE pour un site de petites annonces moderne :
- Taxonomie hiérarchique de catégories (catégories / sous-catégories / sous-sous-catégories)
- Relations transversales entre catégories (ex. « Voitures » ↔ « Réparation automobile »)
- Système d'authentification complet (compatible Django)
- Annonces avec recherche full-text et géolocalisation
- Messagerie intégrée entre utilisateurs
- Système de notation et réputation
- Gestion des favoris et tags
- Modération et signalements
- Analytics et statistiques avancées

-------------------------------------------------
Structure des fichiers
-------------------------------------------------
db/
  - schema_optimized.sql      : Schéma complet (tables, types, fonctions, triggers, index)
  - seed_data.sql            : Données d'exemple complètes (utilisateurs + catégories + annonces)
  - usage_examples.sql       : Exemples de requêtes avancées (recherche, analytics, messagerie)

-------------------------------------------------
Prérequis
-------------------------------------------------
- PostgreSQL 13+ (14+ recommandé)
- psql disponible dans le terminal
- Extensions : unaccent, pg_trgm, postgis (optionnel pour géolocalisation avancée)
- Django 4.0+ pour intégration complète

Connexion (si besoin)
- export PGHOST=localhost
- export PGPORT=5432
- export PGUSER=postgres
- export PGPASSWORD=motdepasse
Puis ajoutez: -h $PGHOST -p $PGPORT -U $PGUSER à vos commandes psql si nécessaire.

-------------------------------------------------
DEMARRAGE RAPIDE (Exécuter dans l'ordre)
-------------------------------------------------
1) Créer la base si besoin
   createdb petites_annonces_django

2) Charger le schéma complet
   psql -d petites_annonces_django -f db/schema_optimized.sql

3) Charger les données d'exemple (utilisateurs + catégories + annonces)
   psql -d petites_annonces_django -f db/seed_data.sql

4) (Optionnel) Tester des requêtes avancées
   psql -d petites_annonces_django -f db/usage_examples.sql

Astuce : vous pouvez aussi ouvrir un shell interactif via: psql -d petites_annonces_django

-------------------------------------------------
Ce que crée le schéma
-------------------------------------------------

Tables principales

AUTHENTIFICATION & UTILISATEURS
- auth_user
  Table utilisateur Django standard (username, email, password, is_active, etc.)
  Compatible 100% avec Django User model.

- user_profile  
  Profil étendu (téléphone, bio, localisation, latitude/longitude, statut, ratings).
  Relation OneToOne avec auth_user.

CATEGORIES & HIERARCHIE
- category
  Arbre par adjacence (parent_id) + chemin matérialisé path_ids (tableau d'IDs des ancêtres + self).
  Champs clés : id, parent_id, name, slug (unique), kind (goods|services|real_estate|jobs|vehicles|other), 
  description, is_active, path_ids, depth, listing_count, created_at, updated_at.
  Index : parent_id, slug, kind, GIN sur path_ids.

- category_relation
  Graphe de liens inter-catégories avec relation_type (related|service_for|accessory_for|similar).
  Contrainte d'unicité (source_category_id, target_category_id, relation_type).

ANNONCES & CONTENU
- listing
  Modèle d'annonces complet : titre, description, prix (en centimes), devise, condition, statut, 
  géolocalisation (latitude/longitude), search_vector (recherche full-text), métadonnées SEO,
  statistiques (vues, favoris, contacts), dates importantes, created_at, updated_at.
  Index : user_id, category_id, status, localisation, prix, GIN sur search_vector.

- listing_image
  Images multiples par annonce avec ordre et image principale.
  Champs : listing_id, image (URL), alt_text, is_primary, sort_order.

- tag, listing_tag
  Système de tags many-to-many avec compteur d'usage.

INTERACTIONS SOCIALES
- user_favorite
  Favoris/wishlist des utilisateurs. Relation many-to-many user <-> listing.

- conversation
  Conversations entre acheteur et vendeur pour une annonce donnée.
  Champs : listing_id, buyer_id, seller_id, last_message_at, is_active.

- message
  Messages individuels avec statut de lecture.
  Champs : conversation_id, sender_id, content, status (sent|delivered|read), read_at, created_at.

- user_rating
  Système de notation entre utilisateurs (1-5 étoiles) avec commentaires.

RECHERCHES & PREFERENCES
- saved_search
  Recherches sauvegardées des utilisateurs avec paramètres JSON et alertes email.

MODERATION & SECURITE
- report
  Signalements d'annonces ou d'utilisateurs avec raison, description, statut de traitement.

Fonctions & triggers (extraits)

GESTION DES CATEGORIES (conservées du schéma original)
- Fonctions utilitaires : slugify(text), ensure_unique_slug(text, table_name, bigint), set_updated_at()
- Intégrité arbre : category_prevent_cycle() (empêche les cycles), category_rebuild_subtree(root) (recalcule path_ids, depth)
- Slug auto : category_set_slug(), listing_set_slug()
- Post-changement : category_after_change()

RECHERCHE & OPTIMISATION
- listing_update_search_vector() : génère automatiquement le vecteur de recherche full-text
- update_listing_count() : maintient le compteur d'annonces par catégorie
- update_tag_usage() : maintient le compteur d'usage des tags
- update_user_rating() : recalcule la note moyenne des utilisateurs

REQUETES OPTIMISEES
- search_listings(search_query, category_slug, min_price, max_price, lat, lng, radius_km, limit_count, offset_count)
  Recherche combinée : full-text + filtres + géolocalisation avec ranking et distance.
- category_descendants(slug text) : descendants (via GIN sur path_ids)
- category_ancestors(slug text) : breadcrumb  
- category_related(slug text, rel_type) : catégories liées
- category_stats(slug text) : statistiques d'une catégorie

VUES UTILES
- active_listings : vue des annonces actives avec détails utilisateur et catégorie

Triggers principaux :
- trg_category_set_slug, trg_listing_slug (génération automatique des slugs)
- trg_category_cycle (prévention des cycles)
- trg_category_after (recalcul automatique de l'arbre)
- trg_listing_search (mise à jour search_vector)
- trg_listing_count, trg_tag_usage, trg_user_rating_update (compteurs automatiques)
- trg_*_updated (timestamps updated_at automatiques)

-------------------------------------------------
Exemples d'utilisation
-------------------------------------------------

NAVIGATION DANS LES CATEGORIES
1) Récupérer tout l'arbre avec indentation
   SELECT REPEAT('  ', depth-1) || name as category_tree, slug, listing_count
   FROM category WHERE is_active = true ORDER BY path_ids;

2) Descendants d'une catégorie
   SELECT name, slug, depth FROM category_descendants('vehicules');

3) Breadcrumb (ancêtres) d'une catégorie
   SELECT * FROM category_ancestors('equipement-auto');

4) Services liés à « voitures »
   SELECT * FROM category_related('voitures', 'service_for');

RECHERCHE D'ANNONCES
5) Recherche simple par mot-clé
   SELECT * FROM search_listings('toyota');

6) Recherche avec filtres multiples
   SELECT * FROM search_listings(
     search_query := 'téléphone',
     category_slug := 'electronique', 
     min_price := 500000,
     max_price := 10000000,
     limit_count := 20
   );

7) Recherche géolocalisée (rayon de 25km autour de Conakry)
   SELECT id, title, distance_km FROM search_listings(
     lat := 9.6412, lng := -13.5784, radius_km := 25
   ) WHERE distance_km IS NOT NULL ORDER BY distance_km;

GESTION DES ANNONCES
8) Créer une annonce complète
   INSERT INTO listing (user_id, category_id, title, description, price_cents, location, status)
   VALUES (
     (SELECT id FROM auth_user WHERE username='john_doe'),
     (SELECT id FROM category WHERE slug='voitures'), 
     'Toyota Corolla 2019',
     'Véhicule en excellent état, entretien suivi',
     12500000,  -- 125,000 GNF
     'Conakry, Guinée',
     'active'
   );

9) Annonces d'une catégorie ET de tout son sous-arbre
   WITH ids AS (SELECT id FROM category_descendants('vehicules'))
   SELECT l.title, l.price_cents/100 as price_gnf, u.username as seller
   FROM listing l
   JOIN ids ON l.category_id = ids.id
   JOIN auth_user u ON l.user_id = u.id
   WHERE l.status = 'active'
   ORDER BY l.created_at DESC;

GESTION DES UTILISATEURS
10) Profil utilisateur avec statistiques
    SELECT u.username, up.rating_average, up.rating_count,
           COUNT(l.id) as total_listings,
           COUNT(l.id) FILTER (WHERE l.status = 'active') as active_listings
    FROM auth_user u
    JOIN user_profile up ON u.id = up.user_id
    LEFT JOIN listing l ON u.id = l.user_id
    WHERE u.username = 'john_doe'
    GROUP BY u.id, up.id;

MESSAGERIE
11) Conversations d'un utilisateur
    SELECT c.id, l.title as listing_title, 
           CASE WHEN c.buyer_id = 1 THEN seller.username ELSE buyer.username END as other_user,
           COUNT(m.id) as message_count
    FROM conversation c
    JOIN listing l ON c.listing_id = l.id
    JOIN auth_user buyer ON c.buyer_id = buyer.id  
    JOIN auth_user seller ON c.seller_id = seller.id
    LEFT JOIN message m ON c.id = m.conversation_id
    WHERE c.buyer_id = 1 OR c.seller_id = 1
    GROUP BY c.id, l.title, buyer.username, seller.username;

ANALYTICS & STATISTIQUES  
12) Statistiques globales
    SELECT 
      (SELECT COUNT(*) FROM auth_user WHERE is_active = true) as users,
      (SELECT COUNT(*) FROM listing WHERE status = 'active') as listings,
      (SELECT COUNT(*) FROM conversation) as conversations;

13) Top catégories par nombre d'annonces
    SELECT name, listing_count FROM category 
    WHERE depth > 1 AND listing_count > 0 
    ORDER BY listing_count DESC LIMIT 10;

14) Évolution des annonces (7 derniers jours)
    SELECT DATE(created_at) as day, COUNT(*) as new_listings
    FROM listing 
    WHERE created_at >= now() - interval '7 days'
    GROUP BY DATE(created_at) ORDER BY day;

MODERATION
15) Signalements en attente
    SELECT r.reason, l.title as listing, reporter.username as reporter
    FROM report r
    LEFT JOIN listing l ON r.listing_id = l.id
    JOIN auth_user reporter ON r.reporter_id = reporter.id
    WHERE r.status = 'pending';

-------------------------------------------------
Données d'exemple incluses
-------------------------------------------------

UTILISATEURS
- 6 utilisateurs de test avec profils complets (admin, john_doe, marie_dubois, ibrahim_diallo, fatou_barry, alpha_conde)
- Localisations réalistes en Guinée (Conakry, Kankan, Labé, Nzérékoré)
- Vérifications email/téléphone, notes et statuts variés

CATEGORIES (hiérarchie complète)
- 14 catégories racines : Emploi, Véhicules, Immobilier, Électronique, Mode, Services, etc.
- 50+ sous-catégories détaillées
- Catégories spéciales Guinée : Produits locaux (huile de palme, bazin, artisanat)
- Relations transversales (voitures ↔ réparation auto, téléphones ↔ réparations électroniques)

ANNONCES
- 5 annonces d'exemple : Toyota Corolla, iPhone 13 Pro, huile de palme, services auto, sculpture ébène
- Images, tags, géolocalisation, prix en GNF
- Conversations et messages entre utilisateurs
- Favoris et interactions sociales

TAGS
- 20 tags populaires : neuf, occasion, urgent, négociable, livraison, qualité, etc.

-------------------------------------------------
Intégration Django
-------------------------------------------------

Le schéma est 100% compatible Django ORM. Table auth_user standard Django.

Exemple models.py :
```python
from django.contrib.auth.models import User
from django.db import models

class UserProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    phone = models.CharField(max_length=20, blank=True)
    location = models.CharField(max_length=255, blank=True)
    # ... autres champs générés automatiquement par Django

class Category(models.Model):
    parent = models.ForeignKey('self', on_delete=models.CASCADE, null=True)
    name = models.CharField(max_length=255)
    slug = models.SlugField(unique=True)
    # ... triggers PostgreSQL gèrent les slugs et path_ids automatiquement
```

Recherche Django ORM :
```python
# Recherche full-text
listings = Listing.objects.filter(search_vector__search='toyota', status='active')

# Catégories avec compteurs  
categories = Category.objects.annotate(
    listing_count=Count('listing', filter=Q(listing__status='active'))
)

# Favoris utilisateur
favorites = UserFavorite.objects.select_related('listing__category').filter(user=request.user)
```

-------------------------------------------------
Personnalisation
-------------------------------------------------
- Types de relations : étendez l'ENUM relation_type si besoin (ex. compatible_with)
  ALTER TYPE relation_type ADD VALUE 'compatible_with';

- Types de catégories : ajoutez de nouveaux types
  ALTER TYPE category_kind ADD VALUE 'education';

- Multilingue : ajoutez une table category_translation(category_id, language_code, name, description)

- Champs personnalisés : utilisez JSONB pour flexibilité
  ALTER TABLE listing ADD COLUMN custom_fields JSONB;
  CREATE INDEX ON listing USING GIN (custom_fields);

- Synonymes/recherche : table category_synonym(category_id, term) + index trigram (pg_trgm)

- Devises multiples : table currency(code, name, symbol) + foreign key dans listing

- Sécurité : créez des rôles en lecture/écriture et restreignez les droits sur les schémas/tables

-------------------------------------------------
Performance & maintenance
-------------------------------------------------
- Index stratégiques déjà posés : GIN sur search_vector, path_ids, géolocalisation, foreign keys
- Compteurs automatiques : listing_count, usage_count, rating_average maintenus par triggers
- Pensez à VACUUM (AUTO) / ANALYZE réguliers
- Sur gros volumes : partitioning par date sur listing, archivage des anciennes données
- Monitoring : pg_stat_user_indexes pour vérifier l'utilisation des index

Sauvegardes recommandées :
- pg_dump petites_annonces_django > backup_complet.sql
- pg_dump --schema-only petites_annonces_django > schema_only.sql  
- pg_dump --data-only petites_annonces_django > data_only.sql

Restauration : psql petites_annonces_django < backup_complet.sql

Nettoyage automatique des données obsolètes :
- Annonces expirées depuis 30+ jours
- Messages anciens (optionnel)
- Recherches sauvegardées non utilisées

-------------------------------------------------
Fonctionnalités avancées
-------------------------------------------------

RECHERCHE INTELLIGENTE
- Full-text search avec ranking et highlighting
- Recherche géolocalisée avec calcul de distance 
- Filtres combinés (prix, catégorie, localisation, condition)
- Recherche dans les sous-catégories automatiquement

GEOLOCALISATION
- Support PostGIS pour fonctionnalités avancées (optionnel)
- Recherche par rayon configurable
- Coordonnées GPS stockées en decimal(10,8) et decimal(11,8)

MESSAGERIE & SOCIAL
- Conversations thread par annonce
- Statuts de lecture des messages (sent, delivered, read)
- Système de favoris/wishlist
- Notifications (structure prête)

REPUTATION & CONFIANCE  
- Notes utilisateurs 1-5 étoiles avec moyennes automatiques
- Compteur de transactions réussies
- Vérifications email/téléphone
- Système de signalement et modération

ANALYTICS & BUSINESS
- Statistiques détaillées par catégorie
- Métriques d'engagement (vues, favoris, contacts)
- Évolution temporelle des annonces
- Top utilisateurs et catégories

SEO & MARKETING
- Slugs automatiques pour URLs friendly
- Métadonnées SEO (meta_title, meta_description)
- Tags pour améliorer la découvrabilité
- Recherches sauvegardées avec alertes email

-------------------------------------------------
Spécificités Guinée
-------------------------------------------------

CATEGORIES LOCALES
- Produits alimentaires : huile de palme, banane, manioc, épices traditionnelles
- Textile traditionnel : bazin riche, habits traditionnels, pagnes (lepi, forêt)
- Artisanat : sculptures ébène, bijoux artisanaux, objets décoratifs
- Géolocalisation : grandes villes (Conakry, Kankan, Labé, Nzérékoré)

DEVISE & PRIX
- Prix stockés en centimes GNF (Franc Guinéen) pour éviter problèmes virgule flottante
- Support multi-devises prêt (champ currency extensible)

DONNEES REALISTES
- Utilisateurs avec vrais noms guinéens et coordonnées GPS
- Annonces d'exemple avec prix du marché local
- Catégories adaptées au contexte économique guinéen

-------------------------------------------------
Dépannage
-------------------------------------------------
- CREATE EXTENSION unaccent/pg_trgm refusé : demandez à votre DBA d'activer les extensions
- Conflit de slug : ensure_unique_slug suffixe automatiquement -2, -3, …
- Erreur de cycle lors d'un UPDATE parent_id : vous tentez de déplacer un nœud sous son propre sous-arbre
- Search vector vide : le trigger listing_update_search_vector se déclenche automatiquement
- Performance lente : vérifiez pg_stat_user_indexes et ajustez les requêtes
- Géolocalisation imprécise : vérifiez la précision des coordonnées (decimal places)

Requêtes de diagnostic :
- SELECT * FROM pg_stat_user_indexes WHERE schemaname = 'public' ORDER BY idx_tup_read DESC;
- SELECT tablename, attname, avg_width FROM pg_stats WHERE schemaname = 'public';

-------------------------------------------------
Roadmap & améliorations futures
-------------------------------------------------
- Support notifications push (structure prête)
- Intégration paiement en ligne (champs prêts)  
- API REST avec pagination (compatible Django REST Framework)
- Support multi-devises avancé
- Système d'enchères (extension possible)
- Import/export données (CSV, JSON)
- Backup incrémental automatisé

-------------------------------------------------
Licence
-------------------------------------------------
Ce schéma et les scripts fournis sont utilisables librement dans vos projets commerciaux et open-source. 
Mention appréciée mais non obligatoire.

Développé pour la communauté des développeurs guinéens et africains.

-------------------------------------------------
Raccourci commandes (rappel)
-------------------------------------------------
# 1) Créer la base si besoin
createdb petites_annonces_django

# 2) Charger le schéma complet
psql -d petites_annonces_django -f db/schema_optimized.sql

# 3) Charger les données d'exemple
psql -d petites_annonces_django -f db/seed_data.sql

# 4) (Optionnel) Tester des requêtes avancées  
psql -d petites_annonces_django -f db/usage_examples.sql

# 5) Shell interactif
psql -d petites_annonces_django