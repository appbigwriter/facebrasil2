-- =========================================================================
-- FINALIZACAO: PROPRIEDADE, PERMISSOES, USUARIOS E INTEGRIDADE
-- =========================================================================

-- 1. Transferencia de propriedade de todos os objetos para 'postgres'
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'custom_facebrasil') LOOP
        EXECUTE 'ALTER TABLE custom_facebrasil.' || quote_ident(r.tablename) || ' OWNER TO postgres;';
    END LOOP;

    FOR r IN (SELECT viewname FROM pg_views WHERE schemaname = 'custom_facebrasil') LOOP
        EXECUTE 'ALTER VIEW custom_facebrasil.' || quote_ident(r.viewname) || ' OWNER TO postgres;';
    END LOOP;

    FOR r IN (SELECT sequence_name FROM information_schema.sequences WHERE sequence_schema = 'custom_facebrasil') LOOP
        EXECUTE 'ALTER SEQUENCE custom_facebrasil.' || quote_ident(r.sequence_name) || ' OWNER TO postgres;';
    END LOOP;

    FOR r IN (SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'custom_facebrasil') LOOP
        EXECUTE 'ALTER FUNCTION custom_facebrasil.' || quote_ident(r.routine_name) || ' OWNER TO postgres;';
    END LOOP;
END $$;

-- 2. Concessao de permissoes
GRANT ALL ON SCHEMA custom_facebrasil TO postgres;
GRANT ALL ON ALL TABLES IN SCHEMA custom_facebrasil TO postgres;
GRANT ALL ON ALL SEQUENCES IN SCHEMA custom_facebrasil TO postgres;
GRANT ALL ON ALL ROUTINES IN SCHEMA custom_facebrasil TO postgres;

GRANT USAGE ON SCHEMA custom_facebrasil TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA custom_facebrasil TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA custom_facebrasil TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA custom_facebrasil TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA custom_facebrasil GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA custom_facebrasil GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA custom_facebrasil GRANT ALL ON ROUTINES TO anon, authenticated, service_role;

-- 3. Inserir evento pendente (FaceBrasil Expo 2026) com event_type valido
INSERT INTO custom_facebrasil.events (
  id, event_type, metadata, created_at, title, description, city, location, start_date, end_date, status, updated_at
) VALUES (
  '28462b98-dc06-406c-a87e-bcbef97b4d95',
  'EXPO',
  '{}'::jsonb,
  '2026-02-06 13:00:24.605144+00',
  'FaceBrasil Expo 2026',
  'Maior feira de negócios e cultura brasileira na Flórida.',
  'Orlando, FL',
  'Orange County Convention Center',
  '2026-02-20',
  NULL,
  'approved',
  '2026-02-06 13:00:24.605144+00'
) ON CONFLICT (id) DO NOTHING;

-- 4. Insercao segura dos usuarios restantes em auth.users
DO $$
DECLARE
    u RECORD;
    users_data jsonb := '[
      {"id": "3bcd8049-188e-4863-a4f0-a987c8c2c74c", "email": "marcoalevato@gmail.com", "role": "authenticated", "meta": {"role": "WRITER"}},
      {"id": "51bdb277-eb6d-40c5-8a14-5b4a05a2883d", "email": "info@facebrasil.com", "role": "authenticated", "pass": "$2a$10$uQLnHjEtNiH5EWZE1uIXOOOACArVp29V4M/IJXGoB9QHgwBDsOBky", "meta": {"full_name": "Redação Facebrasil"}},
      {"id": "203145c8-97f4-4d0b-960b-7cad7c0713c5", "email": "facebrasilmagazine@gmail.com", "role": "authenticated", "pass": "$2a$10$Lisqt96MBKsgoNEGPo.EH.QpHzleBLJGNYNuiMaODbYCcpcmAr30W", "meta": {"full_name": "Carlo Barbieri"}},
      {"id": "199af9cd-3933-4c6f-b228-1e0686b68acf", "email": "ssarkisrosa@gmail.com", "role": "authenticated", "pass": "$2a$10$7bsXXHAdWBFDME8yhaDKvOocrLC7O9mxxKsECuDmLW6P52ZJIMmjW", "meta": {"full_name": "Rosa Maria Sarkis"}},
      {"id": "3dca5353-63e4-45a7-b7c6-b6c324a75e33", "email": "alevato@me.com", "role": "authenticated", "pass": "$2a$10$Gfs3BPhI12vQ3PazinRZ6OfskKWWaPIgDPk.WqcGNEZME4Vzms9ru", "meta": {"full_name": "Marco Alevato"}},
      {"id": "6c7aee6a-3b11-4e40-9c91-bac4a58c952b", "email": "marcoalevato@yahoo.com", "role": "authenticated", "pass": "$2a$10$thxn0jKyP71EGHE8v8g9Tu1AToL8VhJFb13hfCxJkbDsVvjQ6KTF.", "meta": {"role": "VIEWER", "full_name": "Lilian T Alevato"}},
      {"id": "7e9d7d3e-7463-443c-9eec-2cce1d62b93e", "email": "lalevato@gnail.com", "role": "authenticated", "pass": "$2a$10$64XJe/zVS9gRV05vytuowOZArg7mGgsNqjTwFlFmmS03A5XIBugLu", "meta": {"full_name": "Lilian Alevato"}},
      {"id": "8117fe14-b5bb-49f6-985e-ed979da58b6f", "email": "sergiomvj@gmail.com", "role": "authenticated", "pass": "$2a$10$dfLK5635iAFwL0PxOLYhDOcfi8kZCP.ndOjGOnP241nTBullGYuRa", "meta": {"role": "EDITOR"}},
      {"id": "0f6b298b-cb0e-4c30-990e-cd01ce1ee989", "email": "marco@facebrasil.com", "role": "authenticated", "meta": {"role": "EDITOR"}},
      {"id": "89881a60-1b2a-4be0-82ce-668e6bb3c8d0", "email": "alevato@live.com", "role": "authenticated", "pass": "$2a$10$764oLMcNB4pf60JKYHsL.O8hUpzKsGcw15g99Qq2DHZn2AR86uOM.", "meta": {"full_name": "Marco Aurelio Alevato"}},
      {"id": "2de1b90d-5968-475b-820e-dbf19a9d97a3", "email": "lalevato@gmail.com", "role": "authenticated", "pass": "$2a$10$H2EYOyZlnBZo2aRy5/aAN.LJCt2e40nwnf5iIqe2F0SC9EFO/rMD2", "meta": {"full_name": "Lilian Alevato"}},
      {"id": "7b14838e-6309-4767-b76c-b4ba9615e803", "email": "sandromotta@hotmail.com", "role": "authenticated", "pass": "$2a$10$F2S0erhFU7ITJHDhWwcT6eIoQz6dkyowbcEZKazEZsTlezFx4LV9C", "meta": {"full_name": "Sandro Motta"}},
      {"id": "3fb1e4d3-a080-4d1f-8b64-122327400a1e", "email": "mari.hurtado@uol.com.br", "role": "authenticated", "pass": "$2a$10$F77ys/6wTPnWPSUEfh3f0ejjdVxFwyleDzJsdnvrBqqZ15ytNysGC", "meta": {"full_name": "Maristela Hurtado"}},
      {"id": "6921a966-fa02-40ed-94ae-242a313da1f5", "email": "antoniotozzi1954@gmail.com", "role": "authenticated", "pass": "$2a$10$XuiEU9QdPeOY9IbRcfFd2O36b/AR4tEBDo/yhIsXufgF0a/G6YJIO", "meta": {"full_name": "Antonio Tozzi"}},
      {"id": "00efca32-6c7d-4882-9c49-f7138726c122", "email": "barbieri@oxfordusa.com", "role": "authenticated", "pass": "$2a$10$NDK865rUFvvgpMtF.pNB..NvdEECaEa.KBvZoL6CJkKQShs/OhTH.", "meta": {"full_name": "Carlo Barbieri"}},
      {"id": "9596d0d9-a074-4439-ba71-c5f07400d02c", "email": "betofranca1956@gmail.com", "role": "authenticated", "pass": "$2a$10$7DWzrHPelcUx5bLsgWNmtO/y2pFknmOxYQKJroJoBMIMde2s9kyKq", "meta": {"full_name": "PAULO ROBERTO CAMINHA DE CASTILHOS FRANCA"}}
    ]'::jsonb;
BEGIN
    FOR u IN SELECT * FROM jsonb_to_recordset(users_data) AS x(id uuid, email text, role text, pass text, meta jsonb) LOOP
        IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = u.email) THEN
            INSERT INTO auth.users (
              instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
            ) VALUES (
              '00000000-0000-0000-0000-000000000000',
              u.id,
              'authenticated',
              'authenticated',
              u.email,
              COALESCE(u.pass, ''),
              now(),
              '{"provider": "email", "providers": ["email"]}'::jsonb,
              COALESCE(u.meta, '{}'::jsonb),
              now(),
              now()
            ) ON CONFLICT (id) DO NOTHING;

            INSERT INTO auth.identities (
              provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, id
            ) VALUES (
              u.id::text,
              u.id,
              jsonb_build_object('sub', u.id::text, 'email', u.email),
              'email',
              now(),
              now(),
              now(),
              extensions.uuid_generate_v4()
            ) ON CONFLICT (id) DO NOTHING;
        END IF;
    END LOOP;
END $$;

-- 5. Foreign Keys, Triggers, Indices e Politicas de Seguranca
-- =========================================================================
-- PASSO 6: CHAVES ESTRANGEIRAS, TRIGGERS, ÍNDICES E SEGURANÇA (RLS)
-- Execute este arquivo após concluir a importação de TODOS os dados (Passos 3, 4 e 5).
-- =========================================================================

SET search_path = custom_facebrasil, public, auth, extensions;

-- =========================================================================
-- 1. FOREIGN KEYS (CHAVES ESTRANGEIRAS ENTRE TABELAS)
-- =========================================================================
ALTER TABLE custom_facebrasil.ad_publications DROP CONSTRAINT IF EXISTS ad_publications_ad_id_fkey;
--
-- Name: ad_publications ad_publications_ad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.ad_publications
    ADD CONSTRAINT ad_publications_ad_id_fkey FOREIGN KEY (ad_id) REFERENCES custom_facebrasil.ads(id) ON DELETE CASCADE;

ALTER TABLE custom_facebrasil.ad_publications DROP CONSTRAINT IF EXISTS ad_publications_publication_id_fkey;
--
-- Name: ad_publications ad_publications_publication_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.ad_publications
    ADD CONSTRAINT ad_publications_publication_id_fkey FOREIGN KEY (publication_id) REFERENCES custom_facebrasil.publications(id) ON DELETE CASCADE;

ALTER TABLE custom_facebrasil.ads DROP CONSTRAINT IF EXISTS ads_category_id_fkey;
--
-- Name: ads ads_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.ads
    ADD CONSTRAINT ads_category_id_fkey FOREIGN KEY (category_id) REFERENCES custom_facebrasil.categories(id) ON DELETE SET NULL;

ALTER TABLE custom_facebrasil.article_favorites DROP CONSTRAINT IF EXISTS article_favorites_article_id_fkey;
--
-- Name: article_favorites article_favorites_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.article_favorites
    ADD CONSTRAINT article_favorites_article_id_fkey FOREIGN KEY (article_id) REFERENCES custom_facebrasil.articles(id) ON DELETE CASCADE;

ALTER TABLE custom_facebrasil.article_reads DROP CONSTRAINT IF EXISTS article_reads_article_id_fkey;
--
-- Name: article_reads article_reads_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.article_reads
    ADD CONSTRAINT article_reads_article_id_fkey FOREIGN KEY (article_id) REFERENCES custom_facebrasil.articles(id) ON DELETE CASCADE;

ALTER TABLE custom_facebrasil.articles DROP CONSTRAINT IF EXISTS articles_author_id_fkey;
--
-- Name: articles articles_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.articles
    ADD CONSTRAINT articles_author_id_fkey FOREIGN KEY (author_id) REFERENCES custom_facebrasil.profiles(id);

ALTER TABLE custom_facebrasil.articles DROP CONSTRAINT IF EXISTS articles_blog_id_fkey;
--
-- Name: articles articles_blog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.articles
    ADD CONSTRAINT articles_blog_id_fkey FOREIGN KEY (blog_id) REFERENCES custom_facebrasil.blogs(id);

ALTER TABLE custom_facebrasil.articles DROP CONSTRAINT IF EXISTS articles_category_id_fkey;
--
-- Name: articles articles_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.articles
    ADD CONSTRAINT articles_category_id_fkey FOREIGN KEY (category_id) REFERENCES custom_facebrasil.categories(id);

ALTER TABLE custom_facebrasil.articles DROP CONSTRAINT IF EXISTS articles_news_queue_id_fkey;
--
-- Name: articles articles_news_queue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.articles
    ADD CONSTRAINT articles_news_queue_id_fkey FOREIGN KEY (news_queue_id) REFERENCES custom_facebrasil.news_queue(id) ON DELETE SET NULL;

ALTER TABLE custom_facebrasil.blogs DROP CONSTRAINT IF EXISTS blogs_owner_id_fkey;
--
-- Name: blogs blogs_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.blogs
    ADD CONSTRAINT blogs_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES custom_facebrasil.profiles(id);

ALTER TABLE custom_facebrasil.categories DROP CONSTRAINT IF EXISTS categories_blog_id_fkey;
--
-- Name: categories categories_blog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.categories
    ADD CONSTRAINT categories_blog_id_fkey FOREIGN KEY (blog_id) REFERENCES custom_facebrasil.blogs(id);

ALTER TABLE custom_facebrasil.categories DROP CONSTRAINT IF EXISTS categories_parent_id_fkey;
--
-- Name: categories categories_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.categories
    ADD CONSTRAINT categories_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES custom_facebrasil.categories(id);

ALTER TABLE custom_facebrasil.news_queue DROP CONSTRAINT IF EXISTS news_queue_processed_article_id_fkey;
--
-- Name: news_queue news_queue_processed_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.news_queue
    ADD CONSTRAINT news_queue_processed_article_id_fkey FOREIGN KEY (processed_article_id) REFERENCES custom_facebrasil.articles(id) ON DELETE SET NULL;

ALTER TABLE custom_facebrasil.news_queue DROP CONSTRAINT IF EXISTS news_queue_source_id_fkey;
--
-- Name: news_queue news_queue_source_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.news_queue
    ADD CONSTRAINT news_queue_source_id_fkey FOREIGN KEY (source_id) REFERENCES custom_facebrasil.news_sources(id) ON DELETE CASCADE;

ALTER TABLE custom_facebrasil.news_usage DROP CONSTRAINT IF EXISTS news_usage_agent_id_fkey;
--
-- Name: news_usage news_usage_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.news_usage
    ADD CONSTRAINT news_usage_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES custom_facebrasil.virtual_agents(id) ON DELETE SET NULL;

ALTER TABLE custom_facebrasil.news_usage DROP CONSTRAINT IF EXISTS news_usage_news_id_fkey;
--
-- Name: news_usage news_usage_news_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.news_usage
    ADD CONSTRAINT news_usage_news_id_fkey FOREIGN KEY (news_id) REFERENCES custom_facebrasil.captured_news(id) ON DELETE CASCADE;

ALTER TABLE custom_facebrasil.partner_offers DROP CONSTRAINT IF EXISTS partner_offers_partner_id_fkey;
--
-- Name: partner_offers partner_offers_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.partner_offers
    ADD CONSTRAINT partner_offers_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES custom_facebrasil.partners(id) ON DELETE CASCADE;

ALTER TABLE custom_facebrasil.user_activities DROP CONSTRAINT IF EXISTS user_activities_article_id_fkey;
--
-- Name: user_activities user_activities_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.user_activities
    ADD CONSTRAINT user_activities_article_id_fkey FOREIGN KEY (article_id) REFERENCES custom_facebrasil.articles(id) ON DELETE CASCADE;

ALTER TABLE custom_facebrasil.user_badges DROP CONSTRAINT IF EXISTS user_badges_badge_id_fkey;
--
-- Name: user_badges user_badges_badge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.user_badges
    ADD CONSTRAINT user_badges_badge_id_fkey FOREIGN KEY (badge_id) REFERENCES custom_facebrasil.badges(id) ON DELETE CASCADE;

ALTER TABLE custom_facebrasil.user_challenges DROP CONSTRAINT IF EXISTS user_challenges_challenge_id_fkey;
--
-- Name: user_challenges user_challenges_challenge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.user_challenges
    ADD CONSTRAINT user_challenges_challenge_id_fkey FOREIGN KEY (challenge_id) REFERENCES custom_facebrasil.challenges(id) ON DELETE CASCADE;

ALTER TABLE custom_facebrasil.user_challenges DROP CONSTRAINT IF EXISTS user_challenges_user_id_fkey;
--
-- Name: user_challenges user_challenges_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.user_challenges
    ADD CONSTRAINT user_challenges_user_id_fkey FOREIGN KEY (user_id) REFERENCES custom_facebrasil.profiles(id) ON DELETE CASCADE;

ALTER TABLE custom_facebrasil.user_collection_items DROP CONSTRAINT IF EXISTS user_collection_items_article_id_fkey;
--
-- Name: user_collection_items user_collection_items_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.user_collection_items
    ADD CONSTRAINT user_collection_items_article_id_fkey FOREIGN KEY (article_id) REFERENCES custom_facebrasil.articles(id) ON DELETE CASCADE;

ALTER TABLE custom_facebrasil.user_collection_items DROP CONSTRAINT IF EXISTS user_collection_items_collection_id_fkey;
--
-- Name: user_collection_items user_collection_items_collection_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.user_collection_items
    ADD CONSTRAINT user_collection_items_collection_id_fkey FOREIGN KEY (collection_id) REFERENCES custom_facebrasil.user_collections(id) ON DELETE CASCADE;

ALTER TABLE custom_facebrasil.user_collections DROP CONSTRAINT IF EXISTS user_collections_user_id_fkey;
--
-- Name: user_collections user_collections_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.user_collections
    ADD CONSTRAINT user_collections_user_id_fkey FOREIGN KEY (user_id) REFERENCES custom_facebrasil.profiles(id) ON DELETE CASCADE;

ALTER TABLE custom_facebrasil.user_video_reports DROP CONSTRAINT IF EXISTS user_video_reports_user_id_fkey;
--
-- Name: user_video_reports user_video_reports_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.user_video_reports
    ADD CONSTRAINT user_video_reports_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);

ALTER TABLE custom_facebrasil.waterfall_posts DROP CONSTRAINT IF EXISTS waterfall_posts_session_id_fkey;
--
-- Name: waterfall_posts waterfall_posts_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.waterfall_posts
    ADD CONSTRAINT waterfall_posts_session_id_fkey FOREIGN KEY (session_id) REFERENCES custom_facebrasil.waterfall_sessions(id) ON DELETE CASCADE;

ALTER TABLE custom_facebrasil.waterfall_sessions DROP CONSTRAINT IF EXISTS waterfall_sessions_article_id_fkey;
--
-- Name: waterfall_sessions waterfall_sessions_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY custom_facebrasil.waterfall_sessions
    ADD CONSTRAINT waterfall_sessions_article_id_fkey FOREIGN KEY (article_id) REFERENCES custom_facebrasil.articles(id) ON DELETE CASCADE;


-- =========================================================================
-- 2. TRIGGERS AUTOMÁTICOS
-- =========================================================================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION custom_facebrasil.handle_new_user();

DROP TRIGGER IF EXISTS tr_ensure_profile ON custom_facebrasil.articles;
CREATE TRIGGER tr_ensure_profile BEFORE INSERT OR UPDATE ON custom_facebrasil.articles FOR EACH ROW EXECUTE FUNCTION custom_facebrasil.ensure_profile_exists();

DROP TRIGGER IF EXISTS trigger_events_updated_at ON custom_facebrasil.events;
CREATE TRIGGER trigger_events_updated_at BEFORE UPDATE ON custom_facebrasil.events FOR EACH ROW EXECUTE FUNCTION custom_facebrasil.update_events_updated_at();

DROP TRIGGER IF EXISTS trigger_hero_timestamp ON custom_facebrasil.articles;
CREATE TRIGGER trigger_hero_timestamp BEFORE INSERT OR UPDATE ON custom_facebrasil.articles FOR EACH ROW WHEN ((new.colocar_hero = true)) EXECUTE FUNCTION custom_facebrasil.set_hero_timestamp();

DROP TRIGGER IF EXISTS trigger_update_reputation ON custom_facebrasil.user_activities;
CREATE TRIGGER trigger_update_reputation AFTER INSERT ON custom_facebrasil.user_activities FOR EACH ROW EXECUTE FUNCTION custom_facebrasil.update_user_reputation();

DROP TRIGGER IF EXISTS trigger_user_reputation_updated_at ON custom_facebrasil.user_reputation;
CREATE TRIGGER trigger_user_reputation_updated_at BEFORE UPDATE ON custom_facebrasil.user_reputation FOR EACH ROW EXECUTE FUNCTION custom_facebrasil.update_updated_at_timestamp();

DROP TRIGGER IF EXISTS update_news_sources_updated_at ON custom_facebrasil.news_sources;
CREATE TRIGGER update_news_sources_updated_at BEFORE UPDATE ON custom_facebrasil.news_sources FOR EACH ROW EXECUTE FUNCTION custom_facebrasil.update_updated_at_column();

DROP TRIGGER IF EXISTS waterfall_sessions_updated_at ON custom_facebrasil.waterfall_sessions;
CREATE TRIGGER waterfall_sessions_updated_at BEFORE UPDATE ON custom_facebrasil.waterfall_sessions FOR EACH ROW EXECUTE FUNCTION custom_facebrasil.set_updated_at();


-- =========================================================================
-- 3. ÍNDICES DE ALTA PERFORMANCE
-- =========================================================================
--
-- Name: idx_ads_active_position; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_ads_active_position ON custom_facebrasil.ads USING btree ("position", is_active) WHERE (is_active = true);

--
-- Name: idx_article_favorites_article; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_article_favorites_article ON custom_facebrasil.article_favorites USING btree (article_id);

--
-- Name: idx_article_favorites_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_article_favorites_user ON custom_facebrasil.article_favorites USING btree (user_id);

--
-- Name: idx_article_reads_article_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_article_reads_article_id ON custom_facebrasil.article_reads USING btree (article_id);

--
-- Name: idx_article_reads_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_article_reads_created_at ON custom_facebrasil.article_reads USING btree (created_at);

--
-- Name: idx_article_reads_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_article_reads_user_id ON custom_facebrasil.article_reads USING btree (user_id);

--
-- Name: idx_articles_language; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_articles_language ON custom_facebrasil.articles USING btree (language);

--
-- Name: idx_articles_news_queue; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_articles_news_queue ON custom_facebrasil.articles USING btree (news_queue_id);

--
-- Name: idx_articles_sent_to_tv; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_articles_sent_to_tv ON custom_facebrasil.articles USING btree (sent_to_tv, published_at DESC);

--
-- Name: idx_articles_source_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_articles_source_type ON custom_facebrasil.articles USING btree (source_type);

--
-- Name: idx_articles_translation_group_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_articles_translation_group_id ON custom_facebrasil.articles USING btree (translation_group_id);

--
-- Name: idx_badges_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_badges_active ON custom_facebrasil.badges USING btree (active) WHERE (active = true);

--
-- Name: idx_badges_rarity; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_badges_rarity ON custom_facebrasil.badges USING btree (rarity);

--
-- Name: idx_events_city; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_events_city ON custom_facebrasil.events USING btree (city);

--
-- Name: idx_events_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_events_date ON custom_facebrasil.events USING btree (event_date DESC);

--
-- Name: idx_events_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_events_status ON custom_facebrasil.events USING btree (status);

--
-- Name: idx_events_submitted_by; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_events_submitted_by ON custom_facebrasil.events USING btree (submitted_by);

--
-- Name: idx_instagram_events_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_instagram_events_created ON custom_facebrasil.instagram_events USING btree (created_at DESC);

--
-- Name: idx_instagram_events_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_instagram_events_type ON custom_facebrasil.instagram_events USING btree (event_type);

--
-- Name: idx_news_queue_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_news_queue_created ON custom_facebrasil.news_queue USING btree (created_at DESC);

--
-- Name: idx_news_queue_source; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_news_queue_source ON custom_facebrasil.news_queue USING btree (source_id);

--
-- Name: idx_news_queue_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_news_queue_status ON custom_facebrasil.news_queue USING btree (status);

--
-- Name: idx_news_queue_url; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_news_queue_url ON custom_facebrasil.news_queue USING btree (original_url);

--
-- Name: idx_news_sources_enabled; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_news_sources_enabled ON custom_facebrasil.news_sources USING btree (enabled) WHERE (enabled = true);

--
-- Name: idx_news_sources_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_news_sources_type ON custom_facebrasil.news_sources USING btree (type);

--
-- Name: idx_static_pages_slug_lang; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_static_pages_slug_lang ON custom_facebrasil.static_pages USING btree (slug, language);

--
-- Name: idx_user_activities_article; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_user_activities_article ON custom_facebrasil.user_activities USING btree (article_id);

--
-- Name: idx_user_activities_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_user_activities_created ON custom_facebrasil.user_activities USING btree (created_at DESC);

--
-- Name: idx_user_activities_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_user_activities_type ON custom_facebrasil.user_activities USING btree (activity_type);

--
-- Name: idx_user_activities_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_user_activities_user_id ON custom_facebrasil.user_activities USING btree (user_id);

--
-- Name: idx_user_activities_validated; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_user_activities_validated ON custom_facebrasil.user_activities USING btree (validated) WHERE (validated = true);

--
-- Name: idx_user_badges_badge_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_user_badges_badge_id ON custom_facebrasil.user_badges USING btree (badge_id);

--
-- Name: idx_user_badges_earned; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_user_badges_earned ON custom_facebrasil.user_badges USING btree (earned_at DESC);

--
-- Name: idx_user_badges_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_user_badges_user_id ON custom_facebrasil.user_badges USING btree (user_id);

--
-- Name: idx_user_reputation_level; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_user_reputation_level ON custom_facebrasil.user_reputation USING btree (level);

--
-- Name: idx_user_reputation_total_points; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_user_reputation_total_points ON custom_facebrasil.user_reputation USING btree (total_points DESC);

--
-- Name: idx_user_reputation_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_user_reputation_user_id ON custom_facebrasil.user_reputation USING btree (user_id);

--
-- Name: idx_user_reputation_weekly_points; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_user_reputation_weekly_points ON custom_facebrasil.user_reputation USING btree (weekly_points DESC);

--
-- Name: idx_waterfall_posts_session; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_waterfall_posts_session ON custom_facebrasil.waterfall_posts USING btree (session_id);

--
-- Name: idx_waterfall_sessions_article; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX IF NOT EXISTS idx_waterfall_sessions_article ON custom_facebrasil.waterfall_sessions USING btree (article_id, created_at DESC);


-- =========================================================================
-- 4. ROW LEVEL SECURITY (RLS) E POLÍTICAS DE ACESSO
-- =========================================================================
--
-- Name: static_pages Admin write static_pages; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Admin write static_pages" ON custom_facebrasil.static_pages USING (true);

--
-- Name: articles Admins full access; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Admins full access" ON custom_facebrasil.articles USING (true);

--
-- Name: profiles Admins full access profiles; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Admins full access profiles" ON custom_facebrasil.profiles USING (true);

--
-- Name: article_reads Allow anonymous insert article_reads; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow anonymous insert article_reads" ON custom_facebrasil.article_reads FOR INSERT TO authenticated, anon WITH CHECK (true);

--
-- Name: events Allow authenticated delete events; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated delete events" ON custom_facebrasil.events FOR DELETE TO authenticated USING (true);

--
-- Name: categories Allow authenticated delete from categories; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated delete from categories" ON custom_facebrasil.categories FOR DELETE TO authenticated USING (true);

--
-- Name: partner_offers Allow authenticated full access to partner_offers; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated full access to partner_offers" ON custom_facebrasil.partner_offers TO authenticated USING (true);

--
-- Name: partners Allow authenticated full access to partners; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated full access to partners" ON custom_facebrasil.partners TO authenticated USING (true);

--
-- Name: events Allow authenticated insert events; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated insert events" ON custom_facebrasil.events FOR INSERT TO authenticated WITH CHECK (true);

--
-- Name: categories Allow authenticated insert to categories; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated insert to categories" ON custom_facebrasil.categories FOR INSERT TO authenticated WITH CHECK (true);

--
-- Name: ads Allow authenticated manage ads; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated manage ads" ON custom_facebrasil.ads TO authenticated USING (true) WITH CHECK (true);

--
-- Name: blogs Allow authenticated manage blogs; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated manage blogs" ON custom_facebrasil.blogs TO authenticated USING (true) WITH CHECK (true);

--
-- Name: challenges Allow authenticated manage challenges; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated manage challenges" ON custom_facebrasil.challenges TO authenticated USING (true) WITH CHECK (true);

--
-- Name: user_video_reports Allow authenticated manage user_video_reports; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated manage user_video_reports" ON custom_facebrasil.user_video_reports TO authenticated USING (true) WITH CHECK (true);

--
-- Name: xp_logs Allow authenticated read xp_logs; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated read xp_logs" ON custom_facebrasil.xp_logs FOR SELECT TO authenticated USING (true);

--
-- Name: article_reads Allow authenticated select own reads; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated select own reads" ON custom_facebrasil.article_reads FOR SELECT TO authenticated USING (((auth.uid())::text = user_id));

--
-- Name: events Allow authenticated update events; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated update events" ON custom_facebrasil.events FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

--
-- Name: profiles Allow authenticated update own profile; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated update own profile" ON custom_facebrasil.profiles FOR UPDATE TO authenticated USING (((auth.uid())::text = id)) WITH CHECK (((auth.uid())::text = id));

--
-- Name: categories Allow authenticated update to categories; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated update to categories" ON custom_facebrasil.categories FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

--
-- Name: articles Allow authenticated write articles; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated write articles" ON custom_facebrasil.articles TO authenticated USING (true) WITH CHECK (true);

--
-- Name: categories Allow public read access to categories; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public read access to categories" ON custom_facebrasil.categories FOR SELECT USING (true);

--
-- Name: partner_offers Allow public read access to partner_offers; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public read access to partner_offers" ON custom_facebrasil.partner_offers FOR SELECT USING (true);

--
-- Name: partners Allow public read access to partners; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public read access to partners" ON custom_facebrasil.partners FOR SELECT USING (true);

--
-- Name: ads Allow public read ads; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public read ads" ON custom_facebrasil.ads FOR SELECT USING (true);

--
-- Name: blogs Allow public read blogs; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public read blogs" ON custom_facebrasil.blogs FOR SELECT USING (true);

--
-- Name: categories Allow public read categories; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public read categories" ON custom_facebrasil.categories FOR SELECT USING (true);

--
-- Name: events Allow public read events; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow public read events" ON custom_facebrasil.events FOR SELECT USING (true);

--
-- Name: article_reads Allow service_role all article_reads; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow service_role all article_reads" ON custom_facebrasil.article_reads TO service_role USING (true);

--
-- Name: partner_offers Allow service_role full access to partner_offers; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow service_role full access to partner_offers" ON custom_facebrasil.partner_offers TO service_role USING (true);

--
-- Name: partners Allow service_role full access to partners; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow service_role full access to partners" ON custom_facebrasil.partners TO service_role USING (true);

--
-- Name: xp_logs Allow service_role manage xp_logs; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow service_role manage xp_logs" ON custom_facebrasil.xp_logs TO service_role USING (true) WITH CHECK (true);

--
-- Name: article_reads Allow staff select all article_reads; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow staff select all article_reads" ON custom_facebrasil.article_reads FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM custom_facebrasil.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = ANY (ARRAY['ADMIN'::text, 'EDITOR'::text]))))));

--
-- Name: captured_news Enable delete for authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable delete for authenticated users" ON custom_facebrasil.captured_news FOR DELETE TO authenticated USING (true);

--
-- Name: news_usage Enable delete for authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable delete for authenticated users" ON custom_facebrasil.news_usage FOR DELETE TO authenticated USING (true);

--
-- Name: virtual_agents Enable delete for authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable delete for authenticated users" ON custom_facebrasil.virtual_agents FOR DELETE TO authenticated USING (true);

--
-- Name: captured_news Enable insert for authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable insert for authenticated users" ON custom_facebrasil.captured_news FOR INSERT TO authenticated WITH CHECK (true);

--
-- Name: news_usage Enable insert for authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable insert for authenticated users" ON custom_facebrasil.news_usage FOR INSERT TO authenticated WITH CHECK (true);

--
-- Name: virtual_agents Enable insert for authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable insert for authenticated users" ON custom_facebrasil.virtual_agents FOR INSERT TO authenticated WITH CHECK (true);

--
-- Name: captured_news Enable read access for all authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable read access for all authenticated users" ON custom_facebrasil.captured_news FOR SELECT TO authenticated USING (true);

--
-- Name: news_usage Enable read access for all authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable read access for all authenticated users" ON custom_facebrasil.news_usage FOR SELECT TO authenticated USING (true);

--
-- Name: virtual_agents Enable read access for all authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable read access for all authenticated users" ON custom_facebrasil.virtual_agents FOR SELECT TO authenticated USING (true);

--
-- Name: captured_news Enable update for authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable update for authenticated users" ON custom_facebrasil.captured_news FOR UPDATE TO authenticated USING (true);

--
-- Name: news_usage Enable update for authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable update for authenticated users" ON custom_facebrasil.news_usage FOR UPDATE TO authenticated USING (true);

--
-- Name: virtual_agents Enable update for authenticated users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable update for authenticated users" ON custom_facebrasil.virtual_agents FOR UPDATE TO authenticated USING (true);

--
-- Name: articles Public Read Articles; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Public Read Articles" ON custom_facebrasil.articles FOR SELECT USING (true);

--
-- Name: profiles Public Read Profiles; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Public Read Profiles" ON custom_facebrasil.profiles FOR SELECT USING (true);

--
-- Name: article_favorites Public can count favorites; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Public can count favorites" ON custom_facebrasil.article_favorites FOR SELECT TO authenticated, anon USING (true);

--
-- Name: challenges Public challenges are viewable by everyone; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Public challenges are viewable by everyone" ON custom_facebrasil.challenges FOR SELECT USING (true);

--
-- Name: static_pages Public read static_pages; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Public read static_pages" ON custom_facebrasil.static_pages FOR SELECT USING (true);

--
-- Name: user_collection_items Users can add items to their own collections; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can add items to their own collections" ON custom_facebrasil.user_collection_items FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM custom_facebrasil.user_collections
  WHERE ((user_collections.id = user_collection_items.collection_id) AND (user_collections.user_id = (auth.uid())::text)))));

--
-- Name: user_collections Users can create their own collections; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can create their own collections" ON custom_facebrasil.user_collections FOR INSERT WITH CHECK (((auth.uid())::text = user_id));

--
-- Name: user_collections Users can delete their own collections; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can delete their own collections" ON custom_facebrasil.user_collections FOR DELETE USING (((auth.uid())::text = user_id));

--
-- Name: user_collection_items Users can remove items from their own collections; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can remove items from their own collections" ON custom_facebrasil.user_collection_items FOR DELETE USING ((EXISTS ( SELECT 1
   FROM custom_facebrasil.user_collections
  WHERE ((user_collections.id = user_collection_items.collection_id) AND (user_collections.user_id = (auth.uid())::text)))));

--
-- Name: user_challenges Users can update their own challenge progress; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can update their own challenge progress" ON custom_facebrasil.user_challenges FOR UPDATE USING (((auth.uid())::text = user_id));

--
-- Name: user_collections Users can update their own collections; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can update their own collections" ON custom_facebrasil.user_collections FOR UPDATE USING (((auth.uid())::text = user_id));

--
-- Name: user_challenges Users can view their own challenge progress; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can view their own challenge progress" ON custom_facebrasil.user_challenges FOR SELECT USING (((auth.uid())::text = user_id));

--
-- Name: user_collection_items Users can view their own collection items; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can view their own collection items" ON custom_facebrasil.user_collection_items FOR SELECT USING ((EXISTS ( SELECT 1
   FROM custom_facebrasil.user_collections
  WHERE ((user_collections.id = user_collection_items.collection_id) AND (user_collections.user_id = (auth.uid())::text)))));

--
-- Name: user_collections Users can view their own collections; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can view their own collections" ON custom_facebrasil.user_collections FOR SELECT USING (((auth.uid())::text = user_id));

--
-- Name: article_favorites Users manage own favorites; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users manage own favorites" ON custom_facebrasil.article_favorites TO authenticated USING (((auth.uid())::text = user_id)) WITH CHECK (((auth.uid())::text = user_id));

--
-- Name: ads; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.ads ENABLE ROW LEVEL SECURITY;

--
-- Name: ads ads_select_public; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY ads_select_public ON custom_facebrasil.ads FOR SELECT USING (true);

--
-- Name: ads ads_write_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY ads_write_admin ON custom_facebrasil.ads USING ((EXISTS ( SELECT 1
   FROM custom_facebrasil.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = 'ADMIN'::text)))));

--
-- Name: article_favorites; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.article_favorites ENABLE ROW LEVEL SECURITY;

--
-- Name: article_reads; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.article_reads ENABLE ROW LEVEL SECURITY;

--
-- Name: articles; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.articles ENABLE ROW LEVEL SECURITY;

--
-- Name: articles articles_select_published; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY articles_select_published ON custom_facebrasil.articles FOR SELECT USING ((status = ANY (ARRAY['PUBLISHED'::text, 'published'::text])));

--
-- Name: articles articles_select_staff; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY articles_select_staff ON custom_facebrasil.articles FOR SELECT USING ((EXISTS ( SELECT 1
   FROM custom_facebrasil.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = ANY (ARRAY['ADMIN'::text, 'EDITOR'::text]))))));

--
-- Name: articles articles_write_staff; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY articles_write_staff ON custom_facebrasil.articles USING ((EXISTS ( SELECT 1
   FROM custom_facebrasil.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = ANY (ARRAY['ADMIN'::text, 'EDITOR'::text]))))));

--
-- Name: badges; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.badges ENABLE ROW LEVEL SECURITY;

--
-- Name: badges badges_select_public; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY badges_select_public ON custom_facebrasil.badges FOR SELECT USING (true);

--
-- Name: badges badges_write_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY badges_write_admin ON custom_facebrasil.badges USING ((EXISTS ( SELECT 1
   FROM custom_facebrasil.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = 'ADMIN'::text)))));

--
-- Name: blogs; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.blogs ENABLE ROW LEVEL SECURITY;

--
-- Name: blogs blogs_select_public; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY blogs_select_public ON custom_facebrasil.blogs FOR SELECT USING (true);

--
-- Name: blogs blogs_write_owner_or_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY blogs_write_owner_or_admin ON custom_facebrasil.blogs USING (((owner_id = (auth.uid())::text) OR (EXISTS ( SELECT 1
   FROM custom_facebrasil.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = 'ADMIN'::text))))));

--
-- Name: captured_news; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.captured_news ENABLE ROW LEVEL SECURITY;

--
-- Name: categories; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.categories ENABLE ROW LEVEL SECURITY;

--
-- Name: categories categories_select_public; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY categories_select_public ON custom_facebrasil.categories FOR SELECT USING (true);

--
-- Name: categories categories_write_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY categories_write_admin ON custom_facebrasil.categories USING ((EXISTS ( SELECT 1
   FROM custom_facebrasil.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = 'ADMIN'::text)))));

--
-- Name: challenges; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.challenges ENABLE ROW LEVEL SECURITY;

--
-- Name: events; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.events ENABLE ROW LEVEL SECURITY;

--
-- Name: events events_all_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY events_all_admin ON custom_facebrasil.events USING ((EXISTS ( SELECT 1
   FROM custom_facebrasil.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = 'ADMIN'::text)))));

--
-- Name: events events_insert_public; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY events_insert_public ON custom_facebrasil.events FOR INSERT WITH CHECK (true);

--
-- Name: events events_select_approved; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY events_select_approved ON custom_facebrasil.events FOR SELECT USING ((status = 'approved'::text));

--
-- Name: instagram_events; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.instagram_events ENABLE ROW LEVEL SECURITY;

--
-- Name: instagram_events instagram_events_read_auth; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY instagram_events_read_auth ON custom_facebrasil.instagram_events FOR SELECT USING ((auth.role() = 'authenticated'::text));

--
-- Name: instagram_events instagram_events_service_write; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY instagram_events_service_write ON custom_facebrasil.instagram_events FOR INSERT WITH CHECK (true);

--
-- Name: news_queue; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.news_queue ENABLE ROW LEVEL SECURITY;

--
-- Name: news_queue news_queue_staff_only; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY news_queue_staff_only ON custom_facebrasil.news_queue USING ((EXISTS ( SELECT 1
   FROM custom_facebrasil.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = ANY (ARRAY['ADMIN'::text, 'EDITOR'::text]))))));

--
-- Name: news_sources; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.news_sources ENABLE ROW LEVEL SECURITY;

--
-- Name: news_sources news_sources_admin_only; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY news_sources_admin_only ON custom_facebrasil.news_sources USING ((EXISTS ( SELECT 1
   FROM custom_facebrasil.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = 'ADMIN'::text)))));

--
-- Name: news_usage; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.news_usage ENABLE ROW LEVEL SECURITY;

--
-- Name: partner_offers; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.partner_offers ENABLE ROW LEVEL SECURITY;

--
-- Name: partners; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.partners ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles profiles_insert_own; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY profiles_insert_own ON custom_facebrasil.profiles FOR INSERT WITH CHECK (((auth.uid())::text = id));

--
-- Name: profiles profiles_select_public; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY profiles_select_public ON custom_facebrasil.profiles FOR SELECT USING (true);

--
-- Name: profiles profiles_update_own; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY profiles_update_own ON custom_facebrasil.profiles FOR UPDATE USING (((auth.uid())::text = id));

--
-- Name: social_credentials; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.social_credentials ENABLE ROW LEVEL SECURITY;

--
-- Name: social_credentials social_creds_auth; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY social_creds_auth ON custom_facebrasil.social_credentials USING ((auth.role() = 'authenticated'::text));

--
-- Name: static_pages; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.static_pages ENABLE ROW LEVEL SECURITY;

--
-- Name: static_pages static_pages_select_public; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY static_pages_select_public ON custom_facebrasil.static_pages FOR SELECT USING (true);

--
-- Name: static_pages static_pages_write_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY static_pages_write_admin ON custom_facebrasil.static_pages USING ((EXISTS ( SELECT 1
   FROM custom_facebrasil.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = 'ADMIN'::text)))));

--
-- Name: user_activities; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.user_activities ENABLE ROW LEVEL SECURITY;

--
-- Name: user_activities user_activities_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY user_activities_admin ON custom_facebrasil.user_activities USING ((EXISTS ( SELECT 1
   FROM custom_facebrasil.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = 'ADMIN'::text)))));

--
-- Name: user_activities user_activities_insert_auth; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY user_activities_insert_auth ON custom_facebrasil.user_activities FOR INSERT WITH CHECK ((auth.uid() IS NOT NULL));

--
-- Name: user_activities user_activities_own; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY user_activities_own ON custom_facebrasil.user_activities FOR SELECT USING ((user_id = (auth.uid())::text));

--
-- Name: user_badges; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.user_badges ENABLE ROW LEVEL SECURITY;

--
-- Name: user_badges user_badges_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY user_badges_admin ON custom_facebrasil.user_badges USING ((EXISTS ( SELECT 1
   FROM custom_facebrasil.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = 'ADMIN'::text)))));

--
-- Name: user_badges user_badges_select_public; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY user_badges_select_public ON custom_facebrasil.user_badges FOR SELECT USING (true);

--
-- Name: user_challenges; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.user_challenges ENABLE ROW LEVEL SECURITY;

--
-- Name: user_collection_items; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.user_collection_items ENABLE ROW LEVEL SECURITY;

--
-- Name: user_collections; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.user_collections ENABLE ROW LEVEL SECURITY;

--
-- Name: user_reputation; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.user_reputation ENABLE ROW LEVEL SECURITY;

--
-- Name: user_reputation user_reputation_own_update; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY user_reputation_own_update ON custom_facebrasil.user_reputation FOR UPDATE USING ((user_id = (auth.uid())::text));

--
-- Name: user_reputation user_reputation_select_public; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY user_reputation_select_public ON custom_facebrasil.user_reputation FOR SELECT USING (true);

--
-- Name: user_video_reports; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.user_video_reports ENABLE ROW LEVEL SECURITY;

--
-- Name: user_video_reports uvr_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY uvr_admin ON custom_facebrasil.user_video_reports USING ((EXISTS ( SELECT 1
   FROM custom_facebrasil.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = 'ADMIN'::text)))));

--
-- Name: user_video_reports uvr_insert_auth; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY uvr_insert_auth ON custom_facebrasil.user_video_reports FOR INSERT WITH CHECK ((auth.uid() IS NOT NULL));

--
-- Name: user_video_reports uvr_select_approved; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY uvr_select_approved ON custom_facebrasil.user_video_reports FOR SELECT USING ((status = 'APPROVED'::text));

--
-- Name: virtual_agents; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.virtual_agents ENABLE ROW LEVEL SECURITY;

--
-- Name: waterfall_posts; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.waterfall_posts ENABLE ROW LEVEL SECURITY;

--
-- Name: waterfall_posts waterfall_posts_auth; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY waterfall_posts_auth ON custom_facebrasil.waterfall_posts USING ((auth.role() = 'authenticated'::text));

--
-- Name: waterfall_sessions waterfall_read_auth; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY waterfall_read_auth ON custom_facebrasil.waterfall_sessions FOR SELECT USING ((auth.role() = 'authenticated'::text));

--
-- Name: waterfall_sessions; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.waterfall_sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: waterfall_sessions waterfall_write_auth; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY waterfall_write_auth ON custom_facebrasil.waterfall_sessions USING ((auth.role() = 'authenticated'::text));

--
-- Name: xp_logs; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE custom_facebrasil.xp_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: xp_logs xp_logs_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY xp_logs_admin ON custom_facebrasil.xp_logs USING ((EXISTS ( SELECT 1
   FROM custom_facebrasil.profiles
  WHERE ((profiles.id = (auth.uid())::text) AND (profiles.role = 'ADMIN'::text)))));

--
-- Name: xp_logs xp_logs_own; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY xp_logs_own ON custom_facebrasil.xp_logs FOR SELECT USING ((user_id = (auth.uid())::text));


-- =========================================================================
-- 5. PERMISSÕES FINAIS (GRANTS)
-- =========================================================================
GRANT ALL ON ALL TABLES IN SCHEMA custom_facebrasil TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA custom_facebrasil TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA custom_facebrasil TO anon, authenticated, service_role;


DO $$
BEGIN
  RAISE NOTICE '=========================================================';
  RAISE NOTICE 'PROPRIEDADES, REGRAS E FOREIGN KEYS 100% APLICADAS!';
  RAISE NOTICE '=========================================================';
END $$;
