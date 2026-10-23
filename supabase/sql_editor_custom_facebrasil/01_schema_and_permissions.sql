-- =========================================================================
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
