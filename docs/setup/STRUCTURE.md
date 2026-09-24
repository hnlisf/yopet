# Yopet 应用结构与平台目标

> 状态：生效
> 关联：[ADR-0004](../adr/0004-backend-supabase-self-hosted.md)、
> [数据库工作流](./database-workflow.md)

Yopet 使用单一 Flutter 代码库和 Supabase 后端。领域模块按能力划分，跨模块
服务放在 core/，不会把 UI、远程持久化和领域计算混在一个文件里。

~~~
yopet/
├── lib/
│   ├── app.dart / main.dart / splash_screen.dart
│   ├── core/                    # 路由、环境、Supabase 与主题 token
│   ├── data/                    # 静态装饰目录
│   └── features/
│       ├── auth/                # 邮箱身份与会话桥接
│       ├── fish/                # 领养、自定义鱼、图层与持久化
│       ├── home/                # 鱼缸、游动档案、首页原型
│       ├── feeding/             # 单鱼/整缸投喂与饱腹度
│       ├── decorations/         # 装饰目录、位置、缩放与图层
│       ├── presence/            # 当前在场互动
│       ├── weather/             # 城市天气与氛围
│       └── temperature/         # 水温匹配与编辑器
├── supabase/                    # 版本控制的迁移、种子与 pgTAP 测试
├── test/                        # Dart/Widget 回归测试
└── android/ ios/ linux/ macos/ web/ windows/
                                # 由 Flutter 生成的平台壳
~~~

## 依赖方向

1. UI 组件可以读取本 feature 的 provider、模型和 repository。
2. repository 负责 Supabase 查询/写入；模型负责映射和领域值对象。
3. core/ 不依赖任何 feature；feature 之间通过明确的模型或 provider 协作。
4. 数据库行为只在 supabase/migrations/ 和 supabase/tests/ 中定义。

## 平台承诺与验证

PRD 覆盖 Android、iOS、Windows、macOS、Linux；Web 是本地体验和设计验证入口。
所有平台壳已存在，CI 在对应操作系统上分别构建 Android debug APK、Linux、
Windows、macOS 和 unsigned iOS bundle。签名、商店上传和真实设备分发仍是
发布阶段的单独工作，不会由 CI 使用开发密钥代替。

在具备对应工具链的机器上，使用 run-dev.ps1 的 Platform 参数启动 Windows、
Android、iOS、Linux、macOS 或 Web。Android 模拟器仍会自动将 localhost
改为 10.0.2.2；其他设备使用显式 Url 参数连接可达的 Supabase 地址。
