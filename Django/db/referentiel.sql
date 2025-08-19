-- =====================================================================
-- Donnees de reference COMPLETES - Version finale corrigee
-- A executer APRES schema.sql
-- =====================================================================

-- Configuration encodage UTF-8
SET client_encoding TO 'UTF8';

-- =========================
-- Categories racines (niveau 1)
-- =========================

INSERT INTO category (name, slug, kind, parent_id, sort_order) VALUES
  ('Emploi', 'emploi', 'jobs', NULL, 1),
  ('Vehicules', 'vehicules', 'vehicles', NULL, 2),
  ('Immobilier', 'immobilier', 'real_estate', NULL, 3),
  ('Locations de vacances', 'locations-vacances', 'real_estate', NULL, 4),
  ('Electronique', 'electronique', 'goods', NULL, 5),
  ('Maison & Jardin', 'maison-jardin', 'goods', NULL, 6),
  ('Famille', 'famille', 'other', NULL, 7),
  ('Mode', 'mode', 'goods', NULL, 8),
  ('Loisirs', 'loisirs', 'other', NULL, 9),
  ('Animaux', 'animaux', 'other', NULL, 10),
  ('Materiel professionnel', 'materiel-professionnel', 'goods', NULL, 11),
  ('Services', 'services', 'services', NULL, 12),
  ('Produits locaux', 'produits-locaux', 'goods', NULL, 13),
  ('Divers', 'divers', 'other', NULL, 14);

-- =========================
-- Vehicules (niveau 2)
-- =========================

INSERT INTO category (name, slug, parent_id, depth, sort_order, kind)
SELECT 
  v.name,
  v.slug,
  (SELECT id FROM category WHERE name='Vehicules'),
  2,
  ROW_NUMBER() OVER (),
  'vehicles'
FROM (VALUES
  ('Voitures', 'voitures'),
  ('Motos', 'motos'),
  ('Caravaning', 'caravaning'),
  ('Utilitaires', 'utilitaires'),
  ('Nautisme', 'nautisme'),
  ('Equipement auto', 'equipement-auto'),
  ('Equipement moto', 'equipement-moto'),
  ('Equipement caravaning', 'equipement-caravaning'),
  ('Equipement nautisme', 'equipement-nautisme')
) AS v(name, slug);

-- =========================
-- Immobilier (niveau 2)
-- =========================

INSERT INTO category (name, slug, parent_id, depth, sort_order, kind)
SELECT 
  v.name,
  v.slug,
  (SELECT id FROM category WHERE name='Immobilier'),
  2,
  ROW_NUMBER() OVER (),
  'real_estate'
FROM (VALUES
  ('Ventes immobilieres', 'ventes-immobilieres'),
  ('Locations', 'locations'),
  ('Colocations', 'colocations'),
  ('Bureaux & Commerces', 'bureaux-commerces')
) AS v(name, slug);

-- =========================
-- Electronique (niveau 2)
-- =========================

INSERT INTO category (name, slug, parent_id, depth, sort_order, kind)
SELECT 
  v.name,
  v.slug,
  (SELECT id FROM category WHERE name='Electronique'),
  2,
  ROW_NUMBER() OVER (),
  'goods'
FROM (VALUES
  ('Ordinateurs', 'ordinateurs'),
  ('Accessoires informatique', 'accessoires-informatique'),
  ('Tablettes & Liseuses', 'tablettes-liseuses'),
  ('Photo, audio & video', 'photo-audio-video'),
  ('Telephones & Objets connectes', 'telephones-objets-connectes'),
  ('Accessoires telephone & Objets connectes', 'accessoires-telephone-objets-connectes'),
  ('Consoles', 'consoles'),
  ('Jeux video', 'jeux-video')
) AS v(name, slug);

-- =========================
-- Maison & Jardin (niveau 2)
-- =========================

INSERT INTO category (name, slug, parent_id, depth, sort_order, kind)
SELECT 
  v.name,
  v.slug,
  (SELECT id FROM category WHERE name='Maison & Jardin'),
  2,
  ROW_NUMBER() OVER (),
  'goods'
FROM (VALUES
  ('Ameublement', 'ameublement'),
  ('Papeterie & Fournitures scolaires', 'papeterie-fournitures-scolaires'),
  ('Electromenager', 'electromenager'),
  ('Arts de la table', 'arts-de-la-table'),
  ('Decoration', 'decoration'),
  ('Linge de maison', 'linge-de-maison'),
  ('Bricolage', 'bricolage'),
  ('Jardin & Plantes', 'jardin-plantes')
) AS v(name, slug);

-- =========================
-- Mode (niveau 2)
-- =========================

INSERT INTO category (name, slug, parent_id, depth, sort_order, kind)
SELECT 
  v.name,
  v.slug,
  (SELECT id FROM category WHERE name='Mode'),
  2,
  ROW_NUMBER() OVER (),
  'goods'
FROM (VALUES
  ('Vetements', 'vetements'),
  ('Chaussures', 'chaussures'),
  ('Accessoires & Bagagerie', 'accessoires-bagagerie'),
  ('Montres & Bijoux', 'montres-bijoux')
) AS v(name, slug);

-- =========================
-- Emploi (niveau 2)
-- =========================

INSERT INTO category (name, slug, parent_id, depth, sort_order, kind)
SELECT 
  v.name,
  v.slug,
  (SELECT id FROM category WHERE name='Emploi'),
  2,
  ROW_NUMBER() OVER (),
  'jobs'
FROM (VALUES
  ('CDI', 'cdi'),
  ('CDD', 'cdd'),
  ('Interim', 'interim'),
  ('Stage', 'stage'),
  ('Apprentissage', 'apprentissage'),
  ('Freelance', 'freelance'),
  ('Temps partiel', 'temps-partiel')
) AS v(name, slug);

-- =========================
-- Materiel professionnel (niveau 2)
-- =========================

INSERT INTO category (name, slug, parent_id, depth, sort_order, kind)
SELECT 
  v.name,
  v.slug,
  (SELECT id FROM category WHERE name='Materiel professionnel'),
  2,
  ROW_NUMBER() OVER (),
  'goods'
FROM (VALUES
  ('Tracteurs', 'tracteurs'),
  ('Materiel agricole', 'materiel-agricole'),
  ('BTP - Chantier gros-oeuvre', 'btp-chantier-gros-oeuvre'),
  ('Poids lourds', 'poids-lourds'),
  ('Manutention - Levage', 'manutention-levage'),
  ('Equipements industriels', 'equipements-industriels'),
  ('Equipements pour restaurants & hotels', 'equipements-restaurants-hotels'),
  ('Equipements & Fournitures de bureau', 'equipements-fournitures-bureau'),
  ('Equipements pour commerces & marches', 'equipements-commerces-marches'),
  ('Materiel medical', 'materiel-medical')
) AS v(name, slug);

-- =========================
-- Services (niveau 2) - CORRIGE avec kind='services'
-- =========================

INSERT INTO category (name, slug, parent_id, depth, sort_order, kind)
SELECT 
  v.name,
  v.slug,
  (SELECT id FROM category WHERE name='Services'),
  2,
  ROW_NUMBER() OVER (),
  'services'  -- ← FIX: Forcer le bon type !
FROM (VALUES
  ('Artistes & Musiciens', 'artistes-musiciens'),
  ('Livraison rapide', 'livraison-rapide'),
  ('Baby-Sitting', 'baby-sitting'),
  ('Billetterie', 'billetterie'),
  ('Covoiturage', 'covoiturage'),
  ('Cours particuliers', 'cours-particuliers'),
  ('Entraide entre voisins', 'entraide-voisins'),
  ('Evenements', 'evenements'),
  ('Services a la personne', 'services-personne'),
  ('Services de demenagement', 'services-demenagement'),
  ('Services de reparations electroniques', 'services-reparations-electroniques'),
  ('Services de jardinerie & bricolage', 'services-jardinerie-bricolage'),
  ('Services evenementiels', 'services-evenementiels'),
  ('Reparation automobile', 'reparation-automobile'),
  ('Autres services', 'autres-services')
) AS v(name, slug);

-- =========================
-- Produits locaux Guinee (niveau 2)
-- =========================

INSERT INTO category (name, slug, parent_id, depth, sort_order, kind)
SELECT 
  v.name,
  v.slug,
  (SELECT id FROM category WHERE name='Produits locaux'),
  2,
  ROW_NUMBER() OVER (),
  'goods'
FROM (VALUES
  ('Alimentaire', 'alimentaire'),
  ('Textile', 'textile'),
  ('Artisanat', 'artisanat')
) AS v(name, slug);

-- =========================
-- Produits locaux : Alimentaire (niveau 3)
-- =========================

INSERT INTO category (name, slug, parent_id, depth, sort_order, kind)
SELECT 
  v.name,
  v.slug,
  (SELECT id FROM category WHERE name='Alimentaire'),
  3,
  ROW_NUMBER() OVER (),
  'goods'
FROM (VALUES
  ('Huile de palme', 'huile-palme'),
  ('Banane', 'banane'),
  ('Manioc', 'manioc'),
  ('Pomme de terre', 'pomme-terre'),
  ('Fruits & legumes locaux', 'fruits-legumes-locaux'),
  ('Epices et condiments', 'epices-condiments')
) AS v(name, slug);

-- =========================
-- Produits locaux : Textile (niveau 3)
-- =========================

INSERT INTO category (name, slug, parent_id, depth, sort_order, kind)
SELECT 
  v.name,
  v.slug,
  (SELECT id FROM category WHERE name='Textile'),
  3,
  ROW_NUMBER() OVER (),
  'goods'
FROM (VALUES
  ('Bazin', 'bazin'),
  ('Habits traditionnels', 'habits-traditionnels'),
  ('Pagne lepi', 'pagne-lepi'),
  ('Pagne foret', 'pagne-foret')
) AS v(name, slug);

-- =========================
-- Produits locaux : Artisanat (niveau 3)
-- =========================

INSERT INTO category (name, slug, parent_id, depth, sort_order, kind)
SELECT 
  v.name,
  v.slug,
  (SELECT id FROM category WHERE name='Artisanat'),
  3,
  ROW_NUMBER() OVER (),
  'goods'
FROM (VALUES
  ('Objets decoratifs', 'objets-decoratifs'),
  ('Sculptures', 'sculptures'),
  ('Bijoux artisanaux', 'bijoux-artisanaux')
) AS v(name, slug);

-- =========================
-- Famille (niveau 2)
-- =========================

INSERT INTO category (name, slug, parent_id, depth, sort_order, kind)
SELECT 
  v.name,
  v.slug,
  (SELECT id FROM category WHERE name='Famille'),
  2,
  ROW_NUMBER() OVER (),
  'other'
FROM (VALUES
  ('Puericulture', 'puericulture'),
  ('Vetements bebe & enfant', 'vetements-bebe-enfant'),
  ('Jouets & Jeux', 'jouets-jeux'),
  ('Livres & BD', 'livres-bd'),
  ('DVD / Films', 'dvd-films'),
  ('CD / Musique', 'cd-musique')
) AS v(name, slug);

-- =========================
-- Loisirs (niveau 2)
-- =========================

INSERT INTO category (name, slug, parent_id, depth, sort_order, kind)
SELECT 
  v.name,
  v.slug,
  (SELECT id FROM category WHERE name='Loisirs'),
  2,
  ROW_NUMBER() OVER (),
  'other'
FROM (VALUES
  ('Sports & Hobbies', 'sports-hobbies'),
  ('Instruments de musique', 'instruments-musique'),
  ('Collection', 'collection'),
  ('Billards', 'billards'),
  ('Materiel professionnel loisirs', 'materiel-professionnel-loisirs')
) AS v(name, slug);

-- =========================
-- Animaux (niveau 2)
-- =========================

INSERT INTO category (name, slug, parent_id, depth, sort_order, kind)
SELECT 
  v.name,
  v.slug,
  (SELECT id FROM category WHERE name='Animaux'),
  2,
  ROW_NUMBER() OVER (),
  'other'
FROM (VALUES
  ('Chiens', 'chiens'),
  ('Chats', 'chats'),
  ('Chevaux', 'chevaux'),
  ('Animaux de la ferme', 'animaux-ferme'),
  ('Aquariophilie', 'aquariophilie'),
  ('Accessoires & Jouets pour animaux', 'accessoires-jouets-animaux'),
  ('Pensions & Elevages', 'pensions-elevages'),
  ('Saillie', 'saillie')
) AS v(name, slug);

-- =========================
-- Relations transversales
-- =========================

-- Voitures → Reparation automobile (service associe)
INSERT INTO category_relation (source_category_id, target_category_id, relation_type)
SELECT 
  c1.id, 
  c2.id, 
  'service_for'
FROM category c1, category c2
WHERE c1.name = 'Voitures' 
  AND c2.name = 'Reparation automobile'
ON CONFLICT DO NOTHING;

-- Telephones → Services de reparations electroniques
INSERT INTO category_relation (source_category_id, target_category_id, relation_type)
SELECT 
  c1.id, 
  c2.id, 
  'service_for'
FROM category c1, category c2
WHERE c1.name = 'Telephones & Objets connectes' 
  AND c2.name = 'Services de reparations electroniques'
ON CONFLICT DO NOTHING;

-- Equipement auto → Voitures (accessoire)
INSERT INTO category_relation (source_category_id, target_category_id, relation_type)
SELECT 
  c1.id, 
  c2.id, 
  'accessory_for'
FROM category c1, category c2
WHERE c1.name = 'Equipement auto' 
  AND c2.name = 'Voitures'
ON CONFLICT DO NOTHING;

-- Equipement moto → Motos
INSERT INTO category_relation (source_category_id, target_category_id, relation_type)
SELECT 
  c1.id, 
  c2.id, 
  'accessory_for'
FROM category c1, category c2
WHERE c1.name = 'Equipement moto' 
  AND c2.name = 'Motos'
ON CONFLICT DO NOTHING;

-- =========================
-- Tags populaires SANS DOUBLONS
-- =========================

INSERT INTO tag (name, slug) VALUES
  ('Neuf', 'neuf'),
  ('Occasion', 'occasion'),
  ('Vintage', 'vintage'),
  ('Artisanal', 'artisanal'),
  ('Bio', 'bio'),
  ('Ecologique', 'ecologique'),
  ('Fait maison', 'fait-maison'),
  ('Produit local', 'produit-local'),
  ('Urgent', 'urgent'),
  ('A negocier', 'a-negocier'),
  ('Livraison possible', 'livraison-possible'),
  ('Etat parfait', 'etat-parfait'),
  ('Petit prix', 'petit-prix'),
  ('Haut de gamme', 'haut-de-gamme'),
  ('Collection', 'collection')
ON CONFLICT (name) DO NOTHING;

-- =========================
-- Statistiques finales
-- =========================

-- Compter les categories par niveau
SELECT depth, COUNT(*) as count FROM category GROUP BY depth ORDER BY depth;

-- Verification des types corrects
SELECT 
  name, 
  kind, 
  COUNT(*) as nb_sous_categories
FROM category c1
WHERE EXISTS (SELECT 1 FROM category c2 WHERE c2.parent_id = c1.id)
GROUP BY name, kind
ORDER BY name;

-- Voir la hierarchie complete avec types corrects
SELECT 
  CASE depth 
    WHEN 1 THEN name
    WHEN 2 THEN '  └── ' || name
    WHEN 3 THEN '     └── ' || name
  END as hierarchy,
  kind,
  listing_count
FROM category 
ORDER BY 
  COALESCE(parent_id, id), 
  depth, 
  sort_order;