import gzip
import re
import os

backup_file = r"f:\Projetos\_FBR\2FBR-NovaFacebrasil\supabase\db_cluster-19-10-2026@01-13-52.backup.gz"
output_dir = r"f:\Projetos\_FBR\2FBR-NovaFacebrasil\supabase\sql_editor_custom_facebrasil"
os.makedirs(output_dir, exist_ok=True)

def escape_sql_value(val):
    if val == r"\N":
        return "NULL"
    # Postgres copy escapes \n, \r, \t, \\
    # Unescape copy formatting then sql-escape single quotes
    # Replace backslash-escapes
    val = val.replace(r"\\", "\\").replace(r"\n", "\n").replace(r"\r", "\r").replace(r"\t", "\t")
    # Single quotes in SQL
    val = val.replace("'", "''")
    return f"'{val}'"

# 1. Generate 01_schema_and_permissions.sql
setup_sql = """-- =========================================================================
-- 1. CRIAÇÃO DO SCHEMA E PERMISSÕES DO SUPABASE
-- Execute no SQL Editor do Supabase Studio
-- =========================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE SCHEMA IF NOT EXISTS custom_facebrasil;

-- Conceder permissões para os papéis de API do Supabase
GRANT USAGE ON SCHEMA custom_facebrasil TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA custom_facebrasil TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA custom_facebrasil TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA custom_facebrasil TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA custom_facebrasil GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA custom_facebrasil GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA custom_facebrasil GRANT ALL ON ROUTINES TO anon, authenticated, service_role;
"""

with open(os.path.join(output_dir, "01_schema_and_permissions.sql"), "w", encoding="utf-8") as f:
    f.write(setup_sql)

print("01_schema_and_permissions.sql gerado!")
