-- SOLUTION RECOMMANDÉE : Fonction PL/pgSQL avec boucle
-- Cette fonction s'adapte automatiquement à toutes vos tables

SET client_encoding TO 'UTF8';


CREATE OR REPLACE FUNCTION count_all_tables()
RETURNS TABLE(table_name text, row_count bigint) AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN 
        SELECT t.table_name 
        FROM information_schema.tables t
        WHERE t.table_schema = 'public' 
        AND t.table_type = 'BASE TABLE'
        ORDER BY t.table_name
    LOOP
        EXECUTE format('SELECT COUNT(*) FROM %I', r.table_name) INTO row_count;
        table_name := r.table_name;
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Utilisation de la fonction
SELECT * FROM count_all_tables();




/*

-- 1. DESCRIPTION COMPLÈTE DE TOUTES LES TABLES
-- Cette requête affiche les colonnes, types, contraintes pour toutes vos tables
SELECT 
    t.table_name,
    c.column_name,
    c.data_type,
    c.character_maximum_length,
    c.is_nullable,
    c.column_default,
    CASE 
        WHEN pk.column_name IS NOT NULL THEN 'PRIMARY KEY'
        WHEN fk.column_name IS NOT NULL THEN 'FOREIGN KEY'
        ELSE ''
    END as key_type
FROM information_schema.tables t
LEFT JOIN information_schema.columns c ON t.table_name = c.table_name
LEFT JOIN (
    SELECT ku.table_name, ku.column_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage ku 
        ON tc.constraint_name = ku.constraint_name
    WHERE tc.constraint_type = 'PRIMARY KEY'
) pk ON c.table_name = pk.table_name AND c.column_name = pk.column_name
LEFT JOIN (
    SELECT ku.table_name, ku.column_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage ku 
        ON tc.constraint_name = ku.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
) fk ON c.table_name = fk.table_name AND c.column_name = fk.column_name
WHERE t.table_schema = 'public'
    AND t.table_type = 'BASE TABLE'
ORDER BY t.table_name, c.ordinal_position;

-- 2. DESCRIPTION D'UNE TABLE SPÉCIFIQUE (remplacez 'nom_table' par le nom souhaité)
\d+ auth_user;
\d+ category;
\d+ listing;
-- (répétez pour chaque table)

-- 3. RELATIONS ET CLÉS ÉTRANGÈRES
SELECT 
    tc.table_name, 
    kcu.column_name, 
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    tc.constraint_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND tc.table_schema = 'public'
ORDER BY tc.table_name, kcu.column_name;

-- 4. INDEX SUR LES TABLES
SELECT 
    t.relname AS table_name,
    i.relname AS index_name,
    a.attname AS column_name,
    ix.indisunique AS is_unique,
    ix.indisprimary AS is_primary
FROM pg_class t
JOIN pg_index ix ON t.oid = ix.indrelid
JOIN pg_class i ON i.oid = ix.indexrelid
JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(ix.indkey)
WHERE t.relkind = 'r'
    AND t.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
ORDER BY t.relname, i.relname;

-- 5. TAILLE DES TABLES
SELECT 
    schemaname,
    tablename,
    attname as column_name,
    n_distinct,
    most_common_vals,
    most_common_freqs
FROM pg_stats 
WHERE schemaname = 'public'
ORDER BY tablename, attname;

-- 6. STATISTIQUES GÉNÉRALES DES TABLES
SELECT 
    relname AS table_name,
    n_tup_ins AS total_inserts,
    n_tup_upd AS total_updates,
    n_tup_del AS total_deletes,
    n_live_tup AS live_tuples,
    n_dead_tup AS dead_tuples
FROM pg_stat_user_tables 
WHERE schemaname = 'public'
ORDER BY relname;

-- 7. CONTRAINTES PAR TABLE
SELECT 
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name,
    cc.check_clause
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
LEFT JOIN information_schema.check_constraints cc
    ON tc.constraint_name = cc.constraint_name
WHERE tc.table_schema = 'public'
ORDER BY tc.table_name, tc.constraint_type;

-- 8. REQUÊTE POUR COMPTER LES ENREGISTREMENTS DANS CHAQUE TABLE
SELECT 
    'auth_user' as table_name, COUNT(*) as row_count FROM auth_user
UNION ALL SELECT 'category', COUNT(*) FROM category
UNION ALL SELECT 'category_relation', COUNT(*) FROM category_relation
UNION ALL SELECT 'conversation', COUNT(*) FROM conversation
UNION ALL SELECT 'listing', COUNT(*) FROM listing
UNION ALL SELECT 'listing_image', COUNT(*) FROM listing_image
UNION ALL SELECT 'listing_tag', COUNT(*) FROM listing_tag
UNION ALL SELECT 'message', COUNT(*) FROM message
UNION ALL SELECT 'report', COUNT(*) FROM report
UNION ALL SELECT 'saved_search', COUNT(*) FROM saved_search
UNION ALL SELECT 'tag', COUNT(*) FROM tag
UNION ALL SELECT 'user_favorite', COUNT(*) FROM user_favorite
UNION ALL SELECT 'user_profile', COUNT(*) FROM user_profile
UNION ALL SELECT 'user_rating', COUNT(*) FROM user_rating
ORDER BY table_name;

-- 9. SÉQUENCES UTILISÉES
SELECT 
    sequence_name,
    data_type,
    numeric_precision,
    start_value,
    minimum_value,
    maximum_value,
    increment
FROM information_schema.sequences
WHERE sequence_schema = 'public';

-- 10. PERMISSIONS SUR LES TABLES
SELECT 
    table_name,
    grantee,
    privilege_type,
    is_grantable
FROM information_schema.table_privileges 
WHERE table_schema = 'public'
ORDER BY table_name, grantee;
*/