# Yopet

Yopet 是一款以低压力陪伴为核心的跨平台养鱼应用：注册后拥有一个鱼缸，
可以领养、命名与照料鱼，也可以通过水温、天气、装饰和自定义鱼种营造自己的水下空间。

## 支持的平台

- Android、iOS
- Windows、macOS、Linux
- Web（用于本地预览和设计验证）

持续集成会构建 Android、Linux、Windows、macOS 和未签名 iOS 包；商店签名与分发
使用部署密钥，不存放在仓库中。

## 本地启动

安装 Flutter 后，在仓库根目录运行：

~~~powershell
flutter pub get
.\run-dev.ps1 -Platform windows
~~~

`run-dev.ps1` 会读取相邻 `supabase-local/docker/.env` 中的本地 Supabase 地址与
客户端 publishable key。也可切换到 `android`、`ios`、`linux`、`macos` 或 `web`：

~~~powershell
.\run-dev.ps1 -Platform web -WebPort 4196
~~~

完整的本机 Supabase 运行说明见
[本地 Supabase 手册](docs/setup/local-supabase.md)。邮箱确认与生产 SMTP 配置见
[生产认证检查表](docs/setup/production-auth.md)。

## 验证

~~~powershell
flutter analyze
flutter test
~~~

或运行统一的本地验收入口（使用已安装依赖，不部署、不读取凭据、不重置数据库）：

~~~powershell
.\verify-local.ps1
# 仅分析与测试：.\verify-local.ps1 -SkipWebBuild
# Flutter 不在 PATH 时：.\verify-local.ps1 -FlutterPath 'D:\path\flutter.bat'
~~~

Web release 构建只验证编译，不代表已配置生产认证或可直接上线。

数据库的迁移、种子数据与 pgTAP 测试以 `supabase/` 为唯一版本控制来源。在可丢弃的
Supabase CLI 本地栈中执行：

~~~powershell
supabase start
supabase db reset --local
supabase db lint --local --level error --fail-on error
supabase test db
~~~

`supabase db reset --local` 会删除该 CLI 本地栈的数据，不要对正在使用的鱼缸数据库
直接执行。具体约定见[数据库工作流](docs/setup/database-workflow.md)。

## 项目文档

- [产品需求](PRD.md)
- [应用结构与平台目标](docs/setup/STRUCTURE.md)
- [数据库工作流](docs/setup/database-workflow.md)
- [生产认证检查表](docs/setup/production-auth.md)
- [Windows 桌面测试说明](docs/setup/windows-testing.md)
- [UI 设计说明](docs/design/ui-design.md)

## Windows 本地测试包

关闭正在运行的 Release 程序后执行 `./package-windows.ps1`。
脚本先分析和测试，再构建并打包完整运行目录；`artifacts/` 中生成带时间戳的 zip
与校验清单。此包连接本地开发后端，不是签名的生产安装包。

## 性格陪伴互动（第一步）

在鱼附近的空白水域点击，可轻唤最多两条鱼；回应具有性格化延迟、接近距离和停留。
鱼图像仍打开档案，布景仍支持选择和编辑。轻唤有五秒冷却，不保存长期好感或互动历史。
详见 [行为说明](docs/specs/2026-10-06-companion-behavior.md)。
