import { createBrowserClient } from '@supabase/ssr'

let client: ReturnType<typeof createBrowserClient> | undefined;

export function createClient() {
    if (client) return client;

    const schema = process.env.NEXT_PUBLIC_SUPABASE_SCHEMA || 'custom_facebrasil';

    client = createBrowserClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
        {
            db: {
                schema: schema,
            },
        }
    )

    return client;
}
