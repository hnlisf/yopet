# F2 — Flutter 项目骨架 + supabase_flutter

> 状态: implementation and verification
> 关联: [Issue #2](https://github.com/hnlisf/yopet/issues/2)
> 实现: [ADR-0004](../adr/0004-backend-supabase-self-hosted.md), [ADR-0002](../adr/0002-cloud-sync-with-account.md)

## Problem Statement

yopet 仓库当前是纯文档仓库:`PRD.md`、`CONTEXT.md`、`docs/adr/`、`docs/design/`、`docs/agents/` 都已就位,但**没有 `lib/`、`pubspec.yaml`、任何 Flutter 源文件**。F3–F12 共 12 个 feature 要写代码,却没有 Flutter 项目承接。

开发者今天打开 yopet/ 跑 `flutter run`,什么都启动不起来。下游 ticket(邮箱登录 F3、空鱼缸 F4、领养 F6 等)全部阻塞,无法开始任何 feature UI。

## Solution

`flutter create` 在 yopet/ 目录里立起标准 Flutter 项目骨架;加 supabase_flutter + flutter_riverpod + go_router 三个核心 deps;写 6 个文件(`main.dart`、`app.dart`、`splash_screen.dart`、`core/env.dart`、`core/router.dart`、`core/theme/tokens.dart`);一个 widget smoke test;改 `.gitignore`;加一个 `run-dev.ps1` wrapper 和 `docs/setup/STRUCTURE.md` 升级触发器。

跑完 F2,`flutter run -d windows` 能在 60 秒内弹窗显示 splash 屏,`flutter test` 通过,`flutter analyze` 零警告。issue #2 的 6 条 acceptance + F2 新增 3 条全部 ✓,issue 关闭,F3 接手做 sign-in flow。

## User Stories

1. 作为开发者,我希望在 yopet/ 跑 `flutter create` 成功,这样仓库从纯文档状态变成可运行的 Flutter 项目。
2. 作为开发者,我希望 pubspec.yaml 含 `flutter_riverpod` ^2.5.0、`supabase_flutter` ^2.5.0、`go_router` ^14.0.0,这样后续 F3–F12 能用 Riverpod 管状态、用 supabase_flutter 调 Supabase API、用 go_router 做路由。
3. 作为开发者,我希望 dev_dependencies 含 `flutter_lints` ^4.0.0,这样 `flutter analyze` 有可执行的规则集。
4. 作为开发者,我希望 F2 **不安装** `riverpod_annotation`、`riverpod_generator`、`freezed_annotation`、`freezed`、`json_annotation`、`json_serializable`、`build_runner`,这样 F2/F3/F4 阶段工具链死重为 0,build step 简化,IDE analyzer 启动更快。
5. 作为开发者,我希望 main.dart 在启动时 `Supabase.initialize(url, anonKey)`,这样 F3+ 的任何 Supabase 调用都有现成 client。
6. 作为开发者,我希望 `Env.supabaseUrl` 默认 `http://localhost:54321`(干净 Linux dev box 的标准端口),这样干净 box 用户零配置跑 F2。
7. 作为开发者,我希望 `Env.supabaseAnonKey` 默认空字符串,这样强制显式 dart-define,密钥不进 git。
8. 作为开发者,我希望 yopet/ 根目录有 `run-dev.ps1`,这样在本机(Docker Desktop NAT cache 卡 54321)跑 `.ps1` 自动读 `../supabase-local/docker/.env` 的 URL 并 dart-define 注入,不用手记 54321 vs 54331。
9. 作为本机的 Android 模拟器开发者,我希望 `run-dev.ps1 -Platform android` 把 host 翻译成 `10.0.2.2`,这样 Android 模拟器(emulator 隔离 netns)能连到宿主机的 Supabase。
10. 作为开发者,我希望 splash 屏颜色从 `lib/core/theme/tokens.dart` 读 const(`primaryBg = Color(0xFF0E1620)`、`tankGlow = Color(0xFF5BA8B5)`),这样 UI 原型阶段改一个文件就同步品牌色,不用 grep 整个项目。
11. 作为开发者,我希望 splash 屏只 hardcode "yopet" 文字 + 字号 + 字重,字体走系统默认(不引入 Fraunces 文件),这样 F2 不动 asset bundle,UI 原型阶段再加品牌字体。
12. 作为开发者,我希望 `lib/` 在 F2 平铺(`splash_screen.dart` 在 lib/ 根,`core/` 仍在),`features/` 目录**不创建**,这样符合"YAGNI = 骨架用最小可工作结构"。
13. 作为 F3+ 的开发者,我希望 `docs/setup/STRUCTURE.md` 写明"F3 起出现第 2 个 feature 时,从平铺升级为 `lib/features/<name>/` 目录",这样迁移触发器有文档依据,不会被人误删。
14. 作为开发者,我希望 `.gitignore` 加 Flutter 标准项(`.dart_tool/`、`build/`、`.flutter-plugins`、`.flutter-plugins-dependencies`、`、os/Pods/`、`android/.gradle/`、`android/local.properties`),这样生成产物不进 git;同时 `pubspec.lock` commit,这样依赖版本固定。
15. 作为开发者,我希望 `test/widget_test.dart` 有 1 个 widget smoke test:`pumpWidget(ProviderScope(child: YopetApp()))`,然后 `expect(find.text('yopet'), findsOneWidget)`,这样端到端 cover pubspec 解析 → ProviderScope 包好 → MaterialApp.router 不崩 → GoRouter 单 route `/` 能 resolve → SplashScreen widget 渲染 → tokens.dart const 解析。
16. 作为开发者,我希望 smoke test **不调** `Supabase.initialize()`,这样测试是 hermetic 的,不依赖 Supabase 网络/cert。
17. 作为开发者,我希望 `flutter analyze` 零警告通过,这样代码风格有 CI-grade gate。
18. 作为开发者,我希望 `flutter test` 通过,这样 1 个 widget test 跑通断言"yopet"文本可见。
19. 作为开发者,我希望 `flutter run -d windows` 启动后弹窗显示 splash 屏,Windows 是 F2 选定的两个 target 之一。
20. 作为开发者,我希望 `flutter run -d android` 或 `flutter build apk --debug` 成功,Android 是 F2 选定的另一个 target。
21. 作为开发者,我希望 `flutter run` 不报 Supabase 初始化错误(即便 Supabase 不可达也不崩),这样 F2 在 Supabase 没起来时也能跑起来供 UI 调试。
22. 作为项目维护者,我希望 issue #2 body 被更新以反映 grill 决策(URL 默认 54321、`run-dev.ps1`、无 codegen 工具链、平铺结构),这样 issue tracker 是真相之源而非历史提案。
23. 作为 git 仓库,我希望 `pubspec.lock` 进版本控制,这样 CI 和本地锁同一份依赖。

## Implementation Decisions

### 项目结构(平铺,不进 features/)

F2 单 feature,**目录平铺**:

```
yopet/
├── run-dev.ps1                    # 本机 wrapper
├── pubspec.yaml
├── pubspec.lock
├── analysis_options.yaml
├── lib/
│   ├── main.dart                   # WidgetsFlutterBinding + Supabase.initialize + runApp
│   ├── app.dart                    # ProviderScope + MaterialApp.router
│   ├── splash_screen.dart          # 唯一屏幕
│   └── core/
│       ├── env.dart                # SUPABASE_URL / SUPABASE_ANON_KEY dart-define
│       ├── router.dart              # GoRouter 单 route
│       ├── supabase.dart            # 注释:Supabase.instance.client 用法
│       └── theme/
│           └── tokens.dart          # 2 个 const:primaryBg + tankGlow
├── test/
│   └── widget_test.dart            # 1 个 smoke test
├── docs/
│   ├── setup/
│   │   ├── local-supabase.md       # F1 runbook(权威,不动)
│   │   └── STRUCTURE.md            # 新增:F3+ 升级触发器
│   └── specs/
│       └── 2026-08-09-f2-flutter-scaffold.md  # 本文件
├── android/                        # flutter create 生成
├── windows/                        # flutter create 生成
├── ios/                            # flutter create 生成(无 macOS 工具链,跳过构建)
└── .gitignore                      # 加 Flutter 标准项
```

**features/ 目录不在 F2 创建**,由 STRUCTURE.md 写明"F3 起出现第 2 个 feature 时,从平铺升级为 `lib/features/<name>/`"。

### 依赖(pubspec.yaml)

**dependencies**:
- `flutter_riverpod: ^2.5.0`(运行时,F2 实际不用 Provider,但 F3+ 需要)
- `supabase_flutter: ^2.5.0`
- `go_router: ^14.0.0`

**dev_dependencies**:
- `flutter_test: { sdk: flutter }`
- `flutter_lints: ^4.0.0`

**F2 故意不装**(Q4/Q6 YAGNI 决策):
- ~~`riverpod_annotation`、`riverpod_generator`~~(推迟到 F3+ 真用 Provider 时)
- ~~`freezed_annotation`、`freezed`、`json_annotation`、`json_serializable`、`build_runner`~~(推迟到 F5 写模型时)

### env.dart 配置

`SUPABASE_URL` 默认 `http://localhost:54321`(干净 box 标准,F本机用 `run-dev.ps1` 覆盖)。

`SUPABASE_ANON_KEY` 默认空字符串 —— 强制显式 dart-define,密钥不进 git。`Supabase.initialize` 校验非空,空 defaultValue 必须配 dart-define。

### splash 屏颜色源

`lib/core/theme/tokens.dart` 定义两个 const,来源对应 `docs/design/ui-design.md` §3 palette:

| Const | Hex | 来源 token |
|---|---|---|
| `primaryBg` | `Color(0xFF0E1620)` | `--yopet-bg` |
| `tankGlow` | `Color(0xFF5BA8B5)` | `--yopet-tank-glow` |

SplashScreen import 这两个 const,**不用 raw hex**。UI 原型阶段加更多 const,splash 自动跟随。

字体走系统默认(不引入 Fraunces asset),字号 48 / `FontWeight.w600` 写死,F3  改字体时改 SplashScreen 一处。

### 启动流程

`main.dart` 同步 init:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey)`
3. `runApp(const YopetApp())`

`Supabase.initialize` 失败不应当崩 F2 启动流程 —— 即便 Supabase 不可达,UI splash 仍可显示供 UI 调试(UI 原型/issue 排查场景)。具体失败处理:`Supabase.initialize` 内部 try-catch,失败 log 警告但不 throw。

### go_router 配置

`lib/core/router.dart` 单 route `/`,跳到 `SplashScreen`。F3+ 加 auth/tank/fish 路由只需扩 route 表,不重写 main.dart。

### run-dev.ps1 接口

```位置` yopet/ 根目录。

**默认调用**:`.ps1`(Windows desktop,URL 翻译为 `localhost`,读 `../supabase-local/docker/.env` 的 URL 和 anon key)

**-Platform 参数**:取值 `Windows + android`(Android 时把 URL host 翻译为 `10.0.2.2`)

**-Url 参数**:覆盖 URL(debug 用)

**实现要点**:
1. 读 `../supabase-local/docker/.env`,grep `^SUPABASE_URL=` 和 `^ANON_KEY=`(如果 SUPABASE_URL 不存在则用 F2 默认 `http://localhost:54321`)
2. 按 -Platform 翻译 URL host
3. 调用 `flutter run -d <target> --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_ANON_KEY=<key>`

### targets

`flutter create . --platforms=windows,android --org com.yopet --project-name yopet`(在 yopet/ 目录里跑)。

macOS/iOS 不生成(本机无 macOS 工具链;ADR-0004 列出但 F2 defer)。

### .gitignore

加 Flutter 标准项(已在 yopet 既有 `.gitignore` 基础上):

- `.dart_tool/`
- `.flutter-plugins`、`.flutter-plugins-dependencies`、`.packages`
- `build/`
- `ios/Pods/`、`ios/.symlinks/`、`ios/Flutter/Flutter.framework`、`ios/Flutter/Flutter.podspec`
- `macos/Pods/`、`macos/Flutter/{ephemeral,Flutter.framework,Flutter.podspec}`
- `windows/flutter/{ephemeral,Flutter.dll,Flutter.exe}`
- `android>.gradle/`、`android>/local.properties`、`android>/app/release/`、`android>/key.properties`

**`pubspec.lock` commit**(app 项目惯例,锁定依赖版本)。

## Testing Decisions

**单一 smoke test**(唯一测试 seam,追求"ideal number is one"):

```
test/widget_test.dart
```

```dart
void main() {
  testWidgets('splash shows yopet branding', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: YopetApp()));
    expect(find.text('yopet'), findsOneWidget);
  });
}
```

**测试哲学**:只测外部行为,不测实现细节。Splash 上有 "yopet" 文本 = 用户打开 app 看到品牌 = F2 端到端可用。Provider 内部状态、GoRouter 路由表、env.dart 常量值都是实现细节,不直接测。

**Hermetic test**:`tester.pumpWidget` 不调 `Supabase.initialize`,避免网络/cert 依赖。这样 `flutter test` 在无 Supabase、无网络的环境也能跑。

**前置闸门**:
- `flutter analyze` 必须零警告(语法/风格 gate)
- `flutter test` 必须通过(行为 gate)
- `flutter run -d windows` 启动 ≤ 60 秒可见 splash(运行时 gate,人工验证)

**Prior art**:yopet 仓库**没有**现有 test 文件,F2 smoke test 是第一个测试,无 prior art 可参考。

**F2 没有的测试**:
- 单元测试(`test/unit/`):F2 没有 model / service,无单元可测
- 集成测试(`integration_test/`):F2 不调 Supabase API,无集成场景
- Widget 测试覆盖每个 widget:F2 只有 1 个 widget,1 个 smoke test 已覆盖

## Out of Scope

- **F2 不写任何 Supabase 查询**:`auth.users` 没 bootstrap,F2 不可能调 auth API
- **F2 不写任何业务 UI**:Splash 之外没有屏
- **F2 不创建 Riverpod Provider**:无 state 需要共享,F3+ 才用 `@riverpod` 注解
- **F2 不创建任何 freezed / json_serializable 模型**:9 张 yopet 表在 F5 才建 schema
- **F2 不引入 Fraunces 字体文件**:splash 走系统字体,UI 原型阶段加 asset bundle
- **macOS / iOS target**:本机无 Xcode;ADR-0004 列出但 F2 defer
- **Supabase auth migration**:`auth.users` 表 bootstrap、GoTrue 配置、邮箱验证流程——这些是 F3 范围
- **Inbucket 邮件验证**:Aug 4 supabase/supabase 把 Inbucket 从主 compose 文件移除(详见 `docs/setup/local-supabase.md` §11.2);F2 无 Inbucket 端点
- **Postgres pooler 54322 端口的 psql 直连**:supabase/supavisor:2.9.5 镜像 `tini` binary 损坏,`localhost:54322` 永远不通;F2 的 Postgres 验证通过 `docker exec supabase-db psql` fallback(详见 `docs/setup/local-supabase.md` §11.3)
- **Kong API Gateway 返回 HTTP 200**:Kong 默认强制 auth,所有 route 返 401/403;真正 HTTP 200 需要 anon role schema 暴露(F5 范围,详见 `docs/setup/local-supabase.md` §11.4)

## Further Notes

### 与归档 spec 的关系

F2 的归档版本(`docs/.archive-superpowers/specs/2026-08-09-f2-flutter-scaffold-design.md`,commit `65770d8`)是用 superpowers:* 家族生成的,内容已被本 spec 取代。归档 commit 出于审计保留,**不**作为 F2 实施依据。实施者读本 spec。

### grill 决策映射

本 spec 的 7 项核心决策来自 `grill-with-docs` session(Q1–Q7),对话历史保留:

| Q | 决策 | 落到 spec 的哪节 |
|---|---|---|
| Q1 | F2 就装 go_router | go_router 配置 |
| Q2 | URL 默认 54321 + run-dev.ps1 wrapper | env.dart + run-dev.ps1 接口 |
| Q3 | Android emulator URL 用 10.0.2.2 翻译 | run-dev.ps1 -Platform 参数 |
| Q4 | Riverpod codegen 推迟到 F3+ | 依赖 / 不装 codegen 决策 |
| Q5 | F2 平铺 + STRUCTURE.md 升级触发器 | 项目结构 + STRUCTURE.md 决策 |
| Q6 | 模型 codegen (freezed/json_serializable) 推迟到 F5 | 依赖 / 不装 codegen 决策 |
| Q7 | splash 颜色从 tokens.dart 读 const | splash 颜色源决策 |

### F2 验收对应 issue #2

| issue #2 acceptance | spec 落地 | 状态 |
|---|---|---|
| `flutter create` 成功 | 实施步骤 1 | ✓ 待执行 |
| pubspec.yaml 含 supabase_flutter | 依赖 / supabase_flutter: ^2.5.0 | ✓ 待执行 |
| main.dart Supabase client 初始化 URL=http://localhost:54321 + anon key | 启动流程 + env.dart | ✓ 待执行(URL 默认值沿用 54321) |
| 至少一个 target 能 flutter run | targets + run-dev.ps1 | ✓ 待执行(Windows + Android) |
| 首屏显示 yopet splash,无运行时错误 | splash + smoke test | ✓ 待执行 |
| build 无 lint 错误 | flutter analyze gate | ✓ 待执行 |
| ~~`dart run build_runner build` 通过~~ | (Q4/Q6 取消,F2 无 codegen) | ❌ **取消** |

**新增 F2 验收**(grill 后产生):

- [ ] `run-dev.ps1` 在 yopet/ 根,可执行,默认 Windows,接受 `-Platform android` 和 `-Url`
- [ ] `docs/setup/STRUCTURE.md` 写明"F3 起第 2 个 feature 出现时,从平铺升级为 `lib/features/<name>/`"
- [ ] `lib/core/theme/tokens.dart` 定义 `primaryBg` 和 `tankGlow` 两个 const(不是空占位)
- [ ] `lib/` 平铺,无 `features/` 目录
- [ ] `pubspec.lock` commit 进 git

### F2 与下游

F2 关闭后,issue #2 close + F3 (issue #3 邮箱登录)可以开始。F3 + 后续 feature 引用本 spec 的 §"项目结构" 和 STRUCTURE.md。

### 参考

- `docs/agents/triage-labels.md` — issue tracker label 映射(本 spec 不引入新 label)
- `docs/setup/local-supabase.md` — §11 记录本机 F1 实际状态(端口 54331、Inbucket 缺失、pooler tini 损坏、Kong auth 强制),F2 通过 `run-dev.ps1` 适配
- `docs/design/ui-design.md` — §3 palette token 来源(tokens.dart 的 2 个 const 引用)
- `CONTEXT.md` — 领域术语(F2 阶段不引入新术语;F3+ 模型时引用)
- `docs/adr/0004-backend-supabase-self-hosted.md` — 单 Flutter codebase + Supabase 自托管
- `docs/adr/0002-cloud-sync-with-account.md` — 多设备账号同步
