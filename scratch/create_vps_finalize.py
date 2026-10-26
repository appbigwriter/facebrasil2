# -*- coding: utf-8 -*-
import os

with open('supabase/sql_editor_custom_facebrasil/06_constraints_and_indexes.sql', 'r', encoding='utf-8') as f:
    step6_content = f.read()

part1 = """-- =========================================================================
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
"""

part2 = """

DO $$
BEGIN
  RAISE NOTICE '=========================================================';
  RAISE NOTICE 'PROPRIEDADES, REGRAS E FOREIGN KEYS 100% APLICADAS!';
  RAISE NOTICE '=========================================================';
END $$;
"""

with open('supabase/vps_finalize_setup.sql', 'w', encoding='utf-8') as f:
    f.write(part1)
    f.write(step6_content)
    f.write(part2)

print('vps_finalize_setup.sql gerado!')
