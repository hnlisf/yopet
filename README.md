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
- [UI 设计说明](docs/design/ui-design.md)
