# Guia de Execução — Restauração no Schema `custom_facebrasil`

Todos os scripts necessários foram extraídos, sanitizados e compatibilizados para execução direta no **SQL Editor do Supabase Studio (Web)**.

Os arquivos estão localizados em: `supabase/sql_editor_custom_facebrasil/`

---

## 📋 Ordem Obrigatória de Execução

Execute cada arquivo em uma nova query no SQL Editor do Supabase Studio, na seguinte sequência:

### 1️⃣ Passo 1: Schema e Permissões
* **Arquivo:** [`01_schema_and_permissions.sql`](file:///f:/Projetos/_FBR/2FBR-NovaFacebrasil/supabase/sql_editor_custom_facebrasil/01_schema_and_permissions.sql)
* **O que faz:** Cria as extensões `uuid-ossp`, `pgcrypto`, cria o schema `custom_facebrasil` e concede todos os privilégios necessários para as roles da API do Supabase (`anon`, `authenticated`, `service_role`).

---

### 2️⃣ Passo 2: Estrutura de Tabelas e Funções
* **Arquivo:** [`02_tables_and_functions.sql`](file:///f:/Projetos/_FBR/2FBR-NovaFacebrasil/supabase/sql_editor_custom_facebrasil/02_tables_and_functions.sql)
* **O que faz:** Cria todas as 33 tabelas de negócio do Facebrasil Magazine dentro do schema `custom_facebrasil` e registra todas as funções plpgsql (`calculate_level`, `check_and_award_badges`, `increment_article_views`, etc.).

---

### 3️⃣ Passo 3: Dados de Configurações, Perfis e Categorias
* **Arquivo:** [`03_base_data.sql`](file:///f:/Projetos/_FBR/2FBR-NovaFacebrasil/supabase/sql_editor_custom_facebrasil/03_base_data.sql)
* **O que faz:** Insere com integridade via `INSERT INTO ... ON CONFLICT DO NOTHING`:
  - 22 Perfis de autores/editores
  - 20 Categorias de notícias
  - Configurações do site (`site_settings`)
  - 12 Agentes virtuais de IA (`virtual_agents`)
  - Anúncios (`ads` e `ad_publications`)
  - Badges, desafios, eventos e tabelas de gamificação.

---

### 4️⃣ Passo 4: Usuários de Autenticação e Storage
* **Arquivo:** [`04_auth_and_storage.sql`](file:///f:/Projetos/_FBR/2FBR-NovaFacebrasil/supabase/sql_editor_custom_facebrasil/04_auth_and_storage.sql)
* **O que faz:** 
  - Restaura os 17 usuários no `auth.users` e suas identidades no `auth.identities` (preserva senhas criptografadas e permissões de login dos editores).
  - Configura os 3 buckets de storage (`blog-assets`, `ads`, `waterfall-images`) e importa os 380 metadados de arquivos em `storage.objects`.

---

### 5️⃣ Passo 5: Artigos e Notícias (Divididos em Partes)
Para evitar timeout HTTP ou travamento da aba do navegador no SQL Editor com textos longos de HTML, os 8.586 artigos foram divididos em 6 partes:

1. [`05_articles_part_1.sql`](file:///f:/Projetos/_FBR/2FBR-NovaFacebrasil/supabase/sql_editor_custom_facebrasil/05_articles_part_1.sql) — Artigos 1 a 1.500
2. [`05_articles_part_2.sql`](file:///f:/Projetos/_FBR/2FBR-NovaFacebrasil/supabase/sql_editor_custom_facebrasil/05_articles_part_2.sql) — Artigos 1.501 a 3.000
3. [`05_articles_part_3.sql`](file:///f:/Projetos/_FBR/2FBR-NovaFacebrasil/supabase/sql_editor_custom_facebrasil/05_articles_part_3.sql) — Artigos 3.001 a 4.500
4. [`05_articles_part_4.sql`](file:///f:/Projetos/_FBR/2FBR-NovaFacebrasil/supabase/sql_editor_custom_facebrasil/05_articles_part_4.sql) — Artigos 4.501 a 6.000
5. [`05_articles_part_5.sql`](file:///f:/Projetos/_FBR/2FBR-NovaFacebrasil/supabase/sql_editor_custom_facebrasil/05_articles_part_5.sql) — Artigos 6.001 a 7.500
6. [`05_articles_part_6.sql`](file:///f:/Projetos/_FBR/2FBR-NovaFacebrasil/supabase/sql_editor_custom_facebrasil/05_articles_part_6.sql) — Artigos 7.501 a 8.586

---

### 6️⃣ Passo 6: Chaves, Índices e RLS
* **Arquivo:** [`06_constraints_and_indexes.sql`](file:///f:/Projetos/_FBR/2FBR-NovaFacebrasil/supabase/sql_editor_custom_facebrasil/06_constraints_and_indexes.sql)
* **O que faz:** Cria chaves primárias, chaves estrangeiras, índices de alta performance para busca e habilita Row Level Security (RLS) com as devidas políticas.

---

## ⚙️ Configuração Importante no Supabase Self-Hosted (VPS)

No Supabase Self-Hosted, o PostgREST precisa expor o schema `custom_facebrasil` para que a API REST do Supabase responda às queries da aplicação.

No arquivo de ambiente do container do Supabase na VPS (serviço `rest` / `postgrest`), certifique-se de que a variável contém o schema:

```env
PGRST_DB_SCHEMAS="public,storage,graphql_public,custom_facebrasil"
```

Caso precise alterar essa variável no Supabase da VPS, reinicie o container do PostgREST:
```bash
docker restart supabase-rest
# ou no Easypanel, salve o Environment e clique em Redeploy
```

---

## 🚀 Código do Next.js Atualizado

O Next.js já foi atualizado para apontar automaticamente para `custom_facebrasil`:
- [`lib/supabase/client.ts`](file:///f:/Projetos/_FBR/2FBR-NovaFacebrasil/lib/supabase/client.ts)
- [`lib/supabase/server.ts`](file:///f:/Projetos/_FBR/2FBR-NovaFacebrasil/lib/supabase/server.ts)
- [`lib/supabase-admin.ts`](file:///f:/Projetos/_FBR/2FBR-NovaFacebrasil/lib/supabase-admin.ts)
- [`middleware.ts`](file:///f:/Projetos/_FBR/2FBR-NovaFacebrasil/middleware.ts)

Todas as instâncias usam `process.env.NEXT_PUBLIC_SUPABASE_SCHEMA || 'custom_facebrasil'`.
