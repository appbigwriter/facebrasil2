'use client';

import React, { useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { useRouter, useSearchParams, useParams } from 'next/navigation';
import { User, Mail, Lock, Loader2, Star, Trophy, ArrowRight } from 'lucide-react';
import { LogoSVG } from '@/lib/constants';

type AuthMode = 'login' | 'signup';

function translateSupabaseError(message: string): string {
    if (!message) return 'Ocorreu um erro. Tente novamente.';
    const m = message.toLowerCase();
    if (m.includes('invalid login credentials') || m.includes('invalid credentials'))
        return 'Email ou senha incorretos. Verifique seus dados.';
    if (m.includes('email not confirmed'))
        return 'EMAIL_NOT_CONFIRMED';
    if (m.includes('too many requests') || m.includes('rate limit'))
        return 'Muitas tentativas. Aguarde alguns minutos antes de tentar novamente.';
    if (m.includes('user not found'))
        return 'Nenhuma conta encontrada com este email.';
    if (m.includes('password should be') || m.includes('weak password'))
        return 'A senha deve ter pelo menos 6 caracteres.';
    if (m.includes('email already') || m.includes('already registered'))
        return 'Este email já está cadastrado. Tente fazer login.';
    if (m.includes('network') || m.includes('fetch'))
        return 'Erro de conexão. Verifique sua internet e tente novamente.';
    return message;
}

export default function LoginPage() {
    const [mode, setMode] = useState<AuthMode>('login');
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [name, setName] = useState('');
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [success, setSuccess] = useState<string | null>(null);
    const [needsConfirmation, setNeedsConfirmation] = useState(false);
    const [resendLoading, setResendLoading] = useState(false);

    const router = useRouter();
    const searchParams = useSearchParams();
    const params = useParams();
    const locale = (params?.locale as string) || 'pt';
    const supabase = createClient();

    React.useEffect(() => {
        if (searchParams.get('mode') === 'signup') {
            setMode('signup');
        }
    }, [searchParams]);

    const handleResendConfirmation = async () => {
        setResendLoading(true);
        try {
            const { error } = await supabase.auth.resend({
                type: 'signup',
                email,
                options: {
                    emailRedirectTo: `${window.location.origin}/api/auth/callback?next=/${locale}/dashboard`,
                },
            });
            if (error) throw error;
            setSuccess('Email de confirmação reenviado! Verifique sua caixa de entrada.');
            setNeedsConfirmation(false);
            setError(null);
        } catch (err: any) {
            setError('Não foi possível reenviar o email. Tente novamente em alguns minutos.');
        } finally {
            setResendLoading(false);
        }
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);
        setError(null);
        setSuccess(null);
        setNeedsConfirmation(false);

        try {
            if (mode === 'login') {
                console.log('[Login] Attempting sign in for:', email);
                const { data, error } = await supabase.auth.signInWithPassword({ email, password });

                if (error) {
                    console.error('[Login] Supabase error:', error.message);
                    throw error;
                }

                console.log('[Login] Sign in success, session:', !!data.session);
                const nextUrl = searchParams.get('next') || `/${locale}/dashboard`;
                console.log('[Login] Redirecting to:', nextUrl);
                router.push(nextUrl);
            } else {
                const { error, data } = await supabase.auth.signUp({
                    email,
                    password,
                    options: {
                        emailRedirectTo: `${window.location.origin}/api/auth/callback?next=/${locale}/dashboard`,
                        data: { full_name: name },
                    },
                });

                if (error) throw error;

                if (data?.user?.identities?.length === 0) {
                    setError('Este email já está cadastrado. Tente fazer login.');
                } else {
                    setSuccess('Conta criada! Verifique seu email para confirmar o cadastro antes de entrar.');
                    setMode('login');
                }
            }
        } catch (err: any) {
            const translated = translateSupabaseError(err.message || '');
            if (translated === 'EMAIL_NOT_CONFIRMED') {
                setNeedsConfirmation(true);
                setError('Seu email ainda não foi confirmado. Clique no link que enviamos para você ou reenvie abaixo.');
            } else {
                setError(translated);
            }
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="min-h-screen flex items-center justify-center p-6 bg-slate-950 text-white relative overflow-hidden">
            <div className="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] bg-primary/20 blur-[120px] rounded-full"></div>
            <div className="absolute bottom-[-10%] right-[-10%] w-[40%] h-[40%] bg-blue-500/10 blur-[120px] rounded-full"></div>

            <div className="w-full max-w-md relative z-10">
                <div className="text-center mb-8">
                    <div className="inline-flex items-center justify-center p-4 bg-primary/10 rounded-2xl mb-6 border border-primary/20 animate-pulse">
                        <LogoSVG className="w-10 h-10 text-primary" />
                    </div>
                    <h1 className="text-4xl font-black tracking-tighter mb-2">
                        {mode === 'login' ? 'Bem-vindo de volta' : 'Crie sua conta'}
                    </h1>
                    <p className="text-slate-400 text-lg">
                        {mode === 'login'
                            ? 'Acesse o melhor conteúdo da Facebrasil'
                            : 'Junte-se à maior comunidade brasileira nos EUA'}
                    </p>
                </div>

                <div className="bg-slate-900/60 border border-white/10 rounded-[2.5rem] p-8 md:p-10 backdrop-blur-2xl shadow-2xl">

                    {/* Mode Toggle */}
                    <div className="flex bg-slate-950/50 p-1.5 rounded-2xl mb-8 border border-white/5">
                        <button
                            onClick={() => { setMode('login'); setError(null); setSuccess(null); setNeedsConfirmation(false); }}
                            className={`flex-1 py-3 rounded-xl text-sm font-bold transition-all ${mode === 'login' ? 'bg-primary text-slate-950 shadow-lg' : 'text-slate-400 hover:text-white'}`}
                        >
                            Entrar
                        </button>
                        <button
                            onClick={() => { setMode('signup'); setError(null); setSuccess(null); setNeedsConfirmation(false); }}
                            className={`flex-1 py-3 rounded-xl text-sm font-bold transition-all ${mode === 'signup' ? 'bg-primary text-slate-950 shadow-lg' : 'text-slate-400 hover:text-white'}`}
                        >
                            Criar Conta
                        </button>
                    </div>

                    <form onSubmit={handleSubmit} className="space-y-5">
                        {mode === 'signup' && (
                            <div className="animate-in fade-in slide-in-from-top-2 duration-300">
                                <label className="block text-xs font-bold text-slate-400 uppercase tracking-widest mb-2 ml-1">Nome Completo</label>
                                <div className="relative group">
                                    <User className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-500 group-focus-within:text-primary transition-colors" />
                                    <input
                                        type="text"
                                        required
                                        value={name}
                                        onChange={(e) => setName(e.target.value)}
                                        placeholder="Seu nome completo"
                                        className="w-full bg-slate-800/40 border border-white/5 rounded-2xl py-4 pl-12 pr-4 text-white focus:outline-none focus:ring-2 focus:ring-primary/50 focus:bg-slate-800/60 transition-all placeholder:text-slate-600"
                                    />
                                </div>
                            </div>
                        )}

                        <div>
                            <label className="block text-xs font-bold text-slate-400 uppercase tracking-widest mb-2 ml-1">Email</label>
                            <div className="relative group">
                                <Mail className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-500 group-focus-within:text-primary transition-colors" />
                                <input
                                    type="email"
                                    required
                                    value={email}
                                    onChange={(e) => setEmail(e.target.value)}
                                    placeholder="seu@email.com"
                                    className="w-full bg-slate-800/40 border border-white/5 rounded-2xl py-4 pl-12 pr-4 text-white focus:outline-none focus:ring-2 focus:ring-primary/50 focus:bg-slate-800/60 transition-all placeholder:text-slate-600"
                                />
                            </div>
                        </div>

                        <div>
                            <label className="block text-xs font-bold text-slate-400 uppercase tracking-widest mb-2 ml-1">Senha</label>
                            <div className="relative group">
                                <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-500 group-focus-within:text-primary transition-colors" />
                                <input
                                    type="password"
                                    required
                                    value={password}
                                    onChange={(e) => setPassword(e.target.value)}
                                    placeholder="••••••••"
                                    className="w-full bg-slate-800/40 border border-white/5 rounded-2xl py-4 pl-12 pr-4 text-white focus:outline-none focus:ring-2 focus:ring-primary/50 focus:bg-slate-800/60 transition-all placeholder:text-slate-600"
                                />
                            </div>
                        </div>

                        {mode === 'login' && (
                            <div className="flex items-center justify-end">
                                <a
                                    href={`/${locale}/forgot-password`}
                                    className="text-sm text-slate-400 hover:text-primary transition-colors underline underline-offset-4"
                                >
                                    Esqueci a senha
                                </a>
                            </div>
                        )}

                        {error && (
                            <div className="p-4 bg-red-500/10 border border-red-500/20 rounded-2xl text-red-400 text-sm flex flex-col gap-3 animate-in fade-in duration-200">
                                <div className="flex items-start gap-3">
                                    <span className="mt-0.5">⚠️</span>
                                    <span>{error}</span>
                                </div>
                                {needsConfirmation && email && (
                                    <button
                                        type="button"
                                        onClick={handleResendConfirmation}
                                        disabled={resendLoading}
                                        className="w-full py-2.5 bg-amber-500/10 border border-amber-500/30 hover:bg-amber-500/20 text-amber-400 rounded-xl text-xs font-bold transition-all flex items-center justify-center gap-2 disabled:opacity-50"
                                    >
                                        {resendLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : '📧 Reenviar email de confirmação'}
                                    </button>
                                )}
                            </div>
                        )}

                        {success && (
                            <div className="p-4 bg-emerald-500/10 border border-emerald-500/20 rounded-2xl text-emerald-400 text-sm flex items-start gap-3 animate-in zoom-in-95 duration-300">
                                <div className="mt-0.5">✅</div>
                                <span>{success}</span>
                            </div>
                        )}

                        <button
                            type="submit"
                            disabled={loading}
                            className="w-full bg-primary hover:bg-primary/90 text-slate-950 font-black py-4 rounded-2xl transition-all flex items-center justify-center gap-2 shadow-xl shadow-primary/20 disabled:opacity-50 disabled:cursor-not-allowed group"
                        >
                            {loading ? (
                                <Loader2 className="w-6 h-6 animate-spin" />
                            ) : (
                                <>
                                    {mode === 'login' ? 'Acessar Conta' : 'Criar minha conta'}
                                    <ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
                                </>
                            )}
                        </button>
                    </form>
                </div>

                <div className="mt-10 grid grid-cols-2 gap-4">
                    <div className="flex flex-col items-center gap-2 p-4 bg-white/5 rounded-2xl border border-white/5">
                        <Trophy className="w-5 h-5 text-amber-500" />
                        <span className="text-[10px] uppercase font-black text-slate-500 tracking-tighter">Ganhe XP</span>
                    </div>
                    <div className="flex flex-col items-center gap-2 p-4 bg-white/5 rounded-2xl border border-white/5">
                        <Star className="w-5 h-5 text-primary" />
                        <span className="text-[10px] uppercase font-black text-slate-500 tracking-tighter">Badges Exclusivos</span>
                    </div>
                </div>

                <div className="mt-8 text-center space-y-4">
                    <p className="text-slate-500 text-sm">
                        Ao continuar, você concorda com nossos <br />
                        <a href="/terms" className="text-slate-300 underline underline-offset-4 hover:text-primary transition-colors">Termos de Uso</a> e <a href="/privacy" className="text-slate-300 underline underline-offset-4 hover:text-primary transition-colors">Política de Privacidade</a>.
                    </p>
                </div>
            </div>
        </div>
    );
}
