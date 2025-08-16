-- =====================================================================
--  Schéma PostgreSQL pour un site de petites annonces
--  Hiérarchie de catégories + relations transversales + annonces + tags
--  Conçu pour fonctionner sans Django
-- =====================================================================

-- Extensions (facultatives mais utiles)
CREATE EXTENSION IF NOT EXISTS unaccent;

-- =========================
-- Types ENUM métier
-- =========================
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'category_kind') THEN
    CREATE TYPE category_kind AS ENUM ('goods','services','other');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'relation_type') THEN
    CREATE TYPE relation_type AS ENUM ('related','service_for','accessory_for');
  END IF;
END $$;

-- =========================
-- Fonctions utilitaires
-- =========================

-- Slugify simple (accent -> sans accent, espaces/ponctuation -> '-')
CREATE OR REPLACE FUNCTION slugify(txt TEXT)
RETURNS TEXT
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
  s TEXT := lower(unaccent(coalesce(txt,'')));
BEGIN
  -- remplace & par ' et ' pour éviter sa suppression pure
  s := regexp_replace(s, '&', ' et ', 'g');
  -- remplace toute séquence non [a-z0-9] par '-'
  s := regexp_replace(s, '[^a-z0-9]+', '-', 'g');
  -- compresse les multiples '-' et trim en bord
  s := regexp_replace(s, '-{2,}', '-', 'g');
  s := regexp_replace(s, '(^-|-$)', '', 'g');
  RETURN s;
END;
$$;

-- S'assurer qu'un slug est unique en ajoutant -2, -3, ...
CREATE OR REPLACE FUNCTION ensure_unique_slug(base_slug TEXT, exclude_id BIGINT)
RETURNS TEXT
LANGUAGE plpgsql AS $$
DECLARE
  s TEXT := coalesce(nullif(base_slug,''), 'cat');
  i INT := 2;
  exists_row INT;
BEGIN
  LOOP
    SELECT 1 INTO exists_row
    FROM category
    WHERE slug = s
      AND (exclude_id IS NULL OR id <> exclude_id)
    LIMIT 1;

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

-- Empêcher les cycles lors du changement de parent
CREATE OR REPLACE FUNCTION category_prevent_cycle()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
  p BIGINT;
BEGIN
  -- Ne contrôle que si on change le parent
  IF TG_OP = 'UPDATE' AND (NEW.parent_id IS NOT DISTINCT FROM OLD.parent_id) THEN
    RETURN NEW;
  END IF;

  IF NEW.parent_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.parent_id = NEW.id THEN
    RAISE EXCEPTION 'Une catégorie ne peut pas être son propre parent';
  END IF;

  -- Remonte la chaîne des parents pour vérifier que NEW.id n’apparaît pas
  p := NEW.parent_id;
  WHILE p IS NOT NULL LOOP
    IF p = NEW.id THEN
      RAISE EXCEPTION 'Cycle détecté: "%" ne peut pas devenir enfant de son propre sous-arbre', NEW.name;
    END IF;
    SELECT parent_id INTO p FROM category WHERE id = p;
  END LOOP;

  RETURN NEW;
END;
$$;

-- Recalcul du path_ids (liste des ancêtres + self) et de depth pour un sous-arbre
CREATE OR REPLACE FUNCTION category_rebuild_subtree(root BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
  base_path BIGINT[];
BEGIN
  SELECT path_ids
  INTO base_path
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
         depth    = COALESCE(array_length(t.p,1),0) + 1,
         updated_at = now()
    FROM tree t
   WHERE c.id = t.id;
END;
$$;

-- Avant insert/update: générer un slug unique si besoin
CREATE OR REPLACE FUNCTION category_set_slug()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' OR NEW.name IS DISTINCT FROM OLD.name OR NEW.slug IS NULL OR NEW.slug = '' THEN
    NEW.slug := ensure_unique_slug(slugify(NEW.name), NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

-- Après insert/update parent: recalculer le sous-arbre
CREATE OR REPLACE FUNCTION category_after_change()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM category_rebuild_subtree(NEW.id);
  RETURN NEW;
END;
$$;

-- =========================
-- Tables
-- =========================

-- Catégories (arbre par adjacence + chemin matérialisé path_ids)
CREATE TABLE IF NOT EXISTS category (
  id         BIGSERIAL PRIMARY KEY,
  parent_id  BIGINT REFERENCES category(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  slug       TEXT NOT NULL UNIQUE,
  kind       category_kind NOT NULL DEFAULT 'goods',
  is_active  BOOLEAN NOT NULL DEFAULT TRUE,
  -- chemin d'IDs ancêtres + self (ex: {1,5,12}), utile pour DESCENDANTS via GIN
  path_ids   BIGINT[] NOT NULL DEFAULT '{}',
  depth      INT NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_category_parent   ON category(parent_id);
CREATE INDEX IF NOT EXISTS idx_category_slug     ON category(slug);
CREATE INDEX IF NOT EXISTS idx_category_path_gin ON category USING GIN (path_ids);

-- Liens transversaux (graphe inter-catégories)
CREATE TABLE IF NOT EXISTS category_relation (
  id                   BIGSERIAL PRIMARY KEY,
  source_category_id   BIGINT NOT NULL REFERENCES category(id) ON DELETE CASCADE,
  target_category_id   BIGINT NOT NULL REFERENCES category(id) ON DELETE CASCADE,
  relation_type        relation_type NOT NULL,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (source_category_id, target_category_id, relation_type)
);
CREATE INDEX IF NOT EXISTS idx_catrel_source ON category_relation(source_category_id);
CREATE INDEX IF NOT EXISTS idx_catrel_target ON category_relation(target_category_id);

-- Annonces + tags (facultatif mais utile)
CREATE TABLE IF NOT EXISTS listing (
  id           BIGSERIAL PRIMARY KEY,
  title        TEXT NOT NULL,
  category_id  BIGINT NOT NULL REFERENCES category(id) ON DELETE RESTRICT,
  price_cents  BIGINT,
  currency     TEXT NOT NULL DEFAULT 'GNF',
  description  TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_listing_category ON listing(category_id);

CREATE TABLE IF NOT EXISTS tag (
  id   BIGSERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS listing_tag (
  listing_id BIGINT NOT NULL REFERENCES listing(id) ON DELETE CASCADE,
  tag_id     BIGINT NOT NULL REFERENCES tag(id) ON DELETE CASCADE,
  PRIMARY KEY (listing_id, tag_id)
);

-- =========================
-- Triggers
-- =========================
DROP TRIGGER IF EXISTS trg_category_set_slug   ON category;
DROP TRIGGER IF EXISTS trg_category_cycle      ON category;
DROP TRIGGER IF EXISTS trg_category_after      ON category;
DROP TRIGGER IF EXISTS trg_category_set_update ON category;
DROP TRIGGER IF EXISTS trg_listing_set_update  ON listing;

CREATE TRIGGER trg_category_set_slug
BEFORE INSERT OR UPDATE OF name, slug ON category
FOR EACH ROW EXECUTE FUNCTION category_set_slug();

CREATE TRIGGER trg_category_cycle
BEFORE UPDATE OF parent_id ON category
FOR EACH ROW EXECUTE FUNCTION category_prevent_cycle();

CREATE TRIGGER trg_category_after
AFTER INSERT OR UPDATE OF parent_id ON category
FOR EACH ROW EXECUTE FUNCTION category_after_change();

CREATE TRIGGER trg_category_set_update
BEFORE UPDATE ON category
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_listing_set_update
BEFORE UPDATE ON listing
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =========================
-- Vues et fonctions de lecture
-- =========================

-- Descendants d'une catégorie (via slug)
CREATE OR REPLACE FUNCTION category_descendants(slug_input TEXT)
RETURNS SETOF category
LANGUAGE sql STABLE AS $$
  SELECT c.*
  FROM category c
  WHERE c.path_ids @> ARRAY[(SELECT id FROM category WHERE slug = slug_input)]
  ORDER BY c.depth, c.name;
$$;

-- Ancêtres (breadcrumb) d'une catégorie (via slug)
CREATE OR REPLACE FUNCTION category_ancestors(slug_input TEXT)
RETURNS TABLE(id BIGINT, name TEXT, slug TEXT, depth INT, ord INT)
LANGUAGE sql STABLE AS $$
  WITH node AS (SELECT * FROM category WHERE slug = slug_input),
  anc AS (
    SELECT a.ord, a.ancestor_id
    FROM node n,
         LATERAL unnest(n.path_ids) WITH ORDINALITY AS a(ancestor_id, ord)
  )
  SELECT c.id, c.name, c.slug, c.depth, anc.ord
  FROM anc
  JOIN category c ON c.id = anc.ancestor_id
  ORDER BY anc.ord;
$$;

-- Catégories liées (relations transversales)
CREATE OR REPLACE FUNCTION category_related(slug_input TEXT, rel_type relation_type DEFAULT NULL)
RETURNS TABLE(relation relation_type, target_id BIGINT, target_name TEXT, target_slug TEXT, target_kind category_kind)
LANGUAGE sql STABLE AS $$
  SELECT r.relation_type, t.id, t.name, t.slug, t.kind
  FROM category s
  JOIN category_relation r ON r.source_category_id = s.id
  JOIN category t ON t.id = r.target_category_id
  WHERE s.slug = slug_input
    AND (rel_type IS NULL OR r.relation_type = rel_type)
  ORDER BY r.relation_type, t.name;
$$;
