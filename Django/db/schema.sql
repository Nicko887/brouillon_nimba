-- =====================================================================
--  Schéma PostgreSQL avec DROP IF EXISTS pour remplacer les tables
--  Site professionnel type Le Bon Coin
-- =====================================================================

-- Extensions optionnelles (à activer si disponibles)
-- CREATE EXTENSION IF NOT EXISTS unaccent;
-- CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- =========================
-- SUPPRESSION des tables existantes (ordre important pour les FK)
-- =========================

-- Supprimer la vue d'abord
DROP VIEW IF EXISTS active_listings;

-- Supprimer les tables dans l'ordre inverse de création (à cause des clés étrangères)
DROP TABLE IF EXISTS notification CASCADE;
DROP TABLE IF EXISTS report CASCADE;
DROP TABLE IF EXISTS user_rating CASCADE;
DROP TABLE IF EXISTS message CASCADE;
DROP TABLE IF EXISTS conversation CASCADE;
DROP TABLE IF EXISTS saved_search CASCADE;
DROP TABLE IF EXISTS user_favorite CASCADE;
DROP TABLE IF EXISTS listing_tag CASCADE;
DROP TABLE IF EXISTS tag CASCADE;
DROP TABLE IF EXISTS listing_image CASCADE;
DROP TABLE IF EXISTS listing CASCADE;
DROP TABLE IF EXISTS category_relation CASCADE;
DROP TABLE IF EXISTS category CASCADE;
DROP TABLE IF EXISTS user_profile CASCADE;

-- =========================
-- CRÉATION des tables

SET client_encoding TO 'UTF8';
-- =========================

-- Profil utilisateur étendu
CREATE TABLE user_profile (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT UNIQUE NOT NULL,
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
  CONSTRAINT chk_status CHECK (status IN ('active','suspended','banned','pending_verification')),
  CONSTRAINT chk_rating CHECK (rating_average >= 0 AND rating_average <= 5)
);

-- Catégories avec hiérarchie simplifiée
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
  CONSTRAINT chk_kind CHECK (kind IN ('goods','services','real_estate','jobs','vehicles','other')),
  CONSTRAINT fk_category_parent FOREIGN KEY (parent_id) REFERENCES category(id) ON DELETE CASCADE
);

-- Relations entre catégories
CREATE TABLE category_relation (
  id BIGSERIAL PRIMARY KEY,
  source_category_id BIGINT NOT NULL,
  target_category_id BIGINT NOT NULL,
  relation_type VARCHAR(20) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_relation_type CHECK (relation_type IN ('related','service_for','accessory_for','similar')),
  CONSTRAINT fk_catrel_source FOREIGN KEY (source_category_id) REFERENCES category(id) ON DELETE CASCADE,
  CONSTRAINT fk_catrel_target FOREIGN KEY (target_category_id) REFERENCES category(id) ON DELETE CASCADE,
  UNIQUE (source_category_id, target_category_id, relation_type)
);

-- Annonces principales
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
  
  -- SEO
  meta_title VARCHAR(255),
  meta_description TEXT,
  
  -- Statistiques (géré par Django)
  view_count INTEGER NOT NULL DEFAULT 0,
  favorite_count INTEGER NOT NULL DEFAULT 0,
  contact_count INTEGER NOT NULL DEFAULT 0,
  
  -- Dates importantes
  expires_at TIMESTAMPTZ,
  featured_until TIMESTAMPTZ,
  sold_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  CONSTRAINT chk_condition CHECK (condition IN ('new','like_new','good','fair','poor')),
  CONSTRAINT chk_status CHECK (status IN ('draft','active','sold','expired','suspended','deleted')),
  CONSTRAINT fk_listing_category FOREIGN KEY (category_id) REFERENCES category(id) ON DELETE RESTRICT
);

-- Images des annonces
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

-- Tags
CREATE TABLE tag (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(100) UNIQUE NOT NULL,
  slug VARCHAR(100) UNIQUE NOT NULL,
  usage_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Liaison annonces-tags
CREATE TABLE listing_tag (
  id BIGSERIAL PRIMARY KEY,
  listing_id BIGINT NOT NULL,
  tag_id BIGINT NOT NULL,
  CONSTRAINT fk_listingtag_listing FOREIGN KEY (listing_id) REFERENCES listing(id) ON DELETE CASCADE,
  CONSTRAINT fk_listingtag_tag FOREIGN KEY (tag_id) REFERENCES tag(id) ON DELETE CASCADE,
  UNIQUE (listing_id, tag_id)
);

-- Favoris des utilisateurs
CREATE TABLE user_favorite (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  listing_id BIGINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fk_favorite_listing FOREIGN KEY (listing_id) REFERENCES listing(id) ON DELETE CASCADE,
  UNIQUE (user_id, listing_id)
);

-- Recherches sauvegardées
CREATE TABLE saved_search (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  name VARCHAR(255) NOT NULL,
  query_params JSONB NOT NULL,
  email_alerts BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Conversations entre utilisateurs
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

-- Messages dans les conversations
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

-- Évaluations entre utilisateurs
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

-- Signalements
CREATE TABLE report (
  id BIGSERIAL PRIMARY KEY,
  reporter_id BIGINT NOT NULL,
  listing_id BIGINT,
  user_id BIGINT,
  reason VARCHAR(100) NOT NULL,
  description TEXT,
  status VARCHAR(50) NOT NULL DEFAULT 'pending',
  reviewed_by BIGINT,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fk_report_listing FOREIGN KEY (listing_id) REFERENCES listing(id) ON DELETE CASCADE,
  CHECK ((listing_id IS NOT NULL) OR (user_id IS NOT NULL))
);

-- Notifications
CREATE TABLE notification (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  type VARCHAR(50) NOT NULL,
  title VARCHAR(255) NOT NULL,
  content TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  related_listing_id BIGINT,
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT fk_notification_listing FOREIGN KEY (related_listing_id) REFERENCES listing(id) ON DELETE SET NULL
);

-- =========================
-- Index pour les performances
-- =========================

-- Catégories
CREATE INDEX idx_category_parent ON category(parent_id);
CREATE INDEX idx_category_slug ON category(slug);
CREATE INDEX idx_category_kind ON category(kind);
CREATE INDEX idx_category_active ON category(is_active);
CREATE INDEX idx_category_depth ON category(depth);

-- Relations catégories
CREATE INDEX idx_catrel_source ON category_relation(source_category_id);
CREATE INDEX idx_catrel_target ON category_relation(target_category_id);

-- Utilisateurs
CREATE INDEX idx_user_profile_user ON user_profile(user_id);
CREATE INDEX idx_user_profile_location ON user_profile(latitude, longitude);
CREATE INDEX idx_user_profile_status ON user_profile(status);

-- Annonces
CREATE INDEX idx_listing_user ON listing(user_id);
CREATE INDEX idx_listing_category ON listing(category_id);
CREATE INDEX idx_listing_status ON listing(status);
CREATE INDEX idx_listing_location ON listing(latitude, longitude);
CREATE INDEX idx_listing_price ON listing(price_cents);
CREATE INDEX idx_listing_created ON listing(created_at DESC);
CREATE INDEX idx_listing_featured ON listing(featured_until) WHERE featured_until IS NOT NULL;
CREATE INDEX idx_listing_slug ON listing(slug);
CREATE INDEX idx_listing_active ON listing(status, expires_at) WHERE status = 'active';

-- Images
CREATE INDEX idx_listing_image_listing ON listing_image(listing_id);
CREATE INDEX idx_listing_image_primary ON listing_image(listing_id, is_primary);

-- Tags
CREATE INDEX idx_tag_slug ON tag(slug);
CREATE INDEX idx_tag_name ON tag(name);
CREATE INDEX idx_listing_tag_listing ON listing_tag(listing_id);
CREATE INDEX idx_listing_tag_tag ON listing_tag(tag_id);

-- Favoris
CREATE INDEX idx_favorite_user ON user_favorite(user_id);
CREATE INDEX idx_favorite_listing ON user_favorite(listing_id);

-- Messages
CREATE INDEX idx_conversation_listing ON conversation(listing_id);
CREATE INDEX idx_conversation_users ON conversation(buyer_id, seller_id);
CREATE INDEX idx_conversation_active ON conversation(is_active);
CREATE INDEX idx_message_conversation ON message(conversation_id);
CREATE INDEX idx_message_sender ON message(sender_id);
CREATE INDEX idx_message_status ON message(status);

-- Évaluations
CREATE INDEX idx_rating_rated ON user_rating(rated_id);
CREATE INDEX idx_rating_rater ON user_rating(rater_id);

-- Notifications
CREATE INDEX idx_notification_user ON notification(user_id);
CREATE INDEX idx_notification_read ON notification(is_read);

-- Recherches sauvegardées
CREATE INDEX idx_saved_search_user ON saved_search(user_id);

-- =========================
-- Vue des annonces actives
-- =========================

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
  l.updated_at,
  l.user_id,
  l.category_id,
  c.name as category_name,
  c.slug as category_slug
FROM listing l
JOIN category c ON l.category_id = c.id
WHERE l.status = 'active'
  AND (l.expires_at IS NULL OR l.expires_at > now());