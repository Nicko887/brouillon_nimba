-- =====================================================================
-- Données d’exemple : catégories + sous-catégories + relations
-- Lance d'abord:   \i db/schema_postgres.sql
-- Puis:            \i db/seed_taxonomy.sql
-- =====================================================================

-- Racines
INSERT INTO category (name, kind, parent_id) VALUES
  ('Emploi', 'other', NULL),
  ('Véhicules', 'goods', NULL),
  ('Immobilier', 'goods', NULL),
  ('Locations de vacances', 'goods', NULL),
  ('Électronique', 'goods', NULL),
  ('Maison & Jardin', 'goods', NULL),
  ('Famille', 'other', NULL),
  ('Mode', 'goods', NULL),
  ('Loisirs', 'other', NULL),
  ('Animaux', 'other', NULL),
  ('Matériel professionnel', 'goods', NULL),
  ('Services', 'services', NULL),
  ('Produits locaux', 'goods', NULL),
  ('Divers', 'other', NULL);

-- Véhicules
INSERT INTO category (name, parent_id)
SELECT v.name, (SELECT id FROM category WHERE slug='vehicules') FROM (VALUES
  ('Voitures'),('Motos'),('Caravaning'),('Utilitaires'),('Nautisme'),
  ('Équipement auto'),('Équipement moto'),('Équipement caravaning'),('Équipement nautisme')
) AS v(name);

-- Immobilier
INSERT INTO category (name, parent_id)
SELECT v.name, (SELECT id FROM category WHERE slug='immobilier') FROM (VALUES
  ('Ventes immobilières'),('Locations'),('Colocations'),('Bureaux & Commerces')
) AS v(name);

-- Électronique
INSERT INTO category (name, parent_id)
SELECT v.name, (SELECT id FROM category WHERE slug='electronique') FROM (VALUES
  ('Ordinateurs'),
  ('Accessoires informatique'),
  ('Tablettes & Liseuses'),
  ('Photo, audio & vidéo'),
  ('Téléphones & Objets connectés'),
  ('Accessoires téléphone & Objets connectés'),
  ('Consoles'),
  ('Jeux vidéo')
) AS v(name);

-- Maison & Jardin
INSERT INTO category (name, parent_id)
SELECT v.name, (SELECT id FROM category WHERE slug='maison-jardin') FROM (VALUES
  ('Ameublement'),
  ('Papeterie & Fournitures scolaires'),
  ('Électroménager'),
  ('Arts de la table'),
  ('Décoration'),
  ('Linge de maison'),
  ('Bricolage'),
  ('Jardin & Plantes')
) AS v(name);

-- Mode
INSERT INTO category (name, parent_id)
SELECT v.name, (SELECT id FROM category WHERE slug='mode') FROM (VALUES
  ('Vêtements'),('Chaussures'),('Accessoires & Bagagerie'),('Montres & Bijoux')
) AS v(name);

-- Matériel professionnel
INSERT INTO category (name, parent_id)
SELECT v.name, (SELECT id FROM category WHERE slug='materiel-professionnel') FROM (VALUES
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

-- Services (inclut Réparation automobile)
INSERT INTO category (name, kind, parent_id)
SELECT v.name, 'services', (SELECT id FROM category WHERE slug='services') FROM (VALUES
  ('Artistes & Musiciens'),
  ('Livraison rapide')
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

-- Produits locaux (Guinée) : niveau 2
INSERT INTO category (name, parent_id)
SELECT v.name, (SELECT id FROM category WHERE slug='produits-locaux') FROM (VALUES
  ('Alimentaire'),('Textile'),('Artisanat')
) AS v(name);

-- Produits locaux : niveau 3 - Alimentaire
INSERT INTO category (name, parent_id)
SELECT v.name, (SELECT id FROM category WHERE slug='alimentaire') FROM (VALUES
  ('Huile de palme'),('Banane'),('Manioc'), ('pomme de terre'),('Fruits & légumes locaux'),('Épices et condiments')
) AS v(name);

-- Produits locaux : niveau 3 - Textile
INSERT INTO category (name, parent_id)
SELECT v.name, (SELECT id FROM category WHERE slug='textile') FROM (VALUES
  ('Bazin'),('Habits traditionnels'), ('pagne lepi'), ('pagne foret')
) AS v(name);

-- Produits locaux : niveau 3 - Artisanat
INSERT INTO category (name, parent_id)
SELECT v.name, (SELECT id FROM category WHERE slug='artisanat') FROM (VALUES
  ('Objets décoratifs'),('Sculptures'),('Bijoux artisanaux')
) AS v(name);

-- =========================
-- Relations transversales
-- =========================

-- Voitures → Réparation automobile (service associé)
INSERT INTO category_relation (source_category_id, target_category_id, relation_type)
SELECT s.id, t.id, 'service_for'::relation_type
FROM category s, category t
WHERE s.slug='voitures' AND t.slug='reparation-automobile'
ON CONFLICT DO NOTHING;

-- Téléphones & Objets connectés → Services de réparations électroniques (service associé)
INSERT INTO category_relation (source_category_id, target_category_id, relation_type)
SELECT s.id, t.id, 'service_for'::relation_type
FROM category s, category t
WHERE s.slug='telephones-objets-connectes' AND t.slug='services-de-reparations-electroniques'
ON CONFLICT DO NOTHING;

-- Voitures → Équipement auto (accessoire/équipement)
INSERT INTO category_relation (source_category_id, target_category_id, relation_type)
SELECT s.id, t.id, 'accessory_for'::relation_type
FROM category s, category t
WHERE s.slug='equipement-auto' AND t.slug='voitures'
ON CONFLICT DO NOTHING;

-- Motos → Équipement moto
INSERT INTO category_relation (source_category_id, target_category_id, relation_type)
SELECT s.id, t.id, 'accessory_for'::relation_type
FROM category s, category t
WHERE s.slug='equipement-moto' AND t.slug='motos'
ON CONFLICT DO NOTHING;

-- Caravaning → Équipement caravaning
INSERT INTO category_relation (source_category_id, target_category_id, relation_type)
SELECT s.id, t.id, 'accessory_for'::relation_type
FROM category s, category t
WHERE s.slug='equipement-caravaning' AND t.slug='caravaning'
ON CONFLICT DO NOTHING;

-- Nautisme → Équipement nautisme
INSERT INTO category_relation (source_category_id, target_category_id, relation_type)
SELECT s.id, t.id, 'accessory_for'::relation_type
FROM category s, category t
WHERE s.slug='equipement-nautisme' AND t.slug='nautisme'
ON CONFLICT DO NOTHING;

-- =========================
-- Vérifs rapides (optionnel)
-- =========================
-- SELECT id, name, slug, depth, path_ids FROM category ORDER BY depth, name;
-- SELECT * FROM category_descendants('vehicules');
-- SELECT * FROM category_related('voitures', 'service_for');
