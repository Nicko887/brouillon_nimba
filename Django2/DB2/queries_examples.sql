-- =====================================================================
-- EXEMPLES COMPLETS D'UTILISATION DU SCHÉMA
-- Requêtes pour exploiter toutes les fonctionnalités
-- =====================================================================

-- =========================
-- 1. GESTION DES CATÉGORIES
-- =========================

-- Afficher l'arbre complet des catégories avec indentation
SELECT 
  REPEAT('  ', depth-1) || name as category_tree,
  slug,
  kind,
  listing_count,
  is_active
FROM category 
WHERE is_active = true
ORDER BY path_ids;

-- Descendants d'une catégorie (tous les niveaux inférieurs)
SELECT 
  c.name,
  c.slug,
  c.depth,
  c.listing_count,
  REPEAT('  ', c.depth - root.depth) || c.name as indented_name
FROM category root,
     category c
WHERE root.slug = 'vehicules'
  AND c.path_ids @> ARRAY[root.id]
ORDER BY c.path_ids;

-- Fil d'Ariane (breadcrumb) pour une catégorie
WITH RECURSIVE breadcrumb AS (
  SELECT id, name, slug, parent_id, 1 as level
  FROM category 
  WHERE slug = 'equipement-auto'
  
  UNION ALL
  
  SELECT c.id, c.name, c.slug, c.parent_id, b.level + 1
  FROM category c
  JOIN breadcrumb b ON c.id = b.parent_id
)
SELECT name, slug, level
FROM breadcrumb
ORDER BY level DESC;

-- Catégories populaires (plus d'annonces)
SELECT 
  c.name,
  c.slug,
  c.listing_count,
  c.kind
FROM category c
WHERE c.depth > 1  -- Exclut les racines
  AND c.listing_count > 0
ORDER BY c.listing_count DESC
LIMIT 10;

-- Relations entre catégories
SELECT 
  s.name as source_category,
  t.name as target_category,
  cr.relation_type,
  cr.created_at
FROM category_relation cr
JOIN category s ON cr.source_category_id = s.id
JOIN category t ON cr.target_category_id = t.id
ORDER BY s.name, cr.relation_type;

-- =========================
-- 2. RECHERCHE D'ANNONCES
-- =========================

-- Recherche simple par mot-clé
SELECT * FROM search_listings('toyota');

-- Recherche avec filtres multiples
SELECT * FROM search_listings(
  search_query := 'téléphone',
  category_slug := 'electronique',
  min_price := 500000,  -- 5000 GNF
  max_price := 10000000, -- 100000 GNF
  limit_count := 10
);

-- Recherche géolocalisée (dans un rayon de 25km de Conakry)
SELECT 
  id,
  title,
  location,
  distance_km,
  price_cents/100.0 as price_gnf
FROM search_listings(
  lat := 9.6412,
  lng := -13.5784,
  radius_km := 25,
  limit_count := 20
)
WHERE distance_km IS NOT NULL
ORDER BY distance_km;

-- Recherche full-text avancée avec ranking
SELECT 
  l.id,
  l.title,
  l.price_cents/100.0 as price_gnf,
  l.location,
  ts_rank(l.search_vector, query) as rank,
  ts_headline('french', l.description, query) as highlighted_desc
FROM listing l,
     plainto_tsquery('french', 'voiture toyota corolla') as query
WHERE l.search_vector @@ query
  AND l.status = 'active'
ORDER BY rank DESC;

-- =========================
-- 3. GESTION DES ANNONCES
-- =========================

-- Créer une nouvelle annonce complète
WITH new_listing AS (
  INSERT INTO listing (
    user_id, category_id, title, description, 
    price_cents, location, latitude, longitude,
    condition, status
  ) VALUES (
    (SELECT id FROM auth_user WHERE username = 'john_doe'),
    (SELECT id FROM category WHERE slug = 'voitures'),
    'Peugeot 308 2019 - Parfait état',
    'Véhicule récent, peu de kilomètres, toutes options. Entretien suivi en concession.',
    12500000, -- 125,000 GNF
    'Dixinn, Conakry',
    9.5515, -13.6919,
    'good',
    'active'
  ) RETURNING id
)
-- Ajouter des images
INSERT INTO listing_image (listing_id, image, alt_text, is_primary, sort_order)
SELECT 
  nl.id,
  unnest(ARRAY['/media/peugeot_1.jpg', '/media/peugeot_2.jpg']),
  unnest(ARRAY['Peugeot 308 extérieur', 'Peugeot 308 intérieur']),
  unnest(ARRAY[true, false]),
  unnest(ARRAY[1, 2])
FROM new_listing nl;

-- Annonces expirées à désactiver
UPDATE listing 
SET status = 'expired'
WHERE status = 'active' 
  AND expires_at < now()
RETURNING id, title;

-- Statistiques d'une annonce
SELECT 
  l.title,
  l.view_count,
  l.favorite_count,
  l.contact_count,
  COUNT(DISTINCT c.id) as conversation_count,
  COUNT(DISTINCT m.id) as message_count
FROM listing l
LEFT JOIN conversation c ON l.id = c.listing_id
LEFT JOIN message m ON c.id = m.conversation_id
WHERE l.id = 1
GROUP BY l.id, l.title, l.view_count, l.favorite_count, l.contact_count;

-- Annonces similaires (même catégorie + prix proche)
WITH target AS (
  SELECT category_id, price_cents 
  FROM listing 
  WHERE id = 1
)
SELECT 
  l.id,
  l.title,
  l.price_cents/100.0 as price_gnf,
  ABS(l.price_cents - t.price_cents) as price_diff
FROM listing l, target t
WHERE l.category_id = t.category_id
  AND l.id != 1
  AND l.status = 'active'
  AND ABS(l.price_cents - t.price_cents) < t.price_cents * 0.3 -- ±30%
ORDER BY price_diff
LIMIT 5;

-- =========================
-- 4. GESTION DES UTILISATEURS
-- =========================

-- Profil utilisateur complet avec statistiques
SELECT 
  u.username,
  u.first_name,
  u.last_name,
  u.email,
  up.phone,
  up.location,
  up.rating_average,
  up.rating_count,
  up.status,
  COUNT(DISTINCT l.id) as total_listings,
  COUNT(DISTINCT l.id) FILTER (WHERE l.status = 'active') as active_listings,
  COUNT(DISTINCT l.id) FILTER (WHERE l.status = 'sold') as sold_listings,
  COUNT(DISTINCT f.id) as favorite_count
FROM auth_user u
JOIN user_profile up ON u.id = up.user_id
LEFT JOIN listing l ON u.id = l.user_id
LEFT JOIN user_favorite f ON u.id = f.user_id
WHERE u.username = 'john_doe'
GROUP BY u.id, up.id;

-- Top vendeurs par notes
SELECT 
  u.username,
  u.first_name,
  u.last_name,
  up.rating_average,
  up.rating_count,
  COUNT(l.id) as active_listings
FROM auth_user u
JOIN user_profile up ON u.id = up.user_id
LEFT JOIN listing l ON u.id = l.user_id AND l.status = 'active'
WHERE up.rating_count >= 3
  AND up.status = 'active'
GROUP BY u.id, up.id
ORDER BY up.rating_average DESC, up.rating_count DESC
LIMIT 10;

-- Favoris d'un utilisateur avec détails
SELECT 
  l.id,
  l.title,
  l.price_cents/100.0 as price_gnf,
  l.location,
  c.name as category_name,
  seller.username as seller,
  f.created_at as favorited_at
FROM user_favorite f
JOIN listing l ON f.listing_id = l.id
JOIN category c ON l.category_id = c.id
JOIN auth_user seller ON l.user_id = seller.id
WHERE f.user_id = (SELECT id FROM auth_user WHERE username = 'marie_dubois')
  AND l.status = 'active'
ORDER BY f.created_at DESC;

-- =========================
-- 5. MESSAGERIE ET CONVERSATIONS
-- =========================

-- Conversations d'un utilisateur
SELECT 
  c.id,
  l.title as listing_title,
  CASE 
    WHEN c.buyer_id = (SELECT id FROM auth_user WHERE username = 'john_doe')
    THEN seller.username 
    ELSE buyer.username 
  END as other_user,
  c.last_message_at,
  COUNT(m.id) as message_count,
  COUNT(m.id) FILTER (WHERE m.read_at IS NULL AND m.sender_id != (SELECT id FROM auth_user WHERE username = 'john_doe')) as unread_count
FROM conversation c
JOIN listing l ON c.listing_id = l.id
JOIN auth_user buyer ON c.buyer_id = buyer.id
JOIN auth_user seller ON c.seller_id = seller.id
LEFT JOIN message m ON c.id = m.conversation_id
WHERE c.buyer_id = (SELECT id FROM auth_user WHERE username = 'john_doe')
   OR c.seller_id = (SELECT id FROM auth_user WHERE username = 'john_doe')
GROUP BY c.id, l.title, buyer.username, seller.username
ORDER BY c.last_message_at DESC;

-- Messages d'une conversation
SELECT 
  m.id,
  sender.username as sender,
  m.content,
  m.status,
  m.created_at,
  m.read_at
FROM message m
JOIN auth_user sender ON m.sender_id = sender.id
WHERE m.conversation_id = 1
ORDER BY m.created_at;

-- Marquer les messages comme lus
UPDATE message 
SET status = 'read', read_at = now()
WHERE conversation_id = 1
  AND sender_id != (SELECT id FROM auth_user WHERE username = 'john_doe')
  AND read_at IS NULL;

-- =========================
-- 6. TAGS ET RECHERCHES SAUVEGARDÉES
-- =========================

-- Tags les plus populaires
SELECT 
  t.name,
  t.slug,
  t.usage_count
FROM tag t
WHERE t.usage_count > 0
ORDER BY t.usage_count DESC
LIMIT 20;

-- Annonces avec tags spécifiques
SELECT 
  l.title,
  l.price_cents/100.0 as price_gnf,
  STRING_AGG(t.name, ', ') as tags
FROM listing l
JOIN listing_tag lt ON l.id = lt.listing_id
JOIN tag t ON lt.tag_id = t.id
WHERE l.status = 'active'
GROUP BY l.id, l.title, l.price_cents
HAVING STRING_AGG(t.name, ', ') ILIKE '%neuf%'
ORDER BY l.created_at DESC;

-- Sauvegarder une recherche
INSERT INTO saved_search (user_id, name, query_params, email_alerts)
VALUES (
  (SELECT id FROM auth_user WHERE username = 'marie_dubois'),
  'Voitures Toyota 100k-200k',
  '{"search_query": "toyota", "category_slug": "voitures", "min_price": 10000000, "max_price": 20000000}',
  true
);

-- =========================
-- 7. STATISTIQUES ET ANALYTICS
-- =========================

-- Statistiques globales du site
SELECT 
  (SELECT COUNT(*) FROM auth_user WHERE is_active = true) as active_users,
  (SELECT COUNT(*) FROM listing WHERE status = 'active') as active_listings,
  (SELECT COUNT(*) FROM listing WHERE status = 'sold') as sold_listings,
  (SELECT COUNT(*) FROM category WHERE is_active = true) as categories,
  (SELECT COUNT(*) FROM conversation) as conversations,
  (SELECT COUNT(*) FROM message) as messages;

-- Évolution des annonces par jour (7 derniers jours)
SELECT 
  DATE(created_at) as day,
  COUNT(*) as new_listings,
  COUNT(*) FILTER (WHERE status = 'active') as active_listings
FROM listing
WHERE created_at >= now() - interval '7 days'
GROUP BY DATE(created_at)
ORDER BY day;

-- Catégories les plus populaires
SELECT 
  c.name,
  c.listing_count,
  COUNT(l.id) as new_this_month,
  AVG(l.price_cents/100.0) as avg_price_gnf
FROM category c
LEFT JOIN listing l ON c.id = l.category_id 
  AND l.created_at >= date_trunc('month', now())
  AND l.status = 'active'
WHERE c.depth > 1
GROUP BY c.id, c.name, c.listing_count
ORDER BY c.listing_count DESC
LIMIT 15;

-- Prix moyens par catégorie
SELECT 
  c.name as category,
  COUNT(l.id) as listing_count,
  ROUND(AVG(l.price_cents/100.0)) as avg_price_gnf,
  ROUND(MIN(l.price_cents/100.0)) as min_price_gnf,
  ROUND(MAX(l.price_cents/100.0)) as max_price_gnf
FROM category c
JOIN listing l ON c.id = l.category_id
WHERE l.status = 'active'
  AND l.price_cents IS NOT NULL
GROUP BY c.id, c.name
HAVING COUNT(l.id) >= 2
ORDER BY avg_price_gnf DESC;

-- =========================
-- 8. MODÉRATION ET ADMINISTRATION
-- =========================

-- Signalements en attente
SELECT 
  r.id,
  r.reason,
  r.description,
  l.title as listing_title,
  reporter.username as reporter,
  r.created_at
FROM report r
LEFT JOIN listing l ON r.listing_id = l.id
LEFT JOIN auth_user reported_user ON r.user_id = reported_user.id
JOIN auth_user reporter ON r.reporter_id = reporter.id
WHERE r.status = 'pending'
ORDER BY r.created_at;

-- Utilisateurs suspects (beaucoup de signalements)
SELECT 
  u.username,
  u.email,
  up.status,
  COUNT(r.id) as report_count,
  COUNT(DISTINCT r.reporter_id) as unique_reporters
FROM auth_user u
JOIN user_profile up ON u.id = up.user_id
JOIN report r ON u.id = r.user_id
GROUP BY u.id, up.status
HAVING COUNT(r.id) >= 3
ORDER BY report_count DESC;

-- Annonces nécessitant une modération
SELECT 
  l.id,
  l.title,
  l.created_at,
  u.username as seller,
  COUNT(r.id) as report_count
FROM listing l
JOIN auth_user u ON l.user_id = u.id
LEFT JOIN report r ON l.id = r.listing_id
WHERE l.status = 'active'
GROUP BY l.id, u.username
HAVING COUNT(r.id) > 0
ORDER BY report_count DESC, l.created_at DESC;

-- =========================
-- 9. REQUÊTES DE PERFORMANCE
-- =========================

-- Index utilization (à exécuter en tant qu'admin)
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_tup_read DESC;

-- Requêtes lentes potentielles (listings sans géolocalisation)
SELECT id, title, location
FROM listing
WHERE status = 'active'
  AND location IS NOT NULL
  AND (latitude IS NULL OR longitude IS NULL)
LIMIT 10;

-- Nettoyage des données obsolètes
-- Supprimer les annonces expirées depuis plus de 30 jours
DELETE FROM listing
WHERE status = 'expired'
  AND expires_at < now() - interval '30 days';

-- =========================
-- 10. EXEMPLES D'USAGE DJANGO ORM ÉQUIVALENTS
-- =========================

/*
-- Ces requêtes SQL correspondent à ces appels Django ORM :

-- Recherche simple
Listing.objects.filter(
    search_vector__search='toyota',
    status='active'
).order_by('-created_at')

-- Catégories avec compteurs
Category.objects.select_related().annotate(
    listing_count=Count('listing', 
        filter=Q(listing__status='active'))
).order_by('-listing_count')

-- Profil utilisateur avec stats
User.objects.select_related('user_profile').annotate(
    total_listings=Count('listing'),
    active_listings=Count('listing', 
        filter=Q(listing__status='active'))
).get(username='john_doe')

-- Favoris d'un utilisateur
UserFavorite.objects.select_related(
    'listing__category', 'listing__user'
).filter(user=user).order_by('-created_at')

-- Conversations avec compteur de messages
Conversation.objects.select_related(
    'listing', 'buyer', 'seller'
).annotate(
    message_count=Count('message'),
    unread_count=Count('message', 
        filter=Q(message__read_at__isnull=True))
).filter(Q(buyer=user) | Q(seller=user))
*/