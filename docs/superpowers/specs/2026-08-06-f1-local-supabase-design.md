# yopet F1 — 本地 Supabase 开发环境

> 状态: 等待用户审阅
> 作者: 2026-08-06 与用户共同 brainstorm
> 关闭: [#1](https://github.com/hnlisf/yopet/issues/1)
> 实现: ADR-0004(后端 = Supabase,自托管)

## 背景

yopet 的 F1(issue #1,状态原为 `ready`)要求一个本地可跑的 Supabase 栈,以便后续 F2–F12 features 能在真实端点(而不是 mock)上开发。截至 2026-08-06,本机的 Docker Desktop 因 WSL store 损坏而无法运行(见记忆 `project-yopet-docker-desktop-crash`);已通过轻量修复路径(无数据盘重置)解决,所以 F1 可在现有容器运行时上推进。

用户已在 Aug 4 把官方 `supabase/supabase` monorepo clone 到 `d:/myworkspace/claude-workspace/supabase-local/`(commit `1123a748`,master)并把 `docker/.env.example` 拷成 `docker/.env`。剩下要做的是 `docker compose pull && up -d` + 端点验证。

## 目标

一个可复现的本地 Supabase 栈:

1. 通过 `docker compose up -d` 拉起 Postgres + GoTrue + PostgREST + Realtime + Storage + Studio + Inbucket
2. 通过 issue #1 列出的全部 8 条验收标准
3. 在 yopet 仓库留下一份 runbook,记录具体命令 + Docker Desktop/WSL 恢复步骤,下次会话不必重新摸索
4. 把 F1 状态从 `ready` 改为 `done`(在 `PRD.md` §6),并通过 `gh` 关闭 issue #1

## 范围内 (Scope in)

- 拉取与 Aug 4 commit 钉死的镜像(不 `git pull`)
- 后台 `docker compose up -d`
- 健康检查轮询,最多 5 分钟,超时大声失败
- 验证 issue #1 的 4 个端点(Studio、API Gateway、Postgres、Inbucket)
- 撰写 `yopet/docs/setup/local-supabase.md` runbook
- 更新 `yopet/PRD.md` §6 行 F1 状态为 `done`
- 通过 `gh issue close 1 -c "..."` 关闭 issue #1

## 范围外 (YAGNI)

| 项 | 排除理由 |
|---|---|
| yopet 9 张表的 schema migrations | F1 = 空库;schema 留给后续 ticket |
| `.env` 数值覆盖 | local-dev 默认值已够;改值会引入"我之前改过啥"的认知负担 |
| `git pull` supabase-local/ | 已锁定不变;可复现性 > 时效性 |
| 把 supabase-local 变 yopet 子模块 | 当前 sibling 布局可用;引入 submodule = 新故障面 |
| `up` 后立即 `supabase db reset` | 此时还没 schema,reset 是 no-op |
| 生产硬化(TLS、备份、secrets) | 那是 prod-stack 工作,不属于 F1 |

## 实施步骤(共 8 步)

步骤 1–8 是运行时阶段;落盘的工件和 issue 关闭在第 8 步之后做。

```
1. cd d:/myworkspace/claude-workspace/supabase-local/docker
2. docker compose pull          # ~30 张镜像,5–8 GB,5–10 分钟
3. docker compose up -d         # 后台启动
4. 轮询 docker ps 健康检查 (~60–120 秒预期)
5. curl http://localhost:54323 (Studio) — 期望 HTTP 200
6. curl http://localhost:54321 (API)   — 期望 HTTP 200
7. PGPASSWORD=postgres psql -h localhost -p 54322 -U postgres -c '\l' — 期望列出库
8. curl http://localhost:54324 (Inbucket) — 期望 HTTP 200
```

**收尾阶段**(第 8 步之后):

9. 按 "Yopet 落盘产物" §1 写 `yopet/docs/setup/local-supabase.md`
10. 更新 `yopet/PRD.md` §6 行 F1:状态 → `done`,链向新文档
11. 提交 docs(`docs:` scope),然后 `gh issue close 1 -c "..."`

## 失败模式与回退

| 症状 | 行动 | 停止条件 |
|---|---|---|
| `docker compose pull` 网络超时 | 重试一次 | 重试仍失败 → 让用户查代理/VPN |
| 容器达不到 `healthy` | `docker logs <name>`,重试一次 | 2 次重试后 → STOP,回到根因调查 |
| 端口已被占用 | `Get-NetTCPConnection` 找占用进程;释放或改 `docker/.env` `*_PORT` 变量 | 如需改值,在 runbook 里记下来 |
| 同一组件反复失败 | STOP — "3+ 修复 → 质疑架构" | 跟用户讨论后再继续修 |

## yopet 落盘产物

1. `yopet/docs/setup/local-supabase.md` — runbook 含:
   - 前置条件(Docker Desktop 4.x+、WSL2 启用、端口 54321/22/23/24 空)
   - **WSL/Docker Desktop 恢复 playbook**(指纹 + 5 步修复)— 杠杆最大的知识,留给未来会话
   - 运行时命令(cd,`docker compose pull`,`docker compose up -d` 三件套)加注释
   - 端点速查表(端口 → 服务 → PRD/ADR 交叉引用)
   - "能做什么 / 不能做什么"边界声明
2. `yopet/PRD.md` §6 行 F1:状态 → `done`,链向新文档

## 验收标准(逐字来自 issue #1)

- [ ] Docker Desktop 已安装并运行
- [ ] 仓库 `supabase/supabase` 已 clone 到本地(用 `--depth 1` 加速)
- [ ] `docker/.env` 已从 `.env.example` 复制
- [ ] `docker compose up -d` 成功,所有容器 healthy
- [ ] http://localhost:54323(Studio)加载,显示空项目
- [ ] http://localhost:54321(API Gateway)返回 200
- [ ] localhost:54322(Postgres)可用 psql 连接
- [ ] http://localhost:54324(Inbucket)可看到验证邮件

issue #1 的关闭评论应引用 runbook 路径。

## 开放问题

无 — 两个范围决策在 brainstorm 阶段都敲定了:

1. 范围 = 严格 issue #1(无 schema seed)— 用户选 A
2. Clone 处理 = Aug 4 clone 原样用,不要 `git pull` — 用户选"原地"

## 参考

- [Issue #1](https://github.com/hnlisf/yopet/issues/1) — 原始 ticket
- [ADR-0004](../adr/0004-backend-supabase-self-hosted.md) — 为何选自托管
- 记忆:`project-yopet-docker-desktop-crash` — 刚刚解决的、给 F1 解锁的 WSL 损坏
- 工作 scratch:`yopet/.scratch/prd-spec.md` — 9 张表 schema,**不属于** F1