import gzip
import re
import os

backup_file = r"f:\Projetos\_FBR\2FBR-NovaFacebrasil\supabase\db_cluster-19-10-2026@01-13-52.backup.gz"
output_dir = r"f:\Projetos\_FBR\2FBR-NovaFacebrasil\supabase\migration_clean"
os.makedirs(output_dir, exist_ok=True)

schema_file = os.path.join(output_dir, "01_schema_tables.sql")
data_file = os.path.join(output_dir, "02_data.sql")
post_data_file = os.path.join(output_dir, "03_indexes_constraints_rls.sql")
auth_storage_file = os.path.join(output_dir, "04_auth_and_storage.sql")

app_tables = {
    'user_activities', 'ad_publications', 'ads', 'article_favorites', 'article_reads',
    'articles', 'badges', 'user_badges', 'blogs', 'captured_news', 'categories',
    'challenges', 'events', 'instagram_events', 'user_reputation', 'news_queue',
    'news_sources', 'news_usage', 'partner_offers', 'partners', 'profiles',
    'publications', 'site_settings', 'social_credentials', 'static_pages',
    'user_challenges', 'user_collection_items', 'user_collections', 'user_video_reports',
    'virtual_agents', 'waterfall_posts', 'waterfall_sessions', 'xp_logs'
}

auth_storage_tables = {
    'auth.users', 'auth.identities', 'storage.buckets', 'storage.objects'
}

print("Iniciando extração robusta com dollar-quoting handling...")

with gzip.open(backup_file, "rt", encoding="utf-8", errors="ignore") as gz, \
     open(schema_file, "w", encoding="utf-8") as f_schema, \
     open(data_file, "w", encoding="utf-8") as f_data, \
     open(post_data_file, "w", encoding="utf-8") as f_post, \
     open(auth_storage_file, "w", encoding="utf-8") as f_auth:

    in_postgres = False
    in_copy = False
    copy_target = None
    copy_buffer = []
    
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
            
        # Handle COPY data block
        if in_copy:
            if line.strip() == r"\.":
                in_copy = False
                copy_buffer.append(line)
                full_copy = "".join(copy_buffer)
                if copy_target in [f"public.{t}" for t in app_tables] or copy_target in app_tables:
                    f_data.write(full_copy + "\n")
                elif copy_target in auth_storage_tables:
                    f_auth.write(full_copy + "\n")
                copy_buffer = []
                copy_target = None
            else:
                copy_buffer.append(line)
            continue
            
        m_copy = re.match(r"^COPY ([a-zA-Z0-9_.-]+) (?:.*) FROM stdin;", line)
        if m_copy:
            in_copy = True
            copy_target = m_copy.group(1)
            copy_buffer = [line]
            continue
            
        # Statements for schema / post-data
        # Track dollar quoting: e.g. $$ or $tag$
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
            
            # Check if stmt is for public tables or public functions/types
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
                    f_schema.write(stmt + "\n")
                elif any(stmt_upper.startswith(x) for x in ["ALTER TABLE", "CREATE INDEX", "CREATE UNIQUE INDEX", "CREATE TRIGGER", "CREATE POLICY", "ALTER PUBLICATION"]):
                    f_post.write(stmt + "\n")
                elif "GRANT" in stmt_upper or "REVOKE" in stmt_upper:
                    f_post.write(stmt + "\n")
                else:
                    f_schema.write(stmt + "\n")
            elif any(tbl in stmt for tbl in ["auth.users", "storage.buckets", "storage.objects"]):
                if "INSERT INTO" in stmt or "GRANT" in stmt:
                    f_auth.write(stmt + "\n")

print("Extração robusta concluída com sucesso!")
for f in [schema_file, data_file, post_data_file, auth_storage_file]:
    sz = os.path.getsize(f)
    print(f"{os.path.basename(f)}: {sz:,} bytes")
