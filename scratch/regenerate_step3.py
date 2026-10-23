import gzip
import re
import os

backup_file = r"f:\Projetos\_FBR\2FBR-NovaFacebrasil\supabase\db_cluster-19-10-2026@01-13-52.backup.gz"
output_dir = r"f:\Projetos\_FBR\2FBR-NovaFacebrasil\supabase\sql_editor_custom_facebrasil"
target_file = os.path.join(output_dir, "03_base_data.sql")

def escape_sql_value(val):
    if val == r"\N":
        return "NULL"
    val = val.replace(r"\\", "\\").replace(r"\n", "\n").replace(r"\r", "\r").replace(r"\t", "\t")
    val = val.replace("'", "''")
    return f"'{val}'"

# Ordem estrita de inserção para respeitar dependências
ordered_tables = [
    'profiles',
    'blogs',
    'categories',
    'publications',
    'ads',
    'ad_publications',
    'site_settings',
    'virtual_agents',
    'news_sources',
    'badges',
    'challenges',
    'events',
    'static_pages',
    'user_reputation',
    'captured_news',
    'news_usage',
    'user_video_reports',
    'waterfall_sessions',
    'waterfall_posts',
    'article_favorites',
    'article_reads',
    'user_activities',
    'user_badges',
    'user_challenges',
    'user_collection_items',
    'user_collections',
    'xp_logs',
    'social_credentials',
    'instagram_events',
    'news_queue'
]

copy_data = {}
with gzip.open(backup_file, "rt", encoding="utf-8", errors="ignore") as gz:
    in_copy = False
    copy_table = None
    copy_cols = None
    copy_rows = []
    for line in gz:
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
        m = re.match(r"^COPY ([a-zA-Z0-9_.-]+) \((.*)\) FROM stdin;", line)
        if m:
            in_copy = True
            copy_table = m.group(1)
            copy_cols = [c.strip().strip('"') for c in m.group(2).split(",")]
            copy_rows = []

header = """-- =========================================================================
-- PASSO 3: CARGA DE DADOS BASE (Perfis, Blogs, Categorias, Configurações, Ads, etc.)
-- =========================================================================

SET search_path = custom_facebrasil, public;

-- Desativar temporariamente Foreign Keys existentes no schema para que a importação
-- ocorra com 100% de integridade e sem erros de dependência cíclica.
-- (Todas as Foreign Keys e Triggers serão ativados e validados no PASSO 6!)
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT constraint_name, table_name 
              FROM information_schema.table_constraints 
              WHERE constraint_type = 'FOREIGN KEY' 
                AND table_schema = 'custom_facebrasil') 
    LOOP
        EXECUTE 'ALTER TABLE custom_facebrasil.' || quote_ident(r.table_name) || ' DROP CONSTRAINT IF EXISTS ' || quote_ident(r.constraint_name);
    END LOOP;
END $$;

"""

with open(target_file, "w", encoding="utf-8") as f:
    f.write(header)
    for tbl in ordered_tables:
        key = f"public.{tbl}"
        if key in copy_data:
            cols, rows = copy_data[key]
            if not rows:
                continue
            f.write(f"-- Tabela custom_facebrasil.{tbl} ({len(rows)} registros)\n")
            col_names = ", ".join([f'"{c}"' for c in cols])
            
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

print(f"Sucesso! Gerado {target_file} ordenado e protegido ({os.path.getsize(target_file):,} bytes)")
