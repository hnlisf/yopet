# yopet F2 — Flutter 项目骨架 + supabase_flutter

> 状态: 等待用户审阅
> 作者: 2026-08-09 与用户共同 brainstorm
> 关闭: [#2](https://github.com/hnlisf/yopet/issues/2)
> 实现: ADR-0004(单 Flutter codebase)、ADR-0002(Supabase 后端)

## 背景

yopet 仓库目前是**纯文档仓库**:有 PRD/CONTEXT/ADR/ui-design/CLAUDE.md/specs/plans,但**没有 `lib/`、`pubspec.yaml`、任何 Flutter 源文件**。F2 是把仓库从文档状态变成可运行 Flutter 项目的第一步。

F1 已完成(commit `fd5e34c`,issue #1 closed),Supabase 栈在本机跑得起来(Kong API Gateway 54331 上响应;`supabase-local/` 11 张镜像已拉、10 容器 healthy,pooler 因镜像 `tini` binary 损坏被 `--scale=0` 跳过——见 runbook §11.3)。F2 把 Flutter 客户端骨架立起来后,F3 的登录流程就能直接连这个后端。

## 目标

把 yopet 仓库变成可运行的 Flutter 项目,做到:

1. `flutter pub get` 通过、`flutter analyze` 零警告、`flutter test` 通过
2. `flutter run -d windows` 启动后看到 splash 屏(深色画布 + "yopet" 文字)
3. `flutter build apk --debug` 通过(Android target)
4. Supabase client 已初始化(URL + anon key 可配置),未发起任何 API 请求
5. `theme/tokens.dart` 留空占位,等 UI 原型阶段填
6. `.gitignore` 含 Flutter 标准项,`pubspec.lock` 进 git

## 范围内 (Scope in)

- 用 `flutter create` 在现有 yopet/ 目录里初始化 Flutter 项目(macOS 目录跳过——本机非 Mac)
- 加 `pubspec.yaml` 的 §"依赖"列出的所有 packages
- 写 `lib/main.dart`、`lib/app.dart`、`lib/core/{env,supabase,router}.dart`、`lib/features/splash/splash_screen.dart`、`lib/core/theme/tokens.dart`(空占位)
- 1 个 widget smoke test
- 把 `.gitignore` 改成 Flutter 项目标准
- 在 `README.md`(新建)写最小启动说明

## 范围外 (YAGNI)

| 项 | 排除理由 |
|---|---|
| 真正的视觉设计(暗画布 glow + Fraunces 字体)| UI 原型阶段(§6.1)负责,F2 只 hardcode 颜色 hex + 系统字体 |
| 任何业务 UI、屏、navigation | F3+ 范围 |
| Supabase schema 迁移、Fish/Tank 模型 | F5 范围,F2 只 init client 不 query |
| Riverpod `supabaseClientProvider` | F2 用 `supabase_flutter` 自带的全局静态 client;F3+ 需要 mock 时再加 Provider 包装 |
| 任何 `models/`、`services/` 目录 | F3+ 才有意义 |
| macOS / iOS target | 本机无 macOS / iOS 工具链;ADR-0004 列出但 F2 不实现 |
| `flutter_dotenv` 或运行时 .env 读取 | dart-define 是更标准的做法,见 §"配置" |
| ESLint / pre-commit hooks / CI | F12 / 后续 ticket |
| Inbucket / Studio / 邮件验证 | F1 已知 gap;F2 不动这些端点的任何代码 |

## 决策记录(brainstorm 2026-08-09)

| 维度 | 选型 | 备选 |
|---|---|---|
| 状态管理 | **Riverpod 2.x**(含 codegen) | flutter_bloc、原生 setState+InheritedWidget、Provider 6 |
| 项目结构 | **Feature-first** (`lib/features/<feature>/`) | Layer-first、Hybrid |
| 路由 | **go_router 14.x**(从 F2 启用) | auto_route、不装路由(F3 再装) |
| 代码生成 | **装工具链但不写模型**(`freezed` + `json_serializable` + `build_runner`,F5 再用) | 现在写示例模型、F5 再装 |
| Supabase URL/key 配置 | **`--dart-define` + 默认 54331**(`SUPABASE_URL` 和 `SUPABASE_ANON_KEY`) | `flutter_dotenv` 读 .env、hardcode 54331 |
| Target platforms | **Windows + Android** | 仅 Windows、三平台加 iOS |
| .gitignore | **Flutter 标准全套,commit `pubspec.lock`** | ignore lock、最小集 |

## 架构

### lib/ 目录布局

```
lib/
├── main.dart                       # WidgetsFlutterBinding + Supabase.initialize + runApp
├── app.dart                        # ProviderScope + MaterialApp.router
├── core/
│   ├── env.dart                    # SUPABASE_URL / SUPABASE_ANON_KEY dart-define 常量
│   ├── supabase.dart               # 文档注释:Supabase.instance.client 用法
│   ├── router.dart                 # routerProvider (GoRouter 单 route)
│   └── theme/
│       └── tokens.dart             # 占位空文件 (UI 原型阶段填)
└── features/
    └── splash/
        ├── splash_screen.dart      # 唯一屏幕 — 暗背景 + 'yopet' 文字
        └── providers.dart          # 空文件,F3+ 再用
```

### 启动流程(数据流)

```
用户跑: flutter run -d windows --dart-define=SUPABASE_URL=http://localhost:54331 --dart-define=SUPABASE_ANON_KEY=<jwt>
                       ↓
                main.dart main()
                       ↓
        WidgetsFlutterBinding.ensureInitialized()
                       ↓
        Supabase.initialize(url, anonKey)
                       ↓
                 runApp(YopetApp())
                       ↓
       YopetApp.build() ← ConsumerWidget
                       ↓
         ProviderScope 包裹 MaterialApp.router
                       ↓
              routerProvider 提供 GoRouter
                       ↓
            initialLocation: '/' → SplashScreen
                       ↓
                 显示 'yopet' 文字
```

**关键决策**:`supabase_flutter` 把 client 做成全局静态 `Supabase.instance.client`,**F2 不创建 Riverpod Provider**。等 F3+ 需要在 widget 测试里 mock Supabase client 时,再加 `supabaseClientProvider`。

## 依赖(pubspec.yaml)

### dependencies

```yaml
flutter_riverpod: ^2.5.0
riverpod_annotation: ^2.3.0
supabase_flutter: ^2.5.0
go_router: ^14.0.0
freezed_annotation: ^2.4.0
json_annotation: ^4.9.0
```

### dev_dependencies

```yaml
flutter_test:
  sdk: flutter
flutter_lints: ^4.0.0
riverpod_generator: ^2.4.0
build_runner: ^2.4.0
freezed: ^2.5.0
json_serializable: ^6.8.0
```

### 关键 package 角色

| Package | 作用 |
|---|---|
| `supabase_flutter` | Supabase client + 自动 token 持久化(SecureStorage on mobile,shared_preferences on web) |
| `flutter_riverpod` | 状态管理 F3+ 用 |
| `riverpod_annotation` + `riverpod_generator` | `@riverpod` 注解,生成 `.g.dart` |
| `go_router` | F2 单 route `/`,F3+ 加 auth/tank/fish 路由 |
| `freezed_annotation` + `freezed` | F5+ Fish/Tank 模型用 |
| `json_annotation` + `json_serializable` | F5+ 模型 JSON 序列化用 |

## 配置(env.dart + dart-define)

```dart
// lib/core/env.dart
class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://localhost:54331',  // §11.1 NAT cache workaround
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
}
```

**默认 54331** 而不是 54321:沿用 runbook §11.1 workaround 偏移。§11.6 daemon 重启后只需改这里 defaultValue 为 `http://localhost:54321`。

**默认 anon key 空字符串**:`supabase_flutter` 在 init 时校验非空。空默认意味着 F2 阶段的 run 必须显式传 dart-define——这是**有意把密钥从源码里隔离出去**,不进 git。

**验证命令**:
```powershell
$ANON = = (Get-Content ../supabase-local/docker/.env | Select-String -Pattern '^ANON_KEY=').ToString().Split('=',2)[1]
flutter run -d windows --dart-define=SUPABASE_URL=http://localhost:54331 --dart-define=SUPABASE_ANON_KEY=$ANON
```

## .gitignore 改动

加以下行(已有项保留):

```
# Flutter
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
build/
.flutter-plugins
ios/Pods/
ios/.symlinks/
ios/Flutter/Flutter.framework
ios/Flutter/Flutter.podspec
macos/Pods/
macos/Flutter/ephemeral/
macos/Flutter/Flutter.framework
macos/Flutter/Flutter.podspec
windows/flutter/ephemeral/
windows/flutter/Flutter.dll
windows/flutter/Flutter.exe
android/.gradle/
android/local.properties
android/app/release/
android/key.properties
*.iml
```

**`pubspec.lock` commit 进 git**(社区惯例,锁定依赖版本,保证 CI 和本地一致)。

## Splash 屏

`lib/features/splash/splash_screen.dart`:

```dart
import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1620),  // --yopet-bg (ui-design.md §3)
      body: const Center(
        child: Text(
          'yopet',
          style: TextStyle(
            color: Color(0xFF5BA8B5),             // --yopet-tank-glow
            fontSize: 48,
            fontWeight: FontWeight.w600,         // 临时用系统字体
          ),
        ),
      ),
    );
  }
}
```

**故意 hardcode 颜色 hex**:`docs/design/ui-design.md` §3 的 8 个 token 在 UI 原型阶段才进 `theme/tokens.dart`,F2 splash 只需看上去对路。

## 测试

`test/widget_test.dart` 单测试:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yopet/app.dart';

void main() {
  testWidgets('splash shows yopet branding', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: YopetApp()));
    expect(find.text('yopet'), findsOneWidget);
  });
}
```

**没有 Supabase init**:测试里不调 `Supabase.initialize`,直接 mount widget。Splash 屏不依赖 Supabase。

## 实施步骤(8 步)

```
1. flutter create . --platforms=windows,android --org com.yopet --project-name yopet
2. 编辑 pubspec.yaml 加 §"依赖"列出的 packages;flutter pub get
3. 更新 .gitignore (Flutter 标准项)
4. 写 lib/core/env.dart
5. 写 lib/core/router.dart
6. 写 lib/features/splash/splash_screen.dart
7. 写 lib/main.dart + lib/app.dart
8. 写 test/widget_test.dart,跑 flutter analyze + flutter test,build apk --debug 验证
```

## 失败模式与回退

| 症状 | 行动 | 停止条件 |
|---|---|---|
| `flutter create` 报目录非空 | 加 `--project-name yopet` 不影响;若 .git 冲突用 `--no-overwrite` | 2 次重试后 STOP |
| `flutter pub get` 网络超时 | 重试一次;若 daemon 抽风按 runbook §7.1 重启 Docker | 2 次后 STOP |
| `dart run build_runner build` 报 codegen 错 | F2 没写模型,不应该报错;若报,说明 freezed/json_serializable 版本不匹配 | 检查 `^` 兼容性,pin 版本 |
| `flutter analyze` 报 `prefer_const_constructors` 等 lint | 修代码,不要 disable lint | 5 处以上报 STOP |
| `flutter run -d windows` 找不到 Windows 工具链 | 跑 `flutter doctor` 确认 desktop 已 enable;Windows 11 默认有 | 没装过 Flutter 桌面 SDK → STOP 装 |
| `flutter build apk --debug` Android SDK 缺 | 跑 `flutter doctor --android-licenses` 接受 + 安装 | 装环境不可行 → STOP |
| 运行时 Supabase.initialize 抛异常(URL/anonKey 错)| 检查 dart-define 传值(空 anon key 会抛) | 持续抛 → 校验 `.env` 路径 |

## yopet 落盘产物

1. 新文件:
   - `pubspec.yaml` + `pubspec.lock`
   - `analysis_options.yaml`(`flutter_lints` 默认)
   - `lib/main.dart`、`lib/app.dart`
   - `lib/core/env.dart`、`lib/core/router.dart`、`lib/core/supabase.dart`、`lib/core/theme/tokens.dart`
   - `lib/features/splash/splash_screen.dart`、`lib/features/splash/providers.dart`
   - `test/widget_test.dart`
   - `README.md`(最小启动说明)
2. 修改:`yopet/.gitignore`(加 Flutter 标准项)
3. flutter create 自动生成:`android/`、`ios/`(注:`flutter create --platforms=windows,android` 会创建)、`windows/`、`test/`、`analysis_options.yaml`、`pubspec.yaml`

**`analysis_options.yaml` 由 `flutter_lints` 自动提供**——`flutter_lints: ^4.0.0` 在 dev_dependencies 里,会自动用其推荐的规则集。

## 验收清单(对应 issue #2 acceptance)

- [ ] `flutter create .` 在 yopet/ 目录里成功
- [ ] `pubspec.yaml` 含 Riverpod + supabase_flutter + go_router + freezed + json_serializable 系列
- [ ] `flutter pub get` 成功
- [ ] `dart run build_runner build --delete-conflicting-outputs` 通过(无输出正常)
- [ ] `flutter analyze` 零警告
- [ ] `flutter run -d windows` 启动 splash 屏
- [ ] `flutter run -d android` 或 `flutter build apk --debug` 成功
- [ ] Splash 屏显示 "yopet" 文字,无运行时错误
- [ ] `flutter test` 通过
- [ ] `.gitignore` 含 Flutter 标准项,`pubspec.lock` 进 git
- [ ] issue #2 的 comment 字段里把 SUPABASE_URL 从 54321 改成 54331(或在 README 写明)

**issue #2 ticket text 已过期**:里面写 `URL=http://localhost:54321`,本机因 NAT cache 走 54331。F2 实施时**顺手更新 issue #2 body**,把 54321 改成 54331 + 加 dart-define 说明,或关 issue 时在 comment 里说明。

## 开放问题

无——7 个 brainstorm 决策都敲定了:

1. 状态管理:Riverpod 2.x
2. 项目结构:Feature-first
3. 路由:go_router 14.x
4. Codegen:装 freezed/json_serializable 工具链,不写模型
5. URL 配置:dart-define + 默认 54331
6. Target:Windows + Android
7. .gitignore:Flutter 全套,commit pubspec.lock

唯一遗留:**Flutter SDK 安装**——runbook §11 没装过,issue #2 acceptance 第 1 条"`flutter create yopet` 成功"假设用户已装。F2 执行前需用户先装 Flutter SDK(Windows: https://docs.flutter.dev/get-started/install/windows)。

## 参考

- [Issue #2](https://github.com/hnlisf/yopet/issues/2) — 原始 ticket
- [ADR-0004](../adr/0004-backend-supabase-self-hosted.md) — 单 Flutter codebase + 自托管 Supabase
- [ADR-0002](../adr/0002-cloud-sync-with-account.md) — 多设备同步的账号基础
- [ui-design.md](../design/ui-design.md) — splash 屏引用了 §3 palette token
- [CONTEXT.md](../../CONTEXT.md) — 领域术语(F3+ 模型用)
- [PRD.md §6.1](../../PRD.md) — UI 原型阶段排在 F2 之后、F3 之前
- [local-supabase.md §11](../../setup/local-supabase.md) — 端口 54331 workaround、ES256 keys 流程
- 记忆 `project-yopet-docker-desktop-crash` — F1 实际状态