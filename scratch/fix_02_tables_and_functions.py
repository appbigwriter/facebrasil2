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

app_functions = [
    'calculate_level', 'check_and_award_badges', 'ensure_profile_exists',
    'handle_new_user', 'handle_new_user_role', 'increment_ad_clicks',
    'increment_ad_curiosity', 'increment_ad_views', 'increment_article_views',
    'increment_user_xp', 'reset_expired_heroes', 'reset_weekly_points',
    'set_hero_timestamp', 'set_updated_at', 'toggle_article_favorite',
    'update_events_updated_at', 'update_updated_at_column',
    'update_updated_at_timestamp', 'update_user_reputation', 'upsert_article_read'
]

def adapt_statement(stmt):
    stmt = stmt.strip()
    
    # 1. Adapt functions: CREATE OR REPLACE FUNCTION custom_facebrasil.<name>
    m_func = re.match(r"^CREATE (?:OR REPLACE )?FUNCTION (?:public\.)?([a-zA-Z0-9_]+)\b", stmt, re.IGNORECASE)
    if m_func:
        func_name = m_func.group(1)
        # replace beginning with CREATE OR REPLACE FUNCTION custom_facebrasil.<func_name>
        stmt = re.sub(r"^CREATE (?:OR REPLACE )?FUNCTION (?:public\.)?[a-zA-Z0-9_]+\b", f"CREATE OR REPLACE FUNCTION custom_facebrasil.{func_name}", stmt, count=1, flags=re.IGNORECASE)
        # In body, replace references to public.<table/func>
        for t in app_tables:
            stmt = re.sub(rf'\bpublic\.{t}\b', f'custom_facebrasil.{t}', stmt)
            stmt = re.sub(rf'\"public\"\.\"{t}\"', f'"custom_facebrasil"."{t}"', stmt)
        for f in app_functions:
            stmt = re.sub(rf'\bpublic\.{f}\b', f'custom_facebrasil.{f}', stmt)
        return stmt

    # 2. Adapt tables: CREATE TABLE IF NOT EXISTS custom_facebrasil.<name>
    m_tbl = re.match(r"^CREATE TABLE (?:IF NOT EXISTS )?(?:public\.)?([a-zA-Z0-9_]+)\s*\(", stmt, re.IGNORECASE)
    if m_tbl:
        tbl_name = m_tbl.group(1)
        stmt = re.sub(r"^CREATE TABLE (?:IF NOT EXISTS )?(?:public\.)?[a-zA-Z0-9_]+\s*\(", f"CREATE TABLE IF NOT EXISTS custom_facebrasil.{tbl_name} (", stmt, count=1, flags=re.IGNORECASE)
        for t in app_tables:
            stmt = re.sub(rf'\bpublic\.{t}\b', f'custom_facebrasil.{t}', stmt)
            stmt = re.sub(rf'\"public\"\.\"{t}\"', f'"custom_facebrasil"."{t}"', stmt)
        for f in app_functions:
            stmt = re.sub(rf'\bpublic\.{f}\b', f'custom_facebrasil.{f}', stmt)
        return stmt

    # 3. Adapt triggers: DROP TRIGGER IF EXISTS ... ; CREATE TRIGGER ... EXECUTE FUNCTION custom_facebrasil.<func>()
    m_trig = re.match(r"^CREATE TRIGGER ([a-zA-Z0-9_]+)\s+(?:.*)\s+ON\s+(?:public\.)?([a-zA-Z0-9_]+)\s+", stmt, re.IGNORECASE | re.DOTALL)
    if m_trig:
        trig_name = m_trig.group(1)
        trig_table = m_trig.group(2)
        # replace table name
        stmt = re.sub(rf'\bON\s+(?:public\.)?{trig_table}\b', f'ON custom_facebrasil.{trig_table}', stmt, flags=re.IGNORECASE)
        # replace function call in trigger
        for f in app_functions:
            stmt = re.sub(rf'\b(?:public\.)?{f}\s*\(', f'custom_facebrasil.{f}(', stmt, flags=re.IGNORECASE)
        drop_prefix = f"DROP TRIGGER IF EXISTS {trig_name} ON custom_facebrasil.{trig_table};\n"
        return drop_prefix + stmt

    # 4. Adapt constraints: DROP CONSTRAINT IF EXISTS ... ; ALTER TABLE custom_facebrasil.<t> ADD CONSTRAINT ...
    m_const = re.match(r"^ALTER TABLE ONLY (?:public\.)?([a-zA-Z0-9_]+)\s+ADD CONSTRAINT ([a-zA-Z0-9_]+)\s+", stmt, re.IGNORECASE | re.DOTALL)
    if m_const:
        tbl_name = m_const.group(1)
        const_name = m_const.group(2)
        stmt = re.sub(r"^ALTER TABLE ONLY (?:public\.)?[a-zA-Z0-9_]+", f"ALTER TABLE ONLY custom_facebrasil.{tbl_name}", stmt, count=1, flags=re.IGNORECASE)
        for t in app_tables:
            stmt = re.sub(rf'\bpublic\.{t}\b', f'custom_facebrasil.{t}', stmt)
            stmt = re.sub(rf'\"public\"\.\"{t}\"', f'"custom_facebrasil"."{t}"', stmt)
            stmt = re.sub(rf'\bREFERENCES (?:public\.)?{t}\b', f'REFERENCES custom_facebrasil.{t}', stmt, flags=re.IGNORECASE)
        drop_prefix = f"ALTER TABLE custom_facebrasil.{tbl_name} DROP CONSTRAINT IF EXISTS {const_name};\n"
        return drop_prefix + stmt

    # 5. Adapt indexes: CREATE [UNIQUE] INDEX IF NOT EXISTS ...
    if re.match(r"^CREATE (?:UNIQUE )?INDEX", stmt, re.IGNORECASE):
        stmt = re.sub(r"^CREATE UNIQUE INDEX\s+(?:IF NOT EXISTS\s+)?", "CREATE UNIQUE INDEX IF NOT EXISTS ", stmt, flags=re.IGNORECASE)
        stmt = re.sub(r"^CREATE INDEX\s+(?:IF NOT EXISTS\s+)?", "CREATE INDEX IF NOT EXISTS ", stmt, flags=re.IGNORECASE)
        for t in app_tables:
            stmt = re.sub(rf'\bON (?:public\.)?{t}\b', f'ON custom_facebrasil.{t}', stmt, flags=re.IGNORECASE)
            stmt = re.sub(rf'\bpublic\.{t}\b', f'custom_facebrasil.{t}', stmt)
            stmt = re.sub(rf'\"public\"\.\"{t}\"', f'"custom_facebrasil"."{t}"', stmt)
        return stmt

    # General replacements for any other statements
    for t in app_tables:
        stmt = re.sub(rf'\bpublic\.{t}\b', f'custom_facebrasil.{t}', stmt)
        stmt = re.sub(rf'\"public\"\.\"{t}\"', f'"custom_facebrasil"."{t}"', stmt)
    for f in app_functions:
        stmt = re.sub(rf'\bpublic\.{f}\b', f'custom_facebrasil.{f}', stmt)

    return stmt

print("Testando lógica de adaptação...")
