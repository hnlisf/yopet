# F3 — Email/password sign-in & sign-up

> Status: ready-for-agent
> Parent issue: [yopet#3](https://github.com/hnlisf/yopet/issues/3) (邮箱密码登录流)
> Depends on: F2 (Flutter project skeleton) — done
> Implements: PRD §5 step 1 (Sign up) + step 5 (Come back, fish greets you)

## Context

yopet 仓库已就位:F1 Supabase 栈 10 容器 healthy(`D:\docker\data\ext4.vhdx`,Kong 54331 workaround),F2 Flutter 项目骨架 `flutter run -d windows` 能弹 Fraunces splash。F3 进 email/password sign-in & sign-up 流。

**F1 已知 gap**(影响 F3 devmode):上游 supabase-monorepo Aug 4 commit 把 Inbucket 从主 compose 删了(`docs/setup/local-supabase.md` §11.2),`SMTP_HOST=supabase-mail` 容器名解析不到。本 spec 适配策略:`ENABLE_EMAIL_AUTOCONFIRM=true`(已加在 `supabase-local/docker/.env`),GoTrue 跳过邮件发送直接 auto-confirm,sign-up 响应里带 session,F3 一屏流程 `signUp() → if session → 跳 /home`,无 verify link 步骤。

**Production mode**(`ENABLE_EMAIL_AUTOCONFIRM=false`)在 F3+ ticket 里另开一个,跟 Inbucket 替代品(maildev)一起,本 spec 不动。

## User stories

1. As a new player, I want to enter email + password and submit, so my account exists and I'm logged in (no email verification in dev).
2. As a returning player, I want to enter the same email + password, so I get back into my tank.
3. As a signed-in player, I want to see my email on the home screen, so I know which account is active.
4. As a signed-in player, I want to sign out, so I can switch accounts or hand off the device.
5. As a player, I want clear feedback when my email is already in use, my password is too weak, or my credentials are wrong, so I know what to fix.

## Solution

Flutter 端三屏 + 1 个 Postgres trigger:

- `lib/features/auth/auth_screen.dart` — 一屏 toggle,顶部按钮切 Sign in / Sign up,下面表单随 mode 变(注册模式多 confirm password 字段)
- `lib/features/auth/auth_providers.dart` — Riverpod `authStateChangesProvider`(监听 supabase auth),`currentUserProvider`(当前 session 解析)
- `lib/features/home/home_screen.dart` — 显示 email + Sign out 按钮
- `lib/core/router.dart` — 新增 `/sign-in`、`/home` 路由,根 `/` redirect 到 `/sign-in`(用户未登录)或 `/home`(已登录)
- `lib/app.dart` — `YopetApp` 不变,但 MaterialApp 用 `routerConfig` 接 auth redirect
- `supabase/migrations/20260822000000_f3_profiles.sql` — `public.profiles` 表 + RLS + trigger

## User-flow diagram

```
开 app → router redirect:
  已有 session? → /home    没 session? → /sign-in
                                  ↓
                       ┌──────────  toggle  ──────────┐
                       │                             │
                     [Sign in]                    [Sign up]
                       ↓                             ↓
          supabase.auth.signInWithPassword   supabase.auth.signUp
                       ↓                             ↓
                  session OK?                 session OK?  (auto-confirm, dev)
                       ↓                             ↓
                  redirect /home            redirect /home
                                                ↓
                                  DB trigger 同步 insert profiles
                       ↓                             ↓
                                  HomeScreen 显示 email
```

## Implementation decisions

### Project structure (F3 additions to F2's flat `lib/`)

```
lib/
├── core/
│   ├── env.dart                    (existing)
│   ├── router.dart                 (modify: + /sign-in, /home, / redirect)
│   ├── supabase.dart                (NEW: Supabase.instance lazy init)
│   └── theme/tokens.dart            (existing)
├── features/                       (NEW dir; spec §STRUCTURE.md migration)
│   ├── auth/
│   │   ├── auth_screen.dart        (NEW: toggle sign-in/sign-up)
│   │   └── auth_providers.dart     (NEW: authStateChangesProvider)
│   └── home/
│       └── home_screen.dart         (NEW: email display + sign-out)
├── splash_screen.dart              (existing — / 路由暂保留,redirect 时用)
├── app.dart                        (existing — routerConfig 改读 provider)
└── main.dart                       (existing)
```

> **STRUCTURE.md 触发条件命中**:"第 2 个 feature 出现时升级"。F3 + 后续 F4+ 会有 5+ 个 feature,目录从平铺升级为 `lib/features/<name>/`。本 spec 直接落地 F3 到该结构(不延后);F3 是升级点,符合 spec §STRUCTURE.md 触发条件。

### profiles schema (6 列)

```sql
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text null,
  avatar_url text null,
  locale text not null default 'zh-CN',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- RLS
alter table public.profiles enable row level security;

create policy "users read own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "users update own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- INSERT 只能通过 trigger,RLS 不放给 anon/authenticated 显式 insert
```

### profile auto-create trigger

```sql
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
```

`security definer` 让 trigger 跑在创建者权限下(Supabase service_role)绕开 RLS,auth.users 行 insert 时自动建对应 profiles 行。`on conflict do nothing` 防 F4+ 用户误触发重复建时崩。

### Auth screen layout

一屏,toggle bar 在顶:

```
┌──────────────────────────────────────┐
│            [ 登录 ]   [ 注册 ]         │  ← toggle(选中态: --yopet-tank-glow 描边)
│                                      │
│  ┌──────────────────────────────┐    │
│  │  email                       │    │
│  └──────────────────────────────┘    │
│  ┌──────────────────────────────┐    │
│  │  password                    │    │
│  └──────────────────────────────┘    │  ← (sign-up only)
│  ┌──────────────────────────────┐    │
│  │  confirm password            │    │
│  └──────────────────────────────┘    │
│                                      │
│  ┌──────────────────────────────┐    │
│  │  登录 / 注册                │    │  ← primary button, --yopet-tank-glow
│  └──────────────────────────────┘    │
│                                      │
│  (error 文字, 失败时显示)            │  ← 颜色: --yopet-amber
└──────────────────────────────────────┘
```

### Auth providers(Riverpod 包装)

```dart
// lib/features/auth/auth_providers.dart
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateChangesProvider).valueOrNull;
  return authState?.session?.user;
});
```

### Router 路由

- `/` redirect:
  - 已登录(`currentUserProvider` non-null)→ `/home`
  - 未登录 → `/sign-in`
- `/sign-in` → `AuthScreen(mode: signIn)` (默认路由;通过 `AuthScreen(mode: ...)` 显式控制)
- `/home` → `HomeScreen`

### Error mapping(Supabase 异常 → 中文简短)

| Supabase message | 显示 |
|---|---|
| `User already registered` | "邮箱已注册" |
| `Password should be at least 6 characters` | "密码至少 6 位" |
| `Invalid login credentials` | "邮箱或密码错误" |
| 其他 | 原 message(开发期) |

### F3 spec acceptance 逐条覆盖(issue #3)

| acceptance | 落到 |
|---|---|
| profiles 表 (extends auth.users) 已建立,新用户 sign-up 时自动 insert 一行 | migration `20260822000000_f3_profiles.sql` + trigger |
| Flutter 注册页:邮箱 + 密码输入,提交 | `AuthScreen(mode: signUp)` + `supabase.auth.signUp` |
| 提交后 Supabase Auth 触发验证邮件,Inbucket 出现 | ⚠ **devmode skip**:`ENABLE_EMAIL_AUTOCONFIRM=true` 跳过邮件。spec commit 注释里写明 this item 需要后续 maildev ticket |
| 点击邮件里的确认链接,邮箱状态变为 confirmed | ⚠ **devmode skip** 同上 |
| Flutter 登录页用同一凭证登录成功 | `AuthScreen(mode: signIn)` + `supabase.auth.signInWithPassword` |
| 登录后跳转首页,显示当前用户邮箱 | Router redirect → `HomeScreen` 显示 `currentUser.email` |
| 错误路径覆盖:邮箱已存在、密码太弱、密码错误 | Error mapping 表 + AuthScreen 错误显示 |

## Out of scope

- **生产模式 sign-up 流程**(需要 Inbucket / maildev 替代 + Supabase `ENABLE_EMAIL_AUTOCONFIRM=false`)—— 单独 ticket,F3 之后开
- **OAuth / social login providers**(`GOTRUE_EXTERNAL_*` 配置)—— F4+ 邮箱登录稳定后再开
- **Email 重置密码 / change email**—— PRD §5 没要求
- **profile 编辑 UI**—— F3 只读 email,F4+ 加 display_name / avatar 时一起
- **RLS 在 storage / realtime 的策略**—— 那些是 F4 鱼缸 / F6 鱼种的 scope
- **测试 F3 的真实邮件确认** —— devmode skip,生产环境(ENABLE_EMAIL_AUTOCONFIRM=false)才需要 Inbucket/maildev

## Further notes

- **F3 spec commit 注释里**写明上述 7 条 acceptance 中 2 条是 devmode skip,需要在 F3 close comment 里给项目维护者留 follow-up ticket
- **STRUCURE.md 触发**—— F3 引入 `lib/features/`,符合升级条件,本 spec 直接落地结构(而不是等 F4);F4–F12 在新结构上添加 feature
- **dev-mode sign-up 行为**:`ENABLE_EMAIL_AUTOCONFIRM=true` 下 `supabase.auth.signUp` 立即返回 session,Flutter 端直接 `navigator.go('/home')`,**不需要** verify link
- **real password 长度**:Supabase 默认 ≥ 6 字符,跟 spec 一致;不引入额外客户端校验(让 server 决定,避免 dev/prod 漂移)
- **ANON_KEY / SUPABASE_PUBLISHABLE_KEY**:沿用 F2 / F1 的 key,fresh run 仍走 `run-dev.ps1` 注入
- **profile.id mirror auth.users.id**,F6+ 加"我有多少鱼"统计时 profile join 即可

## Reference

- Issue: yopet#3 邮箱密码登录流
- Spec: `docs/specs/2026-08-09-f2-flutter-scaffold.md`(F2 依赖)
- F1 runbook: `docs/setup/local-supabase.md` §11
- 已归档 F1 spec: `docs/.archive-superpowers/specs/2026-08-09-f2-flutter-scaffold-design.md`
- Domain glossary: `CONTEXT.md`
- UI design: `docs/design/ui-design.md` §6.2, §7, §8
- ADRs: `docs/adr/0001-no-punishment-principle.md`(Splash 文字不报错就是 principle 体现)
