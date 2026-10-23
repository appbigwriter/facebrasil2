import gzip
import re
import os
import json

backup_file = r"f:\Projetos\_FBR\2FBR-NovaFacebrasil\supabase\db_cluster-19-10-2026@01-13-52.backup.gz"
output_dir = r"f:\Projetos\_FBR\2FBR-NovaFacebrasil\supabase\sql_editor_custom_facebrasil"
os.makedirs(output_dir, exist_ok=True)

# Application tables to migrate to custom_facebrasil
app_tables = [
    'profiles', 'categories', 'site_settings', 'virtual_agents', 'news_sources',
    'badges', 'challenges', 'ads', 'ad_publications', 'events', 'static_pages',
    'blogs', 'publications', 'user_reputation', 'captured_news', 'news_usage',
    'user_video_reports', 'waterfall_sessions', 'waterfall_posts', 'article_favorites',
    'article_reads', 'user_activities', 'user_badges', 'user_challenges',
    'user_collection_items', 'user_collections', 'xp_logs', 'social_credentials',
    'instagram_events', 'news_queue', 'articles'
]

print("Iniciando parser para SQL Editor (formato INSERT INTO e schema custom_facebrasil)...")
