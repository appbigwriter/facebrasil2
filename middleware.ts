import { type NextRequest, NextResponse } from 'next/server'
import { createServerClient, type CookieOptions } from '@supabase/ssr'
import createIntlMiddleware from 'next-intl/middleware'
import { routing } from './i18n/routing'

const intlMiddleware = createIntlMiddleware(routing)

export async function middleware(request: NextRequest) {
    const path = request.nextUrl.pathname

    // Skip auth for static assets and API routes that don't need session refresh
    const staticApps = ['arva', 'facebrasilshop', 'facebrasiltv', 'fbrnews', 'novafacebrasil', 'tina']
    const pathParts = path.split('/').filter(Boolean)
    const firstPart = pathParts[0]
    const isLocale = ['pt', 'en', 'es'].includes(firstPart)
    const rootPath = isLocale ? pathParts[1] : firstPart

    // Check if it's one of our static apps or an old business route
    if (staticApps.includes(rootPath) || path.startsWith('/business/')) {
        const targetRoute = rootPath || pathParts[1]
        
        // Rewrite internally to the .html file in public root
        // This ensures facebrasil.com/arva serves public/arva.html
        const staticFileUrl = new URL(`/${targetRoute}.html`, request.url)
        return NextResponse.rewrite(staticFileUrl)
    }

    if (
        path.startsWith('/_next') ||
        path.startsWith('/api/auth/callback') ||
        path.startsWith('/fbrapps/') ||
        /\.(svg|png|jpg|jpeg|gif|webp|ico|html|css|js|woff|woff2|ttf)$/.test(path)
    ) {
        return NextResponse.next()
    }

    // ─── 1. Apply next-intl routing first ────────────────────────────────────
    // Skip next-intl for API routes to avoid redirecting /api/ to /pt/api/
    const intlResponse = path.startsWith('/api/')
        ? NextResponse.next()
        : intlMiddleware(request)

    // ─── 2. Refresh Supabase session and propagate cookies to intlResponse ───
    // We must create a new client that reads FROM the request AND writes TO
    // the intlResponse so session cookies are preserved.
    const schema = process.env.NEXT_PUBLIC_SUPABASE_SCHEMA || 'custom_facebrasil';
    const supabase = createServerClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
        {
            db: {
                schema: schema,
            },
            cookies: {
                get(name: string) {
                    return request.cookies.get(name)?.value
                },
                set(name: string, value: string, options: CookieOptions) {
                    // Write the cookie back to both the request and the response
                    request.cookies.set({ name, value, ...options })
                    intlResponse.cookies.set({ name, value, ...options })
                },
                remove(name: string, options: CookieOptions) {
                    request.cookies.set({ name, value: '', ...options })
                    intlResponse.cookies.set({ name, value: '', ...options })
                },
            },
        }
    )

    // getUser() refreshes the access token if needed (safe to call on every request).
    // If it fails (invalid/expired token that couldn't be refreshed), user will be null.
    const { data: { user }, error: getUserError } = await supabase.auth.getUser()

    // ─── 3. Route protection ─────────────────────────────────────────────────
    const isAdminRoute = /^\/(pt|en|es)\/admin/.test(path) || path.startsWith('/admin')
    const isProtectedRoute =
        /^\/(pt|en|es)\/(dashboard|gamification|settings)/.test(path) ||
        /^\/(dashboard|gamification|settings)/.test(path)

    if (isAdminRoute || isProtectedRoute) {
        console.log(`[Middleware] Auth Check: path=${path}, user=${user?.id || 'none'}, error=${getUserError?.message || 'none'}`)
    }

    if ((isAdminRoute || isProtectedRoute) && !user) {
        const locale = path.split('/')[1] || 'pt'
        const validLocales = ['pt', 'en', 'es']
        const resolvedLocale = validLocales.includes(locale) ? locale : 'pt'
        const loginUrl = new URL(`/${resolvedLocale}/login`, request.url)
        loginUrl.searchParams.set('next', path)
        const redirectResponse = NextResponse.redirect(loginUrl)

        // If the session token was invalid (not just absent), clear the auth cookies
        // so the client doesn't keep sending broken tokens on every request.
        if (getUserError) {
            for (const cookie of request.cookies.getAll()) {
                if (cookie.name.startsWith('sb-')) {
                    redirectResponse.cookies.delete(cookie.name)
                }
            }
        }

        return redirectResponse
    }

    return intlResponse
}

export const config = {
    matcher: [
        '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
    ],
}
