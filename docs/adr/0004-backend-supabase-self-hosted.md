# ADR-0004 — 后端栈:Supabase,通过 Docker 自托管

yopet 的后端是 Supabase,自托管部署(Docker Compose),而不是用 Supabase Cloud。Supabase 在一个内聚的栈里给我们 Postgres、Auth(含 Apple / Google / Magic Link)、Storage、Realtime;Flutter 官方的 `supabase_flutter` SDK 直接对接。自托管的选型理由是 ADR-0002 把鱼的数据标为个人数据——数据存在我们自己能控制的基础设施上,没有第三方读访问,有清晰的数据驻留(数据主权)叙事。我们接受随之而来的运维负担(Docker、反向代理、HTTPS、备份)作为这种控制权的代价。

**后果**:需要一个 Linux 主机(VPS / NAS / 专用机)、一个会自动续签证书的反向代理、自动化的 Postgres 备份、以及未来换主机时的迁移计划。`supabase_flutter` SDK 本身在自托管和 Cloud 之间不变——只换 project URL 和 anon key。Schema、RLS、Edge Functions 也不变。以后迁移到 Supabase Cloud 是机械式操作:Postgres 数据库 dump-and-restore、拷 Storage 桶、Flutter 应用里换 URL + key、上线。