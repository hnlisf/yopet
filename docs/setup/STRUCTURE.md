# yopet lib/ 结构与迁移触发器

> 状态: 生效
> 关联: [F2 spec §"项目结构"](../specs/2026-08-09-f2-flutter-scaffold.md)
> 适用: F2 (单 feature) 起,直到迁移触发条件命中

## 当前结构(F2)

yopet 是 Flutter 单 codebase(ADR-0004),F2 阶段只有 1 个屏,`lib/` 平铺:

```
yopet/
├── lib/
│   ├── main.dart                # 入口: Supabase.initialize + runApp
│   ├── app.dart                 # ProviderScope + MaterialApp.router
│   ├── splash_screen.dart       # 唯一屏
│   └── core/
│       ├── env.dart             # SUPABASE_URL / SUPABASE_ANON_KEY
│       ├── router.dart          # GoRouter 单 route /
│       ├── supabase.dart        # 注释:Supabase.instance.client 用法
│       └── theme/
│           └── tokens.dart      # primaryBg + tankGlow 两个 const
└── test/
    └── widget_test.dart         # 1 个 smoke test
```

`features/` 目录**不存在**——YAGNI 决策,1 个 feature 占空目录是过度工程化(grill Q5)。

## 迁移触发条件

出现以下任一情况时,从平铺升级为 `lib/features/<name>/`:

1. **第 2 个 feature 屏出现**(典型:F3 sign-in 加 `lib/features/auth/`)
2. **同一目录下文件数 > 8**(平铺的命名空间开始拥挤)
3. **某个文件 > 300 行**(单文件职责过载)

**简言之**:加第 2 个 feature 时升级。

## 迁移步骤(供参考)

升级是 mechanical,顺序敏感:

1. `mkdir -p lib/features/<feature-name>`
2. 移动 feature 专属文件:`mv lib/<name>_screen.dart lib/features/<feature-name>/<name>_screen.dart`
3. 调整 import 路径(相对路径变长)
4. 若该 feature 有专属 provider/widgets:`mkdir lib/features/<feature-name>/{providers,widgets}/`
5. 更新 `app.dart` 或 `router.dart` 的引用
6. 删除平铺的旧文件
7. 更新本文件:`当前结构`节改为新的 features/ 树
8. 跑 `flutter analyze` 确认零警告
9. 跑 `flutter test` 确认 smoke test 仍然通过

## 不属于迁移触发器的场景

- **新加 widget 但仍属同一 feature**:不迁移,加在 `lib/<existing_feature>/widgets/` 或 `lib/widgets/`
- **新加 core 工具**(新的 env var、新的 router):加在 `lib/core/`,不动 features/
- **新加主题 token**:加在 `lib/core/theme/tokens.dart`,不动 features/
- **重构 SplashScreen**:只要还在 1 个 feature 内,不迁移

## 与 F2 spec 的关系

本文件是 F2 spec §"项目结构"的实施细化。F2 spec 给"平铺,features/ 不创建"的原则,本文件给"何时 + 怎么"退出平铺。两份文件**同时维护**,spec 不动,本文件随项目演化。

参考: [F2 spec §"项目结构"](../specs/2026-08-09-f2-flutter-scaffold.md)、[ADR-0004 单 Flutter codebase + Supabase 自托管](../adr/0004-backend-supabase-self-hosted.md)。