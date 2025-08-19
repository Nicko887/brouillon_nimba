-- =====================================================================
-- Données d'exemple COMPATIBLES DJANGO pour petites annonces
-- À exécuter APRÈS le schéma hybride
-- =====================================================================

-- =========================
-- Catégories racines (niveau 1)
-- =========================

INSERT INTO category (name, kind, parent_id, sort_order) VALUES
  ('Emploi', 'jobs', NULL, 1),
  ('Véhicules', 'vehicles', NULL, 2),
  ('Immobilier', 'real_estate', NULL, 3),
  ('Locations de vacances', 'real_estate', NULL, 4),
  ('Électronique', 'goods', NULL, 5),
  ('Maison & Jardin', 'goods', NULL, 6),
  ('Famille', 'other', NULL, 7),
  ('Mode', 'goods', NULL, 8),
  ('Loisirs', 'other', NULL, 9),
  ('Animaux', 'other', NULL, 10),
  ('Matériel professionnel', 'goods', NULL, 11),
  ('Services', 'services', NULL, 12),
  ('Produits locaux', 'goods', NULL, 13),
  ('Divers', 'other', NULL, 14);

-- =========================
-- Véhicules (niveau 2)
-- =========================

INSERT INTO category (name, parent_id, depth, sort_order)
SELECT 
  v.name, 
  (SELECT id FROM category WHERE name='Véhicules'),
  2,
  ROW_NUMBER() OVER () 
FROM (VALUES
  ('Voitures'),
  ('Motos'),
  ('Caravaning'),
  ('Utilitaires'),
  ('Nautisme'),
  ('Équipement auto'),
  ('Équipement moto'),
  ('Équipement caravaning'),
  ('Équipement nautisme')
) AS v(name);

-- =========================
-- Immobilier (niveau 2)
-- =========================

INSERT INTO category (name, parent_id, depth, sort_order)
SELECT 
  v.name, 
  (SELECT id FROM category WHERE name='Immobilier'),
  2,
  ROW_NUMBER() OVER () 
FROM (VALUES
  ('Ventes immobilières'),
  ('Locations'),
  ('Colocations'),
  ('Bureaux & Commerces')
) AS v(name);

-- =========================
-- Électronique (niveau 2)
-- =========================

INSERT INTO category (name, parent_id, depth, sort_order)
SELECT 
  v.name, 
  (SELECT id FROM category WHERE name='Électronique'),
  2,
  ROW_NUMBER() OVER () 
FROM (VALUES
  ('Ordinateurs'),
  ('Accessoires informatique'),
  ('Tablettes & Liseuses'),
  ('Photo, audio & vidéo'),
  ('Téléphones & Objets connectés'),
  ('Accessoires téléphone & Objets connectés'),
  ('Consoles'),
  ('Jeux vidéo')
) AS v(name);

-- =========================
-- Maison & Jardin (niveau 2)
-- =========================

INSERT INTO category (name, parent_id, depth, sort_order)
SELECT 
  v.name, 
  (SELECT id FROM category WHERE name='Maison & Jardin'),
  2,
  ROW_NUMBER() OVER () 
FROM (VALUES
  ('Ameublement'),
  ('Papeterie & Fournitures scolaires'),
  ('Électroménager'),
  ('Arts de la table'),
  ('Décoration'),
  ('Linge de maison'),
  ('Bricolage'),
  ('Jardin & Plantes')
) AS v(name);

-- =========================
-- Mode (niveau 2)
-- =========================

INSERT INTO category (name, parent_id, depth, sort_order)
SELECT 
  v.name, 
  (SELECT id FROM category WHERE name='Mode'),
  2,
  ROW_NUMBER() OVER () 
FROM (VALUES
  ('Vêtements'),
  ('Chaussures'),
  ('Accessoires & Bagagerie'),
  ('Montres & Bijoux')
) AS v(name);

-- =========================
-- Emploi (niveau 2)
-- =========================

INSERT INTO category (name, parent_id, depth, sort_order)
SELECT 
  v.name, 
  (SELECT id FROM category WHERE name='Emploi'),
  2,
  ROW_NUMBER() OVER () 
FROM (VALUES
  ('CDI'),
  ('CDD'),
  ('Intérim'),
  ('Stage'),
  ('Apprentissage'),
  ('Freelance'),
  ('Temps partiel')
) AS v(name);

-- =========================
-- Matériel professionnel (niveau 2)
-- =========================

INSERT INTO category (name, parent_id, depth, sort_order)
SELECT 
  v.name, 
  (SELECT id FROM category WHERE name='Matériel professionnel'),
  2,
  ROW_NUMBER() OVER () 
FROM (VALUES
  ('Tracteurs'),
  ('Matériel agricole'),
  ('BTP - Chantier gros-oeuvre'),
  ('Poids lourds'),
  ('Manutention - Levage'),
  ('Équipements industriels'),
  ('Équipements pour restaurants & hôtels'),
  ('Équipements & Fournitures de bureau'),
  ('Équipements pour commerces & marchés'),
  ('Matériel médical')
) AS v(name);

-- =========================
-- Services (niveau 2)
-- =========================

INSERT INTO category (name, parent_id, depth, sort_order)
SELECT 
  v.name, 
  (SELECT id FROM category WHERE name='Services'),
  2,
  ROW_NUMBER() OVER () 
FROM (VALUES
  ('Artistes & Musiciens'),
  ('Livraison rapide'),
  ('Baby-Sitting'),
  ('Billetterie'),
  ('Covoiturage'),
  ('Cours particuliers'),
  ('Entraide entre voisins'),
  ('Évènements'),
  ('Services à la personne'),
  ('Services de déménagement'),
  ('Services de réparations électroniques'),
  ('Services de jardinerie & bricolage'),
  ('Services événementiels'),
  ('Réparation automobile'),
  ('Autres services')
) AS v(name);

-- =========================
-- Produits locaux Guinée (niveau 2)
-- =========================

INSERT INTO category (name, parent_id, depth, sort_order)
SELECT 
  v.name, 
  (SELECT id FROM category WHERE name='Produits locaux'),
  2,
  ROW_NUMBER() OVER () 
FROM (VALUES
  ('Alimentaire'),
  ('Textile'),
  ('Artisanat')
) AS v(name);

-- =========================
-- Produits locaux : Alimentaire (niveau 3)
-- =========================

INSERT INTO category (name, parent_id, depth, sort_order)
SELECT 
  v.name, 
  (SELECT id FROM category WHERE name='Alimentaire'),
  3,
  ROW_NUMBER() OVER () 
FROM (VALUES
  ('Huile de palme'),
  ('Banane'),
  ('Manioc'),
  ('Pomme de terre'),
  ('Fruits & légumes locaux'),
  ('Épices et condiments')
) AS v(name);

-- =========================
-- Produits locaux : Textile (niveau 3)
-- =========================

INSERT INTO category (name, parent_id, depth, sort_order)
SELECT 
  v.name, 
  (SELECT id FROM category WHERE name='Textile'),
  3,
  ROW_NUMBER() OVER () 
FROM (VALUES
  ('Bazin'),
  ('Habits traditionnels'),
  ('Pagne lepi'),
  ('Pagne foret')
) AS v(name);

-- =========================
-- Produits locaux : Artisanat (niveau 3)
-- =========================

INSERT INTO category (name, parent_id, depth, sort_order)
SELECT 
  v.name, 
  (SELECT id FROM category WHERE name='Artisanat'),
  3,
  ROW_NUMBER() OVER () 
FROM (VALUES
  ('Objets décoratifs'),
  ('Sculptures'),
  ('Bijoux artisanaux')
) AS v(name);

-- =========================
-- Famille (niveau 2)
-- =========================

INSERT INTO category (name, parent_id, depth, sort_order)
SELECT 
  v.name, 
  (SELECT id FROM category WHERE name='Famille'),
  2,
  ROW_NUMBER() OVER () 
FROM (VALUES
  ('Puériculture'),
  ('Vêtements bébé & enfant'),
  ('Jouets & Jeux'),
  ('Livres & BD'),
  ('DVD / Films'),
  ('CD / Musique')
) AS v(name);

-- =========================
-- Loisirs (niveau 2)
-- =========================

INSERT INTO category (name, parent_id, depth, sort_order)
SELECT 
  v.name, 
  (SELECT id FROM category WHERE name='Loisirs'),
  2,
  ROW_NUMBER() OVER () 
FROM (VALUES
  ('Sports & Hobbies'),
  ('Instruments de musique'),
  ('Collection'),
  ('Billards'),
  ('Matériel professionnel')
) AS v(name);

-- =========================
-- Animaux (niveau 2)
-- =========================

INSERT INTO category (name, parent_id, depth, sort_order)
SELECT 
  v.name, 
  (SELECT id FROM category WHERE name='Animaux'),
  2,
  ROW_NUMBER() OVER () 
FROM (VALUES
  ('Chiens'),
  ('Chats'),
  ('Chevaux'),
  ('Animaux de la ferme'),
  ('Aquariophilie'),
  ('Accessoires & Jouets pour animaux'),
  ('Pensions & Élevages'),
  ('Saillie')
) AS v(name);

-- =========================
-- Relations transversales (VERSION DJANGO)
-- =========================

-- Voitures → Réparation automobile (service associé)
INSERT INTO category_relation (source_category_id, target_category_id, relation_type)
SELECT 
  c1.id, 
  c2.id, 
  'service_for'
FROM category c1, category c2
WHERE c1.name = 'Voitures' 
  AND c2.name = 'Réparation automobile'
ON CONFLICT DO NOTHING;

-- Téléphones → Services de réparations électroniques
INSERT INTO category_relation (source_category_id, target_category_id, relation_type)
SELECT 
  c1.id, 
  c2.id, 
  'service_for'
FROM category c1, category c2
WHERE c1.name = 'Téléphones & Objets connectés' 
  AND c2.name = 'Services de réparations électroniques'
ON CONFLICT DO NOTHING;

-- Équipement auto → Voitures (accessoire)
INSERT INTO category_relation (source_category_id, target_category_id, relation_type)
SELECT 
  c1.id, 
  c2.id, 
  'accessory_for'
FROM category c1, category c2
WHERE c1.name = 'Équipement auto' 
  AND c2.name = 'Voitures'
ON CONFLICT DO NOTHING;

-- Équipement moto → Motos
INSERT INTO category_relation (source_category_id, target_category_id, relation_type)
SELECT 
  c1.id, 
  c2.id, 
  'accessory_for'
FROM category c1, category c2
WHERE c1.name = 'Équipement moto' 
  AND c2.name = 'Motos'
ON CONFLICT DO NOTHING;

-- =========================
-- Quelques tags populaires
-- =========================

INSERT INTO tag (name, slug) VALUES
  ('Neuf', 'neuf'),
  ('Occasion', 'occasion'),
  ('Vintage', 'vintage'),
  ('Artisanal', 'artisanal'),
  ('Bio', 'bio'),
  ('Écologique', 'ecologique'),
  ('Fait maison', 'fait-maison'),
  ('Produit local', 'produit-local'),
  ('Urgent', 'urgent'),
  ('À négocier', 'a-negocier'),
  ('Livraison possible', 'livraison-possible'),
  ('État parfait', 'etat-parfait'),
  ('Petit prix', 'petit-prix'),
  ('Haut de gamme', 'haut-de-gamme'),
  ('Collection', 'collection');

-- =========================
-- Mise à jour des slugs (Django les générera normalement)
-- =========================

UPDATE category SET slug = 
  CASE 
    WHEN name = 'Véhicules' THEN 'vehicules'
    WHEN name = 'Électronique' THEN 'electronique'
    WHEN name = 'Maison & Jardin' THEN 'maison-jardin'
    WHEN name = 'Matériel professionnel' THEN 'materiel-professionnel'
    WHEN name = 'Produits locaux' THEN 'produits-locaux'
    ELSE LOWER(REPLACE(REPLACE(REPLACE(name, ' ', '-'), '&', 'et'), 'é', 'e'))
  END
WHERE slug IS NULL OR slug = '';

-- =========================
-- Statistiques rapides
-- =========================

-- Compter les catégories par niveau
SELECT depth, COUNT(*) as count FROM category GROUP BY depth ORDER BY depth;

-- Voir la hiérarchie complète
SELECT 
  CASE depth 
    WHEN 1 THEN name
    WHEN 2 THEN '  └─ ' || name
    WHEN 3 THEN '     └─ ' || name
  END as hierarchy,
  kind,
  listing_count
FROM category 
ORDER BY 
  COALESCE(parent_id, id), 
  depth, 
  sort_order;