import gzip
import re
import os

backup_file = r"f:\Projetos\_FBR\2FBR-NovaFacebrasil\supabase\db_cluster-19-10-2026@01-13-52.backup.gz"
output_dir = r"f:\Projetos\_FBR\2FBR-NovaFacebrasil\supabase\sql_editor_custom_facebrasil"

step2_file = os.path.join(output_dir, "02_tables_and_functions.sql")
step6_file = os.path.join(output_dir, "06_constraints_and_indexes.sql")

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

all_statements = []
current_stmt = []
in_dollar = False
dollar_tag = None
in_postgres = False
in_copy = False

with gzip.open(backup_file, "rt", encoding="utf-8", errors="ignore") as gz:
    for line in gz:
        if line.startswith(r"\connect template1"):
            in_postgres = False
            continue
        elif line.startswith(r"\connect postgres"):
            in_postgres = True
            continue
            
        if not in_postgres:
            continue
            
        if in_copy:
            if line.strip() == r"\.":
                in_copy = False
            continue
            
        if re.match(r"^COPY ", line):
            in_copy = True
            continue
            
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
                all_statements.append(stmt)

print(f"Statements lidos: {len(all_statements)}")

step2_functions = []
step2_tables = []
step2_primary_and_unique = []

step6_foreign_keys = []
step6_triggers = []
step6_indexes = []
step6_rls_policies = []

for stmt in all_statements:
    stmt_upper = stmt.upper()
    
    # 1. Functions
    if re.search(r"\bCREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\b", stmt, re.IGNORECASE):
        is_app_func = any(f"public.{f}" in stmt or f"{f}(" in stmt for f in app_functions)
        if is_app_func:
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
            step2_functions.append(stmt)
        continue

    # 2. Tables
    if re.search(r"\bCREATE\s+TABLE\b", stmt, re.IGNORECASE):
        is_app_tbl = any(f"public.{t}" in stmt for t in app_tables)
        if is_app_tbl:
            for tbl in app_tables:
                stmt = re.sub(
                    rf'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:public\.)?{tbl}\s*\(',
                    f'CREATE TABLE IF NOT EXISTS custom_facebrasil.{tbl} (',
                    stmt,
                    flags=re.IGNORECASE
                )
                stmt = re.sub(rf'\bpublic\.{tbl}\b', f'custom_facebrasil.{tbl}', stmt)
                stmt = re.sub(rf'\"public\"\.\"{tbl}\"', f'"custom_facebrasil"."{tbl}"', stmt)
            step2_tables.append(stmt)
        continue

    # 3. Foreign Keys
    if "FOREIGN KEY" in stmt_upper and any(f"public.{t}" in stmt or f"custom_facebrasil.{t}" in stmt for t in app_tables):
        m = re.search(r"ALTER\s+TABLE\s+(?:ONLY\s+)?(?:public\.)?([a-zA-Z0-9_]+)\s+ADD\s+CONSTRAINT\s+([a-zA-Z0-9_]+)\s+FOREIGN\s+KEY", stmt, re.IGNORECASE)
        if m:
            tbl_name = m.group(1)
            const_name = m.group(2)
            for tbl in app_tables:
                stmt = re.sub(rf'\bpublic\.{tbl}\b', f'custom_facebrasil.{tbl}', stmt)
                stmt = re.sub(rf'\"public\"\.\"{tbl}\"', f'"custom_facebrasil"."{tbl}"', stmt)
                stmt = re.sub(rf'\bREFERENCES\s+(?:public\.)?{tbl}\b', f'REFERENCES custom_facebrasil.{tbl}', stmt, flags=re.IGNORECASE)
            stmt = re.sub(r"ALTER\s+TABLE\s+(?:ONLY\s+)?(?:custom_facebrasil\.)?[a-zA-Z0-9_]+", f"ALTER TABLE ONLY custom_facebrasil.{tbl_name}", stmt, count=1, flags=re.IGNORECASE)
            idempotent_fk = f"ALTER TABLE custom_facebrasil.{tbl_name} DROP CONSTRAINT IF EXISTS {const_name};\n{stmt}"
            step6_foreign_keys.append(idempotent_fk)
            continue

    # 4. Primary Keys and Unique constraints
    if ("PRIMARY KEY" in stmt_upper or "UNIQUE (" in stmt_upper or "UNIQUE KEY" in stmt_upper) and any(f"public.{t}" in stmt for t in app_tables):
        m = re.search(r"ALTER\s+TABLE\s+(?:ONLY\s+)?(?:public\.)?([a-zA-Z0-9_]+)\s+ADD\s+CONSTRAINT\s+([a-zA-Z0-9_]+)", stmt, re.IGNORECASE)
        if m:
            tbl_name = m.group(1)
            const_name = m.group(2)
            for tbl in app_tables:
                stmt = re.sub(rf'\bpublic\.{tbl}\b', f'custom_facebrasil.{tbl}', stmt)
                stmt = re.sub(rf'\"public\"\.\"{tbl}\"', f'"custom_facebrasil"."{tbl}"', stmt)
            stmt = re.sub(r"ALTER\s+TABLE\s+(?:ONLY\s+)?(?:custom_facebrasil\.)?[a-zA-Z0-9_]+", f"ALTER TABLE ONLY custom_facebrasil.{tbl_name}", stmt, count=1, flags=re.IGNORECASE)
            idempotent_pk = f"ALTER TABLE custom_facebrasil.{tbl_name} DROP CONSTRAINT IF EXISTS {const_name};\n{stmt}"
            step2_primary_and_unique.append(idempotent_pk)
            continue

    # 5. Triggers
    if re.search(r"\bCREATE\s+TRIGGER\b", stmt, re.IGNORECASE) and (any(f"public.{t}" in stmt for t in app_tables) or "auth.users" in stmt):
        m = re.search(r"CREATE\s+TRIGGER\s+([a-zA-Z0-9_]+)\s+((?:BEFORE|AFTER|INSTEAD\s+OF)\s+[A-Z\s]+)\s+ON\s+([a-zA-Z0-9_.]+)\s+(.*)", stmt, re.IGNORECASE | re.DOTALL)
        if m:
            trig_name = m.group(1)
            timing_event = m.group(2)
            tbl_full = m.group(3)
            rest = m.group(4)
            for tbl in app_tables:
                tbl_full = re.sub(rf'\b(?:public\.)?{tbl}\b', f'custom_facebrasil.{tbl}', tbl_full)
            for func in app_functions:
                rest = re.sub(rf'\b(?:public\.)?{func}\s*\(', f'custom_facebrasil.{func}(', rest)
            idempotent_trig = f"DROP TRIGGER IF EXISTS {trig_name} ON {tbl_full};\nCREATE TRIGGER {trig_name} {timing_event} ON {tbl_full} {rest}"
            step6_triggers.append(idempotent_trig)
            continue

    # 6. Indexes
    if re.search(r"\bCREATE\s+(?:UNIQUE\s+)?INDEX\b", stmt, re.IGNORECASE) and any(f"public.{t}" in stmt for t in app_tables):
        stmt = re.sub(r"CREATE\s+UNIQUE\s+INDEX\s+(?:IF\s+NOT\s+EXISTS\s+)?", "CREATE UNIQUE INDEX IF NOT EXISTS ", stmt, flags=re.IGNORECASE)
        stmt = re.sub(r"CREATE\s+INDEX\s+(?:IF\s+NOT\s+EXISTS\s+)?", "CREATE INDEX IF NOT EXISTS ", stmt, flags=re.IGNORECASE)
        for tbl in app_tables:
            stmt = re.sub(rf'\bON\s+(?:public\.)?{tbl}\b', f'ON custom_facebrasil.{tbl}', stmt, flags=re.IGNORECASE)
            stmt = re.sub(rf'\bpublic\.{tbl}\b', f'custom_facebrasil.{tbl}', stmt)
            stmt = re.sub(rf'\"public\"\.\"{tbl}\"', f'"custom_facebrasil"."{tbl}"', stmt)
        step6_indexes.append(stmt)
        continue

    # 7. RLS and Policies
    if ("ROW LEVEL SECURITY" in stmt_upper or "POLICY" in stmt_upper) and any(f"public.{t}" in stmt for t in app_tables):
        for tbl in app_tables:
            stmt = re.sub(rf'\bpublic\.{tbl}\b', f'custom_facebrasil.{tbl}', stmt)
            stmt = re.sub(rf'\"public\"\.\"{tbl}\"', f'"custom_facebrasil"."{tbl}"', stmt)
        step6_rls_policies.append(stmt)
        continue

print(f"Resultados com re.search:")
print(f"  - Funções (Passo 2): {len(step2_functions)}")
print(f"  - Tabelas (Passo 2): {len(step2_tables)}")
print(f"  - Primary Keys & Uniques (Passo 2): {len(step2_primary_and_unique)}")
print(f"  - Foreign Keys (Passo 6): {len(step6_foreign_keys)}")
print(f"  - Triggers (Passo 6): {len(step6_triggers)}")
print(f"  - Índices (Passo 6): {len(step6_indexes)}")
print(f"  - Políticas RLS (Passo 6): {len(step6_rls_policies)}")

# 1. WRITE STEP 2
events_patch = """
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
--
-- ATENÇÃO:
-- 1. Este arquivo cria APENAS a estrutura base (Tabelas, Primary Keys e Funções).
-- 2. NÃO contém nenhuma Foreign Key (elas foram movidas para o PASSO 6).
-- 3. NÃO contém nenhum Trigger (eles foram movidos para o PASSO 6).
-- Isso garante que toda a carga de dados dos Passos 3, 4 e 5 entre com 100% de sucesso!
-- =========================================================================

SET search_path = custom_facebrasil, public, auth, extensions;

-- =========================================================================
-- 1. FUNÇÕES PLPGSQL DA APLICAÇÃO
-- =========================================================================
""")
    for func_stmt in step2_functions:
        f.write(func_stmt + "\n\n")

    f.write("""
-- =========================================================================
-- 2. TABELAS DE NEGÓCIO
-- =========================================================================
""")
    for tbl_stmt in step2_tables:
        f.write(tbl_stmt + "\n\n")
        if "custom_facebrasil.events " in tbl_stmt:
            f.write(events_patch + "\n\n")

    f.write("""
-- =========================================================================
-- 3. CHAVES PRIMÁRIAS E CONSTRAINTS DE UNICIDADE
-- =========================================================================
""")
    for pk_stmt in step2_primary_and_unique:
        f.write(pk_stmt + "\n\n")

print(f"Passo 2 gerado: {step2_file} ({os.path.getsize(step2_file):,} bytes)")

# 2. WRITE STEP 6
with open(step6_file, "w", encoding="utf-8") as f:
    f.write("""-- =========================================================================
-- PASSO 6: CHAVES ESTRANGEIRAS, TRIGGERS, ÍNDICES E SEGURANÇA (RLS)
-- Execute este arquivo após concluir a importação de TODOS os dados (Passos 3, 4 e 5).
-- =========================================================================

SET search_path = custom_facebrasil, public, auth, extensions;

-- =========================================================================
-- 1. FOREIGN KEYS (CHAVES ESTRANGEIRAS ENTRE TABELAS)
-- =========================================================================
""")
    for fk in step6_foreign_keys:
        f.write(fk + "\n\n")

    f.write("""
-- =========================================================================
-- 2. TRIGGERS AUTOMÁTICOS
-- =========================================================================
""")
    for tr in step6_triggers:
        f.write(tr + "\n\n")

    f.write("""
-- =========================================================================
-- 3. ÍNDICES DE ALTA PERFORMANCE
-- =========================================================================
""")
    for idx in step6_indexes:
        f.write(idx + "\n\n")

    f.write("""
-- =========================================================================
-- 4. ROW LEVEL SECURITY (RLS) E POLÍTICAS DE ACESSO
-- =========================================================================
""")
    for pol in step6_rls_policies:
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
