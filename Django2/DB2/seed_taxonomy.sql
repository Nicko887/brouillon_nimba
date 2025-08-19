-- =====================================================================
-- Données d'exemple pour site de petites annonces Django
-- À exécuter APRÈS le schéma principal
-- Usage: psql -d votre_db -f seed_data.sql
-- =====================================================================

-- Vider les tables (en cas de re-exécution)
TRUNCATE TABLE report, user_rating, message, conversation, saved_search, 
               user_favorite, listing_tag, tag, listing_image, listing, 
               category_relation, category, user_profile, auth_user 
               RESTART IDENTITY CASCADE;

-- =========================
-- Utilisateurs de test
-- =========================

-- Super utilisateur admin
INSERT INTO auth_user (username, email, first_name, last_name, is_staff, is_superuser, password, date_joined) VALUES
('admin', 'admin@example.com', 'Admin', 'User', true, true, 'pbkdf2_sha256$600000$placeholder$hashedpassword', now());

-- Utilisateurs normaux
INSERT INTO auth_user (username, email, first_name, last_name, password, date_joined) VALUES
('john_doe', 'john@example.com', 'John', 'Doe', 'pbkdf2_sha256$600000$placeholder$hashedpassword', now()),
('marie_dubois', 'marie@example.com', 'Marie', 'Dubois', 'pbkdf2_sha256$600000$placeholder$hashedpassword', now()),
('ibrahim_diallo', 'ibrahim@example.com', 'Ibrahim', 'Diallo', 'pbkdf2_sha256$600000$placeholder$hashedpassword', now()),
('fatou_barry', 'fatou@example.com', 'Fatou', 'Barry', 'pbkdf2_sha256$600000$placeholder$hashedpassword', now()),
('alpha_conde', 'alpha@example.com', 'Alpha', 'Condé', 'pbkdf2_sha256$600000$placeholder$hashedpassword', now());

-- Profils utilisateurs
INSERT INTO user_profile (user_id, phone, location, latitude, longitude, bio, email_verified, phone_verified) VALUES
((SELECT id FROM auth_user WHERE username='admin'), '+224620000000', 'Conakry, Guinée', 9.6412, -13.5784, 'Administrateur du site', true, true),
((SELECT id FROM auth_user WHERE username='john_doe'), '+224620111111', 'Kaloum, Conakry', 9.5092, -13.7122, 'Passionné de technologie', true, true),
((SELECT id FROM auth_user WHERE username='marie_dubois'), '+224620222222', 'Ratoma, Conakry', 9.6769, -13.6531, 'Amoureuse de la mode', true, false),
((SELECT id FROM auth_user WHERE username='ibrahim_diallo'), '+224620333333', 'Kankan, Guinée', 10.3852, -9.3056, 'Entrepreneur local', false, true),
((SELECT id FROM auth_user WHERE username='fatou_barry'), '+224620444444', 'Labé, Guinée', 11.3242, -12.2826, 'Vendeuse de produits locaux', true, true),
((SELECT id FROM auth_user WHERE username='alpha_conde'), '+224620555555', 'Nzérékoré, Guinée', 7.7562, -8.8179, 'Artisan traditionnel', true, false);

-- =========================
-- Catégories principales
-- =========================

-- Racines principales
INSERT INTO category (name, kind, parent_id, description, sort_order) VALUES
('Emploi', 'jobs', NULL, 'Offres d''emploi et opportunités professionnelles', 1),
('Véhicules', 'vehicles', NULL, 'Voitures, motos et tous types de véhicules', 2),
('Immobilier', 'real_estate', NULL, 'Vente et location de biens immobiliers', 3),
('Locations de vacances', 'real_estate', NULL, 'Hébergements temporaires et vacances', 4),
('Électronique', 'goods', NULL, 'Ordinateurs, téléphones et équipements électroniques', 5),
('Maison & Jardin', 'goods', NULL, 'Mobilier, décoration et jardinage', 6),
('Famille', 'other', NULL, 'Articles pour enfants et famille', 7),
('Mode', 'goods', NULL, 'Vêtements, chaussures et accessoires', 8),
('Loisirs', 'other', NULL, 'Sports, livres, jeux et divertissements', 9),
('Animaux', 'other', NULL, 'Animaux de compagnie et accessoires', 10),
('Matériel professionnel', 'goods', NULL, 'Équipements et outils professionnels', 11),
('Services', 'services', NULL, 'Prestations de services diverses', 12),
('Produits locaux', 'goods', NULL, 'Produits traditionnels de Guinée', 13),
('Divers', 'other', NULL, 'Articles non classés ailleurs', 14);

-- =========================
-- Sous-catégories niveau 2
-- =========================

-- Véhicules
INSERT INTO category (name, parent_id, description) 
SELECT v.name, (SELECT id FROM category WHERE slug='vehicules'), v.desc FROM (VALUES
  ('Voitures', 'Véhicules personnels et familiaux'),
  ('Motos', 'Motos, scooters et cyclomoteurs'),
  ('Caravaning', 'Caravanes, camping-cars et remorques'),
  ('Utilitaires', 'Camions, fourgons et véhicules commerciaux'),
  ('Nautisme', 'Bateaux, jet-skis et équipements nautiques'),
  ('Équipement auto', 'Pièces détachées et accessoires automobiles'),
  ('Équipement moto', 'Casques, équipements et pièces motos'),
  ('Équipement caravaning', 'Accessoires camping et caravaning'),
  ('Équipement nautisme', 'Matériel et accessoires nautiques')
) AS v(name, desc);

-- Immobilier
INSERT INTO category (name, parent_id, description)
SELECT v.name, (SELECT id FROM category WHERE slug='immobilier'), v.desc FROM (VALUES
  ('Ventes immobilières', 'Maisons, appartements et terrains à vendre'),
  ('Locations', 'Logements en location longue durée'),
  ('Colocations', 'Chambres et colocations'),
  ('Bureaux & Commerces', 'Locaux professionnels et commerciaux')
) AS v(name, desc);

-- Électronique
INSERT INTO category (name, parent_id, description)
SELECT v.name, (SELECT id FROM category WHERE slug='electronique'), v.desc FROM (VALUES
  ('Ordinateurs', 'PC, Mac, portables et composants'),
  ('Accessoires informatique', 'Claviers, souris, écrans et périphériques'),
  ('Tablettes & Liseuses', 'iPad, tablettes Android et liseuses'),
  ('Photo, audio & vidéo', 'Appareils photo, caméras et matériel audio'),
  ('Téléphones & Objets connectés', 'Smartphones et objets connectés'),
  ('Accessoires téléphone & Objets connectés', 'Coques, chargeurs et accessoires'),
  ('Consoles', 'PlayStation, Xbox, Nintendo et consoles rétro'),
  ('Jeux vidéo', 'Jeux pour toutes consoles et PC')
) AS v(name, desc);

-- Maison & Jardin
INSERT INTO category (name, parent_id, description)
SELECT v.name, (SELECT id FROM category WHERE slug='maison-jardin'), v.desc FROM (VALUES
  ('Ameublement', 'Mobilier et meubles pour la maison'),
  ('Papeterie & Fournitures scolaires', 'Matériel bureau et école'),
  ('Électroménager', 'Appareils électriques pour la maison'),
  ('Arts de la table', 'Vaisselle, couverts et accessoires repas'),
  ('Décoration', 'Objets déco, tableaux et ornements'),
  ('Linge de maison', 'Draps, serviettes et textiles maison'),
  ('Bricolage', 'Outils et matériel de bricolage'),
  ('Jardin & Plantes', 'Plantes, graines et matériel jardinage')
) AS v(name, desc);

-- Mode
INSERT INTO category (name, parent_id, description)
SELECT v.name, (SELECT id FROM category WHERE slug='mode'), v.desc FROM (VALUES
  ('Vêtements', 'Habits pour hommes, femmes et enfants'),
  ('Chaussures', 'Chaussures de toutes tailles et styles'),
  ('Accessoires & Bagagerie', 'Sacs, ceintures et accessoires mode'),
  ('Montres & Bijoux', 'Montres, bijoux et accessoires précieux')
) AS v(name, desc);

-- Matériel professionnel
INSERT INTO category (name, parent_id, description)
SELECT v.name, (SELECT id FROM category WHERE slug='materiel-professionnel'), v.desc FROM (VALUES
  ('Tracteurs', 'Tracteurs agricoles et forestiers'),
  ('Matériel agricole', 'Équipements pour l''agriculture'),
  ('BTP - Chantier gros-oeuvre', 'Matériel de construction et BTP'),
  ('Poids lourds', 'Camions et véhicules lourds'),
  ('Manutention - Levage', 'Grues, chariots et équipements levage'),
  ('Équipements industriels', 'Machines et outils industriels'),
  ('Équipements pour restaurants & hôtels', 'Matériel CHR professionnel'),
  ('Équipements & Fournitures de bureau', 'Mobilier et matériel bureau'),
  ('Équipements pour commerces & marchés', 'Matériel pour commerces'),
  ('Matériel médical', 'Équipements médicaux et de santé')
) AS v(name, desc);

-- Services
INSERT INTO category (name, kind, parent_id, description)
SELECT v.name, 'services', (SELECT id FROM category WHERE slug='services'), v.desc FROM (VALUES
  ('Artistes & Musiciens', 'Prestations artistiques et musicales'),
  ('Livraison rapide', 'Services de livraison et transport'),
  ('Baby-Sitting', 'Garde d''enfants et services familiaux'),
  ('Billetterie', 'Vente de billets et réservations'),
  ('Covoiturage', 'Partage de trajets et transport'),
  ('Cours particuliers', 'Soutien scolaire et formation'),
  ('Entraide entre voisins', 'Services entre particuliers'),
  ('Évènements', 'Organisation d''événements et fêtes'),
  ('Services à la personne', 'Aide ménagère, soins personnels'),
  ('Services de déménagement', 'Déménagement et transport mobilier'),
  ('Services de réparations électroniques', 'Réparation appareils électroniques'),
  ('Services de jardinerie & bricolage', 'Jardinage et petits travaux'),
  ('Services événementiels', 'Animation et organisation événements'),
  ('Réparation automobile', 'Garage et réparation véhicules'),
  ('Autres services', 'Services divers non classés')
) AS v(name, desc);

-- =========================
-- Produits locaux (spécifique Guinée)
-- =========================

-- Niveau 2 - Produits locaux
INSERT INTO category (name, parent_id, description)
SELECT v.name, (SELECT id FROM category WHERE slug='produits-locaux'), v.desc FROM (VALUES
  ('Alimentaire', 'Produits alimentaires traditionnels guinéens'),
  ('Textile', 'Tissus et vêtements traditionnels'),
  ('Artisanat', 'Objets artisanaux et créations locales')
) AS v(name, desc);

-- Niveau 3 - Alimentaire
INSERT INTO category (name, parent_id, description)
SELECT v.name, (SELECT id FROM category WHERE slug='alimentaire'), v.desc FROM (VALUES
  ('Huile de palme', 'Huile de palme artisanale et traditionnelle'),
  ('Banane', 'Bananes fraîches et séchées'),
  ('Manioc', 'Manioc frais, farine et dérivés'),
  ('Pomme de terre', 'Pommes de terre locales'),
  ('Fruits & légumes locaux', 'Produits frais de saison'),
  ('Épices et condiments', 'Épices traditionnelles guinéennes')
) AS v(name, desc);

-- Niveau 3 - Textile
INSERT INTO category (name, parent_id, description)
SELECT v.name, (SELECT id FROM category WHERE slug='textile'), v.desc FROM (VALUES
  ('Bazin', 'Tissu bazin riche traditionnel'),
  ('Habits traditionnels', 'Vêtements traditionnels guinéens'),
  ('Pagne lepi', 'Pagne traditionnel lepi'),
  ('Pagne foret', 'Pagne traditionnel de la région forestière')
) AS v(name, desc);

-- Niveau 3 - Artisanat
INSERT INTO category (name, parent_id, description)
SELECT v.name, (SELECT id FROM category WHERE slug='artisanat'), v.desc FROM (VALUES
  ('Objets décoratifs', 'Décorations artisanales traditionnelles'),
  ('Sculptures', 'Sculptures en bois et autres matériaux'),
  ('Bijoux artisanaux', 'Bijoux traditionnels faits main')
) AS v(name, desc);

-- =========================
-- Tags populaires
-- =========================

INSERT INTO tag (name, slug) VALUES
('neuf', 'neuf'),
('occasion', 'occasion'),
('urgent', 'urgent'),
('négociable', 'negociable'),
('livraison', 'livraison'),
('garantie', 'garantie'),
('pas cher', 'pas-cher'),
('qualité', 'qualite'),
('rare', 'rare'),
('collection', 'collection'),
('vintage', 'vintage'),
('moderne', 'moderne'),
('traditionnel', 'traditionnel'),
('bio', 'bio'),
('fait main', 'fait-main'),
('artisanal', 'artisanal'),
('local', 'local'),
('import', 'import'),
('professionnel', 'professionnel'),
('particulier', 'particulier');

-- =========================
-- Relations transversales entre catégories
-- =========================

-- Véhicules → Services de réparation
INSERT INTO category_relation (source_category_id, target_category_id, relation_type)
SELECT s.id, t.id, 'service_for'::relation_type
FROM category s, category t
WHERE s.slug='voitures' AND t.slug='reparation-automobile'
ON CONFLICT DO NOTHING;

-- Électronique → Services de réparation
INSERT INTO category_relation (source_category_id, target_category_id, relation_type)
SELECT s.id, t.id, 'service_for'::relation_type
FROM category s, category t
WHERE s.slug='telephones-objets-connectes' AND t.slug='services-de-reparations-electroniques'
ON CONFLICT DO NOTHING;

-- Équipements → Véhicules (relations accessoires)
INSERT INTO category_relation (source_category_id, target_category_id, relation_type)
SELECT s.id, t.id, 'accessory_for'::relation_type
FROM category s, category t
WHERE s.slug='equipement-auto' AND t.slug='voitures'
ON CONFLICT DO NOTHING;

INSERT INTO category_relation (source_category_id, target_category_id, relation_type)
SELECT s.id, t.id, 'accessory_for'::relation_type
FROM category s, category t
WHERE s.slug='equipement-moto' AND t.slug='motos'
ON CONFLICT DO NOTHING;

INSERT INTO category_relation (source_category_id, target_category_id, relation_type)
SELECT s.id, t.id, 'accessory_for'::relation_type
FROM category s, category t
WHERE s.slug='equipement-caravaning' AND t.slug='caravaning'
ON CONFLICT DO NOTHING;

INSERT INTO category_relation (source_category_id, target_category_id, relation_type)
SELECT s.id, t.id, 'accessory_for'::relation_type
FROM category s, category t
WHERE s.slug='equipement-nautisme' AND t.slug='nautisme'
ON CONFLICT DO NOTHING;

-- Accessoires téléphone → Téléphones
INSERT INTO category_relation (source_category_id, target_category_id, relation_type)
SELECT s.id, t.id, 'accessory_for'::relation_type
FROM category s, category t
WHERE s.slug='accessoires-telephone-objets-connectes' AND t.slug='telephones-objets-connectes'
ON CONFLICT DO NOTHING;

-- Relations "similaires" ou "liées"
INSERT INTO category_relation (source_category_id, target_category_id, relation_type)
SELECT s.id, t.id, 'related'::relation_type
FROM category s, category t
WHERE s.slug='voitures' AND t.slug='motos'
ON CONFLICT DO NOTHING;

INSERT INTO category_relation (source_category_id, target_category_id, relation_type)
SELECT s.id, t.id, 'related'::relation_type
FROM category s, category t
WHERE s.slug='ordinateurs' AND t.slug='tablettes-liseuses'
ON CONFLICT DO NOTHING;

-- =========================
-- Annonces d'exemple
-- =========================

-- Quelques annonces pour tester
INSERT INTO listing (user_id, category_id, title, description, price_cents, location, latitude, longitude, status, condition) VALUES

-- Véhicules
((SELECT id FROM auth_user WHERE username='john_doe'),
 (SELECT id FROM category WHERE slug='voitures'),
 'Toyota Corolla 2018 - Excellent état',
 'Véhicule en parfait état, entretien régulier chez concessionnaire. Climatisation, direction assistée, vitres électriques. Très économique et fiable.',
 15000000, -- 150,000 GNF en centimes
 'Kaloum, Conakry',
 9.5092, -13.7122,
 'active', 'good'),

-- Électronique
((SELECT id FROM auth_user WHERE username='marie_dubois'),
 (SELECT id FROM category WHERE slug='telephones-objets-connectes'),
 'iPhone 13 Pro 128GB - Comme neuf',
 'iPhone 13 Pro en excellent état, acheté il y a 6 mois. Boîte d''origine avec tous les accessoires. Protection écran posée dès l''achat.',
 8500000, -- 85,000 GNF
 'Ratoma, Conakry',
 9.6769, -13.6531,
 'active', 'like_new'),

-- Produits locaux
((SELECT id FROM auth_user WHERE username='fatou_barry'),
 (SELECT id FROM category WHERE slug='huile-de-palme'),
 'Huile de palme artisanale - Production familiale',
 'Huile de palme pure, produite artisanalement par notre famille depuis 3 générations. Qualité supérieure, extraction traditionnelle sans additifs.',
 45000, -- 450 GNF le litre
 'Labé, Guinée',
 11.3242, -12.2826,
 'active', 'new'),

-- Services
((SELECT id FROM auth_user WHERE username='ibrahim_diallo'),
 (SELECT id FROM category WHERE slug='reparation-automobile'),
 'Réparation mécanique automobile - Garage expérimenté',
 'Garage avec 15 ans d''expérience. Réparation toutes marques, diagnostic électronique, entretien, vidange. Devis gratuit. Pièces garanties.',
 NULL, -- Prix sur devis
 'Kankan, Guinée',
 10.3852, -9.3056,
 'active', NULL),

-- Artisanat
((SELECT id FROM auth_user WHERE username='alpha_conde'),
 (SELECT id FROM category WHERE slug='sculptures'),
 'Sculpture traditionnelle en ébène - Pièce unique',
 'Magnifique sculpture artisanale taillée dans l''ébène. Représente un masque traditionnel de la région forestière. Pièce unique, travail minutieux.',
 2500000, -- 25,000 GNF
 'Nzérékoré, Guinée',
 7.7562, -8.8179,
 'active', 'new');

-- Images pour les annonces
INSERT INTO listing_image (listing_id, image, alt_text, is_primary, sort_order) VALUES
((SELECT id FROM listing WHERE title LIKE 'Toyota Corolla%'), '/media/listings/toyota_corolla_1.jpg', 'Toyota Corolla vue extérieure', true, 1),
((SELECT id FROM listing WHERE title LIKE 'Toyota Corolla%'), '/media/listings/toyota_corolla_2.jpg', 'Toyota Corolla intérieur', false, 2),
((SELECT id FROM listing WHERE title LIKE 'iPhone 13 Pro%'), '/media/listings/iphone13_1.jpg', 'iPhone 13 Pro face avant', true, 1),
((SELECT id FROM listing WHERE title LIKE 'Huile de palme%'), '/media/listings/huile_palme_1.jpg', 'Bidons d''huile de palme', true, 1),
((SELECT id FROM listing WHERE title LIKE 'Sculpture traditionnelle%'), '/media/listings/sculpture_1.jpg', 'Sculpture ébène masque traditionnel', true, 1);

-- Tags pour les annonces
INSERT INTO listing_tag (listing_id, tag_id) VALUES
((SELECT id FROM listing WHERE title LIKE 'Toyota Corolla%'), (SELECT id FROM tag WHERE slug='occasion')),
((SELECT id FROM listing WHERE title LIKE 'Toyota Corolla%'), (SELECT id FROM tag WHERE slug='qualite')),
((SELECT id FROM listing WHERE title LIKE 'iPhone 13 Pro%'), (SELECT id FROM tag WHERE slug='neuf')),
((SELECT id FROM listing WHERE title LIKE 'iPhone 13 Pro%'), (SELECT id FROM tag WHERE slug='garantie')),
((SELECT id FROM listing WHERE title LIKE 'Huile de palme%'), (SELECT id FROM tag WHERE slug='artisanal')),
((SELECT id FROM listing WHERE title LIKE 'Huile de palme%'), (SELECT id FROM tag WHERE slug='local')),
((SELECT id FROM listing WHERE title LIKE 'Huile de palme%'), (SELECT id FROM tag WHERE slug='bio')),
((SELECT id FROM listing WHERE title LIKE 'Sculpture traditionnelle%'), (SELECT id FROM tag WHERE slug='fait-main')),
((SELECT id FROM listing WHERE title LIKE 'Sculpture traditionnelle%'), (SELECT id FROM tag WHERE slug='traditionnel')),
((SELECT id FROM listing WHERE title LIKE 'Sculpture traditionnelle%'), (SELECT id FROM tag WHERE slug='rare'));

-- =========================
-- Quelques favoris et interactions
-- =========================

-- Favoris
INSERT INTO user_favorite (user_id, listing_id) VALUES
((SELECT id FROM auth_user WHERE username='marie_dubois'), (SELECT id FROM listing WHERE title LIKE 'Toyota Corolla%')),
((SELECT id FROM auth_user WHERE username='john_doe'), (SELECT id FROM listing WHERE title LIKE 'Huile de palme%')),
((SELECT id FROM auth_user WHERE username='ibrahim_diallo'), (SELECT id FROM listing WHERE title LIKE 'iPhone 13 Pro%'));

-- Conversations
INSERT INTO conversation (listing_id, buyer_id, seller_id, last_message_at, created_at) VALUES
((SELECT id FROM listing WHERE title LIKE 'Toyota Corolla%'), 
 (SELECT id FROM auth_user WHERE username='marie_dubois'),
 (SELECT id FROM auth_user WHERE username='john_doe'),
 now() - interval '2 hours',
 now() - interval '1 day');

-- Messages
INSERT INTO message (conversation_id, sender_id, content, status, created_at) VALUES
((SELECT id FROM conversation LIMIT 1),
 (SELECT id FROM auth_user WHERE username='marie_dubois'),
 'Bonjour, votre Toyota Corolla m''intéresse. Est-il possible de la voir ce weekend ?',
 'read',
 now() - interval '1 day'),
 
((SELECT id FROM conversation LIMIT 1),
 (SELECT id FROM auth_user WHERE username='john_doe'),
 'Bonjour ! Oui bien sûr, je suis disponible samedi après-midi. Le véhicule est en excellent état.',
 'read',
 now() - interval '2 hours');

-- =========================
-- Mise à jour des compteurs
-- =========================

-- Mettre à jour les compteurs d'usage des tags
UPDATE tag SET usage_count = (
  SELECT COUNT(*) FROM listing_tag WHERE tag_id = tag.id
);

-- Mettre à jour les compteurs de listings par catégorie
UPDATE category SET listing_count = (
  SELECT COUNT(*) 
  FROM listing l 
  WHERE l.category_id IN (
    SELECT c2.id 
    FROM category c2 
    WHERE c2.path_ids @> ARRAY[category.id]
  )
  AND l.status = 'active'
);

-- =========================
-- Vérifications et statistiques
-- =========================

-- Afficher un résumé des données créées
DO $$
DECLARE
    cat_count INTEGER;
    user_count INTEGER;
    listing_count INTEGER;
    tag_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO cat_count FROM category;
    SELECT COUNT(*) INTO user_count FROM auth_user;
    SELECT COUNT(*) INTO listing_count FROM listing;
    SELECT COUNT(*) INTO tag_count FROM tag;
    
    RAISE NOTICE '=== DONNÉES CRÉÉES ===';
    RAISE NOTICE 'Catégories: %', cat_count;
    RAISE NOTICE 'Utilisateurs: %', user_count;
    RAISE NOTICE 'Annonces: %', listing_count;
    RAISE NOTICE 'Tags: %', tag_count;
    RAISE NOTICE '=====================';
END $$;

-- Exemples de requêtes de test (commentées)
/*
-- Voir la hiérarchie des catégories
SELECT 
  REPEAT('  ', depth-1) || name as category_tree,
  slug,
  depth,
  listing_count
FROM category 
ORDER BY path_ids;

-- Rechercher des annonces
SELECT * FROM search_listings('toyota');
SELECT * FROM search_listings('téléphone', 'electronique');

-- Voir les descendants d'une catégorie
SELECT * FROM category_descendants('vehicules');

-- Voir les relations entre catégories
SELECT * FROM category_related('voitures');
*/