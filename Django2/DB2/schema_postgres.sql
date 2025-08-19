-- =====================================================================
--  Schéma PostgreSQL optimisé pour un site de petites annonces
--  Compatible Django + fonctionnalités complètes
-- =====================================================================

-- Extensions utiles
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS pg_trgm;  -- Pour la recherche textuelle
CREATE EXTENSION IF NOT EXISTS postgis;  -- Pour la géolocalisation (optionnel)

-- =========================
-- Types ENUM métier
-- =========================
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'category_kind') THEN
    CREATE TYPE category_kind AS ENUM ('goods','services','real_estate','jobs','vehicles','other');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'relation_type') THEN
    CREATE TYPE relation_type AS ENUM ('related','service_for','accessory_for','similar');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'listing_status') THEN
    CREATE TYPE listing_status AS ENUM ('draft','active','sold','expired','suspended','deleted');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_status') THEN
    CREATE TYPE user_status AS ENUM ('active','suspended','banned','pending_verification');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'message_status') THEN
    CREATE TYPE message_status AS ENUM ('sent','delivered','read');
  END IF;
END $$;

-- =========================
-- Fonctions utilitaires (conservées du code original)
-- =========================

-- Slugify simple 
CREATE OR REPLACE FUNCTION slugify(txt TEXT)
RETURNS TEXT
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
  s TEXT := lower(unaccent(coalesce(txt,'')));
BEGIN
  s := regexp_replace(s, '&', ' et ', 'g');
  s := regexp_replace(s, '[^a-z0-9]+', '-', 'g');
  s := regexp_replace(s, '-{2,}', '-', 'g');
  s := regexp_replace(s, '(^-|-$)', '', 'g');
  RETURN s;
END;
$$;

-- S'assurer qu'un slug est unique
CREATE OR REPLACE FUNCTION ensure_unique_slug(base_slug TEXT, table_name TEXT, exclude_id BIGINT DEFAULT NULL)
RETURNS TEXT
LANGUAGE plpgsql AS $$
DECLARE
  s TEXT := coalesce(nullif(base_slug,''), 'item');
  i INT := 2;
  exists_row INT;
  query TEXT;
BEGIN
  LOOP
    query := format('SELECT 1 FROM %I WHERE slug = $1 AND ($2 IS NULL OR id <> $2) LIMIT 1', table_name);
    EXECUTE query INTO exists_row USING s, exclude_id;
    
    IF NOT FOUND THEN
      RETURN s;
    END IF;

    s := base_slug || '-' || i;
    i := i + 1;
  END LOOP;
END;
$$;

-- Mettre à jour automatiquement updated_at
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- Empêcher les cycles dans les catégories
CREATE OR REPLACE FUNCTION category_prevent_cycle()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
  p BIGINT;
BEGIN
  IF TG_OP = 'UPDATE' AND (NEW.parent_id IS NOT DISTINCT FROM OLD.parent_id) THEN
    RETURN NEW;
  END IF;

  IF NEW.parent_id IS NULL OR NEW.parent_id = NEW.id THEN
    IF NEW.parent_id = NEW.id THEN
      RAISE EXCEPTION 'Une catégorie ne peut pas être son propre parent';
    END IF;
    RETURN NEW;
  END IF;

  p := NEW.parent_id;
  WHILE p IS NOT NULL LOOP
    IF p = NEW.id THEN
      RAISE EXCEPTION 'Cycle détecté dans la hiérarchie des catégories';
    END IF;
    SELECT parent_id INTO p FROM category WHERE id = p;
  END LOOP;

  RETURN NEW;
END;
$$;

-- Recalcul du path et depth
CREATE OR REPLACE FUNCTION category_rebuild_subtree(root BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
  base_path BIGINT[];
BEGIN
  SELECT path_ids INTO base_path
  FROM category
  WHERE id = (SELECT parent_id FROM category WHERE id = root);

  base_path := COALESCE(base_path, ARRAY[]::BIGINT[]);

  WITH RECURSIVE tree AS (
    SELECT c.id, c.parent_id, base_path AS p
    FROM category c WHERE c.id = root
    UNION ALL
    SELECT ch.id, ch.parent_id, t.p || t.id
    FROM category ch
    JOIN tree t ON ch.parent_id = t.id
  )
  UPDATE category c
     SET path_ids = t.p || c.id,
         depth = COALESCE(array_length(t.p,1),0) + 1,
         updated_at = now()
    FROM tree t
   WHERE c.id = t.id;
END;
$$;

-- =========================
-- Tables principales
-- =========================

-- Utilisateurs (compatible avec Django User model)
CREATE TABLE IF NOT EXISTS auth_user (
  id BIGSERIAL PRIMARY KEY,
  password VARCHAR(128) NOT NULL,
  last_login TIMESTAMPTZ,
  is_superuser BOOLEAN NOT NULL DEFAULT FALSE,
  username VARCHAR(150) UNIQUE NOT NULL,
  first_name VARCHAR(150),
  last_name VARCHAR(150),
  email VARCHAR(254),
  is_staff BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  date_joined TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Profil utilisateur étendu
CREATE TABLE IF NOT EXISTS user_profile (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT UNIQUE NOT NULL REFERENCES auth_user(id) ON DELETE CASCADE,
  phone VARCHAR(20),
  avatar VARCHAR(200),  -- URL de l'avatar
  bio TEXT,
  location VARCHAR(255),
  latitude DECIMAL(10,8),
  longitude DECIMAL(11,8),
  status user_status NOT NULL DEFAULT 'active',
  email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  phone_verified BOOLEAN NOT NULL DEFAULT FALSE,
  rating_average DECIMAL(3,2) DEFAULT 0.00,
  rating_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Catégories (structure optimisée conservée)
CREATE TABLE IF NOT EXISTS category (
  id BIGSERIAL PRIMARY KEY,
  parent_id BIGINT REFERENCES category(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(255) NOT NULL UNIQUE,
  kind category_kind NOT NULL DEFAULT 'goods',
  description TEXT,
  icon VARCHAR(100),  -- Nom de l'icône
  image VARCHAR(200), -- Image de la catégorie
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  path_ids BIGINT[] NOT NULL DEFAULT '{}',
  depth INTEGER NOT NULL DEFAULT 1,
  listing_count INTEGER NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Relations entre catégories
CREATE TABLE IF NOT EXISTS category_relation (
  id BIGSERIAL PRIMARY KEY,
  source_category_id BIGINT NOT NULL REFERENCES category(id) ON DELETE CASCADE,
  target_category_id BIGINT NOT NULL REFERENCES category(id) ON DELETE CASCADE,
  relation_type relation_type NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (source_category_id, target_category_id, relation_type)
);

-- Annonces principales
CREATE TABLE IF NOT EXISTS listing (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES auth_user(id) ON DELETE CASCADE,
  category_id BIGINT NOT NULL REFERENCES category(id) ON DELETE RESTRICT,
  title VARCHAR(255) NOT NULL,
  slug VARCHAR(255) UNIQUE,
  description TEXT,
  price_cents BIGINT,
  currency VARCHAR(3) NOT NULL DEFAULT 'GNF',
  is_negotiable BOOLEAN NOT NULL DEFAULT TRUE,
  condition VARCHAR(50), -- 'new', 'like_new', 'good', 'fair', 'poor'
  status listing_status NOT NULL DEFAULT 'draft',
  
  -- Géolocalisation
  location VARCHAR(255),
  latitude DECIMAL(10,8),
  longitude DECIMAL(11,8),
  
  -- SEO et recherche
  meta_title VARCHAR(255),
  meta_description TEXT,
  search_vector tsvector,
  
  -- Statistiques
  view_count INTEGER NOT NULL DEFAULT 0,
  favorite_count INTEGER NOT NULL DEFAULT 0,
  contact_count INTEGER NOT NULL DEFAULT 0,
  
  -- Dates importantes
  expires_at TIMESTAMPTZ,
  featured_until TIMESTAMPTZ,
  sold_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Images des annonces
CREATE TABLE IF NOT EXISTS listing_image (
  id BIGSERIAL PRIMARY KEY,
  listing_id BIGINT NOT NULL REFERENCES listing(id) ON DELETE CASCADE,
  image VARCHAR(200) NOT NULL,  -- URL de l'image
  alt_text VARCHAR(255),
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tags
CREATE TABLE IF NOT EXISTS tag (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(100) UNIQUE NOT NULL,
  slug VARCHAR(100) UNIQUE NOT NULL,
  usage_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Liaison annonces-tags
CREATE TABLE IF NOT EXISTS listing_tag (
  id BIGSERIAL PRIMARY KEY,
  listing_id BIGINT NOT NULL REFERENCES listing(id) ON DELETE CASCADE,
  tag_id BIGINT NOT NULL REFERENCES tag(id) ON DELETE CASCADE,
  UNIQUE (listing_id, tag_id)
);

-- Favoris des utilisateurs
CREATE TABLE IF NOT EXISTS user_favorite (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES auth_user(id) ON DELETE CASCADE,
  listing_id BIGINT NOT NULL REFERENCES listing(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, listing_id)
);

-- Recherches sauvegardées
CREATE TABLE IF NOT EXISTS saved_search (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES auth_user(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  query_params JSONB NOT NULL,
  email_alerts BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Conversations entre utilisateurs
CREATE TABLE IF NOT EXISTS conversation (
  id BIGSERIAL PRIMARY KEY,
  listing_id BIGINT NOT NULL REFERENCES listing(id) ON DELETE CASCADE,
  buyer_id BIGINT NOT NULL REFERENCES auth_user(id) ON DELETE CASCADE,
  seller_id BIGINT NOT NULL REFERENCES auth_user(id) ON DELETE CASCADE,
  last_message_at TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (listing_id, buyer_id, seller_id)
);

-- Messages dans les conversations
CREATE TABLE IF NOT EXISTS message (
  id BIGSERIAL PRIMARY KEY,
  conversation_id BIGINT NOT NULL REFERENCES conversation(id) ON DELETE CASCADE,
  sender_id BIGINT NOT NULL REFERENCES auth_user(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  status message_status NOT NULL DEFAULT 'sent',
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Évaluations entre utilisateurs
CREATE TABLE IF NOT EXISTS user_rating (
  id BIGSERIAL PRIMARY KEY,
  rater_id BIGINT NOT NULL REFERENCES auth_user(id) ON DELETE CASCADE,
  rated_id BIGINT NOT NULL REFERENCES auth_user(id) ON DELETE CASCADE,
  listing_id BIGINT REFERENCES listing(id) ON DELETE SET NULL,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (rater_id, rated_id, listing_id)
);

-- Signalements
CREATE TABLE IF NOT EXISTS report (
  id BIGSERIAL PRIMARY KEY,
  reporter_id BIGINT NOT NULL REFERENCES auth_user(id) ON DELETE CASCADE,
  listing_id BIGINT REFERENCES listing(id) ON DELETE CASCADE,
  user_id BIGINT REFERENCES auth_user(id) ON DELETE CASCADE,
  reason VARCHAR(100) NOT NULL,
  description TEXT,
  status VARCHAR(50) NOT NULL DEFAULT 'pending',
  reviewed_by BIGINT REFERENCES auth_user(id),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK ((listing_id IS NOT NULL) OR (user_id IS NOT NULL))
);

-- =========================
-- Index pour les performances
-- =========================

-- Catégories
CREATE INDEX IF NOT EXISTS idx_category_parent ON category(parent_id);
CREATE INDEX IF NOT EXISTS idx_category_slug ON category(slug);
CREATE INDEX IF NOT EXISTS idx_category_path_gin ON category USING GIN (path_ids);
CREATE INDEX IF NOT EXISTS idx_category_kind ON category(kind);
CREATE INDEX IF NOT EXISTS idx_category_active ON category(is_active);

-- Relations catégories
CREATE INDEX IF NOT EXISTS idx_catrel_source ON category_relation(source_category_id);
CREATE INDEX IF NOT EXISTS idx_catrel_target ON category_relation(target_category_id);

-- Utilisateurs
CREATE INDEX IF NOT EXISTS idx_user_profile_user ON user_profile(user_id);
CREATE INDEX IF NOT EXISTS idx_user_profile_location ON user_profile(latitude, longitude);

-- Annonces
CREATE INDEX IF NOT EXISTS idx_listing_user ON listing(user_id);
CREATE INDEX IF NOT EXISTS idx_listing_category ON listing(category_id);
CREATE INDEX IF NOT EXISTS idx_listing_status ON listing(status);
CREATE INDEX IF NOT EXISTS idx_listing_location ON listing(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_listing_price ON listing(price_cents);
CREATE INDEX IF NOT EXISTS idx_listing_created ON listing(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_listing_featured ON listing(featured_until) WHERE featured_until IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_listing_search_gin ON listing USING GIN (search_vector);
CREATE INDEX IF NOT EXISTS idx_listing_slug ON listing(slug);

-- Images
CREATE INDEX IF NOT EXISTS idx_listing_image_listing ON listing_image(listing_id);
CREATE INDEX IF NOT EXISTS idx_listing_image_primary ON listing_image(listing_id, is_primary);

-- Tags
CREATE INDEX IF NOT EXISTS idx_tag_slug ON tag(slug);
CREATE INDEX IF NOT EXISTS idx_listing_tag_listing ON listing_tag(listing_id);
CREATE INDEX IF NOT EXISTS idx_listing_tag_tag ON listing_tag(tag_id);

-- Favoris
CREATE INDEX IF NOT EXISTS idx_favorite_user ON user_favorite(user_id);
CREATE INDEX IF NOT EXISTS idx_favorite_listing ON user_favorite(listing_id);

-- Messages
CREATE INDEX IF NOT EXISTS idx_conversation_listing ON conversation(listing_id);
CREATE INDEX IF NOT EXISTS idx_conversation_users ON conversation(buyer_id, seller_id);
CREATE INDEX IF NOT EXISTS idx_message_conversation ON message(conversation_id);
CREATE INDEX IF NOT EXISTS idx_message_sender ON message(sender_id);

-- Évaluations
CREATE INDEX IF NOT EXISTS idx_rating_rated ON user_rating(rated_id);
CREATE INDEX IF NOT EXISTS idx_rating_rater ON user_rating(rater_id);

-- =========================
-- Triggers
-- =========================

-- Catégories (triggers conservés)
CREATE OR REPLACE FUNCTION category_set_slug()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' OR NEW.name IS DISTINCT FROM OLD.name OR NEW.slug IS NULL OR NEW.slug = '' THEN
    NEW.slug := ensure_unique_slug(slugify(NEW.name), 'category', NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION category_after_change()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM category_rebuild_subtree(NEW.id);
  RETURN NEW;
END;
$$;

-- Annonces
CREATE OR REPLACE FUNCTION listing_set_slug()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' OR NEW.title IS DISTINCT FROM OLD.title OR NEW.slug IS NULL OR NEW.slug = '' THEN
    NEW.slug := ensure_unique_slug(slugify(NEW.title), 'listing', NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION listing_update_search_vector()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  NEW.search_vector := 
    setweight(to_tsvector('french', coalesce(NEW.title,'')), 'A') ||
    setweight(to_tsvector('french', coalesce(NEW.description,'')), 'B') ||
    setweight(to_tsvector('french', coalesce(NEW.location,'')), 'C');
  RETURN NEW;
END;
$$;

-- Gestion des compteurs
CREATE OR REPLACE FUNCTION update_listing_count()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE category SET listing_count = listing_count + 1 WHERE id = NEW.category_id;
  ELSIF TG_OP = 'UPDATE' AND OLD.category_id != NEW.category_id THEN
    UPDATE category SET listing_count = listing_count - 1 WHERE id = OLD.category_id;
    UPDATE category SET listing_count = listing_count + 1 WHERE id = NEW.category_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE category SET listing_count = listing_count - 1 WHERE id = OLD.category_id;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE OR REPLACE FUNCTION update_tag_usage()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE tag SET usage_count = usage_count + 1 WHERE id = NEW.tag_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE tag SET usage_count = usage_count - 1 WHERE id = OLD.tag_id;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE OR REPLACE FUNCTION update_user_rating()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE user_profile 
    SET rating_average = (
      SELECT AVG(rating)::DECIMAL(3,2) 
      FROM user_rating 
      WHERE rated_id = NEW.rated_id
    ),
    rating_count = rating_count + 1
    WHERE user_id = NEW.rated_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE user_profile 
    SET rating_average = COALESCE((
      SELECT AVG(rating)::DECIMAL(3,2) 
      FROM user_rating 
      WHERE rated_id = OLD.rated_id
    ), 0.00),
    rating_count = rating_count - 1
    WHERE user_id = OLD.rated_id;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Application des triggers
DROP TRIGGER IF EXISTS trg_category_set_slug ON category;
DROP TRIGGER IF EXISTS trg_category_cycle ON category;
DROP TRIGGER IF EXISTS trg_category_after ON category;
DROP TRIGGER IF EXISTS trg_category_updated ON category;
DROP TRIGGER IF EXISTS trg_listing_slug ON listing;
DROP TRIGGER IF EXISTS trg_listing_search ON listing;
DROP TRIGGER IF EXISTS trg_listing_updated ON listing;
DROP TRIGGER IF EXISTS trg_listing_count ON listing;
DROP TRIGGER IF EXISTS trg_tag_usage ON listing_tag;
DROP TRIGGER IF EXISTS trg_user_rating_update ON user_rating;
DROP TRIGGER IF EXISTS trg_user_profile_updated ON user_profile;

CREATE TRIGGER trg_category_set_slug
  BEFORE INSERT OR UPDATE OF name, slug ON category
  FOR EACH ROW EXECUTE FUNCTION category_set_slug();

CREATE TRIGGER trg_category_cycle
  BEFORE UPDATE OF parent_id ON category
  FOR EACH ROW EXECUTE FUNCTION category_prevent_cycle();

CREATE TRIGGER trg_category_after
  AFTER INSERT OR UPDATE OF parent_id ON category
  FOR EACH ROW EXECUTE FUNCTION category_after_change();

CREATE TRIGGER trg_category_updated
  BEFORE UPDATE ON category
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_listing_slug
  BEFORE INSERT OR UPDATE OF title, slug ON listing
  FOR EACH ROW EXECUTE FUNCTION listing_set_slug();

CREATE TRIGGER trg_listing_search
  BEFORE INSERT OR UPDATE OF title, description, location ON listing
  FOR EACH ROW EXECUTE FUNCTION listing_update_search_vector();

CREATE TRIGGER trg_listing_updated
  BEFORE UPDATE ON listing
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_listing_count
  AFTER INSERT OR UPDATE OF category_id OR DELETE ON listing
  FOR EACH ROW EXECUTE FUNCTION update_listing_count();

CREATE TRIGGER trg_tag_usage
  AFTER INSERT OR DELETE ON listing_tag
  FOR EACH ROW EXECUTE FUNCTION update_tag_usage();

CREATE TRIGGER trg_user_rating_update
  AFTER INSERT OR DELETE ON user_rating
  FOR EACH ROW EXECUTE FUNCTION update_user_rating();

CREATE TRIGGER trg_user_profile_updated
  BEFORE UPDATE ON user_profile
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =========================
-- Vues utiles
-- =========================

-- Vue des annonces actives avec détails
CREATE OR REPLACE VIEW active_listings AS
SELECT 
  l.*,
  u.username,
  u.first_name,
  u.last_name,
  up.phone,
  up.rating_average,
  up.rating_count,
  c.name as category_name,
  c.slug as category_slug,
  (SELECT image FROM listing_image WHERE listing_id = l.id AND is_primary = true LIMIT 1) as primary_image
FROM listing l
JOIN auth_user u ON l.user_id = u.id
JOIN user_profile up ON u.id = up.user_id
JOIN category c ON l.category_id = c.id
WHERE l.status = 'active'
  AND l.expires_at > now()
  AND u.is_active = true
  AND up.status = 'active';

-- =========================
-- Fonctions de recherche optimisées
-- =========================

-- Recherche full-text avec géolocalisation
CREATE OR REPLACE FUNCTION search_listings(
  search_query TEXT DEFAULT NULL,
  category_slug TEXT DEFAULT NULL,
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
    JOIN auth_user u ON l.user_id = u.id
    JOIN user_profile up ON u.id = up.user_id
    LEFT JOIN category c ON l.category_id = c.id
    WHERE l.status = 'active'
      AND (l.expires_at IS NULL OR l.expires_at > now())
      AND (search_query IS NULL OR l.search_vector @@ plainto_tsquery('french', search_query))
      AND (category_slug IS NULL OR c.slug = category_slug OR c.path_ids @> ARRAY[(SELECT id FROM category WHERE slug = category_slug)])
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

-- Fonction pour les statistiques des catégories
CREATE OR REPLACE FUNCTION category_stats(slug_input TEXT)
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
  JOIN category c ON l.category_id = c.id
  WHERE c.path_ids @> ARRAY[(SELECT id FROM category WHERE slug = slug_input)];
$$;