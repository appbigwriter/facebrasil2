import { SupabaseClient } from '@supabase/supabase-js';
import { BlogPost, FetchPostsParams, PaginatedResponse, VideoReport } from './fbr-types';
import { supabase as browserClient } from './supabase';

export type AnySupabaseClient = SupabaseClient<any, any, any>;

// Allow callers (e.g. Server Components) to supply a pre-built server client so
// that cookie-based auth is forwarded to Supabase and RLS policies evaluate
// correctly.  Client Components that don't pass a client fall back to the
// shared browser singleton.
function db(client?: AnySupabaseClient): AnySupabaseClient {
    return (client ?? browserClient) as AnySupabaseClient;
}

export async function fetchPosts(params?: FetchPostsParams, client?: AnySupabaseClient): Promise<PaginatedResponse<BlogPost>> {
    // Base select - use !inner if we might filter by category, otherwise left join is fine.
    let selectString = `
        *,
        author:profiles(name, avatar_url),
        category:categories(name, slug)
    `;

    if (params?.category || params?.excludeCategory) {
        // Use !inner to allow filtering
        selectString = `
            *,
            author:profiles(name, avatar_url),
            category:categories!inner(name, slug)
        `;
    }

    let query = db(client)
        .from('articles')
        .select(selectString, { count: 'exact' });

    // Handle both 'PUBLISHED' and 'published' if status is case-sensitive
    query = query.or('status.eq.PUBLISHED,status.eq.published');

    if (params?.category) {
        if (Array.isArray(params.category)) {
            query = query.in('category.slug', params.category);
        } else {
            query = query.eq('category.slug', params.category);
        }
    }

    if (params?.excludeCategory) {
        query = query.neq('category.slug', params.excludeCategory);
    }

    // Language column missing in DB, disabling filter
    // if (params?.language) {
    //     query = query.eq('language', params.language);
    // }

    // Sort
    if (params?.sort === 'popular') {
        query = query.order('views', { ascending: false });
    } else {
        query = query.order('published_at', { ascending: false });
    }

    // Pagination
    const page = params?.page || 1;
    const limit = params?.limit || 10;
    const from = (page - 1) * limit;
    const to = from + limit - 1;

    query = query.range(from, to);

    const { data, count, error } = await query;

    if (error) {
        console.error('Error fetching posts:', error);
        return { data: [], meta: { total: 0, page, limit, pages: 0 } };
    }

    // Mapping
    const posts: BlogPost[] = (data || []).map((row: any) => mapRowToBlogPost(row)).filter(p => {
        if (!params?.category) return true;
        const requestedCategories = Array.isArray(params.category) ? params.category : [params.category];

        // Normalize requested categories for comparison
        const normalizedRequested = requestedCategories.map(c => c.toLowerCase());

        // Check if any of the article's categories (slug or name-slugged) match the requested ones
        return p.categories.some(catSlug => normalizedRequested.includes(catSlug.toLowerCase()));
    });

    return {
        data: posts,
        meta: {
            total: count || 0,
            page,
            limit,
            pages: Math.ceil((count || 0) / limit)
        }
    };
}

export async function fetchMainHero(language?: string, client?: AnySupabaseClient): Promise<BlogPost | null> {
    try {
        // Priority 1: Check 'colocar_hero'
        // Wrap in internal try-catch so if column doesn't exist (user didn't run SQL), we fall through to latest
        try {
            let heroQuery = db(client)
                .from('articles')
                .select(`
                    *,
                    author:profiles(name, avatar_url),
                    category:categories(name, slug)
                `)
                .eq('colocar_hero', true)
                .eq('status', 'PUBLISHED')
                .order('hero_set_at', { ascending: false }); // Latest set wins

            // if (language) {
            //     heroQuery = heroQuery.eq('language', language);
            // }

            const { data: heroData, error: heroError } = await heroQuery.limit(1).single();

            if (!heroError && heroData) {
                return mapRowToBlogPost(heroData);
            }
        } catch (innerError) {
            // Ignore error (likely missing column) and proceed to fallback
            console.warn('Daily Hero query failed, falling back to latest.');
        }

        // Priority 2: Fallback to latest published article
        let latestQuery = db(client)
            .from('articles')
            .select(`
                *,
                author:profiles(name, avatar_url),
                category:categories(name, slug)
            `)
            .eq('status', 'PUBLISHED')
            .order('published_at', { ascending: false });

        // if (language) {
        //     latestQuery = latestQuery.eq('language', language);
        // }

        const { data: latestData, error: latestError } = await latestQuery.limit(1).single();

        if (latestData) {
            return mapRowToBlogPost(latestData);
        }

        return null;

    } catch (error) {
        console.error('Error fetching main hero:', error);
        return null;
    }
}

export async function fetchFeaturedPosts(limit: number = 5, language?: string, client?: AnySupabaseClient): Promise<BlogPost[]> {
    let query = db(client)
        .from('articles')
        .select(`
            *,
            author:profiles(name, avatar_url),
            category:categories(name, slug)
        `)
        .eq('status', 'PUBLISHED')
        .eq('destaque_hero', true);

    // if (language) {
    //     query = query.eq('language', language);
    // }

    const { data } = await query.limit(limit);

    return (data || []).map(mapRowToBlogPost);
}

export async function fetchVideoReports(limit: number = 4, client?: AnySupabaseClient): Promise<VideoReport[]> {
    const { data } = await db(client)
        .from('user_video_reports')
        .select('*')
        .eq('status', 'APPROVED')
        .order('created_at', { ascending: false })
        .limit(limit);

    return (data || []) as VideoReport[];
}

export async function fetchPost(slug: string, language?: string, client?: AnySupabaseClient): Promise<BlogPost | null> {
    let query = db(client)
        .from('articles')
        .select(`
            *,
            author:profiles(name, avatar_url),
            category:categories(name, slug)
        `)
        .eq('slug', slug);

    // if (language) {
    //     query = query.eq('language', language);
    // }

    const { data, error } = await query.single();

    if (error || !data) return null;

    return mapRowToBlogPost(data);
}




export function mapRowToBlogPost(row: any): BlogPost {
    let featuredImage = { url: '', alt: '', width: 800, height: 600 };
    if (row.featured_image) {
        try {
            const parsed = typeof row.featured_image === 'string' ? JSON.parse(row.featured_image) : row.featured_image;
            featuredImage = { ...featuredImage, ...parsed };
        } catch (e) {
            // plain string url
            if (typeof row.featured_image === 'string') featuredImage.url = row.featured_image;
        }
    }

    return {
        id: row.id,
        slug: row.slug,
        title: row.title,
        excerpt: row.excerpt,
        content: row.content,
        author: {
            name: row.author?.name || 'Facebrasil',
            avatar: row.author?.avatar_url,
        },
        categories: row.category ? [row.category.slug || row.category.name] : [], // Use slug for filtering
        tags: [],
        featuredImage,
        images: [],
        seo: {
            metaTitle: row.seo_title || row.title,
            metaDescription: row.seo_description || row.excerpt,
            keywords: row.keywords || [],
        },
        publishedAt: row.published_at || row.created_at,
        updatedAt: row.updated_at || row.created_at,
        status: row.status as any || 'published',
        readTime: row.read_time || 5,
        socialSummary: row.social_summary,
        instagramPostUrl: row.instagram_post_url,
        destaqueHero: row.destaque_hero,
        source_type: row.source_type,
        ai_context: row.ai_context
    };
}
