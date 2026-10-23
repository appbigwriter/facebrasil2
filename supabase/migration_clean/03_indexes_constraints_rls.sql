

ALTER TABLE public.user_activities OWNER TO postgres;



ALTER TABLE public.ad_publications OWNER TO postgres;



ALTER TABLE public.ads OWNER TO postgres;



ALTER TABLE public.article_favorites OWNER TO postgres;



ALTER TABLE public.article_reads OWNER TO postgres;



ALTER TABLE public.articles OWNER TO postgres;



ALTER TABLE public.badges OWNER TO postgres;



ALTER TABLE public.user_badges OWNER TO postgres;



ALTER TABLE public.blogs OWNER TO postgres;



ALTER TABLE public.captured_news OWNER TO postgres;



ALTER TABLE public.categories OWNER TO postgres;



ALTER TABLE public.challenges OWNER TO postgres;



ALTER TABLE public.events OWNER TO postgres;



ALTER TABLE public.instagram_events OWNER TO postgres;



ALTER TABLE public.user_reputation OWNER TO postgres;



ALTER TABLE public.news_queue OWNER TO postgres;



ALTER TABLE public.news_sources OWNER TO postgres;



ALTER TABLE public.news_usage OWNER TO postgres;



ALTER TABLE public.partner_offers OWNER TO postgres;



ALTER TABLE public.partners OWNER TO postgres;



ALTER TABLE public.profiles OWNER TO postgres;



ALTER TABLE public.publications OWNER TO postgres;



ALTER TABLE public.site_settings OWNER TO postgres;



ALTER TABLE public.social_credentials OWNER TO postgres;



ALTER TABLE public.static_pages OWNER TO postgres;



ALTER TABLE public.user_challenges OWNER TO postgres;



ALTER TABLE public.user_collection_items OWNER TO postgres;



ALTER TABLE public.user_collections OWNER TO postgres;



ALTER TABLE public.user_video_reports OWNER TO postgres;



ALTER TABLE public.virtual_agents OWNER TO postgres;



ALTER TABLE public.waterfall_posts OWNER TO postgres;



ALTER TABLE public.waterfall_sessions OWNER TO postgres;



ALTER TABLE public.xp_logs OWNER TO postgres;



--
-- Name: TABLE user_activities; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.user_activities TO anon;

GRANT ALL ON TABLE public.user_activities TO authenticated;

GRANT ALL ON TABLE public.user_activities TO service_role;



--
-- Name: TABLE ad_publications; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.ad_publications TO anon;

GRANT ALL ON TABLE public.ad_publications TO authenticated;

GRANT ALL ON TABLE public.ad_publications TO service_role;



--
-- Name: TABLE ads; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.ads TO anon;

GRANT ALL ON TABLE public.ads TO authenticated;

GRANT ALL ON TABLE public.ads TO service_role;



--
-- Name: TABLE article_favorites; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.article_favorites TO anon;

GRANT ALL ON TABLE public.article_favorites TO authenticated;

GRANT ALL ON TABLE public.article_favorites TO service_role;



--
-- Name: TABLE article_reads; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.article_reads TO anon;

GRANT ALL ON TABLE public.article_reads TO authenticated;

GRANT ALL ON TABLE public.article_reads TO service_role;



--
-- Name: TABLE articles; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.articles TO anon;

GRANT ALL ON TABLE public.articles TO authenticated;

GRANT ALL ON TABLE public.articles TO service_role;



--
-- Name: TABLE badges; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.badges TO anon;

GRANT ALL ON TABLE public.badges TO authenticated;

GRANT ALL ON TABLE public.badges TO service_role;



--
-- Name: TABLE user_badges; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.user_badges TO anon;

GRANT ALL ON TABLE public.user_badges TO authenticated;

GRANT ALL ON TABLE public.user_badges TO service_role;



--
-- Name: TABLE blogs; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.blogs TO anon;

GRANT ALL ON TABLE public.blogs TO authenticated;

GRANT ALL ON TABLE public.blogs TO service_role;



--
-- Name: TABLE captured_news; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.captured_news TO anon;

GRANT ALL ON TABLE public.captured_news TO authenticated;

GRANT ALL ON TABLE public.captured_news TO service_role;



--
-- Name: TABLE categories; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.categories TO anon;

GRANT ALL ON TABLE public.categories TO authenticated;

GRANT ALL ON TABLE public.categories TO service_role;



--
-- Name: TABLE challenges; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.challenges TO anon;

GRANT ALL ON TABLE public.challenges TO authenticated;

GRANT ALL ON TABLE public.challenges TO service_role;



--
-- Name: TABLE events; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.events TO anon;

GRANT ALL ON TABLE public.events TO authenticated;

GRANT ALL ON TABLE public.events TO service_role;



--
-- Name: TABLE instagram_events; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.instagram_events TO anon;

GRANT ALL ON TABLE public.instagram_events TO authenticated;

GRANT ALL ON TABLE public.instagram_events TO service_role;



--
-- Name: TABLE user_reputation; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.user_reputation TO anon;

GRANT ALL ON TABLE public.user_reputation TO authenticated;

GRANT ALL ON TABLE public.user_reputation TO service_role;



--
-- Name: TABLE news_queue; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.news_queue TO anon;

GRANT ALL ON TABLE public.news_queue TO authenticated;

GRANT ALL ON TABLE public.news_queue TO service_role;



--
-- Name: TABLE news_queue_stats; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.news_queue_stats TO anon;

GRANT ALL ON TABLE public.news_queue_stats TO authenticated;

GRANT ALL ON TABLE public.news_queue_stats TO service_role;



--
-- Name: TABLE news_sources; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.news_sources TO anon;

GRANT ALL ON TABLE public.news_sources TO authenticated;

GRANT ALL ON TABLE public.news_sources TO service_role;



--
-- Name: TABLE news_usage; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.news_usage TO anon;

GRANT ALL ON TABLE public.news_usage TO authenticated;

GRANT ALL ON TABLE public.news_usage TO service_role;



--
-- Name: TABLE partner_offers; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.partner_offers TO anon;

GRANT ALL ON TABLE public.partner_offers TO authenticated;

GRANT ALL ON TABLE public.partner_offers TO service_role;



--
-- Name: TABLE partners; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.partners TO anon;

GRANT ALL ON TABLE public.partners TO authenticated;

GRANT ALL ON TABLE public.partners TO service_role;



--
-- Name: TABLE profiles; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.profiles TO anon;

GRANT ALL ON TABLE public.profiles TO authenticated;

GRANT ALL ON TABLE public.profiles TO service_role;



--
-- Name: TABLE publications; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.publications TO anon;

GRANT ALL ON TABLE public.publications TO authenticated;

GRANT ALL ON TABLE public.publications TO service_role;



--
-- Name: TABLE site_settings; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.site_settings TO anon;

GRANT ALL ON TABLE public.site_settings TO authenticated;

GRANT ALL ON TABLE public.site_settings TO service_role;



--
-- Name: TABLE social_credentials; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.social_credentials TO anon;

GRANT ALL ON TABLE public.social_credentials TO authenticated;

GRANT ALL ON TABLE public.social_credentials TO service_role;



--
-- Name: TABLE static_pages; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.static_pages TO anon;

GRANT ALL ON TABLE public.static_pages TO authenticated;

GRANT ALL ON TABLE public.static_pages TO service_role;



--
-- Name: TABLE user_challenges; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.user_challenges TO anon;

GRANT ALL ON TABLE public.user_challenges TO authenticated;

GRANT ALL ON TABLE public.user_challenges TO service_role;



--
-- Name: TABLE user_collection_items; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.user_collection_items TO anon;

GRANT ALL ON TABLE public.user_collection_items TO authenticated;

GRANT ALL ON TABLE public.user_collection_items TO service_role;



--
-- Name: TABLE user_collections; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.user_collections TO anon;

GRANT ALL ON TABLE public.user_collections TO authenticated;

GRANT ALL ON TABLE public.user_collections TO service_role;



--
-- Name: TABLE user_reputation_detailed; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.user_reputation_detailed TO anon;

GRANT ALL ON TABLE public.user_reputation_detailed TO authenticated;

GRANT ALL ON TABLE public.user_reputation_detailed TO service_role;



--
-- Name: TABLE user_video_reports; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.user_video_reports TO anon;

GRANT ALL ON TABLE public.user_video_reports TO authenticated;

GRANT ALL ON TABLE public.user_video_reports TO service_role;



--
-- Name: TABLE virtual_agents; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.virtual_agents TO anon;

GRANT ALL ON TABLE public.virtual_agents TO authenticated;

GRANT ALL ON TABLE public.virtual_agents TO service_role;



--
-- Name: TABLE waterfall_posts; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.waterfall_posts TO anon;

GRANT ALL ON TABLE public.waterfall_posts TO authenticated;

GRANT ALL ON TABLE public.waterfall_posts TO service_role;



--
-- Name: TABLE waterfall_sessions; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.waterfall_sessions TO anon;

GRANT ALL ON TABLE public.waterfall_sessions TO authenticated;

GRANT ALL ON TABLE public.waterfall_sessions TO service_role;



--
-- Name: TABLE xp_logs; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.xp_logs TO anon;

GRANT ALL ON TABLE public.xp_logs TO authenticated;

GRANT ALL ON TABLE public.xp_logs TO service_role;

