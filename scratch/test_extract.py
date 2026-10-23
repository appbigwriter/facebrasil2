import gzip
import re

output_sql_path = r"f:\Projetos\_FBR\2FBR-NovaFacebrasil\scratch\extracted_public_schema.sql"

# Vamos extrair do dump as partes que pertencem a public.* e opcionalmente auth.users e storage.objects
# Vamos ver como o dump organiza as tabelas e dados

tables_to_extract = [
    'public.profiles',
    'public.categories',
    'public.articles',
    'public.ads',
    'public.ad_publications',
    'public.site_settings',
    'public.virtual_agents',
    'public.captured_news',
    'public.news_sources',
    'public.news_usage',
    'public.news_queue',
    'public.article_favorites',
    'public.article_reads',
    'public.badges',
    'public.user_badges',
    'public.blogs',
    'public.challenges',
    'public.user_challenges',
    'public.events',
    'public.instagram_events',
    'public.partner_offers',
    'public.partners',
    'public.publications',
    'public.social_credentials',
    'public.static_pages',
    'public.user_activities',
    'public.user_collection_items',
    'public.user_collections',
    'public.user_reputation',
    'public.user_video_reports',
    'public.waterfall_posts',
    'public.waterfall_sessions',
    'public.xp_logs'
]

print(f"Total application tables to target: {len(tables_to_extract)}")
