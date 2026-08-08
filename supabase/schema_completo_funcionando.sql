-- =========================================================================
-- SCHEMA COMPLETO E AUTO-SUFICIENTE (Rode do início ao fim)
-- Este script cria todas as dependências globais e depois as tabelas locais.
-- Garanta que você execute todo o script (e não apenas partes dele).
-- =========================================================================

-- Habilitar a extensão para geração de UUIDs se não estiver ativa
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========================================================================
-- 1. TABELAS GLOBAIS NECESSÁRIAS
-- =========================================================================

-- Tabela de Perfis de Usuários (Autores/Editores)
CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid NOT NULL PRIMARY KEY, -- Deve corresponder ao ID de autenticação (auth.users)
    name text NOT NULL,
    avatar_url text,
    role text DEFAULT 'EDITOR'::text CHECK (role = ANY (ARRAY['ADMIN'::text, 'EDITOR'::text, 'AUTHOR'::text])),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- =========================================================================
-- 2. SCHEMA TEMPLATE E TABELAS LOCAIS
-- =========================================================================

-- Criar o schema dedicado do blog
CREATE SCHEMA IF NOT EXISTS blog_template;

-- Categorias do Blog (dentro do schema local)
CREATE TABLE IF NOT EXISTS blog_template.categories (
    id uuid NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    name text NOT NULL,
    slug text NOT NULL,
    color text, -- Ex: '#ff0000' ou 'red'
    parent_id uuid REFERENCES blog_template.categories(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    
    -- O slug deve ser único apenas dentro deste blog específico
    CONSTRAINT categories_slug_unique UNIQUE (slug)
);

-- Artigos do Blog (dentro do schema local)
CREATE TABLE IF NOT EXISTS blog_template.articles (
    id uuid NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    slug text NOT NULL UNIQUE,
    title text NOT NULL,
    excerpt text,
    content text,
    featured_image jsonb, -- {"url": string, "alt": string, "width": int, "height": int}
    status text DEFAULT 'DRAFT'::text CHECK (status = ANY (ARRAY['DRAFT'::text, 'PUBLISHED'::text, 'ARCHIVED'::text])),
    
    -- Datas e Metadados
    published_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    
    -- Métricas e Leitura
    views integer DEFAULT 0,
    read_time integer DEFAULT 5, -- Tempo estimado de leitura em minutos
    
    -- Redes Sociais
    social_summary text,
    instagram_post_url text,
    
    -- Controle de Destaques na Home
    destaque_hero boolean DEFAULT false,
    colocar_hero boolean DEFAULT false,
    hero_set_at timestamp with time zone,
    
    -- Origem do Conteúdo (IA / Manual)
    source_type text DEFAULT 'manual'::text CHECK (source_type = ANY (ARRAY['manual'::text, 'automated'::text])),
    original_source text, -- Link original se capturado
    ai_context jsonb, -- Contexto adicional gerado por IA para o app
    
    -- Internacionalização (i18n)
    language text DEFAULT 'pt'::text,
    translation_group_id uuid DEFAULT gen_random_uuid(),
    
    -- Campos de SEO explícitos
    seo_applied boolean DEFAULT false,
    seo_title text,
    seo_description text,
    seo_keywords text[], -- Array de tags para SEO
    
    -- Relacionamentos com Tabelas do Banco (Chaves Estrangeiras)
    author_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    category_id uuid REFERENCES blog_template.categories(id) ON DELETE SET NULL
);

-- =========================================================================
-- 3. ÍNDICES RECOMENDADOS PARA PERFORMANCE
-- =========================================================================

-- Índices de Categoria
CREATE INDEX IF NOT EXISTS idx_categories_slug ON blog_template.categories(slug);
CREATE INDEX IF NOT EXISTS idx_categories_parent ON blog_template.categories(parent_id);

-- Índices de Artigos
CREATE INDEX IF NOT EXISTS idx_articles_slug ON blog_template.articles(slug);
CREATE INDEX IF NOT EXISTS idx_articles_status_pub ON blog_template.articles(status, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_articles_author ON blog_template.articles(author_id);
CREATE INDEX IF NOT EXISTS idx_articles_category ON blog_template.articles(category_id);
CREATE INDEX IF NOT EXISTS idx_articles_translation_group ON blog_template.articles(translation_group_id);
CREATE INDEX IF NOT EXISTS idx_articles_language ON blog_template.articles(language);
CREATE INDEX IF NOT EXISTS idx_articles_hero ON blog_template.articles(colocar_hero) WHERE colocar_hero = true;
