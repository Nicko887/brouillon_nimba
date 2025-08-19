-- =====================================================================
-- Annonces d'exemple avec les VRAIES catégories créées
-- À exécuter APRÈS schema.sql et referentiel_corrige.sql
-- =====================================================================

-- =========================
-- Profils utilisateurs d'exemple

SET client_encoding TO 'UTF8';
-- =========================

SET client_encoding TO 'UTF8';



INSERT INTO user_profile (user_id, phone, bio, location, latitude, longitude, email_verified, phone_verified, rating_average, rating_count) VALUES
  (1, '+224 622 123 456', 'Vendeur particulier depuis 3 ans', 'Kaloum, Conakry', 9.5092, -13.7122, TRUE, TRUE, 4.8, 25),
  (2, '+224 664 789 012', 'Boutique de materiel informatique', 'Matam, Conakry', 9.5370, -13.6785, TRUE, TRUE, 4.5, 42),
  (3, '+224 655 345 678', 'Artisan local specialise en textile', 'Kindia', 10.0570, -12.8470, TRUE, FALSE, 4.9, 18),
  (4, '+224 628 901 234', 'Concessionnaire automobile', 'Dixinn, Conakry', 9.5580, -13.6840, TRUE, TRUE, 4.2, 67),
  (5, '+224 666 567 890', 'Producteur agricole', 'Coyah', 9.7100, -13.3850, TRUE, TRUE, 4.7, 12),
  (6, '+224 620 111 222', 'Etudiante a l''universite', 'Ratoma, Conakry', 9.5720, -13.6520, TRUE, TRUE, 4.6, 8),
  (7, '+224 654 333 444', 'Chef d''entreprise', 'Almamya, Conakry', 9.5150, -13.7020, TRUE, TRUE, 4.3, 33),
  (8, '+224 677 555 666', 'Artisan menuisier', 'Kankan', 10.3883, -9.3061, FALSE, TRUE, 4.8, 15);

-- =========================
-- ANNONCES RÉALISTES
-- =========================

INSERT INTO listing (user_id, category_id, title, slug, description, price_cents, is_negotiable, condition, status, location, latitude, longitude, view_count, favorite_count, contact_count, expires_at) VALUES

-- === VÉHICULES ===

-- Voitures (récupérer l'ID de la catégorie Voitures)
(4, (SELECT id FROM category WHERE slug = 'voitures'), 
 'Toyota Corolla 2018 - Tres bon etat', 
 'toyota-corolla-2018-tres-bon-etat',
 'Vehicule bien entretenu, revisions a jour. Climatisation, direction assistee, vitres electriques. Ideal pour famille ou professionnel. Possibilite de voir le vehicule sur rendez-vous.',
 1250000000, TRUE, 'good', 'active', 'Dixinn, Conakry', 9.5580, -13.6840, 156, 23, 12,
 now() + interval '30 days'),

(1, (SELECT id FROM category WHERE slug = 'voitures'), 
 'Nissan Almera 2015 a vendre rapidement', 
 'nissan-almera-2015-a-vendre-rapidement',
 'Cause depart urgent. Voiture fiable, consommation raisonnable. Quelques eraflures mais moteur en parfait etat. Papiers en regle.',
 950000000, TRUE, 'fair', 'active', 'Kaloum, Conakry', 9.5092, -13.7122, 89, 15, 8,
 now() + interval '45 days'),

-- Motos 
(7, (SELECT id FROM category WHERE slug = 'motos'), 
 'Yamaha 125cc - Parfait pour livraisons', 
 'yamaha-125cc-parfait-pour-livraisons',
 'Moto robuste et economique. Ideale pour le transport urbain ou les livraisons. Entretien regulier effectue.',
 85000000, TRUE, 'good', 'active', 'Almamya, Conakry', 9.5150, -13.7020, 234, 41, 18,
 now() + interval '20 days'),

-- === ÉLECTRONIQUE ===

-- Ordinateurs
(2, (SELECT id FROM category WHERE slug = 'ordinateurs'), 
 'Laptop Dell Inspiron 15 - Ideal etudiant', 
 'laptop-dell-inspiron-15-ideal-etudiant',
 'Ordinateur portable en excellent etat. Intel Core i5, 8GB RAM, 256GB SSD. Parfait pour les etudes, bureautique et navigation internet.',
 420000000, TRUE, 'good', 'active', 'Matam, Conakry', 9.5370, -13.6785, 145, 19, 9,
 now() + interval '40 days'),

-- Téléphones (si la catégorie existe)
(2, (SELECT id FROM category WHERE slug = 'telephones-objets-connectes'), 
 'iPhone 13 128GB - Etat neuf sous garantie', 
 'iphone-13-128gb-etat-neuf-sous-garantie',
 'Telephone achete il y a 6 mois, tres peu utilise. Vendu avec chargeur original, ecouteurs et boite. Aucun defaut visible.',
 720000000, FALSE, 'like_new', 'active', 'Matam, Conakry', 9.5370, -13.6785, 312, 67, 28,
 now() + interval '15 days'),

(6, (SELECT id FROM category WHERE slug = 'telephones-objets-connectes'), 
 'Samsung Galaxy A32 - Bon etat', 
 'samsung-galaxy-a32-bon-etat',
 'Smartphone fonctionnel, quelques micro-rayures sur l''ecran mais sans impact sur l''utilisation. Batterie tient encore bien la charge.',
 45000000, TRUE, 'good', 'active', 'Ratoma, Conakry', 9.5720, -13.6520, 178, 22, 15,
 now() + interval '25 days'),

-- === PRODUITS LOCAUX ===

-- Huile de palme (niveau 3)
(5, (SELECT id FROM category WHERE slug = 'huile-palme'), 
 'Huile de palme artisanale - Production familiale', 
 'huile-de-palme-artisanale-production-familiale',
 'Huile de palme pure, produite de maniere traditionnelle dans notre plantation familiale. Qualite superieure, sans additifs. Livraison possible sur Conakry.',
 1500000, TRUE, 'new', 'active', 'Coyah', 9.7100, -13.3850, 89, 12, 7,
 now() + interval '10 days'),

-- Bananes
(5, (SELECT id FROM category WHERE slug = 'banane'), 
 'Bananes douces - Regime entier', 
 'bananes-douces-regime-entier',
 'Bananes fraiches de notre plantation. Parfaitement mures, ideales pour consommation immediate ou pour revente. Prix degressif selon quantite.',
 800000, TRUE, 'new', 'active', 'Coyah', 9.7100, -13.3850, 45, 3, 2,
 now() + interval '3 days'),

-- === IMMOBILIER ===

-- Locations
(1, (SELECT id FROM category WHERE slug = 'locations'), 
 'Appartement 3 pieces - Quartier residentiel', 
 'appartement-3-pieces-quartier-residentiel',
 'Bel appartement au 2eme etage, 3 chambres, salon, cuisine equipee. Quartier calme et securise. Eau et electricite regulieres.',
 180000000, TRUE, NULL, 'active', 'Kaloum, Conakry', 9.5092, -13.7122, 289, 45, 23,
 now() + interval '45 days'),

-- === EMPLOI ===

-- CDI (en supposant qu'il y a une sous-catégorie CDI sous Emploi)
(7, (SELECT id FROM category WHERE name = 'Emploi'), 
 'Recherche Comptable experimente(e) - CDI', 
 'recherche-comptable-experimente-cdi',
 'Entreprise en expansion recherche comptable avec minimum 3 ans d''experience. Maitrise des logiciels comptables exigee. Salaire motivant + avantages.',
 0, FALSE, NULL, 'active', 'Almamya, Conakry', 9.5150, -13.7020, 423, 89, 67,
 now() + interval '30 days'),

-- === ANNONCES VENDUES (historique) ===

(4, (SELECT id FROM category WHERE slug = 'voitures'), 
 'Honda Civic 2016 - VENDUE', 
 'honda-civic-2016-vendue',
 'Vehicule vendu rapidement grace a la plateforme. Merci aux acheteurs serieux !',
 1100000000, TRUE, 'good', 'sold', 'Dixinn, Conakry', 9.5580, -13.6840, 345, 89, 45,
 now() + interval '30 days');

-- =========================
-- TAGS sur les annonces
-- =========================

-- iPhone avec tags "Haut de gamme" et "Etat parfait"
INSERT INTO listing_tag (listing_id, tag_id) VALUES
  ((SELECT id FROM listing WHERE slug = 'iphone-13-128gb-etat-neuf-sous-garantie'), (SELECT id FROM tag WHERE slug = 'haut-de-gamme')),
  ((SELECT id FROM listing WHERE slug = 'iphone-13-128gb-etat-neuf-sous-garantie'), (SELECT id FROM tag WHERE slug = 'etat-parfait'));

-- Huile de palme avec "Produit local" et "Artisanal"  
INSERT INTO listing_tag (listing_id, tag_id) VALUES
  ((SELECT id FROM listing WHERE slug = 'huile-de-palme-artisanale-production-familiale'), (SELECT id FROM tag WHERE slug = 'produit-local')),
  ((SELECT id FROM listing WHERE slug = 'huile-de-palme-artisanale-production-familiale'), (SELECT id FROM tag WHERE slug = 'artisanal'));

-- Voiture avec "Occasion" et "A negocier"
INSERT INTO listing_tag (listing_id, tag_id) VALUES
  ((SELECT id FROM listing WHERE slug = 'toyota-corolla-2018-tres-bon-etat'), (SELECT id FROM tag WHERE slug = 'occasion')),
  ((SELECT id FROM listing WHERE slug = 'toyota-corolla-2018-tres-bon-etat'), (SELECT id FROM tag WHERE slug = 'a-negocier'));

-- =========================
-- STATISTIQUES FINALES
-- =========================

-- Résumé des annonces créées
SELECT 
  c.name as categorie,
  COUNT(l.id) as nb_annonces,
  ROUND(AVG(l.price_cents/1000000), 0) as prix_moyen_gnf
FROM category c
LEFT JOIN listing l ON c.id = l.category_id AND l.status = 'active'
GROUP BY c.name, c.depth
HAVING COUNT(l.id) > 0
ORDER BY nb_annonces DESC;

-- Annonces les plus consultées
SELECT 
  title,
  view_count,
  favorite_count,
  ROUND(price_cents/1000000, 0) as prix_gnf,
  location
FROM listing 
WHERE status = 'active'
ORDER BY view_count DESC
LIMIT 10;

-- Vérification des tags associés
SELECT 
  l.title,
  array_agg(t.name) as tags
FROM listing l
JOIN listing_tag lt ON l.id = lt.listing_id
JOIN tag t ON lt.tag_id = t.id
GROUP BY l.title;

