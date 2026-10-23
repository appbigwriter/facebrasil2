
--
-- Name: calculate_level(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.calculate_level(points integer) RETURNS TABLE(level integer, level_name text)
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

CREATE FUNCTION public.check_and_award_badges(p_user_id text) RETURNS TABLE(badge_id uuid, badge_name text, badge_icon text, badge_rarity text, newly_earned boolean)
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

CREATE FUNCTION public.ensure_profile_exists() RETURNS trigger
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

CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.profiles (id, name, avatar_url, role, email)
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

CREATE FUNCTION public.handle_new_user_role() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.profiles (id, role, name, avatar_url)
  VALUES (NEW.id, 'USER', NEW.raw_user_meta_data->>'name', NEW.raw_user_meta_data->>'avatar_url')
  ON CONFLICT (id) DO UPDATE 
  SET role = EXCLUDED.role;
  RETURN NEW;
END;
$$;


--
-- Name: increment_ad_clicks(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.increment_ad_clicks(ad_id uuid) RETURNS void
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

CREATE FUNCTION public.increment_ad_curiosity(ad_id uuid) RETURNS void
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

CREATE FUNCTION public.increment_ad_views(ad_id uuid) RETURNS void
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

CREATE FUNCTION public.increment_article_views(p_article_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    UPDATE public.articles
    SET views = views + 1
    WHERE id = p_article_id;
END;
$$;


--
-- Name: increment_user_xp(text, integer, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.increment_user_xp(uid text, xp_points integer, activity_col text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.user_reputation (user_id, total_points, last_activity_at)
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
  UPDATE public.user_reputation
  SET level = floor((sqrt(8 * total_points / 100 + 1) - 1) / 2) + 1
  WHERE user_id = uid;
END;
$$;


--
-- Name: reset_expired_heroes(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.reset_expired_heroes() RETURNS void
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

CREATE FUNCTION public.reset_weekly_points() RETURNS void
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

CREATE FUNCTION public.set_hero_timestamp() RETURNS trigger
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

CREATE FUNCTION public.set_updated_at() RETURNS trigger
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

CREATE FUNCTION public.toggle_article_favorite(p_article_id uuid, p_user_id text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_exists BOOLEAN;
    v_count INTEGER;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM public.article_favorites
        WHERE article_id = p_article_id AND user_id = p_user_id
    ) INTO v_exists;

    IF v_exists THEN
        DELETE FROM public.article_favorites WHERE article_id = p_article_id AND user_id = p_user_id;
        UPDATE public.articles SET favorites_count = GREATEST(0, favorites_count - 1) WHERE id = p_article_id;
        RETURN jsonb_build_object('favorited', false);
    ELSE
        INSERT INTO public.article_favorites(article_id, user_id) VALUES (p_article_id, p_user_id);
        UPDATE public.articles SET favorites_count = favorites_count + 1 WHERE id = p_article_id;
        RETURN jsonb_build_object('favorited', true);
    END IF;
END;
$$;


--
-- Name: update_events_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_events_updated_at() RETURNS trigger
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

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
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

CREATE FUNCTION public.update_updated_at_timestamp() RETURNS trigger
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

CREATE FUNCTION public.update_user_reputation() RETURNS trigger
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

CREATE FUNCTION public.upsert_article_read(p_article_id uuid, p_session_id text, p_user_id text, p_read_time_seconds integer, p_scroll_depth integer, p_completed boolean, p_bounced boolean, p_translator_used boolean, p_translator_lang text, p_referrer text, p_country_code text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_is_new_session boolean;
BEGIN
    -- Check if it's a new session for this article
    v_is_new_session := NOT EXISTS (
        SELECT 1 FROM public.article_reads 
        WHERE session_id = p_session_id
    );

    -- Insert or update the read log
    INSERT INTO public.article_reads (
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
        UPDATE public.articles
        SET views = COALESCE(views, 0) + 1
        WHERE id = p_article_id;
    END IF;
END;
$$;


--
-- Name: user_activities; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_activities (
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
-- Name: TABLE user_activities; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.user_activities IS 'Detailed log of all user engagement activities';



--
-- Name: activity_statistics; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.activity_statistics AS
 SELECT activity_type,
    count(*) AS total_count,
    count(DISTINCT user_id) AS unique_users,
    sum(points_earned) AS total_points_distributed,
    avg(points_earned) AS avg_points_per_activity,
    count(*) FILTER (WHERE (validated = true)) AS validated_count,
    max(created_at) AS last_activity_at
   FROM public.user_activities
  GROUP BY activity_type
  ORDER BY (count(*)) DESC;


--
-- Name: ad_publications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ad_publications (
    ad_id uuid NOT NULL,
    publication_id uuid NOT NULL
);


--
-- Name: ads; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ads (
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

CREATE TABLE public.article_favorites (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    article_id uuid,
    user_id text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: article_reads; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.article_reads (
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

CREATE TABLE public.articles (
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
-- Name: COLUMN articles.source_type; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.articles.source_type IS 'manual = human-written, automated = AI-generated from news sources';



--
-- Name: COLUMN articles.ai_context; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.articles.ai_context IS 'Structured AI-generated context: historical, statistical, geopolitical, practical';



--
-- Name: COLUMN articles.language; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.articles.language IS 'Idioma do artigo (ex: pt, en, es)';



--
-- Name: COLUMN articles.translation_group_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.articles.translation_group_id IS 'UUID compartilhado por todas as traduções do mesmo artigo';



--
-- Name: COLUMN articles.disable_view_simulation; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.articles.disable_view_simulation IS 'When TRUE, the automate-analytics Edge Function will skip incrementing views for this article.';



--
-- Name: badges; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.badges (
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
-- Name: TABLE badges; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.badges IS 'Badge definitions with criteria and metadata';



--
-- Name: user_badges; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_badges (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id text NOT NULL,
    badge_id uuid,
    earned_at timestamp with time zone DEFAULT now(),
    progress jsonb DEFAULT '{}'::jsonb
);


--
-- Name: TABLE user_badges; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.user_badges IS 'Junction table tracking which users earned which badges';



--
-- Name: badge_statistics; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.badge_statistics AS
 SELECT b.id,
    b.name,
    b.icon,
    b.rarity,
    count(ub.id) AS times_earned,
    count(DISTINCT ub.user_id) AS unique_users,
    max(ub.earned_at) AS last_earned_at
   FROM (public.badges b
     LEFT JOIN public.user_badges ub ON ((b.id = ub.badge_id)))
  WHERE (b.active = true)
  GROUP BY b.id, b.name, b.icon, b.rarity
  ORDER BY (count(ub.id)) DESC;


--
-- Name: blogs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.blogs (
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

CREATE TABLE public.captured_news (
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

CREATE TABLE public.categories (
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
-- Name: COLUMN categories.escopo; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.categories.escopo IS 'Lista de tópicos/temas sugeridos para a categoria (usado no gerador IA)';



--
-- Name: challenges; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.challenges (
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

CREATE TABLE public.events (
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


--
-- Name: TABLE events; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.events IS 'Community events calendar';



--
-- Name: COLUMN events.description; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.events.description IS 'Max 200 characters';



--
-- Name: COLUMN events.status; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.events.status IS 'pending (awaiting approval), approved (visible), rejected';



--
-- Name: instagram_events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.instagram_events (
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

CREATE TABLE public.user_reputation (
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
-- Name: TABLE user_reputation; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.user_reputation IS 'User gamification reputation, points, and level tracking';



--
-- Name: leaderboard_weekly; Type: MATERIALIZED VIEW; Schema: public; Owner: postgres
--

CREATE MATERIALIZED VIEW public.leaderboard_weekly AS
 SELECT user_id,
    weekly_points AS points,
    level,
    level_name,
    badges,
    articles_read,
    comments_made,
    shares_made,
    row_number() OVER (ORDER BY weekly_points DESC, total_points DESC) AS rank,
    updated_at
   FROM public.user_reputation ur
  WHERE (weekly_points > 0)
  ORDER BY weekly_points DESC, total_points DESC
 LIMIT 100
  WITH NO DATA;



--
-- Name: news_queue; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.news_queue (
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
-- Name: TABLE news_queue; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.news_queue IS 'Processing pipeline for news items from capture to publication';



--
-- Name: news_queue_stats; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.news_queue_stats AS
 SELECT status,
    count(*) AS count,
    avg(ai_tokens_used) AS avg_tokens,
    avg(ai_processing_time_ms) AS avg_processing_time_ms,
    min(created_at) AS oldest_item,
    max(created_at) AS newest_item
   FROM public.news_queue
  GROUP BY status;



ALTER VIEW public.news_queue_stats OWNER TO postgres;


--
-- Name: news_sources; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.news_sources (
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
-- Name: TABLE news_sources; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.news_sources IS 'RSS feeds, APIs, and scrapers for automated news collection';



--
-- Name: news_source_performance; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.news_source_performance AS
 SELECT ns.id,
    ns.name,
    ns.type,
    ns.enabled,
    ns.last_fetch,
    count(nq.id) AS total_items,
    count(nq.id) FILTER (WHERE (nq.status = 'published'::text)) AS published_count,
    count(nq.id) FILTER (WHERE (nq.status = 'failed'::text)) AS failed_count,
    count(nq.id) FILTER (WHERE (nq.status = 'pending'::text)) AS pending_count
   FROM (public.news_sources ns
     LEFT JOIN public.news_queue nq ON ((ns.id = nq.source_id)))
  GROUP BY ns.id, ns.name, ns.type, ns.enabled, ns.last_fetch
  ORDER BY (count(nq.id) FILTER (WHERE (nq.status = 'published'::text))) DESC;


--
-- Name: news_usage; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.news_usage (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    news_id uuid NOT NULL,
    agent_id uuid,
    used_by_user_id uuid,
    used_at timestamp with time zone DEFAULT now()
);


--
-- Name: partner_offers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.partner_offers (
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

CREATE TABLE public.partners (
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

CREATE TABLE public.profiles (
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

CREATE TABLE public.publications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: site_settings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.site_settings (
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

CREATE TABLE public.social_credentials (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    platform text NOT NULL,
    credentials jsonb DEFAULT '{}'::jsonb NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: static_pages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.static_pages (
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

CREATE TABLE public.user_challenges (
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

CREATE TABLE public.user_collection_items (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    collection_id uuid NOT NULL,
    article_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: user_collections; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_collections (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id text NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: user_reputation_detailed; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.user_reputation_detailed AS
 SELECT user_id,
    total_points,
    weekly_points,
    monthly_points,
    level,
    level_name,
    articles_read,
    comments_made,
    shares_made,
    fact_checks_submitted,
    topics_suggested,
    ( SELECT json_agg(json_build_object('id', b.id, 'name', b.name, 'icon', b.icon, 'rarity', b.rarity, 'earned_at', ub.earned_at) ORDER BY ub.earned_at DESC) AS json_agg
           FROM (public.user_badges ub
             JOIN public.badges b ON ((ub.badge_id = b.id)))
          WHERE (ub.user_id = ur.user_id)) AS badges_detailed,
    created_at,
    updated_at,
    last_activity_at
   FROM public.user_reputation ur;



ALTER VIEW public.user_reputation_detailed OWNER TO postgres;


--
-- Name: user_video_reports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_video_reports (
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

CREATE TABLE public.virtual_agents (
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

CREATE TABLE public.waterfall_posts (
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

CREATE TABLE public.waterfall_sessions (
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

CREATE TABLE public.xp_logs (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id text,
    type text NOT NULL,
    points integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now()
);



--
-- Name: ad_publications ad_publications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ad_publications
    ADD CONSTRAINT ad_publications_pkey PRIMARY KEY (ad_id, publication_id);



--
-- Name: ads ads_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ads
    ADD CONSTRAINT ads_pkey PRIMARY KEY (id);



--
-- Name: article_favorites article_favorites_article_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.article_favorites
    ADD CONSTRAINT article_favorites_article_id_user_id_key UNIQUE (article_id, user_id);



--
-- Name: article_favorites article_favorites_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.article_favorites
    ADD CONSTRAINT article_favorites_pkey PRIMARY KEY (id);



--
-- Name: article_reads article_reads_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.article_reads
    ADD CONSTRAINT article_reads_pkey PRIMARY KEY (id);



--
-- Name: article_reads article_reads_session_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.article_reads
    ADD CONSTRAINT article_reads_session_id_key UNIQUE (session_id);



--
-- Name: articles articles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_pkey PRIMARY KEY (id);



--
-- Name: articles articles_slug_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_slug_key UNIQUE (slug);



--
-- Name: badges badges_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.badges
    ADD CONSTRAINT badges_name_key UNIQUE (name);



--
-- Name: badges badges_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.badges
    ADD CONSTRAINT badges_pkey PRIMARY KEY (id);



--
-- Name: blogs blogs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blogs
    ADD CONSTRAINT blogs_pkey PRIMARY KEY (id);



--
-- Name: blogs blogs_slug_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blogs
    ADD CONSTRAINT blogs_slug_key UNIQUE (slug);



--
-- Name: captured_news captured_news_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.captured_news
    ADD CONSTRAINT captured_news_pkey PRIMARY KEY (id);



--
-- Name: captured_news captured_news_url_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.captured_news
    ADD CONSTRAINT captured_news_url_key UNIQUE (url);



--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);



--
-- Name: categories categories_slug_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_slug_key UNIQUE (slug);



--
-- Name: challenges challenges_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.challenges
    ADD CONSTRAINT challenges_pkey PRIMARY KEY (id);



--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);



--
-- Name: instagram_events instagram_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instagram_events
    ADD CONSTRAINT instagram_events_pkey PRIMARY KEY (id);



--
-- Name: news_queue news_queue_original_url_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.news_queue
    ADD CONSTRAINT news_queue_original_url_key UNIQUE (original_url);



--
-- Name: news_queue news_queue_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.news_queue
    ADD CONSTRAINT news_queue_pkey PRIMARY KEY (id);



--
-- Name: news_sources news_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.news_sources
    ADD CONSTRAINT news_sources_pkey PRIMARY KEY (id);



--
-- Name: news_sources news_sources_url_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.news_sources
    ADD CONSTRAINT news_sources_url_key UNIQUE (url);



--
-- Name: news_usage news_usage_news_id_agent_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.news_usage
    ADD CONSTRAINT news_usage_news_id_agent_id_key UNIQUE (news_id, agent_id);



--
-- Name: news_usage news_usage_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.news_usage
    ADD CONSTRAINT news_usage_pkey PRIMARY KEY (id);



--
-- Name: partner_offers partner_offers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.partner_offers
    ADD CONSTRAINT partner_offers_pkey PRIMARY KEY (id);



--
-- Name: partners partners_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.partners
    ADD CONSTRAINT partners_pkey PRIMARY KEY (id);



--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);



--
-- Name: publications publications_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.publications
    ADD CONSTRAINT publications_name_key UNIQUE (name);



--
-- Name: publications publications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.publications
    ADD CONSTRAINT publications_pkey PRIMARY KEY (id);



--
-- Name: site_settings site_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.site_settings
    ADD CONSTRAINT site_settings_pkey PRIMARY KEY (id);



--
-- Name: social_credentials social_credentials_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.social_credentials
    ADD CONSTRAINT social_credentials_pkey PRIMARY KEY (id);



--
-- Name: social_credentials social_credentials_platform_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.social_credentials
    ADD CONSTRAINT social_credentials_platform_key UNIQUE (platform);



--
-- Name: static_pages static_pages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.static_pages
    ADD CONSTRAINT static_pages_pkey PRIMARY KEY (id);



--
-- Name: static_pages static_pages_slug_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.static_pages
    ADD CONSTRAINT static_pages_slug_key UNIQUE (slug);



--
-- Name: user_activities user_activities_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_activities
    ADD CONSTRAINT user_activities_pkey PRIMARY KEY (id);



--
-- Name: user_badges user_badges_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_badges
    ADD CONSTRAINT user_badges_pkey PRIMARY KEY (id);



--
-- Name: user_badges user_badges_user_id_badge_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_badges
    ADD CONSTRAINT user_badges_user_id_badge_id_key UNIQUE (user_id, badge_id);



--
-- Name: user_challenges user_challenges_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_challenges
    ADD CONSTRAINT user_challenges_pkey PRIMARY KEY (id);



--
-- Name: user_challenges user_challenges_user_id_challenge_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_challenges
    ADD CONSTRAINT user_challenges_user_id_challenge_id_key UNIQUE (user_id, challenge_id);



--
-- Name: user_collection_items user_collection_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_collection_items
    ADD CONSTRAINT user_collection_items_pkey PRIMARY KEY (id);



--
-- Name: user_collection_items user_collection_items_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_collection_items
    ADD CONSTRAINT user_collection_items_unique UNIQUE (collection_id, article_id);



--
-- Name: user_collections user_collections_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_collections
    ADD CONSTRAINT user_collections_pkey PRIMARY KEY (id);



--
-- Name: user_reputation user_reputation_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_reputation
    ADD CONSTRAINT user_reputation_pkey PRIMARY KEY (id);



--
-- Name: user_reputation user_reputation_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_reputation
    ADD CONSTRAINT user_reputation_user_id_key UNIQUE (user_id);



--
-- Name: user_video_reports user_video_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_video_reports
    ADD CONSTRAINT user_video_reports_pkey PRIMARY KEY (id);



--
-- Name: virtual_agents virtual_agents_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.virtual_agents
    ADD CONSTRAINT virtual_agents_pkey PRIMARY KEY (id);



--
-- Name: waterfall_posts waterfall_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.waterfall_posts
    ADD CONSTRAINT waterfall_posts_pkey PRIMARY KEY (id);



--
-- Name: waterfall_sessions waterfall_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.waterfall_sessions
    ADD CONSTRAINT waterfall_sessions_pkey PRIMARY KEY (id);



--
-- Name: xp_logs xp_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.xp_logs
    ADD CONSTRAINT xp_logs_pkey PRIMARY KEY (id);



--
-- Name: idx_ads_active_position; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ads_active_position ON public.ads USING btree ("position", is_active) WHERE (is_active = true);



--
-- Name: idx_article_favorites_article; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_article_favorites_article ON public.article_favorites USING btree (article_id);



--
-- Name: idx_article_favorites_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_article_favorites_user ON public.article_favorites USING btree (user_id);



--
-- Name: idx_article_reads_article_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_article_reads_article_id ON public.article_reads USING btree (article_id);



--
-- Name: idx_article_reads_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_article_reads_created_at ON public.article_reads USING btree (created_at);



--
-- Name: idx_article_reads_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_article_reads_user_id ON public.article_reads USING btree (user_id);



--
-- Name: idx_articles_language; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_articles_language ON public.articles USING btree (language);



--
-- Name: idx_articles_news_queue; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_articles_news_queue ON public.articles USING btree (news_queue_id);



--
-- Name: idx_articles_sent_to_tv; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_articles_sent_to_tv ON public.articles USING btree (sent_to_tv, published_at DESC);



--
-- Name: idx_articles_source_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_articles_source_type ON public.articles USING btree (source_type);



--
-- Name: idx_articles_translation_group_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_articles_translation_group_id ON public.articles USING btree (translation_group_id);



--
-- Name: idx_badges_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_badges_active ON public.badges USING btree (active) WHERE (active = true);



--
-- Name: idx_badges_rarity; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_badges_rarity ON public.badges USING btree (rarity);



--
-- Name: idx_events_city; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_city ON public.events USING btree (city);



--
-- Name: idx_events_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_date ON public.events USING btree (event_date DESC);



--
-- Name: idx_events_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_status ON public.events USING btree (status);



--
-- Name: idx_events_submitted_by; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_submitted_by ON public.events USING btree (submitted_by);



--
-- Name: idx_instagram_events_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_instagram_events_created ON public.instagram_events USING btree (created_at DESC);



--
-- Name: idx_instagram_events_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_instagram_events_type ON public.instagram_events USING btree (event_type);



--
-- Name: idx_news_queue_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_news_queue_created ON public.news_queue USING btree (created_at DESC);



--
-- Name: idx_news_queue_source; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_news_queue_source ON public.news_queue USING btree (source_id);



--
-- Name: idx_news_queue_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_news_queue_status ON public.news_queue USING btree (status);



--
-- Name: idx_news_queue_url; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_news_queue_url ON public.news_queue USING btree (original_url);



--
-- Name: idx_news_sources_enabled; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_news_sources_enabled ON public.news_sources USING btree (enabled) WHERE (enabled = true);



--
-- Name: idx_news_sources_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_news_sources_type ON public.news_sources USING btree (type);



--
-- Name: idx_static_pages_slug_lang; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_static_pages_slug_lang ON public.static_pages USING btree (slug, language);



--
-- Name: idx_user_activities_article; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_activities_article ON public.user_activities USING btree (article_id);



--
-- Name: idx_user_activities_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_activities_created ON public.user_activities USING btree (created_at DESC);



--
-- Name: idx_user_activities_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_activities_type ON public.user_activities USING btree (activity_type);



--
-- Name: idx_user_activities_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_activities_user_id ON public.user_activities USING btree (user_id);



--
-- Name: idx_user_activities_validated; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_activities_validated ON public.user_activities USING btree (validated) WHERE (validated = true);



--
-- Name: idx_user_badges_badge_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_badges_badge_id ON public.user_badges USING btree (badge_id);



--
-- Name: idx_user_badges_earned; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_badges_earned ON public.user_badges USING btree (earned_at DESC);



--
-- Name: idx_user_badges_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_badges_user_id ON public.user_badges USING btree (user_id);



--
-- Name: idx_user_reputation_level; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_reputation_level ON public.user_reputation USING btree (level);



--
-- Name: idx_user_reputation_total_points; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_reputation_total_points ON public.user_reputation USING btree (total_points DESC);



--
-- Name: idx_user_reputation_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_reputation_user_id ON public.user_reputation USING btree (user_id);



--
-- Name: idx_user_reputation_weekly_points; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_reputation_weekly_points ON public.user_reputation USING btree (weekly_points DESC);



--
-- Name: idx_waterfall_posts_session; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_waterfall_posts_session ON public.waterfall_posts USING btree (session_id);



--
-- Name: idx_waterfall_sessions_article; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_waterfall_sessions_article ON public.waterfall_sessions USING btree (article_id, created_at DESC);



--
-- Name: articles tr_ensure_profile; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_ensure_profile BEFORE INSERT OR UPDATE ON public.articles FOR EACH ROW EXECUTE FUNCTION public.ensure_profile_exists();



--
-- Name: events trigger_events_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_events_updated_at BEFORE UPDATE ON public.events FOR EACH ROW EXECUTE FUNCTION public.update_events_updated_at();



--
-- Name: articles trigger_hero_timestamp; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_hero_timestamp BEFORE INSERT OR UPDATE ON public.articles FOR EACH ROW WHEN ((new.colocar_hero = true)) EXECUTE FUNCTION public.set_hero_timestamp();



--
-- Name: user_activities trigger_update_reputation; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_reputation AFTER INSERT ON public.user_activities FOR EACH ROW EXECUTE FUNCTION public.update_user_reputation();



--
-- Name: user_reputation trigger_user_reputation_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_user_reputation_updated_at BEFORE UPDATE ON public.user_reputation FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_timestamp();



--
-- Name: news_sources update_news_sources_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_news_sources_updated_at BEFORE UPDATE ON public.news_sources FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();



--
-- Name: waterfall_sessions waterfall_sessions_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER waterfall_sessions_updated_at BEFORE UPDATE ON public.waterfall_sessions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();



--
-- Name: ad_publications ad_publications_ad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ad_publications
    ADD CONSTRAINT ad_publications_ad_id_fkey FOREIGN KEY (ad_id) REFERENCES public.ads(id) ON DELETE CASCADE;



--
-- Name: ad_publications ad_publications_publication_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ad_publications
    ADD CONSTRAINT ad_publications_publication_id_fkey FOREIGN KEY (publication_id) REFERENCES public.publications(id) ON DELETE CASCADE;



--
-- Name: ads ads_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ads
    ADD CONSTRAINT ads_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE SET NULL;



--
-- Name: article_favorites article_favorites_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.article_favorites
    ADD CONSTRAINT article_favorites_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.articles(id) ON DELETE CASCADE;



--
-- Name: article_reads article_reads_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.article_reads
    ADD CONSTRAINT article_reads_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.articles(id) ON DELETE CASCADE;



--
-- Name: articles articles_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.profiles(id);



--
-- Name: articles articles_blog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_blog_id_fkey FOREIGN KEY (blog_id) REFERENCES public.blogs(id);



--
-- Name: articles articles_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id);



--
-- Name: articles articles_news_queue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_news_queue_id_fkey FOREIGN KEY (news_queue_id) REFERENCES public.news_queue(id) ON DELETE SET NULL;



--
-- Name: blogs blogs_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blogs
    ADD CONSTRAINT blogs_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id);



--
-- Name: categories categories_blog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_blog_id_fkey FOREIGN KEY (blog_id) REFERENCES public.blogs(id);



--
-- Name: categories categories_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.categories(id);



--
-- Name: news_queue news_queue_processed_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.news_queue
    ADD CONSTRAINT news_queue_processed_article_id_fkey FOREIGN KEY (processed_article_id) REFERENCES public.articles(id) ON DELETE SET NULL;



--
-- Name: news_queue news_queue_source_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.news_queue
    ADD CONSTRAINT news_queue_source_id_fkey FOREIGN KEY (source_id) REFERENCES public.news_sources(id) ON DELETE CASCADE;



--
-- Name: news_usage news_usage_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.news_usage
    ADD CONSTRAINT news_usage_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES public.virtual_agents(id) ON DELETE SET NULL;



--
-- Name: news_usage news_usage_news_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.news_usage
    ADD CONSTRAINT news_usage_news_id_fkey FOREIGN KEY (news_id) REFERENCES public.captured_news(id) ON DELETE CASCADE;



--
-- Name: partner_offers partner_offers_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.partner_offers
    ADD CONSTRAINT partner_offers_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES public.partners(id) ON DELETE CASCADE;



--
-- Name: user_activities user_activities_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_activities
    ADD CONSTRAINT user_activities_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.articles(id) ON DELETE CASCADE;



--
-- Name: user_badges user_badges_badge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_badges
    ADD CONSTRAINT user_badges_badge_id_fkey FOREIGN KEY (badge_id) REFERENCES public.badges(id) ON DELETE CASCADE;



--
-- Name: user_challenges user_challenges_challenge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_challenges
    ADD CONSTRAINT user_challenges_challenge_id_fkey FOREIGN KEY (challenge_id) REFERENCES public.challenges(id) ON DELETE CASCADE;



--
-- Name: user_challenges user_challenges_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_challenges
    ADD CONSTRAINT user_challenges_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;



--
-- Name: user_collection_items user_collection_items_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_collection_items
    ADD CONSTRAINT user_collection_items_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.articles(id) ON DELETE CASCADE;



--
-- Name: user_collection_items user_collection_items_collection_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_collection_items
    ADD CONSTRAINT user_collection_items_collection_id_fkey FOREIGN KEY (collection_id) REFERENCES public.user_collections(id) ON DELETE CASCADE;



--
-- Name: user_collections user_collections_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_collections
    ADD CONSTRAINT user_collections_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;



--
-- Name: user_video_reports user_video_reports_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_video_reports
    ADD CONSTRAINT user_video_reports_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);



--
-- Name: waterfall_posts waterfall_posts_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.waterfall_posts
    ADD CONSTRAINT waterfall_posts_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.waterfall_sessions(id) ON DELETE CASCADE;



--
-- Name: waterfall_sessions waterfall_sessions_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.waterfall_sessions
    ADD CONSTRAINT waterfall_sessions_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.articles(id) ON DELETE CASCADE;


--
-- Name: static_pages Admin write static_pages; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Admin write static_pages" ON public.static_pages USING (true);



--
-- Name: articles Admins full access; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Admins full access" ON public.articles USING (true);



--
-- Name: profiles Admins full access profiles; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Admins full access profiles" ON public.profiles USING (true);



--
-- Name: article_reads Allow anonymous insert article_reads; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow anonymous insert article_reads" ON public.article_reads FOR INSERT TO authenticated, anon WITH CHECK (true);



--
-- Name: events Allow authenticated delete events; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated delete events" ON public.events FOR DELETE TO authenticated USING (true);



--
-- Name: categories Allow authenticated delete from categories; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated delete from categories" ON public.categories FOR DELETE TO authenticated USING (true);



--
-- Name: partner_offers Allow authenticated full access to partner_offers; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated full access to partner_offers" ON public.partner_offers TO authenticated USING (true);



--
-- Name: partners Allow authenticated full access to partners; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated full access to partners" ON public.partners TO authenticated USING (true);



--
-- Name: events Allow authenticated insert events; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated insert events" ON public.events FOR INSERT TO authenticated WITH CHECK (true);



--
-- Name: categories Allow authenticated insert to categories; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated insert to categories" ON public.categories FOR INSERT TO authenticated WITH CHECK (true);



--
-- Name: ads Allow authenticated manage ads; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated manage ads" ON public.ads TO authenticated USING (true) WITH CHECK (true);



--
-- Name: blogs Allow authenticated manage blogs; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated manage blogs" ON public.blogs TO authenticated USING (true) WITH CHECK (true);



--
-- Name: challenges Allow authenticated manage challenges; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated manage challenges" ON public.challenges TO authenticated USING (true) WITH CHECK (true);



--
-- Name: user_video_reports Allow authenticated manage user_video_reports; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated manage user_video_reports" ON public.user_video_reports TO authenticated USING (true) WITH CHECK (true);



--
-- Name: xp_logs Allow authenticated read xp_logs; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated read xp_logs" ON public.xp_logs FOR SELECT TO authenticated USING (true);



--
-- Name: article_reads Allow authenticated select own reads; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated select own reads" ON public.article_reads FOR SELECT TO authenticated USING (((auth.uid())::text = user_id));



--
-- Name: events Allow authenticated update events; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated update events" ON public.events FOR UPDATE TO authenticated USING (true) WITH CHECK (true);



--
-- Name: profiles Allow authenticated update own profile; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated update own profile" ON public.profiles FOR UPDATE TO authenticated USING (((auth.uid())::text = id)) WITH CHECK (((auth.uid())::text = id));



--
-- Name: categories Allow authenticated update to categories; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated update to categories" ON public.categories FOR UPDATE TO authenticated USING (true) WITH CHECK (true);



--
-- Name: articles Allow authenticated write articles; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated write articles" ON public.articles TO authenticated USING (true) WITH CHECK (true);



--
-- Name: categories Allow public read access to categories; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public read access to categories" ON public.categories FOR SELECT USING (true);



--
-- Name: partner_offers Allow public read access to partner_offers; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public read access to partner_offers" ON public.partner_offers FOR SELECT USING (true);



--
-- Name: partners Allow public read access to partners; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public read access to partners" ON public.partners FOR SELECT USING (true);



--
-- Name: ads Allow public read ads; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public read ads" ON public.ads FOR SELECT USING (true);



--
-- Name: blogs Allow public read blogs; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public read blogs" ON public.blogs FOR SELECT USING (true);



--
-- Name: categories Allow public read categories; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public read categories" ON public.categories FOR SELECT USING (true);



--
-- Name: events Allow public read events; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public read events" ON public.events FOR SELECT USING (true);



--
-- Name: article_reads Allow service_role all article_reads; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow service_role all article_reads" ON public.article_reads TO service_role USING (true);



--
-- Name: partner_offers Allow service_role full access to partner_offers; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow service_role full access to partner_offers" ON public.partner_offers TO service_role USING (true);



--
-- Name: partners Allow service_role full access to partners; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow service_role full access to partners" ON public.partners TO service_role USING (true);



--
-- Name: xp_logs Allow service_role manage xp_logs; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow service_role manage xp_logs" ON public.xp_logs TO service_role USING (true) WITH CHECK (true);



--
-- Name: article_reads Allow staff select all article_reads; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow staff select all article_reads" ON public.article_reads FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = ANY (ARRAY['ADMIN'::text, 'EDITOR'::text]))))));



--
-- Name: captured_news Enable delete for authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable delete for authenticated users" ON public.captured_news FOR DELETE TO authenticated USING (true);



--
-- Name: news_usage Enable delete for authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable delete for authenticated users" ON public.news_usage FOR DELETE TO authenticated USING (true);



--
-- Name: virtual_agents Enable delete for authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable delete for authenticated users" ON public.virtual_agents FOR DELETE TO authenticated USING (true);



--
-- Name: captured_news Enable insert for authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable insert for authenticated users" ON public.captured_news FOR INSERT TO authenticated WITH CHECK (true);



--
-- Name: news_usage Enable insert for authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable insert for authenticated users" ON public.news_usage FOR INSERT TO authenticated WITH CHECK (true);



--
-- Name: virtual_agents Enable insert for authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable insert for authenticated users" ON public.virtual_agents FOR INSERT TO authenticated WITH CHECK (true);



--
-- Name: captured_news Enable read access for all authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable read access for all authenticated users" ON public.captured_news FOR SELECT TO authenticated USING (true);



--
-- Name: news_usage Enable read access for all authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable read access for all authenticated users" ON public.news_usage FOR SELECT TO authenticated USING (true);



--
-- Name: virtual_agents Enable read access for all authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable read access for all authenticated users" ON public.virtual_agents FOR SELECT TO authenticated USING (true);



--
-- Name: captured_news Enable update for authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable update for authenticated users" ON public.captured_news FOR UPDATE TO authenticated USING (true);



--
-- Name: news_usage Enable update for authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable update for authenticated users" ON public.news_usage FOR UPDATE TO authenticated USING (true);



--
-- Name: virtual_agents Enable update for authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable update for authenticated users" ON public.virtual_agents FOR UPDATE TO authenticated USING (true);



--
-- Name: articles Public Read Articles; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Public Read Articles" ON public.articles FOR SELECT USING (true);



--
-- Name: profiles Public Read Profiles; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Public Read Profiles" ON public.profiles FOR SELECT USING (true);



--
-- Name: article_favorites Public can count favorites; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Public can count favorites" ON public.article_favorites FOR SELECT TO authenticated, anon USING (true);



--
-- Name: challenges Public challenges are viewable by everyone; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Public challenges are viewable by everyone" ON public.challenges FOR SELECT USING (true);



--
-- Name: static_pages Public read static_pages; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Public read static_pages" ON public.static_pages FOR SELECT USING (true);



--
-- Name: user_collection_items Users can add items to their own collections; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can add items to their own collections" ON public.user_collection_items FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM public.user_collections
  WHERE ((user_collections.id = user_collection_items.collection_id) AND (user_collections.user_id = (auth.uid())::text)))));



--
-- Name: user_collections Users can create their own collections; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can create their own collections" ON public.user_collections FOR INSERT WITH CHECK (((auth.uid())::text = user_id));



--
-- Name: user_collections Users can delete their own collections; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can delete their own collections" ON public.user_collections FOR DELETE USING (((auth.uid())::text = user_id));



--
-- Name: user_collection_items Users can remove items from their own collections; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can remove items from their own collections" ON public.user_collection_items FOR DELETE USING ((EXISTS ( SELECT 1
   FROM public.user_collections
  WHERE ((user_collections.id = user_collection_items.collection_id) AND (user_collections.user_id = (auth.uid())::text)))));



--
-- Name: user_challenges Users can update their own challenge progress; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can update their own challenge progress" ON public.user_challenges FOR UPDATE USING (((auth.uid())::text = user_id));



--
-- Name: user_collections Users can update their own collections; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can update their own collections" ON public.user_collections FOR UPDATE USING (((auth.uid())::text = user_id));



--
-- Name: user_challenges Users can view their own challenge progress; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can view their own challenge progress" ON public.user_challenges FOR SELECT USING (((auth.uid())::text = user_id));



--
-- Name: user_collection_items Users can view their own collection items; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can view their own collection items" ON public.user_collection_items FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.user_collections
  WHERE ((user_collections.id = user_collection_items.collection_id) AND (user_collections.user_id = (auth.uid())::text)))));



--
-- Name: user_collections Users can view their own collections; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can view their own collections" ON public.user_collections FOR SELECT USING (((auth.uid())::text = user_id));



--
-- Name: article_favorites Users manage own favorites; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users manage own favorites" ON public.article_favorites TO authenticated USING (((auth.uid())::text = user_id)) WITH CHECK (((auth.uid())::text = user_id));



--
-- Name: ads; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.ads ENABLE ROW LEVEL SECURITY;


--
-- Name: ads ads_select_public; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY ads_select_public ON public.ads FOR SELECT USING (true);



--
-- Name: ads ads_write_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY ads_write_admin ON public.ads USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = 'ADMIN'::text)))));



--
-- Name: article_favorites; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.article_favorites ENABLE ROW LEVEL SECURITY;


--
-- Name: article_reads; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.article_reads ENABLE ROW LEVEL SECURITY;


--
-- Name: articles; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.articles ENABLE ROW LEVEL SECURITY;


--
-- Name: articles articles_select_published; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY articles_select_published ON public.articles FOR SELECT USING ((status = ANY (ARRAY['PUBLISHED'::text, 'published'::text])));



--
-- Name: articles articles_select_staff; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY articles_select_staff ON public.articles FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = ANY (ARRAY['ADMIN'::text, 'EDITOR'::text]))))));



--
-- Name: articles articles_write_staff; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY articles_write_staff ON public.articles USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = ANY (ARRAY['ADMIN'::text, 'EDITOR'::text]))))));



--
-- Name: badges; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.badges ENABLE ROW LEVEL SECURITY;


--
-- Name: badges badges_select_public; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY badges_select_public ON public.badges FOR SELECT USING (true);



--
-- Name: badges badges_write_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY badges_write_admin ON public.badges USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = 'ADMIN'::text)))));



--
-- Name: blogs; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.blogs ENABLE ROW LEVEL SECURITY;


--
-- Name: blogs blogs_select_public; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY blogs_select_public ON public.blogs FOR SELECT USING (true);



--
-- Name: blogs blogs_write_owner_or_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY blogs_write_owner_or_admin ON public.blogs USING (((owner_id = (auth.uid())::text) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = 'ADMIN'::text))))));



--
-- Name: captured_news; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.captured_news ENABLE ROW LEVEL SECURITY;


--
-- Name: categories; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;


--
-- Name: categories categories_select_public; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY categories_select_public ON public.categories FOR SELECT USING (true);



--
-- Name: categories categories_write_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY categories_write_admin ON public.categories USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = 'ADMIN'::text)))));



--
-- Name: challenges; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;


--
-- Name: events; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;


--
-- Name: events events_all_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY events_all_admin ON public.events USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = 'ADMIN'::text)))));



--
-- Name: events events_insert_public; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY events_insert_public ON public.events FOR INSERT WITH CHECK (true);



--
-- Name: events events_select_approved; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY events_select_approved ON public.events FOR SELECT USING ((status = 'approved'::text));



--
-- Name: instagram_events; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.instagram_events ENABLE ROW LEVEL SECURITY;


--
-- Name: instagram_events instagram_events_read_auth; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY instagram_events_read_auth ON public.instagram_events FOR SELECT USING ((auth.role() = 'authenticated'::text));



--
-- Name: instagram_events instagram_events_service_write; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY instagram_events_service_write ON public.instagram_events FOR INSERT WITH CHECK (true);



--
-- Name: news_queue; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.news_queue ENABLE ROW LEVEL SECURITY;


--
-- Name: news_queue news_queue_staff_only; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY news_queue_staff_only ON public.news_queue USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = ANY (ARRAY['ADMIN'::text, 'EDITOR'::text]))))));



--
-- Name: news_sources; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.news_sources ENABLE ROW LEVEL SECURITY;


--
-- Name: news_sources news_sources_admin_only; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY news_sources_admin_only ON public.news_sources USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = 'ADMIN'::text)))));



--
-- Name: news_usage; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.news_usage ENABLE ROW LEVEL SECURITY;


--
-- Name: partner_offers; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.partner_offers ENABLE ROW LEVEL SECURITY;


--
-- Name: partners; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.partners ENABLE ROW LEVEL SECURITY;


--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;


--
-- Name: profiles profiles_insert_own; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY profiles_insert_own ON public.profiles FOR INSERT WITH CHECK (((auth.uid())::text = id));



--
-- Name: profiles profiles_select_public; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY profiles_select_public ON public.profiles FOR SELECT USING (true);



--
-- Name: profiles profiles_update_own; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY profiles_update_own ON public.profiles FOR UPDATE USING (((auth.uid())::text = id));



--
-- Name: social_credentials; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.social_credentials ENABLE ROW LEVEL SECURITY;


--
-- Name: social_credentials social_creds_auth; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY social_creds_auth ON public.social_credentials USING ((auth.role() = 'authenticated'::text));



--
-- Name: static_pages; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.static_pages ENABLE ROW LEVEL SECURITY;


--
-- Name: static_pages static_pages_select_public; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY static_pages_select_public ON public.static_pages FOR SELECT USING (true);



--
-- Name: static_pages static_pages_write_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY static_pages_write_admin ON public.static_pages USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = 'ADMIN'::text)))));



--
-- Name: user_activities; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.user_activities ENABLE ROW LEVEL SECURITY;


--
-- Name: user_activities user_activities_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY user_activities_admin ON public.user_activities USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = 'ADMIN'::text)))));



--
-- Name: user_activities user_activities_insert_auth; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY user_activities_insert_auth ON public.user_activities FOR INSERT WITH CHECK ((auth.uid() IS NOT NULL));



--
-- Name: user_activities user_activities_own; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY user_activities_own ON public.user_activities FOR SELECT USING ((user_id = (auth.uid())::text));



--
-- Name: user_badges; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;


--
-- Name: user_badges user_badges_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY user_badges_admin ON public.user_badges USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = 'ADMIN'::text)))));



--
-- Name: user_badges user_badges_select_public; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY user_badges_select_public ON public.user_badges FOR SELECT USING (true);



--
-- Name: user_challenges; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.user_challenges ENABLE ROW LEVEL SECURITY;


--
-- Name: user_collection_items; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.user_collection_items ENABLE ROW LEVEL SECURITY;


--
-- Name: user_collections; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.user_collections ENABLE ROW LEVEL SECURITY;


--
-- Name: user_reputation; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.user_reputation ENABLE ROW LEVEL SECURITY;


--
-- Name: user_reputation user_reputation_own_update; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY user_reputation_own_update ON public.user_reputation FOR UPDATE USING ((user_id = (auth.uid())::text));



--
-- Name: user_reputation user_reputation_select_public; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY user_reputation_select_public ON public.user_reputation FOR SELECT USING (true);



--
-- Name: user_video_reports; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.user_video_reports ENABLE ROW LEVEL SECURITY;


--
-- Name: user_video_reports uvr_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY uvr_admin ON public.user_video_reports USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = 'ADMIN'::text)))));



--
-- Name: user_video_reports uvr_insert_auth; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY uvr_insert_auth ON public.user_video_reports FOR INSERT WITH CHECK ((auth.uid() IS NOT NULL));



--
-- Name: user_video_reports uvr_select_approved; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY uvr_select_approved ON public.user_video_reports FOR SELECT USING ((status = 'APPROVED'::text));



--
-- Name: virtual_agents; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.virtual_agents ENABLE ROW LEVEL SECURITY;


--
-- Name: waterfall_posts; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.waterfall_posts ENABLE ROW LEVEL SECURITY;


--
-- Name: waterfall_posts waterfall_posts_auth; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY waterfall_posts_auth ON public.waterfall_posts USING ((auth.role() = 'authenticated'::text));



--
-- Name: waterfall_sessions waterfall_read_auth; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY waterfall_read_auth ON public.waterfall_sessions FOR SELECT USING ((auth.role() = 'authenticated'::text));



--
-- Name: waterfall_sessions; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.waterfall_sessions ENABLE ROW LEVEL SECURITY;


--
-- Name: waterfall_sessions waterfall_write_auth; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY waterfall_write_auth ON public.waterfall_sessions USING ((auth.role() = 'authenticated'::text));



--
-- Name: xp_logs; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.xp_logs ENABLE ROW LEVEL SECURITY;


--
-- Name: xp_logs xp_logs_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY xp_logs_admin ON public.xp_logs USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = 'ADMIN'::text)))));



--
-- Name: xp_logs xp_logs_own; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY xp_logs_own ON public.xp_logs FOR SELECT USING ((user_id = (auth.uid())::text));


--
-- Name: supabase_realtime instagram_events; Type: PUBLICATION TABLE; Schema: public; Owner: postgres
--

ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.instagram_events;



--
-- Name: supabase_realtime partner_offers; Type: PUBLICATION TABLE; Schema: public; Owner: postgres
--

ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.partner_offers;



--
-- Name: supabase_realtime partners; Type: PUBLICATION TABLE; Schema: public; Owner: postgres
--

ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.partners;

