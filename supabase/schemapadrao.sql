-- =========================================================================
-- SCHEMA BASE MULTI-BLOG (Completo e Funcional)
-- Execute este script no SQL Editor do Supabase para criar a estrutura global 
-- e um schema de exemplo (blog_template) para novos blogs.
-- =========================================================================

-- Habilitar a extensão para geração de UUIDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========================================================================
-- 1. ESTRUTURA GLOBAL / COMPARTILHADA (Schema public)
-- =========================================================================

-- Tabela de Perfis de Usuários (Autores/Editores)
CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid NOT NULL PRIMARY KEY, -- Deve bater com o ID de autenticação do Supabase (auth.users)
    name text NOT NULL,
    avatar_url text,
    role text DEFAULT 'EDITOR'::text CHECK (role = ANY (ARRAY['ADMIN'::text, 'EDITOR'::text, 'AUTHOR'::text])),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- Tabela de Blogs cadastrados no sistema (Tenants)
CREATE TABLE IF NOT EXISTS public.blogs (
    id uuid NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    name text NOT NULL,
    slug text NOT NULL UNIQUE,
    description text,
    owner_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- Índices das tabelas globais
CREATE INDEX IF NOT EXISTS idx_blogs_slug ON public.blogs(slug);

-- =========================================================================
-- 2. SCHEMA TEMPLATE PARA NOVOS BLOGS (blog_template)
-- =========================================================================

-- Criar o schema que vai isolar o blog
CREATE SCHEMA IF NOT EXISTS blog_template;

-- Tabela de Categorias do Blog (dentro do schema do blog)
CREATE TABLE IF NOT EXISTS blog_template.categories (
    id uuid NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    name text NOT NULL,
    slug text NOT NULL,
    color text,
    parent_id uuid REFERENCES blog_template.categories(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    
    -- O slug deve ser único dentro desse blog específico
    CONSTRAINT categories_slug_unique UNIQUE (slug)
);

-- Tabela de Artigos do Blog (dentro do schema do blog)
CREATE TABLE IF NOT EXISTS blog_template.articles (
    id uuid NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    slug text NOT NULL UNIQUE,
    title text NOT NULL,
    excerpt text,
    content text,
    featured_image jsonb, -- Armazena {"url": string, "alt": string, "width": int, "height": int}
    status text DEFAULT 'DRAFT'::text CHECK (status = ANY (ARRAY['DRAFT'::text, 'PUBLISHED'::text, 'ARCHIVED'::text])),
    
    -- Controle de Destaques
    destaque_hero boolean DEFAULT false,
    colocar_hero boolean DEFAULT false,
    hero_set_at timestamp with time zone,
    
    -- Métricas e Leitura
    views integer DEFAULT 0,
    read_time integer DEFAULT 5,
    
    -- Redes Sociais
    social_summary text,
    instagram_post_url text,
    
    -- Origem do Conteúdo (Integração IA)
    source_type text DEFAULT 'manual'::text CHECK (source_type = ANY (ARRAY['manual'::text, 'automated'::text])),
    original_source text,
    ai_context jsonb, -- Informações complementares geradas por IA
    
    -- Internacionalização (i18n)
    language text DEFAULT 'pt'::text,
    translation_group_id uuid DEFAULT gen_random_uuid(),
    
    -- Otimizações e Metadados de SEO
    seo_applied boolean DEFAULT false,
    seo_title text,
    seo_description text,
    seo_keywords text[],
    
    -- Auditoria
    published_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    
    -- Chaves Estrangeiras apontando para as tabelas corretas
    author_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    category_id uuid REFERENCES blog_template.categories(id) ON DELETE SET NULL
);

-- =========================================================================
-- 3. ÍNDICES DE PERFORMANCE (blog_template)
-- =========================================================================

CREATE INDEX IF NOT EXISTS idx_categories_slug ON blog_template.categories(slug);
CREATE INDEX IF NOT EXISTS idx_categories_parent ON blog_template.categories(parent_id);

CREATE INDEX IF NOT EXISTS idx_articles_slug ON blog_template.articles(slug);
CREATE INDEX IF NOT EXISTS idx_articles_status_pub ON blog_template.articles(status, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_articles_author ON blog_template.articles(author_id);
CREATE INDEX IF NOT EXISTS idx_articles_category ON blog_template.articles(category_id);
CREATE INDEX IF NOT EXISTS idx_articles_translation_group ON blog_template.articles(translation_group_id);
CREATE INDEX IF NOT EXISTS idx_articles_language ON blog_template.articles(language);
CREATE INDEX IF NOT EXISTS idx_articles_hero ON blog_template.articles(colocar_hero) WHERE colocar_hero = true;
