import gzip
import re
import os

backup_file = r"f:\Projetos\_FBR\2FBR-NovaFacebrasil\supabase\db_cluster-19-10-2026@01-13-52.backup.gz"
output_dir = r"f:\Projetos\_FBR\2FBR-NovaFacebrasil\supabase\sql_editor_custom_facebrasil"
os.makedirs(output_dir, exist_ok=True)

app_tables = [
    'user_activities', 'ad_publications', 'ads', 'article_favorites', 'article_reads',
    'articles', 'badges', 'user_badges', 'blogs', 'captured_news', 'categories',
    'challenges', 'events', 'instagram_events', 'user_reputation', 'news_queue',
    'news_sources', 'news_usage', 'partner_offers', 'partners', 'profiles',
    'publications', 'site_settings', 'social_credentials', 'static_pages',
    'user_challenges', 'user_collection_items', 'user_collections', 'user_video_reports',
    'virtual_agents', 'waterfall_posts', 'waterfall_sessions', 'xp_logs'
]

def escape_sql_value(val):
    if val == r"\N":
        return "NULL"
    val = val.replace(r"\\", "\\").replace(r"\n", "\n").replace(r"\r", "\r").replace(r"\t", "\t")
    val = val.replace("'", "''")
    return f"'{val}'"

print("Lendo dump e organizando instruções DDL, dados e índices...")

# We will collect:
# - schema_stmts: CREATE TABLE, CREATE SEQUENCE, CREATE FUNCTION (converted to custom_facebrasil)
# - post_stmts: ALTER TABLE ADD CONSTRAINT, CREATE INDEX, ALTER TABLE ENABLE ROW LEVEL SECURITY, CREATE POLICY
# - copy_data: dict of table -> (columns_list, list_of_rows)

schema_stmts = []
post_stmts = []
copy_data = {}

with gzip.open(backup_file, "rt", encoding="utf-8", errors="ignore") as gz:
    in_postgres = False
    in_copy = False
    copy_table = None
    copy_cols = None
    copy_rows = []
    
    current_statement = []
    in_dollar_quote = False
    dollar_tag = None
    
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
                copy_data[copy_table] = (copy_cols, copy_rows)
                copy_table = None
                copy_cols = None
                copy_rows = []
            else:
                copy_rows.append(line.rstrip("\r\n"))
            continue
            
        m_copy = re.match(r"^COPY ([a-zA-Z0-9_.-]+) \((.*)\) FROM stdin;", line)
        if m_copy:
            in_copy = True
            copy_table = m_copy.group(1)
            copy_cols = [c.strip() for c in m_copy.group(2).split(",")]
            copy_rows = []
            continue
            
        dollar_matches = list(re.finditer(r"\$([a-zA-Z0-9_]*)\$", line))
        for dm in dollar_matches:
            tag = dm.group(0)
            if not in_dollar_quote:
                in_dollar_quote = True
                dollar_tag = tag
            elif tag == dollar_tag:
                in_dollar_quote = False
                dollar_tag = None

        current_statement.append(line)
        if not in_dollar_quote and line.strip().endswith(";"):
            stmt = "".join(current_statement)
            current_statement = []
            
            is_app_stmt = (
                any(f"public.{t}" in stmt for t in app_tables) or
                "CREATE FUNCTION public." in stmt or
                "CREATE OR REPLACE FUNCTION public." in stmt
            )
            
            if is_app_stmt:
                stmt_upper = stmt.strip().upper()
                if (
                    stmt_upper.startswith("CREATE TABLE") or 
                    stmt_upper.startswith("CREATE SEQUENCE") or 
                    stmt_upper.startswith("ALTER SEQUENCE") or 
                    stmt_upper.startswith("CREATE TYPE") or
                    stmt_upper.startswith("CREATE FUNCTION") or
                    stmt_upper.startswith("CREATE OR REPLACE FUNCTION")
                ):
                    schema_stmts.append(stmt)
                elif any(stmt_upper.startswith(x) for x in ["ALTER TABLE", "CREATE INDEX", "CREATE UNIQUE INDEX", "CREATE TRIGGER", "CREATE POLICY", "ALTER PUBLICATION"]):
                    post_stmts.append(stmt)
                elif "GRANT" in stmt_upper or "REVOKE" in stmt_upper:
                    post_stmts.append(stmt)
                else:
                    schema_stmts.append(stmt)

print(f"Total DDL stmts: {len(schema_stmts)}")
print(f"Total Post DDL stmts: {len(post_stmts)}")
print(f"Total COPY tables found: {len(copy_data)}")

# 1. Write 01_schema_and_permissions.sql
with open(os.path.join(output_dir, "01_schema_and_permissions.sql"), "w", encoding="utf-8") as f:
    f.write("""-- =========================================================================
-- PASSO 1: CRIAÇÃO DO SCHEMA E PERMISSÕES DO SUPABASE
-- Execute no SQL Editor do Supabase Studio
-- =========================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE SCHEMA IF NOT EXISTS custom_facebrasil;

-- Conceder permissões para as roles da API do Supabase
GRANT USAGE ON SCHEMA custom_facebrasil TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA custom_facebrasil TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA custom_facebrasil TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA custom_facebrasil TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA custom_facebrasil GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA custom_facebrasil GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA custom_facebrasil GRANT ALL ON ROUTINES TO anon, authenticated, service_role;
""")

# 2. Write 02_tables_and_functions.sql
def adapt_to_custom(text):
    # Replace public.<app_table> with custom_facebrasil.<app_table>
    for t in app_tables:
        text = re.sub(rf'\bpublic\.{t}\b', f'custom_facebrasil.{t}', text)
        text = re.sub(rf'\"public\"\.\"{t}\"', f'"custom_facebrasil"."{t}"', text)
    # Also replace function schemas
    text = re.sub(r'\bpublic\.(calculate_level|check_and_award_badges|handle_new_user|handle_new_user_role|increment_article_views|increment_user_xp|set_current_timestamp_updated_at)\b', r'custom_facebrasil.\1', text)
    return text

with open(os.path.join(output_dir, "02_tables_and_functions.sql"), "w", encoding="utf-8") as f:
    f.write("-- =========================================================================\n")
    f.write("-- PASSO 2: CRIAÇÃO DAS TABELAS E FUNÇÕES NO SCHEMA custom_facebrasil\n")
    f.write("-- =========================================================================\n\n")
    f.write("SET search_path = custom_facebrasil, public, auth, extensions;\n\n")
    for s in schema_stmts:
        f.write(adapt_to_custom(s) + "\n")

# 3. Write 03_base_data.sql (all tables except articles)
base_tables = [
    'profiles', 'categories', 'site_settings', 'virtual_agents', 'news_sources',
    'badges', 'challenges', 'ads', 'ad_publications', 'events', 'static_pages',
    'blogs', 'publications', 'user_reputation', 'captured_news', 'news_usage',
    'user_video_reports', 'waterfall_sessions', 'waterfall_posts', 'article_favorites',
    'article_reads', 'user_activities', 'user_badges', 'user_challenges',
    'user_collection_items', 'user_collections', 'xp_logs', 'social_credentials',
    'instagram_events', 'news_queue'
]

with open(os.path.join(output_dir, "03_base_data.sql"), "w", encoding="utf-8") as f:
    f.write("-- =========================================================================\n")
    f.write("-- PASSO 3: CARGA DE DADOS BASE (Perfis, Categorias, Configurações, Ads, etc.)\n")
    f.write("-- =========================================================================\n\n")
    f.write("SET search_path = custom_facebrasil, public;\n\n")
    
    for tbl in base_tables:
        key = f"public.{tbl}"
        if key in copy_data:
            cols, rows = copy_data[key]
            if not rows:
                continue
            f.write(f"-- Tabela custom_facebrasil.{tbl} ({len(rows)} registros)\n")
            col_names = ", ".join([f'"{c}"' for c in cols])
            
            # Write in batches of 100 rows
            batch_size = 100
            for i in range(0, len(rows), batch_size):
                batch = rows[i:i+batch_size]
                f.write(f"INSERT INTO custom_facebrasil.{tbl} ({col_names}) VALUES\n")
                val_lines = []
                for r in batch:
                    vals = [escape_sql_value(v) for v in r.split("\t")]
                    val_lines.append(f"  ({', '.join(vals)})")
                f.write(",\n".join(val_lines))
                f.write("\nON CONFLICT DO NOTHING;\n\n")

# 4. Write 04_auth_and_storage.sql
with open(os.path.join(output_dir, "04_auth_and_storage.sql"), "w", encoding="utf-8") as f:
    f.write("-- =========================================================================\n")
    f.write("-- PASSO 4: USUÁRIOS DE AUTENTICAÇÃO E STORAGE DO SUPABASE\n")
    f.write("-- =========================================================================\n\n")
    
    # auth.users
    if "auth.users" in copy_data:
        cols, rows = copy_data["auth.users"]
        col_names = ", ".join([f'"{c}"' for c in cols])
        f.write(f"-- auth.users ({len(rows)} usuarios)\n")
        f.write(f"INSERT INTO auth.users ({col_names}) VALUES\n")
        val_lines = []
        for r in rows:
            vals = [escape_sql_value(v) for v in r.split("\t")]
            val_lines.append(f"  ({', '.join(vals)})")
        f.write(",\n".join(val_lines))
        f.write("\nON CONFLICT (id) DO NOTHING;\n\n")
        
    # auth.identities
    if "auth.identities" in copy_data:
        cols, rows = copy_data["auth.identities"]
        col_names = ", ".join([f'"{c}"' for c in cols])
        f.write(f"-- auth.identities ({len(rows)} identidades)\n")
        f.write(f"INSERT INTO auth.identities ({col_names}) VALUES\n")
        val_lines = []
        for r in rows:
            vals = [escape_sql_value(v) for v in r.split("\t")]
            val_lines.append(f"  ({', '.join(vals)})")
        f.write(",\n".join(val_lines))
        f.write("\nON CONFLICT (id) DO NOTHING;\n\n")
        
    # storage.buckets
    if "storage.buckets" in copy_data:
        cols, rows = copy_data["storage.buckets"]
        col_names = ", ".join([f'"{c}"' for c in cols])
        f.write(f"-- storage.buckets ({len(rows)} buckets)\n")
        f.write(f"INSERT INTO storage.buckets ({col_names}) VALUES\n")
        val_lines = []
        for r in rows:
            vals = [escape_sql_value(v) for v in r.split("\t")]
            val_lines.append(f"  ({', '.join(vals)})")
        f.write(",\n".join(val_lines))
        f.write("\nON CONFLICT (id) DO NOTHING;\n\n")

    # storage.objects
    if "storage.objects" in copy_data:
        cols, rows = copy_data["storage.objects"]
        col_names = ", ".join([f'"{c}"' for c in cols])
        f.write(f"-- storage.objects ({len(rows)} objetos)\n")
        batch_size = 50
        for i in range(0, len(rows), batch_size):
            batch = rows[i:i+batch_size]
            f.write(f"INSERT INTO storage.objects ({col_names}) VALUES\n")
            val_lines = []
            for r in batch:
                vals = [escape_sql_value(v) for v in r.split("\t")]
                val_lines.append(f"  ({', '.join(vals)})")
            f.write(",\n".join(val_lines))
            f.write("\nON CONFLICT (id) DO NOTHING;\n\n")

# 5. Write 05_articles in batches of 1500 rows
if "public.articles" in copy_data:
    cols, rows = copy_data["public.articles"]
    col_names = ", ".join([f'"{c}"' for c in cols])
    total_articles = len(rows)
    batch_file_size = 1500
    file_idx = 1
    
    for start_idx in range(0, total_articles, batch_file_size):
        end_idx = min(start_idx + batch_file_size, total_articles)
        sub_rows = rows[start_idx:end_idx]
        filename = f"05_articles_part_{file_idx}.sql"
        
        with open(os.path.join(output_dir, filename), "w", encoding="utf-8") as f:
            f.write(f"-- =========================================================================\n")
            f.write(f"-- PASSO 5 - PARTE {file_idx}: ARTIGOS {start_idx+1} A {end_idx} DE {total_articles}\n")
            f.write(f"-- =========================================================================\n\n")
            f.write("SET search_path = custom_facebrasil, public;\n\n")
            
            chunk_size = 50
            for i in range(0, len(sub_rows), chunk_size):
                chunk = sub_rows[i:i+chunk_size]
                f.write(f"INSERT INTO custom_facebrasil.articles ({col_names}) VALUES\n")
                val_lines = []
                for r in chunk:
                    vals = [escape_sql_value(v) for v in r.split("\t")]
                    val_lines.append(f"  ({', '.join(vals)})")
                f.write(",\n".join(val_lines))
                f.write("\nON CONFLICT (id) DO NOTHING;\n\n")
                
        file_idx += 1

# 6. Write 06_constraints_and_indexes.sql
with open(os.path.join(output_dir, "06_constraints_and_indexes.sql"), "w", encoding="utf-8") as f:
    f.write("-- =========================================================================\n")
    f.write("-- PASSO 6: ÍNDICES, CONSTRAINTS E POLÍTICAS RLS NO SCHEMA custom_facebrasil\n")
    f.write("-- =========================================================================\n\n")
    f.write("SET search_path = custom_facebrasil, public, auth, extensions;\n\n")
    for s in post_stmts:
        f.write(adapt_to_custom(s) + "\n")
        
    # Add grant all to anon, authenticated and service_role
    f.write("""
-- Permissões completas finais
GRANT ALL ON ALL TABLES IN SCHEMA custom_facebrasil TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA custom_facebrasil TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA custom_facebrasil TO anon, authenticated, service_role;
""")

print("Processo concluído com êxito!")
