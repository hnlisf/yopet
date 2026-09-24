# Yopet 数据库迁移与验证流程

/supabase 是 Yopet 领域数据库的唯一受版本控制来源：迁移、种子数据和
自动化 pgTAP 测试必须在这里维护。以前存在于临时工作区的 SQL 已迁入该
目录；临时工作区和本机 Docker 配置都不再是迁移来源。

## 开发与 CI

在可丢弃的 Supabase CLI 本地栈中，从仓库根目录依次执行：

~~~powershell
supabase start
supabase db reset --local
supabase test db
supabase db lint --local --level error --fail-on error
~~~

db reset 会删除该 CLI 本地栈的数据，因此不能对正在使用的鱼缸数据库
直接运行。需要把既有本地数据迁入新环境时，先做备份和演练，再单独执行
数据迁移；不要以复制 SQL 文件代替迁移记录。

CI 用完全新建的本地数据库执行同一组迁移和 pgTAP 检查。当前回归用例
覆盖：基础领域表、fish RLS、wave 在约束和触发器中的一致性、本人保存
波浪纹自定义鱼，以及其他用户不可读取该鱼；还覆盖整缸投喂的 25 点上限与
逐鱼日志、跨鱼缸投喂拒绝、送别的 owner-only 删除，以及投喂/成长日志级联
清理。

## 迁移约定

1. 只新建 supabase/migrations/<UTC 时间戳>_<说明>.sql，不重写已应用迁移。
2. 修改 RLS、校验约束、触发器或 RPC 时，要添加/更新
   supabase/tests/database/ 下的 pgTAP 用例。
3. 种子目录只保存开发参考数据，不能包含真实用户资料或密钥。
4. ../supabase-local 只负责本机 Docker 运行时及其私密配置，不能保存
   Yopet 领域 SQL。
