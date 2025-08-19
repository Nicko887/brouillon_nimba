-- =====================================================================
--  Schéma HYBRIDE PostgreSQL + Django pour petites annonces
--  Garde les avantages PostgreSQL + Compatibilité Django ORM
-- =====================================================================

-- =========================
-- ÉTAPE 1: Extensions PostgreSQL (ON GARDE)
-- =========================
-- Extensions utiles pour la performance
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
-- CREATE EXTENSION IF NOT EXISTS postgis;  -- Si géolocalisation avancée nécessaire

-- =========================
-- ÉTAPE 2: Tables principales (COMPATIBLE DJANGO)
-- =========================

-- User Profile (Django créera auth_user automatiquement)
CREATE TABLE user_profile (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT UNIQUE NOT NULL,  -- FK vers auth_user, Django s'en charge
  phone VARCHAR(20),
  avatar VARCHAR(200),
  bio TEXT,
  location VARCHAR(255),
  latitude DECIMAL(10,8),
  longitude DECIMAL(11,8),
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  phone_verified BOOLEAN NOT NULL DEFAULT FALSE,
  rating_average DECIMAL(3,2) DEFAULT 0.00,
  rating_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  -- Contraintes Django-compatible
  CONSTRAINT chk_profile_status CHECK (status IN ('active','suspended','banned','pending_verification')),
  CONSTRAINT chk_profile_rating CHECK (rating_average >= 0 AND rating_average <= 5)
);

-- Catégories (VERSION SIMPLIFIÉE pour Django)
CREATE TABLE category (
  id BIGSERIAL PRIMARY KEY,
  parent_id BIGINT,
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(255) NOT NULL UNIQUE,
  kind VARCHAR(20) NOT NULL DEFAULT 'goods',
  description TEXT,
  icon VARCHAR(100),
  image VARCHAR(200),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  depth INTEGER NOT NULL DEFAULT 1,
  listing_count INTEGER NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  CONSTRAINT chk_category_kind CHECK (kind IN ('goods','services','real_estate','jobs','vehicles','other')),
  CONSTRAINT fk_category_parent FOREIGN KEY (parent_id) REFERENCES category(id) ON DELETE CASCADE
);

-- Annonces (COMPATIBLE DJANGO + fonctionnalités avancées)
CREATE TABLE listing (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  category_id BIGINT NOT NULL,
  title VARCHAR(255) NOT NULL,
  slug VARCHAR(255) UNIQUE,
  description TEXT,
  price_cents BIGINT,
  currency VARCHAR(3) NOT NULL DEFAULT 'GNF',
  is_negotiable BOOLEAN NOT NULL DEFAULT TRUE,
  condition VARCHAR(20),
  status VARCHAR(20) NOT NULL DEFAULT 'draft',
  
  -- Géolocalisation
  location VARCHAR(255),
  latitude DECIMAL(10,8),
  longitude DECIMAL(11,8),
  
  -- SEO et recherche (ON GARDE search_vector)
  meta_title VARCHAR(255),
  meta_description TEXT,
  search_vector tsvector,  -- PostgreSQL full-text search
  
  -- Statistiques
  view_count INTEGER NOT NULL DEFAULT 0,
  favorite_count INTEGER NOT NULL DEFAULT 0,
  contact_count INTEGER NOT NULL DEFAULT 0,
  
  -- Dates importantes
  expires_at TIMESTAMPTZ,
  featured_until TIMESTAMPTZ,
  sold_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  CONSTRAINT chk_listing_condition CHECK (condition IN ('new','like_new','good','fair','poor')),
  CONSTRAINT chk_listing_status CHECK (status IN ('draft','active','sold','expired','suspended','deleted')),
  CONSTRAINT fk_listing_category FOREIGN KEY (category_id) REFERENCES category(id) ON DELETE RESTRICT
);

-- Tables complémentaires (toutes Django-compatible)
CREATE TABLE listing_image (
  id BIGSERIAL PRIMARY KEY,
  listing_id BIGINT NOT NULL,
  image VARCHAR(200) NOT NULL,
  alt_text VARCHAR(255),
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fk_listingimg_listing FOREIGN KEY (listing_id) REFERENCES listing(id) ON DELETE CASCADE
);

CREATE TABLE tag (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(100) UNIQUE NOT NULL,
  slug VARCHAR(100) UNIQUE NOT NULL,
  usage_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE listing_tag (
  id BIGSERIAL PRIMARY KEY,
  listing_id BIGINT NOT NULL,
  tag_id BIGINT NOT NULL,
  CONSTRAINT fk_listingtag_listing FOREIGN KEY (listing_id) REFERENCES listing(id) ON DELETE CASCADE,
  CONSTRAINT fk_listingtag_tag FOREIGN KEY (tag_id) REFERENCES tag(id) ON DELETE CASCADE,
  UNIQUE (listing_id, tag_id)
);

CREATE TABLE user_favorite (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  listing_id BIGINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fk_favorite_listing FOREIGN KEY (listing_id) REFERENCES listing(id) ON DELETE CASCADE,
  UNIQUE (user_id, listing_id)
);

CREATE TABLE conversation (
  id BIGSERIAL PRIMARY KEY,
  listing_id BIGINT NOT NULL,
  buyer_id BIGINT NOT NULL,
  seller_id BIGINT NOT NULL,
  last_message_at TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fk_conversation_listing FOREIGN KEY (listing_id) REFERENCES listing(id) ON DELETE CASCADE,
  UNIQUE (listing_id, buyer_id, seller_id)
);

CREATE TABLE message (
  id BIGSERIAL PRIMARY KEY,
  conversation_id BIGINT NOT NULL,
  sender_id BIGINT NOT NULL,
  content TEXT NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'sent',
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_message_status CHECK (status IN ('sent','delivered','read')),
  CONSTRAINT fk_message_conversation FOREIGN KEY (conversation_id) REFERENCES conversation(id) ON DELETE CASCADE
);

CREATE TABLE user_rating (
  id BIGSERIAL PRIMARY KEY,
  rater_id BIGINT NOT NULL,
  rated_id BIGINT NOT NULL,
  listing_id BIGINT,
  rating INTEGER NOT NULL,
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_rating CHECK (rating >= 1 AND rating <= 5),
  CONSTRAINT fk_rating_listing FOREIGN KEY (listing_id) REFERENCES listing(id) ON DELETE SET NULL,
  UNIQUE (rater_id, rated_id, listing_id)
);

CREATE TABLE saved_search (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  name VARCHAR(255) NOT NULL,
  query_params JSONB NOT NULL,  -- ON GARDE JSONB
  email_alerts BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================
-- ÉTAPE 3: Index de performance (ON GARDE TOUT)
-- =========================

-- Catégories
CREATE INDEX idx_category_parent ON category(parent_id);
CREATE INDEX idx_category_slug ON category(slug);
CREATE INDEX idx_category_kind ON category(kind);
CREATE INDEX idx_category_active ON category(is_active);

-- Annonces (INDEX CRITIQUES)
CREATE INDEX idx_listing_user ON listing(user_id);
CREATE INDEX idx_listing_category ON listing(category_id);
CREATE INDEX idx_listing_status ON listing(status);
CREATE INDEX idx_listing_location ON listing(latitude, longitude);
CREATE INDEX idx_listing_price ON listing(price_cents);
CREATE INDEX idx_listing_created ON listing(created_at DESC);
CREATE INDEX idx_listing_featured ON listing(featured_until) WHERE featured_until IS NOT NULL;
CREATE INDEX idx_listing_slug ON listing(slug);

-- Index pour recherche full-text (CRITIQUE)
CREATE INDEX idx_listing_search_gin ON listing USING GIN (search_vector);

-- Autres index importants
CREATE INDEX idx_listing_image_listing ON listing_image(listing_id);
CREATE INDEX idx_listing_image_primary ON listing_image(listing_id, is_primary);
CREATE INDEX idx_favorite_user ON user_favorite(user_id);
CREATE INDEX idx_favorite_listing ON user_favorite(listing_id);
CREATE INDEX idx_conversation_listing ON conversation(listing_id);
CREATE INDEX idx_message_conversation ON message(conversation_id);

-- =========================
-- ÉTAPE 4: Fonctions PostgreSQL spécialisées (ON GARDE)
-- =========================

-- Fonction de recherche géolocalisée (TROP COMPLEXE pour Django ORM)
CREATE OR REPLACE FUNCTION search_listings(
  search_query TEXT DEFAULT NULL,
  category_id_param BIGINT DEFAULT NULL,
  min_price BIGINT DEFAULT NULL,
  max_price BIGINT DEFAULT NULL,
  lat DECIMAL DEFAULT NULL,
  lng DECIMAL DEFAULT NULL,
  radius_km INTEGER DEFAULT 50,
  limit_count INTEGER DEFAULT 20,
  offset_count INTEGER DEFAULT 0
)
RETURNS TABLE(
  id BIGINT,
  title TEXT,
  slug TEXT,
  price_cents BIGINT,
  currency TEXT,
  location TEXT,
  distance_km DECIMAL,
  created_at TIMESTAMPTZ,
  primary_image TEXT,
  user_rating DECIMAL,
  rank REAL
)
LANGUAGE sql STABLE AS $$
  WITH search_results AS (
    SELECT 
      l.id, l.title, l.slug, l.price_cents, l.currency, 
      l.location, l.created_at,
      CASE 
        WHEN lat IS NOT NULL AND lng IS NOT NULL AND l.latitude IS NOT NULL AND l.longitude IS NOT NULL
        THEN ROUND((6371 * acos(cos(radians(lat)) * cos(radians(l.latitude)) * 
             cos(radians(l.longitude) - radians(lng)) + sin(radians(lat)) * 
             sin(radians(l.latitude))))::DECIMAL, 2)
        ELSE NULL 
      END as distance_km,
      (SELECT image FROM listing_image WHERE listing_id = l.id AND is_primary = true LIMIT 1) as primary_image,
      up.rating_average as user_rating,
      CASE 
        WHEN search_query IS NOT NULL 
        THEN ts_rank(l.search_vector, plainto_tsquery('french', search_query))
        ELSE 0 
      END as rank
    FROM listing l
    JOIN user_profile up ON l.user_id = up.user_id
    WHERE l.status = 'active'
      AND (l.expires_at IS NULL OR l.expires_at > now())
      AND (search_query IS NULL OR l.search_vector @@ plainto_tsquery('french', search_query))
      AND (category_id_param IS NULL OR l.category_id = category_id_param)
      AND (min_price IS NULL OR l.price_cents >= min_price)
      AND (max_price IS NULL OR l.price_cents <= max_price)
      AND (lat IS NULL OR lng IS NULL OR 
           (l.latitude IS NOT NULL AND l.longitude IS NOT NULL AND
            6371 * acos(cos(radians(lat)) * cos(radians(l.latitude)) * 
            cos(radians(l.longitude) - radians(lng)) + sin(radians(lat)) * 
            sin(radians(l.latitude))) <= radius_km))
  )
  SELECT * FROM search_results
  ORDER BY 
    CASE WHEN search_query IS NOT NULL THEN rank END DESC,
    distance_km ASC NULLS LAST,
    created_at DESC
  LIMIT limit_count OFFSET offset_count;
$$;

-- Fonction pour mettre à jour le search_vector (SERA APPELÉE PAR DJANGO)
CREATE OR REPLACE FUNCTION update_listing_search_vector(listing_id_param BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE listing 
  SET search_vector = 
    setweight(to_tsvector('french', coalesce(title,'')), 'A') ||
    setweight(to_tsvector('french', coalesce(description,'')), 'B') ||
    setweight(to_tsvector('french', coalesce(location,'')), 'C')
  WHERE id = listing_id_param;
END;
$$;

-- Vue optimisée pour les annonces actives
CREATE OR REPLACE VIEW active_listings AS
SELECT 
  l.id,
  l.title,
  l.slug,
  l.description,
  l.price_cents,
  l.currency,
  l.location,
  l.latitude,
  l.longitude,
  l.view_count,
  l.favorite_count,
  l.created_at,
  l.user_id,
  l.category_id,
  c.name as category_name,
  c.slug as category_slug,
  up.rating_average as user_rating,
  (SELECT image FROM listing_image WHERE listing_id = l.id AND is_primary = true LIMIT 1) as primary_image
FROM listing l
JOIN category c ON l.category_id = c.id
JOIN user_profile up ON l.user_id = up.user_id
WHERE l.status = 'active'
  AND (l.expires_at IS NULL OR l.expires_at > now())
  AND up.status = 'active';

-- =========================
-- ÉTAPE 5: Fonctions utilitaires Django peut utiliser
-- =========================

-- Fonction pour calculer les statistiques d'une catégorie
CREATE OR REPLACE FUNCTION get_category_stats(category_id_param BIGINT)
RETURNS TABLE(
  total_listings BIGINT,
  active_listings BIGINT,
  avg_price DECIMAL,
  min_price BIGINT,
  max_price BIGINT
)
LANGUAGE sql STABLE AS $$
  SELECT 
    COUNT(*) as total_listings,
    COUNT(*) FILTER (WHERE l.status = 'active') as active_listings,
    ROUND(AVG(l.price_cents)::DECIMAL / 100, 2) as avg_price,
    MIN(l.price_cents) as min_price,
    MAX(l.price_cents) as max_price
  FROM listing l
  WHERE l.category_id = category_id_param;
$$;