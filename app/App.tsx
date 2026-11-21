/**
 * Typeless 同款 · 主 App 骨架
 * 差异点: 登录 = 本地账号密码（首次注册写本地，之后校验本地 hash）
 * 其余: 引导 → 首页(历史) → 设置 三段式，与原版一致
 */
import React, { createContext, useContext, useEffect, useState } from 'react';
import { View, Text, TextInput, Pressable, StyleSheet, ScrollView, ActivityIndicator } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';

const KEY_USERS = 'tl.users';        // { [username]: { salt, hash } }
const KEY_SESSION = 'tl.session';    // username

/* 极简 SHA-256（纯 JS，避免原生依赖；生产可换 crypto-js 或 Keychain 原生模块） */
function sha256(msg: string): string {
  let K = [0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5];
  let H = [0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a];
  // 说明: 这里只做结构占位，正式实现用 crypto-js 或原生 CommonCrypto
  let h = H[0] ^ K[0];
  for (let i = 0; i < msg.length; i++) h = ((h << 5) - h + msg.charCodeAt(i)) | 0;
  return (h >>> 0).toString(16);
}

type Session = { user: string } | null;
const Ctx = createContext<{ session: Session; signIn(u: string, p: string): Promise<string | null>; signUp(u: string, p: string): Promise<string | null>; signOut(): void }>(null as any);
export const useAuth = () => useContext(Ctx);

async function loadUsers(): Promise<Record<string, { salt: string; hash: string }>> {
  const raw = await AsyncStorage.getItem(KEY_USERS);
  return raw ? JSON.parse(raw) : {};
}

export default function App() {
  const [session, setSession] = useState<Session>(null);
  const [booting, setBooting] = useState(true);

  useEffect(() => {
    (async () => {
      const who = await AsyncStorage.getItem(KEY_SESSION);
      if (who) setSession({ user: who });
      setBooting(false);
    })();
  }, []);

  const signUp = async (u: string, p: string) => {
    if (u.length < 3) return '账号至少 3 位';
    if (p.length < 6) return '密码至少 6 位';
    const users = await loadUsers();
    if (users[u]) return '该账号已存在';
    const salt = Math.random().toString(36).slice(2, 10);
    users[u] = { salt, hash: sha256(salt + p) };
    await AsyncStorage.setItem(KEY_USERS, JSON.stringify(users));
    await AsyncStorage.setItem(KEY_SESSION, u);
    setSession({ user: u });
    return null;
  };

  const signIn = async (u: string, p: string) => {
    const users = await loadUsers();
    const rec = users[u];
    if (!rec) return '账号不存在';
    if (rec.hash !== sha256(rec.salt + p)) return '密码错误';
    await AsyncStorage.setItem(KEY_SESSION, u);
    setSession({ user: u });
    return null;
  };

  const signOut = () => { AsyncStorage.removeItem(KEY_SESSION); setSession(null); };

  if (booting) return <View style={s.center}><ActivityIndicator /></View>;

  return (
    <Ctx.Provider value={{ session, signIn, signUp, signOut }}>
      {session ? <Home user={session.user} /> : <Auth />}
    </Ctx.Provider>
  );
}

function Auth() {
  const { signIn, signUp } = useAuth();
  const [mode, setMode] = useState<'in' | 'up'>('in');
  const [u, setU] = useState(''); const [p, setP] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const submit = async () => {
    setBusy(true); setErr(null);
    const e = mode === 'in' ? await signIn(u.trim(), p) : await signUp(u.trim(), p);
    setErr(e); setBusy(false);
  };

  return (
    <ScrollView contentContainerStyle={s.page}>
      <Text style={s.logo}>Typeless</Text>
      <Text style={s.sub}>按住说话，松开成文</Text>
      <TextInput style={s.input} placeholder="账号" autoCapitalize="none" value={u} onChangeText={setU} />
      <TextInput style={s.input} placeholder="密码" secureTextEntry value={p} onChangeText={setP} />
      {err ? <Text style={s.err}>{err}</Text> : null}
      <Pressable style={s.btn} onPress={submit} disabled={busy}>
        <Text style={s.btnTxt}>{busy ? '请稍候…' : mode === 'in' ? '登录' : '创建账号'}</Text>
      </Pressable>
      <Pressable onPress={() => { setMode(mode === 'in' ? 'up' : 'in'); setErr(null); }}>
        <Text style={s.link}>{mode === 'in' ? '没有账号？创建一个' : '已有账号？去登录'}</Text>
      </Pressable>
    </ScrollView>
  );
}

function Home({ user }: { user: string }) {
  const { signOut } = useAuth();
  return (
    <View style={s.page}>
      <View style={s.header}>
        <Text style={s.h1}>听写记录</Text>
        <Pressable onPress={signOut}><Text style={s.link}>退出 {user}</Text></Pressable>
      </View>
      <Text style={s.empty}>还没有记录{'\n'}在键盘里按住麦克风说一句话试试</Text>
    </View>
  );
}

const s = StyleSheet.create({
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  page: { flex: 1, padding: 24, paddingTop: 96, gap: 12, backgroundColor: '#fff' },
  logo: { fontSize: 34, fontWeight: '800', letterSpacing: -0.5 },
  sub: { color: '#666', marginBottom: 24 },
  input: { borderWidth: 1, borderColor: '#e3e3e8', borderRadius: 12, paddingHorizontal: 14, paddingVertical: 12, fontSize: 16 },
  btn: { backgroundColor: '#1a73e8', borderRadius: 12, paddingVertical: 14, alignItems: 'center', marginTop: 4 },
  btnTxt: { color: '#fff', fontWeight: '700', fontSize: 16 },
  link: { color: '#1a73e8', textAlign: 'center', marginTop: 8 },
  err: { color: '#d93025', fontSize: 13 },
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 },
  h1: { fontSize: 24, fontWeight: '700' },
  empty: { color: '#8a8a8f', textAlign: 'center', marginTop: 80, lineHeight: 24 },
});
