import re
import os

source_file = r"f:\Projetos\_FBR\2FBR-NovaFacebrasil\supabase\migration_clean\01_schema_tables.sql"
step2_file = r"f:\Projetos\_FBR\2FBR-NovaFacebrasil\supabase\sql_editor_custom_facebrasil\02_tables_and_functions.sql"
step6_file = r"f:\Projetos\_FBR\2FBR-NovaFacebrasil\supabase\sql_editor_custom_facebrasil\06_constraints_and_indexes.sql"

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

print("Separando DDL base (tabelas e funcoes) das Foreign Keys e Triggers...")

with open(source_file, "r", encoding="utf-8") as f:
    raw_content = f.read()

# Separate statements
# Let's split raw_content by standard statement delimiters (double newlines / comment blocks)
# Actually, let's parse statement by statement using regex
statements = []
current_stmt = []
in_dollar = False
dollar_tag = None

for line in raw_content.splitlines(keepends=True):
    dollar_matches = list(re.finditer(r"\$([a-zA-Z0-9_]*)\$", line))
    for dm in dollar_matches:
        tag = dm.group(0)
        if not in_dollar:
            in_dollar = True
            dollar_tag = tag
        elif tag == dollar_tag:
            in_dollar = False
            dollar_tag = None

    current_stmt.append(line)
    if not in_dollar and line.strip().endswith(";"):
        stmt = "".join(current_stmt).strip()
        current_stmt = []
        if stmt:
            statements.append(stmt)

step2_stmts = []
foreign_keys = []
triggers = []
indexes = []
policies = []
owners_and_grants = []

for stmt in statements:
    stmt_upper = stmt.upper()
    
    # 1. Functions
    if re.match(r"^CREATE (?:OR REPLACE )?FUNCTION", stmt, re.IGNORECASE):
        # Adapt function to custom_facebrasil
        for func in app_functions:
            stmt = re.sub(
                rf'CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+(?:public\.)?{func}\b',
                f'CREATE OR REPLACE FUNCTION custom_facebrasil.{func}',
                stmt,
                flags=re.IGNORECASE
            )
        for tbl in app_tables:
            stmt = re.sub(rf'\bpublic\.{tbl}\b', f'custom_facebrasil.{tbl}', stmt)
            stmt = re.sub(rf'\"public\"\.\"{tbl}\"', f'"custom_facebrasil"."{tbl}"', stmt)
        for func in app_functions:
            stmt = re.sub(rf'\bpublic\.{func}\s*\(', f'custom_facebrasil.{func}(', stmt)
        step2_stmts.append(stmt)
        continue

    # 2. Tables
    if re.match(r"^CREATE TABLE", stmt, re.IGNORECASE):
        for tbl in app_tables:
            stmt = re.sub(
                rf'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:public\.)?{tbl}\s*\(',
                f'CREATE TABLE IF NOT EXISTS custom_facebrasil.{tbl} (',
                stmt,
                flags=re.IGNORECASE
            )
            stmt = re.sub(rf'\bpublic\.{tbl}\b', f'custom_facebrasil.{tbl}', stmt)
            stmt = re.sub(rf'\"public\"\.\"{tbl}\"', f'"custom_facebrasil"."{tbl}"', stmt)
        step2_stmts.append(stmt)
        continue

    # 3. Foreign Keys (ALTER TABLE ... ADD CONSTRAINT ... FOREIGN KEY)
    if "FOREIGN KEY" in stmt_upper:
        m = re.search(r"ALTER\s+TABLE\s+(?:ONLY\s+)?(?:public\.)?([a-zA-Z0-9_]+)\s+ADD\s+CONSTRAINT\s+([a-zA-Z0-9_]+)\s+FOREIGN\s+KEY", stmt, re.IGNORECASE)
        if m:
            tbl_name = m.group(1)
            const_name = m.group(2)
            for tbl in app_tables:
                stmt = re.sub(rf'\bpublic\.{tbl}\b', f'custom_facebrasil.{tbl}', stmt)
                stmt = re.sub(rf'\"public\"\.\"{tbl}\"', f'"custom_facebrasil"."{tbl}"', stmt)
                stmt = re.sub(rf'\bREFERENCES\s+(?:public\.)?{tbl}\b', f'REFERENCES custom_facebrasil.{tbl}', stmt, flags=re.IGNORECASE)
            stmt = re.sub(r"^ALTER\s+TABLE\s+(?:ONLY\s+)?(?:custom_facebrasil\.)?[a-zA-Z0-9_]+", f"ALTER TABLE ONLY custom_facebrasil.{tbl_name}", stmt, flags=re.IGNORECASE)
            idempotent_fk = f"ALTER TABLE custom_facebrasil.{tbl_name} DROP CONSTRAINT IF EXISTS {const_name};\n{stmt}"
            foreign_keys.append(idempotent_fk)
            continue

    # 4. Primary Keys and Unique constraints (keep in step 2 so ON CONFLICT works!)
    if "PRIMARY KEY" in stmt_upper or "UNIQUE (" in stmt_upper or "UNIQUE KEY" in stmt_upper:
        m = re.search(r"ALTER\s+TABLE\s+(?:ONLY\s+)?(?:public\.)?([a-zA-Z0-9_]+)\s+ADD\s+CONSTRAINT\s+([a-zA-Z0-9_]+)", stmt, re.IGNORECASE)
        if m:
            tbl_name = m.group(1)
            const_name = m.group(2)
            for tbl in app_tables:
                stmt = re.sub(rf'\bpublic\.{tbl}\b', f'custom_facebrasil.{tbl}', stmt)
                stmt = re.sub(rf'\"public\"\.\"{tbl}\"', f'"custom_facebrasil"."{tbl}"', stmt)
            stmt = re.sub(r"^ALTER\s+TABLE\s+(?:ONLY\s+)?(?:custom_facebrasil\.)?[a-zA-Z0-9_]+", f"ALTER TABLE ONLY custom_facebrasil.{tbl_name}", stmt, flags=re.IGNORECASE)
            idempotent_pk = f"ALTER TABLE custom_facebrasil.{tbl_name} DROP CONSTRAINT IF EXISTS {const_name};\n{stmt}"
            step2_stmts.append(idempotent_pk)
            continue

    # 5. Triggers
    if re.match(r"^CREATE TRIGGER", stmt, re.IGNORECASE):
        m = re.search(r"^CREATE\s+TRIGGER\s+([a-zA-Z0-9_]+)\s+((?:BEFORE|AFTER|INSTEAD\s+OF)\s+[A-Z\s]+)\s+ON\s+(?:public\.)?([a-zA-Z0-9_]+)\s+(.*)", stmt, re.IGNORECASE | re.DOTALL)
        if m:
            trig_name = m.group(1)
            timing_event = m.group(2)
            tbl_name = m.group(3)
            rest = m.group(4)
            for func in app_functions:
                rest = re.sub(rf'\b(?:public\.)?{func}\s*\(', f'custom_facebrasil.{func}(', rest)
            idempotent_trig = f"DROP TRIGGER IF EXISTS {trig_name} ON custom_facebrasil.{tbl_name};\nCREATE TRIGGER {trig_name} {timing_event} ON custom_facebrasil.{tbl_name} {rest}"
            triggers.append(idempotent_trig)
            continue

    # 6. Indexes
    if re.match(r"^CREATE (?:UNIQUE )?INDEX", stmt, re.IGNORECASE):
        stmt = re.sub(r"^CREATE UNIQUE INDEX\s+(?:IF NOT EXISTS\s+)?", "CREATE UNIQUE INDEX IF NOT EXISTS ", stmt, flags=re.IGNORECASE)
        stmt = re.sub(r"^CREATE INDEX\s+(?:IF NOT EXISTS\s+)?", "CREATE INDEX IF NOT EXISTS ", stmt, flags=re.IGNORECASE)
        for tbl in app_tables:
            stmt = re.sub(rf'\bON\s+(?:public\.)?{tbl}\b', f'ON custom_facebrasil.{tbl}', stmt, flags=re.IGNORECASE)
            stmt = re.sub(rf'\bpublic\.{tbl}\b', f'custom_facebrasil.{tbl}', stmt)
            stmt = re.sub(rf'\"public\"\.\"{tbl}\"', f'"custom_facebrasil"."{tbl}"', stmt)
        indexes.append(stmt)
        continue

    # 7. RLS & Policies
    if "ROW LEVEL SECURITY" in stmt_upper or "POLICY" in stmt_upper:
        for tbl in app_tables:
            stmt = re.sub(rf'\bpublic\.{tbl}\b', f'custom_facebrasil.{tbl}', stmt)
            stmt = re.sub(rf'\"public\"\.\"{tbl}\"', f'"custom_facebrasil"."{tbl}"', stmt)
        policies.append(stmt)
        continue

    # 8. Comments
    if re.match(r"^COMMENT ON", stmt, re.IGNORECASE):
        for tbl in app_tables:
            stmt = re.sub(rf'\bpublic\.{tbl}\b', f'custom_facebrasil.{tbl}', stmt)
            stmt = re.sub(rf'\"public\"\.\"{tbl}\"', f'"custom_facebrasil"."{tbl}"', stmt)
        safe_comment = f"DO $$ BEGIN\n  {stmt}\nEXCEPTION WHEN undefined_column OR undefined_table THEN NULL;\nEND $$;"
        step2_stmts.append(safe_comment)
        continue

    # Other statements
    for tbl in app_tables:
        stmt = re.sub(rf'\bpublic\.{tbl}\b', f'custom_facebrasil.{tbl}', stmt)
        stmt = re.sub(rf'\"public\"\.\"{tbl}\"', f'"custom_facebrasil"."{tbl}"', stmt)
    owners_and_grants.append(stmt)

print(f"Estatisticas da separacao:")
print(f"  - Step 2 DDL statements: {len(step2_stmts)}")
print(f"  - Foreign Keys: {len(foreign_keys)}")
print(f"  - Triggers: {len(triggers)}")
print(f"  - Indexes: {len(indexes)}")
print(f"  - Policies: {len(policies)}")

# 1. WRITE STEP 2 (TABLES, PRIMARY KEYS, UNIQUE CONSTRAINTS, FUNCTIONS - ZERO FOREIGN KEYS & ZERO TRIGGERS!)
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

with open(step2_file, "w", encoding="utf-8") as f:
    f.write("""-- =========================================================================
-- PASSO 2: CRIAÇÃO DAS TABELAS, CHAVES PRIMÁRIAS E FUNÇÕES NO SCHEMA custom_facebrasil
-- IMPORTANTE: Foreign Keys e Triggers foram movidos para o PASSO 6 para garantir
-- que a carga de dados (Passos 3, 4 e 5) execute com ZERO conflitos de dependência!
-- =========================================================================

SET search_path = custom_facebrasil, public, auth, extensions;

""")
    for s in step2_stmts:
        f.write(s + "\n\n")
        if "CREATE TABLE IF NOT EXISTS custom_facebrasil.events " in s:
            f.write(events_column_patch + "\n\n")

print(f"Passo 2 gerado: {step2_file} ({os.path.getsize(step2_file):,} bytes)")

# 2. WRITE STEP 6 (FOREIGN KEYS, TRIGGERS, INDEXES, RLS, GRANTS)
with open(step6_file, "w", encoding="utf-8") as f:
    f.write("""-- =========================================================================
-- PASSO 6: FOREIGN KEYS, TRIGGERS, ÍNDICES E SEGURANÇA (RLS)
-- Execute este arquivo APÓS a conclusão da carga de dados (Passos 3, 4 e 5)
-- =========================================================================

SET search_path = custom_facebrasil, public, auth, extensions;

-- =========================================================================
-- 1. FOREIGN KEYS (CHAVES ESTRANGEIRAS)
-- =========================================================================
""")
    for fk in foreign_keys:
        f.write(fk + "\n\n")

    f.write("""
-- =========================================================================
-- 2. TRIGGERS
-- =========================================================================
""")
    for tr in triggers:
        f.write(tr + "\n\n")

    f.write("""
-- =========================================================================
-- 3. ÍNDICES DE ALTA PERFORMANCE
-- =========================================================================
""")
    for idx in indexes:
        f.write(idx + "\n\n")

    f.write("""
-- =========================================================================
-- 4. ROW LEVEL SECURITY (RLS) & POLICIES
-- =========================================================================
""")
    for pol in policies:
        f.write(pol + "\n\n")

    f.write("""
-- =========================================================================
-- 5. PERMISSÕES FINAIS (GRANTS)
-- =========================================================================
GRANT ALL ON ALL TABLES IN SCHEMA custom_facebrasil TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA custom_facebrasil TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA custom_facebrasil TO anon, authenticated, service_role;
""")

print(f"Passo 6 gerado: {step6_file} ({os.path.getsize(step6_file):,} bytes)")
