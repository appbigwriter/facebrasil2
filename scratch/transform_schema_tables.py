import re
import os

source_file = r"f:\Projetos\_FBR\2FBR-NovaFacebrasil\supabase\migration_clean\01_schema_tables.sql"
target_file = r"f:\Projetos\_FBR\2FBR-NovaFacebrasil\supabase\sql_editor_custom_facebrasil\02_tables_and_functions.sql"

app_tables = [
    'user_activities', 'ad_publications', 'ads', 'article_favorites', 'article_reads',
    'articles', 'badges', 'user_badges', 'blogs', 'captured_news', 'categories',
    'challenges', 'events', 'instagram_events', 'user_reputation', 'news_queue',
    'news_sources', 'news_usage', 'partner_offers', 'partners', 'profiles',
    'publications', 'site_settings', 'social_credentials', 'static_pages',
    'user_challenges', 'user_collection_items', 'user_collections', 'user_video_reports',
    'virtual_agents', 'waterfall_posts', 'waterfall_sessions', 'xp_logs'
]

app_functions = [
    'calculate_level', 'check_and_award_badges', 'ensure_profile_exists',
    'handle_new_user', 'handle_new_user_role', 'increment_ad_clicks',
    'increment_ad_curiosity', 'increment_ad_views', 'increment_article_views',
    'increment_user_xp', 'reset_expired_heroes', 'reset_weekly_points',
    'set_hero_timestamp', 'set_updated_at', 'toggle_article_favorite',
    'update_events_updated_at', 'update_updated_at_column',
    'update_updated_at_timestamp', 'update_user_reputation', 'upsert_article_read'
]

with open(source_file, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Transform CREATE FUNCTION to CREATE OR REPLACE FUNCTION custom_facebrasil.<name>
for func in app_functions:
    content = re.sub(
        rf'CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+(?:public\.)?{func}\b',
        f'CREATE OR REPLACE FUNCTION custom_facebrasil.{func}',
        content,
        flags=re.IGNORECASE
    )

# 2. Transform CREATE TABLE to CREATE TABLE IF NOT EXISTS custom_facebrasil.<name>
for tbl in app_tables:
    content = re.sub(
        rf'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:public\.)?{tbl}\s*\(',
        f'CREATE TABLE IF NOT EXISTS custom_facebrasil.{tbl} (',
        content,
        flags=re.IGNORECASE
    )

# 3. Replace all schema occurrences in tables
for tbl in app_tables:
    content = re.sub(rf'\bpublic\.{tbl}\b', f'custom_facebrasil.{tbl}', content)
    content = re.sub(rf'\"public\"\.\"{tbl}\"', f'"custom_facebrasil"."{tbl}"', content)
    content = re.sub(rf'\bREFERENCES\s+(?:public\.)?{tbl}\b', f'REFERENCES custom_facebrasil.{tbl}', content, flags=re.IGNORECASE)

# 4. Replace all function calls
for func in app_functions:
    content = re.sub(rf'\bpublic\.{func}\s*\(', f'custom_facebrasil.{func}(', content)

# 5. Make CREATE TRIGGER idempotent with DROP TRIGGER IF EXISTS
def fix_triggers(match):
    trig_name = match.group(1)
    timing_event = match.group(2)
    tbl_name = match.group(3)
    rest = match.group(4)
    return f"DROP TRIGGER IF EXISTS {trig_name} ON custom_facebrasil.{tbl_name};\nCREATE TRIGGER {trig_name} {timing_event} ON custom_facebrasil.{tbl_name} {rest}"

content = re.sub(
    r'CREATE\s+TRIGGER\s+([a-zA-Z0-9_]+)\s+((?:BEFORE|AFTER|INSTEAD\s+OF)\s+[A-Z\s]+)\s+ON\s+custom_facebrasil\.([a-zA-Z0-9_]+)\s+([^;]+;)',
    fix_triggers,
    content,
    flags=re.IGNORECASE
)

# 6. Make ALTER TABLE ADD CONSTRAINT idempotent with DROP CONSTRAINT IF EXISTS
def fix_constraints(match):
    tbl_name = match.group(1)
    const_name = match.group(2)
    const_body = match.group(3)
    return f"ALTER TABLE custom_facebrasil.{tbl_name} DROP CONSTRAINT IF EXISTS {const_name};\nALTER TABLE ONLY custom_facebrasil.{tbl_name}\n    ADD CONSTRAINT {const_name} {const_body}"

content = re.sub(
    r'ALTER\s+TABLE\s+ONLY\s+custom_facebrasil\.([a-zA-Z0-9_]+)\s*\n\s*ADD\s+CONSTRAINT\s+([a-zA-Z0-9_]+)\s+([^;]+;)',
    fix_constraints,
    content,
    flags=re.IGNORECASE
)

# 7. Make CREATE INDEX IF NOT EXISTS
content = re.sub(r'CREATE\s+UNIQUE\s+INDEX\s+(?:IF\s+NOT\s+EXISTS\s+)?', 'CREATE UNIQUE INDEX IF NOT EXISTS ', content, flags=re.IGNORECASE)
content = re.sub(r'CREATE\s+INDEX\s+(?:IF\s+NOT\s+EXISTS\s+)?', 'CREATE INDEX IF NOT EXISTS ', content, flags=re.IGNORECASE)

# 8. Safely wrap COMMENT ON COLUMN in DO blocks so it never fails if a column is missing or pre-existing
def safe_comment(match):
    full_stmt = match.group(0)
    return f"DO $$ BEGIN\n  {full_stmt}\nEXCEPTION WHEN undefined_column OR undefined_table THEN NULL;\nEND $$;\n"

content = re.sub(r'COMMENT\s+ON\s+COLUMN\s+[^;]+;', safe_comment, content, flags=re.IGNORECASE)

# 9. Special handling for custom_facebrasil.events (which may pre-exist from Control Tower scaffold):
# Ensure all calendar columns exist on custom_facebrasil.events!
events_column_patch = """
-- Garantir compatibilidade e colunas do calendário de eventos do Facebrasil
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS title text;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS description text;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS city text;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS state text;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS location text;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS event_date date;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS event_time time without time zone;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS organizer_name text;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS organizer_email text;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS organizer_phone text;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS submitted_by text;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS status text DEFAULT 'pending'::text;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS created_at timestamp with time zone DEFAULT now();
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT now();

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'custom_facebrasil' AND table_name = 'events' AND column_name = 'project_id') THEN
        ALTER TABLE custom_facebrasil.events ALTER COLUMN project_id DROP NOT NULL;
        ALTER TABLE custom_facebrasil.events ALTER COLUMN project_id SET DEFAULT '0b70ae83-8ab7-4b9b-9f3d-8d26eba2d36b'::uuid;
    END IF;
END $$;
"""

# Insert events patch right after CREATE TABLE IF NOT EXISTS custom_facebrasil.events
content = re.sub(
    r'(CREATE TABLE IF NOT EXISTS custom_facebrasil\.events\s*\([^;]+;\s*)',
    r'\1' + events_column_patch + '\n',
    content,
    flags=re.IGNORECASE
)

# Header
header = """-- =========================================================================
-- PASSO 2: CRIAÇÃO DAS TABELAS E FUNÇÕES NO SCHEMA custom_facebrasil
-- 100% Idempotente: pode ser executado repetidas vezes sem erros de duplicidade
-- =========================================================================

SET search_path = custom_facebrasil, public, auth, extensions;

"""

final_sql = header + content

with open(target_file, "w", encoding="utf-8") as f:
    f.write(final_sql)

print(f"Arquivo gerado e protegido: {target_file} ({len(final_sql):,} caracteres)")
