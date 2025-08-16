Base de données – Petites Annonces (PostgreSQL)
=================================================

Ce dépôt fournit UNIQUEMENT la couche base de données pour un site de petites annonces :
- Taxonomie hiérarchique de catégories (catégories / sous-catégories / sous-sous-catégories)
- Relations transversales entre catégories (ex. « Voitures » ↔ « Réparation automobile »)
- Annonces et tags (facultatifs mais prêts à l’emploi)
- Fonctions (descendants, ancêtres/breadcrumb, catégories liées) et triggers (slug unique, prévention des cycles, recalcul d’arbre)

-------------------------------------------------
Structure des fichiers
-------------------------------------------------
db/
  - schema_postgres.sql       : Schéma (tables, types, fonctions, triggers, index)
  - seed_taxonomy.sql         : Données d’exemple (catégories + relations)
  - queries_examples.sql      : Exemples de requêtes (lecture, navigation, relations)

-------------------------------------------------
Prérequis
-------------------------------------------------
- PostgreSQL 13+ (14+ recommandé)
- psql disponible dans le terminal
- (Optionnel) Extension unaccent – activée automatiquement par le script si autorisée

Connexion (si besoin)
- export PGHOST=localhost
- export PGPORT=5432
- export PGUSER=postgres
- export PGPASSWORD=motdepasse
Puis ajoutez: -h $PGHOST -p $PGPORT -U $PGUSER à vos commandes psql si nécessaire.

-------------------------------------------------
DEMARRAGE RAPIDE (Exécuter dans l’ordre)
-------------------------------------------------
1) Créer la base si besoin
   createdb petites_annonces

2) Charger le schéma
   psql -d petites_annonces -f db/schema_postgres.sql

3) Charger les catégories + relations
   psql -d petites_annonces -f db/seed_taxonomy.sql

4) (Optionnel) Tester des requêtes
   psql -d petites_annonces -f db/queries_examples.sql

Astuce : vous pouvez aussi ouvrir un shell interactif via: psql -d petites_annonces

-------------------------------------------------
Ce que crée le schéma
-------------------------------------------------

Tables principales
- category
  Arbre par adjacence (parent_id) + chemin matérialisé path_ids (tableau d’IDs des ancêtres + self).
  Champs clés : id, parent_id, name, slug (unique), kind (goods|services|other), is_active, path_ids, depth, created_at, updated_at.
  Index : parent_id, slug, GIN sur path_ids.

- category_relation
  Graphe de liens inter-catégories avec relation_type (related|service_for|accessory_for).
  Contrainte d’unicité (source_category_id, target_category_id, relation_type).

- listing, tag, listing_tag
  Modèle d’annonces (catégorie principale, prix, devise, description) + système de tags many-to-many.

Fonctions & triggers (extraits)
- Fonctions utilitaires : slugify(text), ensure_unique_slug(text, bigint), set_updated_at()
- Intégrité arbre : category_prevent_cycle() (empêche les cycles), category_rebuild_subtree(root) (recalcule path_ids, depth)
- Slug auto : category_set_slug()
- Post-changement : category_after_change()
- Requêtes prêtes à l’emploi :
  * category_descendants(slug text)            -> descendants (via GIN sur path_ids)
  * category_ancestors(slug text)              -> breadcrumb
  * category_related(slug text, rel_type NULL) -> catégories liées

Triggers principaux :
- trg_category_set_slug (avant insert/update)
- trg_category_cycle (avant update de parent_id)
- trg_category_after (après insert/update de parent_id)
- trg_category_set_update, trg_listing_set_update (timestamps)

-------------------------------------------------
Exemples d’utilisation
-------------------------------------------------
1) Récupérer tout l’arbre (racines -> feuilles)
   SELECT id, name, slug, depth, parent_id
   FROM category
   ORDER BY depth, name;

2) Descendants d’une catégorie
   SELECT id, name, slug, depth
   FROM category_descendants('vehicules');

3) Breadcrumb (ancêtres) d’une catégorie
   SELECT * FROM category_ancestors('equipement-auto');

4) Services liés à « voitures »
   SELECT * FROM category_related('voitures', 'service_for');

5) Déplacer une catégorie (recalcule auto du sous-arbre)
   UPDATE category
   SET parent_id = (SELECT id FROM category WHERE slug='services')
   WHERE slug = 'reparation-automobile';

6) Lister les annonces d’une catégorie ET de tout son sous-arbre
   WITH ids AS (SELECT id FROM category_descendants('vehicules'))
   SELECT l.*
   FROM listing l
   JOIN ids ON l.category_id = ids.id
   ORDER BY l.created_at DESC;

-------------------------------------------------
Personnalisation
-------------------------------------------------
- Types de relations : étendez l’ENUM relation_type si besoin (ex. compatible_with)
- Multilingue : ajoutez une table category_locale(category_id, locale, name)
- Synonymes/recherche : table category_synonym(category_id, term) + index trigram (pg_trgm)
- Sécurité : créez des rôles en lecture/écriture et restreignez les droits sur les schémas/tables

-------------------------------------------------
Performance & maintenance
-------------------------------------------------
- Index déjà posés (parent_id, slug, GIN sur path_ids)
- Pensez à VACUUM (AUTO) / ANALYZE réguliers
- Sur gros volumes : batcher les insertions et exécuter ANALYZE category après gros chargements
- Sauvegardes : pg_dump petites_annonces > backup.sql
  Restauration : psql petites_annonces < backup.sql

-------------------------------------------------
Dépannage
-------------------------------------------------
- CREATE EXTENSION unaccent refusé : demandez à votre DBA d’activer l’extension ou retirez son usage (la fonction slugify en dépend).
- Conflit de slug : ensure_unique_slug suffixe automatiquement -2, -3, …
- Erreur de cycle lors d’un UPDATE parent_id : vous tentez de déplacer un nœud sous son propre sous-arbre.

-------------------------------------------------
Licence
-------------------------------------------------
Ce schéma et les scripts fournis sont utilisables librement dans vos projets. Mention appréciée mais non obligatoire.

-------------------------------------------------
Raccourci commandes (rappel)
-------------------------------------------------
# 1) Créer la base si besoin
createdb petites_annonces

# 2) Charger le schéma
psql -d petites_annonces -f db/schema_postgres.sql

# 3) Charger les catégories + relations
psql -d petites_annonces -f db/seed_taxonomy.sql

# 4) (Optionnel) Tester des requêtes
psql -d petites_annonces -f db/queries_examples.sql
