-- =========================================================================
-- PASSO 2: CRIAÇÃO DAS TABELAS, CHAVES PRIMÁRIAS E FUNÇÕES NO SCHEMA custom_facebrasil
--
-- ATENÇÃO:
-- 1. Este arquivo cria APENAS a estrutura base (Tabelas, Primary Keys e Funções).
-- 2. NÃO contém nenhuma Foreign Key (elas foram movidas para o PASSO 6).
-- 3. NÃO contém nenhum Trigger (eles foram movidos para o PASSO 6).
-- Isso garante que toda a carga de dados dos Passos 3, 4 e 5 entre com 100% de sucesso!
-- =========================================================================

SET search_path = custom_facebrasil, public, auth, extensions;

-- =========================================================================
-- 1. FUNÇÕES PLPGSQL DA APLICAÇÃO
-- =========================================================================
--
-- Name: calculate_level(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION custom_facebrasil.calculate_level(points integer) RETURNS TABLE(level integer, level_name text)
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
  IF points >= 1500 THEN
    RETURN QUERY SELECT 5, 'SuperFace'::TEXT;
  ELSIF points >= 700 THEN
    RETURN QUERY SELECT 4, 'Editor Comunitário'::TEXT;
  ELSIF points >= 300 THEN
    RETURN QUERY SELECT 3, 'Analista Pleno'::TEXT;
  ELSIF points >= 100 THEN
    RETURN QUERY SELECT 2, 'Analista Iniciante'::TEXT;
  ELSE
    RETURN QUERY SELECT 1, 'Leitor Casual'::TEXT;
  END IF;
END;
$$;

--
-- Name: check_and_award_badges(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION custom_facebrasil.check_and_award_badges(p_user_id text) RETURNS TABLE(badge_id uuid, badge_name text, badge_icon text, badge_rarity text, newly_earned boolean)
    LANGUAGE plpgsql
    AS $$
DECLARE
  user_stats RECORD;
  badge_record RECORD;
  criteria_met BOOLEAN;
BEGIN
  -- Get user stats
  SELECT * INTO user_stats
  FROM user_reputation
  WHERE user_id = p_user_id;
  
  -- Loop through all active badges
  FOR badge_record IN 
    SELECT * FROM badges WHERE active = true
  LOOP
    criteria_met := false;
    
    -- Check criteria (simplified - expand based on actual criteria structure)
    IF badge_record.criteria->>'articles_read' IS NOT NULL THEN
      criteria_met := user_stats.articles_read >= (badge_record.criteria->>'articles_read')::INTEGER;
    ELSIF badge_record.criteria->>'comments_validated' IS NOT NULL THEN
      criteria_met := (
        SELECT COUNT(*) FROM user_activities 
        WHERE user_id = p_user_id 
          AND activity_type = 'comment' 
          AND validated = true
      ) >= (badge_record.criteria->>'comments_validated')::INTEGER;
    ELSIF badge_record.criteria->>'shares' IS NOT NULL THEN
      criteria_met := user_stats.shares_made >= (badge_record.criteria->>'shares')::INTEGER;
    ELSIF badge_record.criteria->>'fact_checks_validated' IS NOT NULL THEN
      criteria_met := (
        SELECT COUNT(*) FROM user_activities 
        WHERE user_id = p_user_id 
          AND activity_type = 'fact_check' 
          AND validated = true
      ) >= (badge_record.criteria->>'fact_checks_validated')::INTEGER;
    ELSIF badge_record.criteria->>'topics_published' IS NOT NULL THEN
      criteria_met := user_stats.topics_suggested >= (badge_record.criteria->>'topics_published')::INTEGER;
    ELSIF badge_record.criteria->>'total_points' IS NOT NULL THEN
      criteria_met := user_stats.total_points >= (badge_record.criteria->>'total_points')::INTEGER;
    END IF;
    
    -- If criteria met and not already earned
    IF criteria_met THEN
      -- Try to insert (will fail silently if already exists due to UNIQUE constraint)
      INSERT INTO user_badges (user_id, badge_id)
      VALUES (p_user_id, badge_record.id)
      ON CONFLICT (user_id, badge_id) DO NOTHING;
      
      -- Return badge info
      RETURN QUERY
      SELECT 
        badge_record.id,
        badge_record.name,
        badge_record.icon,
        badge_record.rarity,
        NOT EXISTS(
          SELECT 1 FROM user_badges 
          WHERE user_id = p_user_id 
            AND badge_id = badge_record.id 
            AND earned_at < NOW() - INTERVAL '1 second'
        ) as newly_earned;
    END IF;
  END LOOP;
END;
$$;

--
-- Name: ensure_profile_exists(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION custom_facebrasil.ensure_profile_exists() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Verificar se author_id é nulo antes de tentar inserir
    IF NEW.author_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Inserir perfil apenas com colunas que existem
    INSERT INTO profiles (id, name, role, created_at)
    VALUES (
        NEW.author_id, 
        'Admin User',
        'admin',
        NOW()
    )
    ON CONFLICT (id) DO NOTHING;
    
    RETURN NEW;
END;
$$;

--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION custom_facebrasil.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO custom_facebrasil.profiles (id, name, avatar_url, role, email)
  VALUES (
    new.id, 
    new.raw_user_meta_data->>'full_name', 
    new.raw_user_meta_data->>'avatar_url', 
    COALESCE(new.raw_user_meta_data->>'role', 'VIEWER'),
    new.email
  )
  ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    avatar_url = EXCLUDED.avatar_url,
    role = EXCLUDED.role,
    email = EXCLUDED.email;
  RETURN new;
END;
$$;

--
-- Name: handle_new_user_role(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION custom_facebrasil.handle_new_user_role() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO custom_facebrasil.profiles (id, role, name, avatar_url)
  VALUES (NEW.id, 'USER', NEW.raw_user_meta_data->>'name', NEW.raw_user_meta_data->>'avatar_url')
  ON CONFLICT (id) DO UPDATE 
  SET role = EXCLUDED.role;
  RETURN NEW;
END;
$$;

--
-- Name: increment_ad_clicks(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION custom_facebrasil.increment_ad_clicks(ad_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    UPDATE ads
    SET clicks = clicks + 1
    WHERE id = ad_id;
END;
$$;

--
-- Name: increment_ad_curiosity(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION custom_facebrasil.increment_ad_curiosity(ad_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    UPDATE ads
    SET curiosity_count = curiosity_count + 1
    WHERE id = ad_id;
END;
$$;

--
-- Name: increment_ad_views(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION custom_facebrasil.increment_ad_views(ad_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    UPDATE ads
    SET views = views + 1
    WHERE id = ad_id;
END;
$$;

--
-- Name: increment_article_views(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION custom_facebrasil.increment_article_views(p_article_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    UPDATE custom_facebrasil.articles
    SET views = views + 1
    WHERE id = p_article_id;
END;
$$;

--
-- Name: increment_user_xp(text, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION custom_facebrasil.increment_user_xp(uid text, xp_points integer, activity_col text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO custom_facebrasil.user_reputation (user_id, total_points, last_activity_at)
  VALUES (uid, xp_points, NOW())
  ON CONFLICT (user_id) DO UPDATE
  SET 
    total_points = user_reputation.total_points + xp_points,
    articles_read = CASE WHEN activity_col = 'articles_read' THEN user_reputation.articles_read + 1 ELSE user_reputation.articles_read END,
    shares_made = CASE WHEN activity_col = 'shares_made' THEN user_reputation.shares_made + 1 ELSE user_reputation.shares_made END,
    comments_made = CASE WHEN activity_col = 'comments_made' THEN user_reputation.comments_made + 1 ELSE user_reputation.comments_made END,
    last_activity_at = NOW(),
    updated_at = NOW();

  -- Opcional: Atualizar o nível se necessário (lógica simples de 100 XP por nível para este exemplo)
  UPDATE custom_facebrasil.user_reputation
  SET level = floor((sqrt(8 * total_points / 100 + 1) - 1) / 2) + 1
  WHERE user_id = uid;
END;
$$;

--
-- Name: reset_expired_heroes(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION custom_facebrasil.reset_expired_heroes() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE articles
    SET colocar_hero = FALSE
    WHERE colocar_hero = TRUE 
    AND hero_set_at < NOW() - INTERVAL '1 day';
END;
$$;

--
-- Name: reset_weekly_points(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION custom_facebrasil.reset_weekly_points() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Archive current week to history (optional)
  -- INSERT INTO leaderboard_history SELECT *, NOW() FROM leaderboard_weekly;
  
  -- Reset weekly points
  UPDATE user_reputation SET weekly_points = 0;
  
  -- Refresh materialized view
  REFRESH MATERIALIZED VIEW leaderboard_weekly;
  
  RAISE NOTICE 'Weekly points reset completed at %', NOW();
END;
$$;

--
-- Name: set_hero_timestamp(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION custom_facebrasil.set_hero_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.colocar_hero = TRUE AND (OLD.colocar_hero = FALSE OR OLD.colocar_hero IS NULL) THEN
        NEW.hero_set_at = NOW();
    END IF;
    -- If manually turning off, we don't need to clear timestamps, but we could if we wanted.
    RETURN NEW;
END;
$$;

--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION custom_facebrasil.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

--
-- Name: toggle_article_favorite(uuid, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION custom_facebrasil.toggle_article_favorite(p_article_id uuid, p_user_id text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_exists BOOLEAN;
    v_count INTEGER;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM custom_facebrasil.article_favorites
        WHERE article_id = p_article_id AND user_id = p_user_id
    ) INTO v_exists;

    IF v_exists THEN
        DELETE FROM custom_facebrasil.article_favorites WHERE article_id = p_article_id AND user_id = p_user_id;
        UPDATE custom_facebrasil.articles SET favorites_count = GREATEST(0, favorites_count - 1) WHERE id = p_article_id;
        RETURN jsonb_build_object('favorited', false);
    ELSE
        INSERT INTO custom_facebrasil.article_favorites(article_id, user_id) VALUES (p_article_id, p_user_id);
        UPDATE custom_facebrasil.articles SET favorites_count = favorites_count + 1 WHERE id = p_article_id;
        RETURN jsonb_build_object('favorited', true);
    END IF;
END;
$$;

--
-- Name: update_events_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION custom_facebrasil.update_events_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION custom_facebrasil.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

--
-- Name: update_updated_at_timestamp(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION custom_facebrasil.update_updated_at_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

--
-- Name: update_user_reputation(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION custom_facebrasil.update_user_reputation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  new_level_data RECORD;
BEGIN
  -- Update reputation stats
  UPDATE user_reputation
  SET 
    total_points = total_points + NEW.points_earned,
    weekly_points = weekly_points + NEW.points_earned,
    monthly_points = monthly_points + NEW.points_earned,
    articles_read = CASE WHEN NEW.activity_type = 'read_complete' THEN articles_read + 1 ELSE articles_read END,
    comments_made = CASE WHEN NEW.activity_type = 'comment' THEN comments_made + 1 ELSE comments_made END,
    shares_made = CASE WHEN NEW.activity_type = 'share' THEN shares_made + 1 ELSE shares_made END,
    fact_checks_submitted = CASE WHEN NEW.activity_type = 'fact_check' THEN fact_checks_submitted + 1 ELSE fact_checks_submitted END,
    topics_suggested = CASE WHEN NEW.activity_type = 'topic_suggest' THEN topics_suggested + 1 ELSE topics_suggested END,
    last_activity_at = NOW(),
    updated_at = NOW()
  WHERE user_id = NEW.user_id;
  
  -- Calculate new level
  SELECT * INTO new_level_data 
  FROM calculate_level((SELECT total_points FROM user_reputation WHERE user_id = NEW.user_id));
  
  -- Update level if changed
  UPDATE user_reputation
  SET 
    level = new_level_data.level,
    level_name = new_level_data.level_name
  WHERE user_id = NEW.user_id 
    AND level != new_level_data.level;
  
  RETURN NEW;
END;
$$;

--
-- Name: upsert_article_read(uuid, text, text, integer, integer, boolean, boolean, boolean, text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION custom_facebrasil.upsert_article_read(p_article_id uuid, p_session_id text, p_user_id text, p_read_time_seconds integer, p_scroll_depth integer, p_completed boolean, p_bounced boolean, p_translator_used boolean, p_translator_lang text, p_referrer text, p_country_code text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_is_new_session boolean;
BEGIN
    -- Check if it's a new session for this article
    v_is_new_session := NOT EXISTS (
        SELECT 1 FROM custom_facebrasil.article_reads 
        WHERE session_id = p_session_id
    );

    -- Insert or update the read log
    INSERT INTO custom_facebrasil.article_reads (
        article_id, 
        session_id, 
        user_id, 
        read_time_seconds, 
        scroll_depth,
        completed, 
        bounced, 
        translator_used, 
        translator_lang, 
        referrer, 
        country_code
    ) VALUES (
        p_article_id, 
        p_session_id, 
        p_user_id, 
        p_read_time_seconds, 
        p_scroll_depth,
        p_completed, 
        p_bounced, 
        p_translator_used, 
        p_translator_lang, 
        p_referrer, 
        p_country_code
    )
    ON CONFLICT (session_id) DO UPDATE SET
        read_time_seconds = EXCLUDED.read_time_seconds,
        scroll_depth = EXCLUDED.scroll_depth,
        completed = EXCLUDED.completed,
        translator_used = EXCLUDED.translator_used,
        translator_lang = EXCLUDED.translator_lang,
        updated_at = now();

    -- If it's a new session, increment the global view count in articles table
    IF v_is_new_session THEN
        UPDATE custom_facebrasil.articles
        SET views = COALESCE(views, 0) + 1
        WHERE id = p_article_id;
    END IF;
END;
$$;




-- =========================================================================
-- 2. TABELAS DE NEGÓCIO
-- =========================================================================
--
-- Name: user_activities; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.user_activities (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id text NOT NULL,
    activity_type text NOT NULL,
    article_id uuid,
    points_earned integer DEFAULT 0,
    validated boolean DEFAULT false,
    validated_by text,
    validated_at timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT user_activities_activity_type_check CHECK ((activity_type = ANY (ARRAY['read_complete'::text, 'comment'::text, 'share'::text, 'fact_check'::text, 'topic_suggest'::text, 'like'::text, 'bookmark'::text])))
);

--
-- Name: ad_publications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.ad_publications (
    ad_id uuid NOT NULL,
    publication_id uuid NOT NULL
);

--
-- Name: ads; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.ads (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    title text NOT NULL,
    "position" text NOT NULL,
    image_url text,
    link_url text NOT NULL,
    is_active boolean DEFAULT true,
    start_date timestamp with time zone DEFAULT now(),
    end_date timestamp with time zone,
    views integer DEFAULT 0,
    clicks integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    category_id uuid,
    target_countries text[] DEFAULT '{}'::text[],
    target_regions text[] DEFAULT '{}'::text[],
    curiosity_count integer DEFAULT 0,
    target_zip_codes text[] DEFAULT '{}'::text[],
    mobile_image_url text,
    CONSTRAINT ads_position_check CHECK (("position" = ANY (ARRAY['super_hero'::text, 'sidebar'::text, 'column'::text, 'column_1'::text, 'column_2'::text, 'column_3'::text, 'super_footer'::text])))
);

--
-- Name: article_favorites; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.article_favorites (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    article_id uuid,
    user_id text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);

--
-- Name: article_reads; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.article_reads (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    article_id uuid,
    user_id text,
    session_id text NOT NULL,
    read_time_seconds integer DEFAULT 0,
    scroll_depth integer DEFAULT 0,
    completed boolean DEFAULT false,
    bounced boolean DEFAULT false,
    translator_used boolean DEFAULT false,
    translator_lang text,
    referrer text,
    country_code text,
    created_at timestamp with time zone DEFAULT now()
);

--
-- Name: articles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.articles (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    slug text NOT NULL,
    title text NOT NULL,
    excerpt text,
    content text,
    featured_image jsonb,
    status text DEFAULT 'DRAFT'::text,
    published_at timestamp with time zone DEFAULT now(),
    author_id text,
    category_id uuid,
    blog_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid,
    views integer DEFAULT 0,
    read_time integer DEFAULT 5,
    social_summary text,
    instagram_post_url text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    destaque_hero boolean DEFAULT false,
    colocar_hero boolean DEFAULT false,
    hero_set_at timestamp with time zone,
    source_type text DEFAULT 'manual'::text,
    original_source text,
    ai_context jsonb,
    news_queue_id uuid,
    language text DEFAULT 'pt'::text,
    translation_group_id uuid DEFAULT gen_random_uuid(),
    sent_to_tv boolean DEFAULT false,
    tv_sent_at timestamp with time zone,
    favorites_count integer DEFAULT 0,
    seo_applied boolean DEFAULT false,
    disable_view_simulation boolean DEFAULT false NOT NULL,
    CONSTRAINT articles_source_type_check CHECK ((source_type = ANY (ARRAY['manual'::text, 'automated'::text])))
);

--
-- Name: badges; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.badges (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    name text NOT NULL,
    description text NOT NULL,
    icon text NOT NULL,
    criteria jsonb NOT NULL,
    rarity text DEFAULT 'common'::text,
    color text DEFAULT '#6B7280'::text,
    order_priority integer DEFAULT 0,
    active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT badges_rarity_check CHECK ((rarity = ANY (ARRAY['common'::text, 'rare'::text, 'epic'::text, 'legendary'::text])))
);

--
-- Name: user_badges; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.user_badges (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id text NOT NULL,
    badge_id uuid,
    earned_at timestamp with time zone DEFAULT now(),
    progress jsonb DEFAULT '{}'::jsonb
);

--
-- Name: blogs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.blogs (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    description text,
    owner_id text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

--
-- Name: captured_news; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.captured_news (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    original_title text NOT NULL,
    translated_title text,
    url text NOT NULL,
    image_url text,
    source_vehicle text,
    source_tier integer,
    category text,
    sentiment text,
    is_trending boolean DEFAULT false,
    cross_reference_data jsonb,
    published_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now()
);

--
-- Name: categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.categories (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    color text,
    parent_id uuid,
    blog_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    escopo text[] DEFAULT '{}'::text[]
);

--
-- Name: challenges; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.challenges (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    title text NOT NULL,
    description text,
    points_reward integer DEFAULT 0,
    facets_reward numeric DEFAULT 0,
    icon text,
    type text,
    target_value integer DEFAULT 1,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT challenges_type_check CHECK ((type = ANY (ARRAY['reading'::text, 'sharing'::text, 'engagement'::text, 'special'::text])))
);

--
-- Name: events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.events (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    title text NOT NULL,
    description text,
    city text NOT NULL,
    state text,
    location text NOT NULL,
    event_date date NOT NULL,
    event_time time without time zone,
    organizer_name text,
    organizer_email text,
    organizer_phone text,
    submitted_by text,
    status text DEFAULT 'pending'::text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT events_description_check CHECK ((char_length(description) <= 200)),
    CONSTRAINT events_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])))
);


-- Garantir compatibilidade e colunas do calendário de eventos do Facebrasil
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS title text;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS description text;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS city text;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS state text;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS location text;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS event_date date;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS event_time time without time zone;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS organizer_name text;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS organizer_email text;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS organizer_phone text;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS submitted_by text;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS status text DEFAULT 'pending'::text;
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS created_at timestamp with time zone DEFAULT now();
ALTER TABLE custom_facebrasil.events ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT now();

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'custom_facebrasil' AND table_name = 'events' AND column_name = 'project_id') THEN
        ALTER TABLE custom_facebrasil.events ALTER COLUMN project_id DROP NOT NULL;
        ALTER TABLE custom_facebrasil.events ALTER COLUMN project_id SET DEFAULT '0b70ae83-8ab7-4b9b-9f3d-8d26eba2d36b'::uuid;
    END IF;
END $$;


--
-- Name: instagram_events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.instagram_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    event_type text NOT NULL,
    object text,
    sender_id text,
    sender_name text,
    media_id text,
    media_url text,
    message text,
    raw_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    processed boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: user_reputation; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.user_reputation (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id text NOT NULL,
    total_points integer DEFAULT 0,
    weekly_points integer DEFAULT 0,
    monthly_points integer DEFAULT 0,
    level integer DEFAULT 1,
    level_name text DEFAULT 'Leitor Casual'::text,
    badges jsonb DEFAULT '[]'::jsonb,
    achievements jsonb DEFAULT '{}'::jsonb,
    articles_read integer DEFAULT 0,
    comments_made integer DEFAULT 0,
    shares_made integer DEFAULT 0,
    fact_checks_submitted integer DEFAULT 0,
    topics_suggested integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    last_activity_at timestamp with time zone DEFAULT now(),
    facets_balance numeric DEFAULT 0
);

--
-- Name: news_queue; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.news_queue (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    source_id uuid,
    original_url text NOT NULL,
    original_title text NOT NULL,
    original_content text,
    original_image text,
    original_author text,
    original_published_at timestamp with time zone,
    status text DEFAULT 'pending'::text,
    ai_request_id text,
    ai_tokens_used integer,
    ai_processing_time_ms integer,
    processed_article_id uuid,
    error_message text,
    created_at timestamp with time zone DEFAULT now(),
    processing_started_at timestamp with time zone,
    processed_at timestamp with time zone,
    CONSTRAINT news_queue_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'processing'::text, 'published'::text, 'failed'::text, 'duplicate'::text, 'rejected'::text])))
);

--
-- Name: news_sources; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.news_sources (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    name text NOT NULL,
    type text NOT NULL,
    url text NOT NULL,
    category_slug text,
    enabled boolean DEFAULT true,
    last_fetch timestamp with time zone,
    fetch_interval_minutes integer DEFAULT 15,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT news_sources_type_check CHECK ((type = ANY (ARRAY['rss'::text, 'api'::text, 'scraper'::text])))
);

--
-- Name: news_usage; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.news_usage (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    news_id uuid NOT NULL,
    agent_id uuid,
    used_by_user_id uuid,
    used_at timestamp with time zone DEFAULT now()
);

--
-- Name: partner_offers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.partner_offers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    partner_id uuid NOT NULL,
    title text NOT NULL,
    description text,
    offer_type text,
    facet_cost numeric NOT NULL,
    currency_value numeric,
    discount_percent numeric,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT partner_offers_offer_type_check CHECK ((offer_type = ANY (ARRAY['product'::text, 'service'::text, 'discount'::text])))
);

--
-- Name: partners; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.partners (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    logo_url text,
    website_url text,
    category text,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

--
-- Name: profiles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.profiles (
    id text NOT NULL,
    name text,
    avatar_url text,
    role text DEFAULT 'EDITOR'::text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    email text,
    phone text,
    whatsapp text,
    tiktok text,
    instagram text,
    city text,
    profession text
);

--
-- Name: publications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.publications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);

--
-- Name: site_settings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.site_settings (
    id bigint DEFAULT 1 NOT NULL,
    site_name text,
    site_description text,
    og_image_url text,
    meta_title_template text,
    meta_description_template text,
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT one_row CHECK ((id = 1))
);

--
-- Name: social_credentials; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.social_credentials (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    platform text NOT NULL,
    credentials jsonb DEFAULT '{}'::jsonb NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: static_pages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.static_pages (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    slug text NOT NULL,
    title text NOT NULL,
    content text,
    updated_at timestamp with time zone DEFAULT now(),
    language text DEFAULT 'pt'::text,
    excerpt text,
    featured_image text,
    is_published boolean DEFAULT true,
    translation_group_id uuid,
    views integer DEFAULT 0
);

--
-- Name: user_challenges; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.user_challenges (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id text,
    challenge_id uuid,
    current_progress integer DEFAULT 0,
    status text DEFAULT 'ongoing'::text,
    completed_at timestamp with time zone,
    CONSTRAINT user_challenges_status_check CHECK ((status = ANY (ARRAY['ongoing'::text, 'completed'::text])))
);

--
-- Name: user_collection_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.user_collection_items (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    collection_id uuid NOT NULL,
    article_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);

--
-- Name: user_collections; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.user_collections (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id text NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

--
-- Name: user_video_reports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.user_video_reports (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid,
    title text NOT NULL,
    description text,
    video_url text NOT NULL,
    status text DEFAULT 'APPROVED'::text,
    created_at timestamp with time zone DEFAULT now(),
    city text,
    reporter_name text
);

--
-- Name: virtual_agents; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.virtual_agents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    profile_description text,
    location text,
    writing_style text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

--
-- Name: waterfall_posts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.waterfall_posts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    session_id uuid,
    platform text NOT NULL,
    content_type text NOT NULL,
    post_id text,
    post_url text,
    status text DEFAULT 'pending'::text NOT NULL,
    error_message text,
    published_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: waterfall_sessions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.waterfall_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    article_id uuid NOT NULL,
    tone text DEFAULT 'impactante'::text NOT NULL,
    angle text DEFAULT 'emocional'::text NOT NULL,
    audience text DEFAULT 'diaspora'::text NOT NULL,
    data jsonb NOT NULL,
    images jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    slide_images jsonb DEFAULT '{}'::jsonb NOT NULL
);

--
-- Name: xp_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS custom_facebrasil.xp_logs (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id text,
    type text NOT NULL,
    points integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now()
);


-- =========================================================================
-- 3. CHAVES PRIMÁRIAS E CONSTRAINTS DE UNICIDADE
-- =========================================================================
ALTER TABLE custom_facebrasil.ad_publications DROP CONSTRAINT IF EXISTS ad_publications_pkey;
--
-- Name: ad_publications ad_publications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.ad_publications
    ADD CONSTRAINT ad_publications_pkey PRIMARY KEY (ad_id, publication_id);

ALTER TABLE custom_facebrasil.ads DROP CONSTRAINT IF EXISTS ads_pkey;
--
-- Name: ads ads_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.ads
    ADD CONSTRAINT ads_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.article_favorites DROP CONSTRAINT IF EXISTS article_favorites_article_id_user_id_key;
--
-- Name: article_favorites article_favorites_article_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.article_favorites
    ADD CONSTRAINT article_favorites_article_id_user_id_key UNIQUE (article_id, user_id);

ALTER TABLE custom_facebrasil.article_favorites DROP CONSTRAINT IF EXISTS article_favorites_pkey;
--
-- Name: article_favorites article_favorites_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.article_favorites
    ADD CONSTRAINT article_favorites_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.article_reads DROP CONSTRAINT IF EXISTS article_reads_pkey;
--
-- Name: article_reads article_reads_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.article_reads
    ADD CONSTRAINT article_reads_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.article_reads DROP CONSTRAINT IF EXISTS article_reads_session_id_key;
--
-- Name: article_reads article_reads_session_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.article_reads
    ADD CONSTRAINT article_reads_session_id_key UNIQUE (session_id);

ALTER TABLE custom_facebrasil.articles DROP CONSTRAINT IF EXISTS articles_pkey;
--
-- Name: articles articles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.articles
    ADD CONSTRAINT articles_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.articles DROP CONSTRAINT IF EXISTS articles_slug_key;
--
-- Name: articles articles_slug_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.articles
    ADD CONSTRAINT articles_slug_key UNIQUE (slug);

ALTER TABLE custom_facebrasil.badges DROP CONSTRAINT IF EXISTS badges_name_key;
--
-- Name: badges badges_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.badges
    ADD CONSTRAINT badges_name_key UNIQUE (name);

ALTER TABLE custom_facebrasil.badges DROP CONSTRAINT IF EXISTS badges_pkey;
--
-- Name: badges badges_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.badges
    ADD CONSTRAINT badges_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.blogs DROP CONSTRAINT IF EXISTS blogs_pkey;
--
-- Name: blogs blogs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.blogs
    ADD CONSTRAINT blogs_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.blogs DROP CONSTRAINT IF EXISTS blogs_slug_key;
--
-- Name: blogs blogs_slug_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.blogs
    ADD CONSTRAINT blogs_slug_key UNIQUE (slug);

ALTER TABLE custom_facebrasil.captured_news DROP CONSTRAINT IF EXISTS captured_news_pkey;
--
-- Name: captured_news captured_news_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.captured_news
    ADD CONSTRAINT captured_news_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.captured_news DROP CONSTRAINT IF EXISTS captured_news_url_key;
--
-- Name: captured_news captured_news_url_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.captured_news
    ADD CONSTRAINT captured_news_url_key UNIQUE (url);

ALTER TABLE custom_facebrasil.categories DROP CONSTRAINT IF EXISTS categories_pkey;
--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.categories DROP CONSTRAINT IF EXISTS categories_slug_key;
--
-- Name: categories categories_slug_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.categories
    ADD CONSTRAINT categories_slug_key UNIQUE (slug);

ALTER TABLE custom_facebrasil.challenges DROP CONSTRAINT IF EXISTS challenges_pkey;
--
-- Name: challenges challenges_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.challenges
    ADD CONSTRAINT challenges_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.events DROP CONSTRAINT IF EXISTS events_pkey;
--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.instagram_events DROP CONSTRAINT IF EXISTS instagram_events_pkey;
--
-- Name: instagram_events instagram_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.instagram_events
    ADD CONSTRAINT instagram_events_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.news_queue DROP CONSTRAINT IF EXISTS news_queue_original_url_key;
--
-- Name: news_queue news_queue_original_url_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.news_queue
    ADD CONSTRAINT news_queue_original_url_key UNIQUE (original_url);

ALTER TABLE custom_facebrasil.news_queue DROP CONSTRAINT IF EXISTS news_queue_pkey;
--
-- Name: news_queue news_queue_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.news_queue
    ADD CONSTRAINT news_queue_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.news_sources DROP CONSTRAINT IF EXISTS news_sources_pkey;
--
-- Name: news_sources news_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.news_sources
    ADD CONSTRAINT news_sources_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.news_sources DROP CONSTRAINT IF EXISTS news_sources_url_key;
--
-- Name: news_sources news_sources_url_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.news_sources
    ADD CONSTRAINT news_sources_url_key UNIQUE (url);

ALTER TABLE custom_facebrasil.news_usage DROP CONSTRAINT IF EXISTS news_usage_news_id_agent_id_key;
--
-- Name: news_usage news_usage_news_id_agent_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.news_usage
    ADD CONSTRAINT news_usage_news_id_agent_id_key UNIQUE (news_id, agent_id);

ALTER TABLE custom_facebrasil.news_usage DROP CONSTRAINT IF EXISTS news_usage_pkey;
--
-- Name: news_usage news_usage_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.news_usage
    ADD CONSTRAINT news_usage_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.partner_offers DROP CONSTRAINT IF EXISTS partner_offers_pkey;
--
-- Name: partner_offers partner_offers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.partner_offers
    ADD CONSTRAINT partner_offers_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.partners DROP CONSTRAINT IF EXISTS partners_pkey;
--
-- Name: partners partners_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.partners
    ADD CONSTRAINT partners_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.profiles DROP CONSTRAINT IF EXISTS profiles_pkey;
--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.publications DROP CONSTRAINT IF EXISTS publications_name_key;
--
-- Name: publications publications_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.publications
    ADD CONSTRAINT publications_name_key UNIQUE (name);

ALTER TABLE custom_facebrasil.publications DROP CONSTRAINT IF EXISTS publications_pkey;
--
-- Name: publications publications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.publications
    ADD CONSTRAINT publications_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.site_settings DROP CONSTRAINT IF EXISTS site_settings_pkey;
--
-- Name: site_settings site_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.site_settings
    ADD CONSTRAINT site_settings_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.social_credentials DROP CONSTRAINT IF EXISTS social_credentials_pkey;
--
-- Name: social_credentials social_credentials_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.social_credentials
    ADD CONSTRAINT social_credentials_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.social_credentials DROP CONSTRAINT IF EXISTS social_credentials_platform_key;
--
-- Name: social_credentials social_credentials_platform_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.social_credentials
    ADD CONSTRAINT social_credentials_platform_key UNIQUE (platform);

ALTER TABLE custom_facebrasil.static_pages DROP CONSTRAINT IF EXISTS static_pages_pkey;
--
-- Name: static_pages static_pages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.static_pages
    ADD CONSTRAINT static_pages_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.static_pages DROP CONSTRAINT IF EXISTS static_pages_slug_key;
--
-- Name: static_pages static_pages_slug_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.static_pages
    ADD CONSTRAINT static_pages_slug_key UNIQUE (slug);

ALTER TABLE custom_facebrasil.user_activities DROP CONSTRAINT IF EXISTS user_activities_pkey;
--
-- Name: user_activities user_activities_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.user_activities
    ADD CONSTRAINT user_activities_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.user_badges DROP CONSTRAINT IF EXISTS user_badges_pkey;
--
-- Name: user_badges user_badges_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.user_badges
    ADD CONSTRAINT user_badges_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.user_badges DROP CONSTRAINT IF EXISTS user_badges_user_id_badge_id_key;
--
-- Name: user_badges user_badges_user_id_badge_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.user_badges
    ADD CONSTRAINT user_badges_user_id_badge_id_key UNIQUE (user_id, badge_id);

ALTER TABLE custom_facebrasil.user_challenges DROP CONSTRAINT IF EXISTS user_challenges_pkey;
--
-- Name: user_challenges user_challenges_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.user_challenges
    ADD CONSTRAINT user_challenges_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.user_challenges DROP CONSTRAINT IF EXISTS user_challenges_user_id_challenge_id_key;
--
-- Name: user_challenges user_challenges_user_id_challenge_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.user_challenges
    ADD CONSTRAINT user_challenges_user_id_challenge_id_key UNIQUE (user_id, challenge_id);

ALTER TABLE custom_facebrasil.user_collection_items DROP CONSTRAINT IF EXISTS user_collection_items_pkey;
--
-- Name: user_collection_items user_collection_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.user_collection_items
    ADD CONSTRAINT user_collection_items_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.user_collection_items DROP CONSTRAINT IF EXISTS user_collection_items_unique;
--
-- Name: user_collection_items user_collection_items_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.user_collection_items
    ADD CONSTRAINT user_collection_items_unique UNIQUE (collection_id, article_id);

ALTER TABLE custom_facebrasil.user_collections DROP CONSTRAINT IF EXISTS user_collections_pkey;
--
-- Name: user_collections user_collections_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.user_collections
    ADD CONSTRAINT user_collections_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.user_reputation DROP CONSTRAINT IF EXISTS user_reputation_pkey;
--
-- Name: user_reputation user_reputation_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.user_reputation
    ADD CONSTRAINT user_reputation_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.user_reputation DROP CONSTRAINT IF EXISTS user_reputation_user_id_key;
--
-- Name: user_reputation user_reputation_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.user_reputation
    ADD CONSTRAINT user_reputation_user_id_key UNIQUE (user_id);

ALTER TABLE custom_facebrasil.user_video_reports DROP CONSTRAINT IF EXISTS user_video_reports_pkey;
--
-- Name: user_video_reports user_video_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.user_video_reports
    ADD CONSTRAINT user_video_reports_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.virtual_agents DROP CONSTRAINT IF EXISTS virtual_agents_pkey;
--
-- Name: virtual_agents virtual_agents_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.virtual_agents
    ADD CONSTRAINT virtual_agents_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.waterfall_posts DROP CONSTRAINT IF EXISTS waterfall_posts_pkey;
--
-- Name: waterfall_posts waterfall_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.waterfall_posts
    ADD CONSTRAINT waterfall_posts_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.waterfall_sessions DROP CONSTRAINT IF EXISTS waterfall_sessions_pkey;
--
-- Name: waterfall_sessions waterfall_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.waterfall_sessions
    ADD CONSTRAINT waterfall_sessions_pkey PRIMARY KEY (id);

ALTER TABLE custom_facebrasil.xp_logs DROP CONSTRAINT IF EXISTS xp_logs_pkey;
--
-- Name: xp_logs xp_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.xp_logs
    ADD CONSTRAINT xp_logs_pkey PRIMARY KEY (id);

