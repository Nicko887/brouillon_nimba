-- =====================================================================
-- Exemples de requêtes pour exploiter le schéma
-- =====================================================================

-- 1) Récupérer tout l'arbre (racines -> feuilles)
SELECT id, name, slug, depth, parent_id
FROM category
ORDER BY depth, name;

-- 2) Descendants d'une catégorie (par slug)
--    Utilise la fonction fournie (GIN sur path_ids)
SELECT id, name, slug, depth
FROM category_descendants('vehicules');

-- 3) Ancêtres (breadcrumb) d'une catégorie
SELECT * FROM category_ancestors('equipement-auto');

-- 4) Catégories liées (services associés à "voitures")
SELECT * FROM category_related('voitures', 'service_for');

-- 5) Tous les services associés à une catégorie donnée (quel que soit le type)
SELECT * FROM category_related('voitures', NULL);

-- 6) Déplacer une catégorie (changement de parent)
--    (les path_ids + depth du sous-arbre seront recalculés automatiquement)
-- UPDATE category SET parent_id = (SELECT id FROM category WHERE slug='services')
-- WHERE slug = 'reparation-automobile';

-- 7) Insérer une annonce
-- INSERT INTO listing (title, category_id, price_cents, currency)
-- VALUES ('Toyota Corolla 2015', (SELECT id FROM category WHERE slug='voitures'), 75000000, 'GNF');

-- 8) Lister les annonces d’une catégorie (et de tout son sous-arbre)
--    -> On récupère d'abord les IDs descendants puis on filtre listing
WITH ids AS (
  SELECT id FROM category_descendants('vehicules')
)
SELECT l.*
FROM listing l
JOIN ids ON l.category_id = ids.id
ORDER BY l.created_at DESC;

-- 9) Ajouter un tag et l’associer à une annonce
-- INSERT INTO tag(name) VALUES ('occasion') ON CONFLICT DO NOTHING;
-- INSERT INTO listing_tag(listing_id, tag_id)
-- SELECT l.id, t.id
-- FROM listing l, tag t
-- WHERE l.title = 'Toyota Corolla 2015' AND t.name = 'occasion';
