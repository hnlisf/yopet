# F1 — 本地 Supabase 实施计划

> **给 agent 执行者:** 必备子技能: 使用 `superpowers:subagent-driven-development`(推荐)或 `superpowers:executing-plans` 按本计划 task-by-task 实施。步骤用 checkbox(`- [ ]`)语法标记。

**目标:** 在本地拉起官方 `supabase/supabase` docker-compose 栈,并证明四个运营端点(Studio、API Gateway、Postgres、Inbucket)都返回 healthy。然后把过程记到 runbook 里,关闭 issue #1。

**架构:** 运营型 task,不是代码项目。我们在已有的 `d:/myworkspace/claude-workspace/supabase-local/` clone 上(Aug 4 commit `1123a748`,**不要** `git pull`)做 `docker compose pull && docker compose up -d`。轮询直到所有容器 `healthy`。验证四个端点。撰写一份 runbook,内容覆盖前置条件 + 刚发现的 WSL 恢复方法。更新 PRD 状态,关闭 issue。

**技术栈:**
- Docker Desktop(刚通过 5 步 WSL 恢复 — 记忆 `project-yopet-docker-desktop-crash`)
- `docker compose`(Docker Desktop 自带;v2,**不要**老的 `docker-compose` v1)
- `supabase/supabase` monorepo,`docker/` 目录
- `gh` CLI(根据 yopet `CLAUDE.md` 走 issue tracking)
- PowerShell 做 PSQL 后端(或 WSL 内的 postgres-client)

## 全局约束

以下约束从[这份 spec](docs/superpowers/specs/2026-08-06-f1-local-supabase-design.md)和 `ADR-0004` 逐字复制。每个 task 的要求隐式包含本节。

- **Aug 4 clone 原样用。** 不要 `git pull` `supabase-local/` — 镜像 tag 和模板变量钉死在 `1123a748` commit。
- **不要删** `%LOCALAPPDATA%\Docker\wsl\disk\docker_data.vhdx`(数据盘即便为空也可能长到 17–20 GB,保留它)。
- **范围** = 严格 issue #1 的验收标准。不动 `yopet.*` schema migrations、不改 `.env` 默认值、不引入 submodule。
- **重试预算**: 每个 task、每个组件最多 2 次重试。3+ 次失败 → STOP,回到 `superpowers:systematic-debugging` 的 Phase 1 重新调查。
- **compose 命令的工作目录** = `d:/myworkspace/claude-workspace/supabase-local/docker/`。compose 命令都从这里执行。
- **issue tracker** = GitHub,通过 `gh` CLI。yopet `CLAUDE.md` 写明 "Issues live in this repo's GitHub Issues, accessed via the `gh` CLI."
- **Yopet commit 规范** = conventional commits(本仓库此前 commit:`chore: initial commit (agent skills scaffolding)`、`docs(superpowers): ...`、`docs(prd): ...`)。
- **每条 commit 消息以** `Co-Authored-By: Claude <noreply@anthropic.com>` 结尾。

---

## Task 1: 拉取所有 Supabase 镜像

**Files:** 无(纯运营)

**Interfaces:** 无(不碰任何 yopet 文件;Docker 镜像缓存就是产出)

- [ ] **Step 1: 验证 Docker daemon 响应**

Run:

```bash
docker info --format 'Server:{{.Server.Version}}'
```

Expected: 输出 `Server:29.6.2`(或类似)。如果报 "Cannot connect to the Docker daemon",从开始菜单打开 Docker Desktop,等托盘图标变绿,再重试。

- [ ] **Step 2: 验证当前镜像缓存为空(failing precondition)**

Run:

```bash
docker images --format '{{.Repository}}:{{.Tag}}' | grep -c 'supabase\|postgres\|gotrue\|kong\|postgrest' || true
```

Expected: `0`。如果非零,说明之前已经填过缓存 —— 这没问题,但可以确认 step 3 会走增量而非完整拉取。

- [ ] **Step 3: 运行 `docker compose pull`**

Run:

```bash
cd "d:/myworkspace/claude-workspace/supabase-local/docker"
docker compose pull
```

Expected output: 一串 `Pulling xxx Pull complete`,约 30 张镜像(Postgres 15、GoTrue、PostgREST、Realtime、Storage、Studio、Inbucket、Analytics/Logflare、Imgproxy、Supavisor/Pooler、pg-meta、Edge Runtime、Migrator 等)。首跑预期时长:5–10 分钟;缓存暖时 ~30 秒。

失败处理:

- 网络/代理超时 → 重试 ONCE;第二次失败 → STOP,回到 systematic-debugging Phase 1
- 拉 layer 出错 → 重跑 `docker compose pull`(从失败的 layer 续传),重试 ONCE;第二次失败 → STOP

- [ ] **Step 4: 验证 pull 落地**

Run:

```bash
docker images --format '{{.Repository}}:{{.Tag}}' | grep -E 'supabase|postgres|gotrue|kong|postgrest' | wc -l
```

Expected: 至少 `15` 张匹配镜像。(这是个模糊下界,因为 Supabase 的 compose 文件同时引用 `supabase/*` 和 `postgres:*` 镜像。)

- [ ] **Step 5: 无 commit 确认**

本 task 不动任何 yopet 源文件,所以没有 commit。镜像缓存存在 `%LOCALAPPDATA%\Docker\wsl\disk\docker_data.vhdx` 中,跨 commit 存活 —— 不用追踪。

---

## Task 2: 后台启动栈并等 healthy

**Files:** 无(运营型)

**Interfaces:**

- Consumes: Task 1 的镜像缓存
- Produces: ~30 个运行中的容器,端口 54321–54324,5 分钟内全部 `State: Up (healthy)`

- [ ] **Step 1: 验证 failing precondition —— 没有 Supabase 容器在跑**

Run:

```bash
docker ps --filter "label=com.supabase.project" --format '{{.Names}}'
```

Expected: 空行。如果非空,说明之前的 run 漏掉了容器 — Task 4 故障排查先 `docker compose down`,再继续。

- [ ] **Step 2: 后台启动栈**

Run:

```bash
cd "d:/myworkspace/claude-workspace/supabase-local/docker"
docker compose up -d
```

Expected output: 类似 `Container supabase-db-1 Started` 的汇总,~30 行,~10 秒返回。

- [ ] **Step 3: 轮询直到所有容器 healthy(≤ 5 min)**

Run(单 shell 命令):

```bash
cd "d:/myworkspace/claude-workspace/supabase-local/docker"
end=$(( $(date +%s) + 300 ))
while [ $(date +%s) -lt $end ]; do
  healthy=$(docker ps --filter "label=com.supabase.project" --format '{{.Status}}' | grep -c '(healthy)')
  total=$(docker ps --filter "label=com.supabase.project" --format '{{.Names}}' | wc -l)
  echo "$(date +%H:%M:%S) $healthy/$total healthy"
  if [ "$healthy" = "$total" ] && [ "$total" -gt 0 ]; then break; fi
  sleep 10
done
docker ps --filter "label=com.supabase.project" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

Expected output: 一段进度日志,最终所有行都是 `(healthy)`。常见时长:缓存暖时 60–120 秒。迁移容器(`supabase-db-1`)通常最慢,因为它首启时要跑 SQL migrations。

失败处理:

- 5 分钟后还不全 healthy → `docker ps --filter "label=com.supabase.project" --format '{{.Names}}\t{{.Status}}'` 找出滞后的,然后 `docker logs <name> --tail 50` 一次一个 debug。debug 2 个后回 Phase 1。

- [ ] **Step 4: 验证端口映射(健全性)**

Run:

```bash
powershell -NoProfile -Command 'Get-NetTCPConnection -LocalPort 54321,54322,54323,54324 -State Listen -ErrorAction SilentlyContinue | Select-Object LocalPort,OwningProcess | Format-Table -AutoSize'
```

Expected: 4 行,`LocalPort` 分别为 54321/54322/54323/54324,状态 `Listen`。任一端口缺失,说明对应服务没起 —— 在进 Task 3 之前先排查。

- [ ] **Step 5: 无 commit 确认**

同 Task 1。

---

## Task 3: 验证 issue #1 的 4 个端点

**Files:** 无(运营型)

**Interfaces:**

- Consumes: Task 2 跑起来的栈(端口 54321–54324)
- Produces: issue #1 全部 8 条验收 checkbox 的通过证据

- [ ] **Step 1: 验证 Studio (http://localhost:54323)**

Run:

```bash
curl -fsS -o /dev/null -w 'Studio HTTP %{http_code}\n' http://localhost:54323
```

Expected: `Studio HTTP 200`。30x(重定向)也可以接受,因为 Studio 可能重定向到 `/project/default`。

- [ ] **Step 2: 验证 API Gateway (http://localhost:54321)**

Run:

```bash
curl -fsS -o /dev/null -w 'API HTTP %{http_code}\n' http://localhost:54321/rest/v1/
```

Expected: `API HTTP 200`。(PostgREST 的 `/rest/v1/` 即便库为空也返回 200。)

- [ ] **Step 3: 验证 Postgres (localhost:54322)**

Run(假设 psql 在 PATH 上):

```bash
PGPASSWORD=postgres psql -h localhost -p 54322 -U postgres -c '\l' -A -t 2>&1 | head -10
```

Expected: 列出 `postgres`、`template0`、`template1`、`supabase_admin` 等数据库。

如果 psql 不在 PATH(这台 Windows 可能没装 postgres-client),回退到 Docker:

```bash
docker exec supabase-db-1 psql -U postgres -c '\l' -A -t 2>&1 | head -10
```

两种方式应该列出相同的库。

- [ ] **Step 4: 验证 Inbucket (http://localhost:54324)**

Run:

```bash
curl -fsS -o /dev/null -w 'Inbucket HTTP %{http_code}\n' http://localhost:54324/
```

Expected: `Inbucket HTTP 200`。

- [ ] **Step 5: 对照 issue #1 的 8 条验收标准**

这 4 个验证各对应 issue #1 中的两条 checkbox,逐一脑内打勾:

| # | 验收标准 | 验证来源 |
|---|---|---|
| 1 | Docker Desktop 已安装并运行 | Task 1 step 1 + Task 2 step 1(前置) |
| 2 | 仓库 `supabase/supabase` 已 clone 到本地 | 前置;`d:/myworkspace/claude-workspace/supabase-local/` 的 clone 早于本次会话 |
| 3 | `docker/.env` 已从 `.env.example` 复制 | 前置;`docker/.env` 已存在(与 `.env.example` 字节数完全一致,11773 bytes) |
| 4 | `docker compose up -d` 成功,所有容器 healthy | Task 2 step 3 |
| 5 | http://localhost:54323 (Studio) 加载,显示空项目 | Task 3 step 1 |
| 6 | http://localhost:54321 (API Gateway) 返回 200 | Task 3 step 2 |
| 7 | localhost:54322 (Postgres) 可用 psql 连接 | Task 3 step 3 |
| 8 | http://localhost:54324 (Inbucket) 可看到验证邮件 | Task 3 step 4 |

- [ ] **Step 6: 无 commit 确认**

同 Task 1。

---

## Task 4: 写 runbook + 更新 PRD 状态 + commit

**Files:**

- Create: `yopet/docs/setup/local-supabase.md`
- Modify: `yopet/PRD.md` §6 行 F1(当前 `status: ready`)

**Interfaces:**

- Consumes: 来自记忆 `project-yopet-docker-desktop-crash` 的 WSL 恢复方法;Task 3 确认的端点列表
- Produces: 一份 runbook,另一个 agent 从干净 Windows 装机即可用;一份更新过的 PRD,反映 F1 真实状态

- [ ] **Step 1: 验证 failing precondition —— runbook 还不存在**

Run:

```bash
ls "d:/myworkspace/claude-workspace/yopet/docs/setup/local-supabase.md" 2>&1
```

Expected: `No such file or directory`。

- [ ] **Step 2: 验证 failing precondition —— PRD §6 行 F1 还是 `ready`**

Run:

```bash
grep -n '| F1 | Local dev environment' "d:/myworkspace/claude-workspace/yopet/PRD.md"
```

Expected: 一行含 `| F1 | Local dev environment (Docker Supabase) | [#1](...) | ready |`。如果已经是 `done`,本 task 部分重复 —— 仍更新这行,在 commit body 里说明重复。

- [ ] **Step 3: 创建 runbook 目录并写文件**

Run:

```bash
mkdir -p "d:/myworkspace/claude-workspace/yopet/docs/setup"
```

然后创建 `d:/myworkspace/claude-workspace/yopet/docs/setup/local-supabase.md`,内容如下:

````markdown
# yopet — 本地 Supabase 部署

> 状态: 生效(F1 完成,issue #1 已关闭)
> 最近验证: 2026-08-06
> 关闭: [#1](https://github.com/hnlisf/yopet/issues/1)

这份 runbook 在 Windows 11 + Docker Desktop 主机上把自托管的 Supabase 栈拉起来。它还记录了 WSL 恢复方法,以备 Docker Desktop 进入卡死状态(也就是把 F1 自身解锁的那次)。

## 1. 前置条件

| | |
|---|---|
| 操作系统 | Windows 11,启用 WSL2(大多数新装的 Win11 默认启用) |
| Docker Desktop | 4.x+,WSL2 后端(Settings → General → Use WSL2) |
| 空闲端口 | 54321(Kong/API)、54322(Postgres)、54323(Studio)、54324(Inbucket) |
| `gh` CLI | 走 `CLAUDE.md` 规定的 issue tracking |
| `psql`(可选) | 直连 DB 用;`docker exec supabase-db-1 psql …` 也能 fallback |

验证方式:

```bash
wsl --status                     # 应显示 默认版本: 2
docker --version                 # 应为 Docker Desktop,Engine 25+
docker run --rm hello-world      # 烟雾测试(证明 Docker + WSL + netns 全部 OK)
```

## 2. ⚠ Docker Desktop WSL 恢复 playbook

如果 `docker compose up` 报错形态如下:

```
terminating WSL distro "docker-desktop": ... 不存在具有所提供名称的分发
错误代码: Wsl/Service/WSL_E_DISTRO_NOT_FOUND
... running WSL command wsl.exe ... --terminate docker-desktop ...
checking if isocache exists: CreateFile \\wsl$\docker-desktop-data\isocache\:
The network name cannot be found.
```

…那 WSL-store 里的 `docker-desktop` 条目处于半卸状态。按这 5 步恢复。**这一步不会删你的镜像** —— 数据 vhdx 会保留。

```bash
# 1. 确保 Docker Desktop 没在运行(看托盘图标)

# 2. 静默 WSL
wsl --shutdown

# 3. 清掉卡死的 docker-desktop 注册条目。
#    先查它的 GUID:
#       powershell -NoProfile -Command "Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' | Select Name"
#    然后把 docker-desktop 的 GUID 替换进去:
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss\{<docker-desktop-guid>}" /f

# 4. 删运行时 vhdx(小,约 128 MB —— Docker Desktop 会重建)
rm "$LOCALAPPDATA/Docker/wsl/main/ext4.vhdx"

# 5. 从开始菜单重启 Docker Desktop —— 它会重建运行时 + 重新识别数据 vhdx
```

恢复后,`disk/docker_data.vhdx`(哪怕显示 17–20 GB,也可能为空,因为是按需扩容的动态 ext4 文件系统)原封不动。

## 3. 启动栈

```bash
cd d:/myworkspace/claude-workspace/supabase-local/docker

# 拉取 ~30 张镜像(约 5–8 GB,首跑 5–10 分钟,缓存暖时约 30 秒)
docker compose pull

# 后台启动
docker compose up -d

# 看 healthy 状态(约 60–120 秒)
docker ps --filter health=healthy --format 'table {{.Names}}\t{{.Status}}'
```

预期输出是几分钟内全部行都 `(healthy)`。最慢的通常是 `supabase-db-1`,因为首启时它要跑 SQL migrations。

## 4. 端点速查表

| 端口 | URL | 服务 | 用途 | PRD/ADR 交叉引用 |
|---|---|---|---|---|
| 54321 | http://localhost:54321 | Kong(API Gateway) | REST/GraphQL 入口 | ADR-0004 |
| 54322 | `psql -h localhost -p 54322 -U postgres` | Postgres 直连 | migrations 的 DB 连接 | PRD §5 step 1 |
| 54323 | http://localhost:54323 | Studio | DB GUI,跑 ad-hoc SQL | F2 |
| 54324 | http://localhost:54324 | Inbucket | dev 环境下 GoTrue 的邮件收件箱 | PRD §5 step 1(邮件验证) |

Postgres 密码: `postgres`(默认值 —— `docker/.env` 里 `POSTGRES_PASSWORD` 的值)。
默认 schema bootstrap(`auth.users`、`storage.objects` 等)会自动创建;F1 不需要手写 migration。

## 5. 边界 —— 这里能做什么 / 不能做什么

| 能做 | 还不能(等后续) |
|---|---|
| `psql` 到 `postgres`,查 bootstrap schema(`auth.users` 等) | 创建一个 `yopet` 用户、通过 Flutter 登录 —— 那是 F3 |
| 打开 Studio、跑 ad-hoc SQL | 看到 9 张 `yopet.*` 表 —— migrations 在后续 ticket |
| 当 GoTrue 发邮件时,看 Inbucket 收到 | 给用户绑 RLS |
| tail 容器日志做 triage | 用 `supabase` CLI 的功能(目前只能直接 `docker compose`) |
````

- [ ] **Step 4: 更新 PRD.md §6 行 F1,从 `ready` 改成 `done`**

打开 `d:/myworkspace/claude-workspace/yopet/PRD.md`,找到:

```
| F1 | Local dev environment (Docker Supabase) | [#1](https://github.com/hnlisf/yopet/issues/1) | ready |
```

把这一行的最后一个格子从 `ready` 改成 `done`,并加上 runbook 链接。最终这行:

```
| F1 | Local dev environment (Docker Supabase) | [#1](https://github.com/hnlisf/yopet/issues/1) | [done](./docs/setup/local-supabase.md) |
```

- [ ] **Step 5: 验证改动**

Run:

```bash
head -5 "d:/myworkspace/claude-workspace/yopet/docs/setup/local-supabase.md"
grep -n '| F1 | Local dev environment' "d:/myworkspace/claude-workspace/yopet/PRD.md"
```

Expected: runbook head 与前 5 行匹配(标题块);grep 命中 1 行,最后格子是 `done`。

- [ ] **Step 6: Commit**

Run:

```bash
cd "d:/myworkspace/claude-workspace/yopet"
git add docs/setup/local-supabase.md PRD.md
git diff --cached --stat
git commit -m "docs(setup): ship F1 local-supabase runbook; mark F1 done in PRD

Closes: #1

Adds docs/setup/local-supabase.md (5 sections: prereqs, WSL recovery
playbook, start commands, endpoint cheat sheet, can/cannot boundary).
The WSL recovery recipe is the high-leverage knowledge from the 2026-08-06
Docker Desktop crash that unblocked F1; baking it into the runbook means
the next time this WSL fingerprint appears, recovery is one search away.

PRD \u00a76 row F1 status flips ready -> done with a link to the runbook.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

Expected: 在 `main` 上新增一个 commit。diff stat 应显示两个文件合计新增约 100 行。

---

## Task 5: 关闭 issue #1,并加引用评论

**Files:** 仓库内无文件(运营型 —— 用 `gh` CLI)

**Interfaces:**

- Consumes: Task 4 的 commit SHA
- Produces: issue #1 状态 = `CLOSED`,并附一条评论指向操作者参考的 runbook

- [ ] **Step 1: 抓取 F1 的 commit SHA**

Run:

```bash
cd "d:/myworkspace/claude-workspace/yopet"
git log -1 --format='%H' HEAD
```

Expected: 一个 40 位的 SHA。复制这个值,粘到 step 3 的关闭评论里。

- [ ] **Step 2: 验证 issue #1 当前是 OPEN**

Run:

```bash
cd "d:/myworkspace/claude-workspace/yopet"
gh issue view 1 --json state --jq .state
```

Expected: `OPEN`。如果已经是 `CLOSED`,停下来问用户 —— 重复关闭会让 issue 历史出现噪声。

- [ ] **Step 3: 关闭 issue #1,带引用评论**

Run:

```bash
cd "d:/myworkspace/claude-workspace/yopet"
gh issue close 1 -c "F1 done.

- stack: supabase/supabase master @ 1123a748 (Aug 4 clone, no pull)
- 4 endpoints verified on 2026-08-06: Studio 54323, API 54321, Postgres 54322, Inbucket 54324
- runbook: docs/setup/local-supabase.md (includes the WSL recovery recipe from this session)
- closing commit: <paste Task 4's commit SHA here>"
```

Expected: GH CLI 报告 `✓ Closed issue hnlisf/yopet#1`。如果需要鉴权但还没配置,`gh` 会打印一个 URL —— 在浏览器里访问并完成关闭。

- [ ] **Step 4: 验证关闭**

Run:

```bash
cd "d:/myworkspace/claude-workspace/yopet"
gh issue view 1 --json state,closedAt,comments --jq '{state: .state, closedAt: .closedAt, commentCount: (.comments | length)}'
```

Expected: `{ "state": "CLOSED", "closedAt": "2026-08-06T...", "commentCount": 1 }`(或更高,如果已有旧评论)。

- [ ] **Step 5: 无 commit 确认**

issue 关闭是外部状态变更,不是仓库文件变更,不需要 commit。

---

## 自审(写计划时顺手填的)

1. **Spec 覆盖:** 走了一遍 spec —— 每节都对应到一个 task: Approach 1–8 → Tasks 1–3;Yopet 落盘产物 §1(runbook)→ Task 4 step 3;Yopet 落盘产物 §2(PRD 更新)→ Task 4 step 4;spec 中"收尾阶段"9–11 → Task 4(commit) + Task 5(关闭 issue)。失败模式都通过每个运营步骤里的重试预算语言覆盖。
2. **占位符扫描:** 没有 "TBD"、"TODO"、"implement later"。每个 step 都有明确的 run 命令和 expected 输出。
3. **类型/命名一致性:** 同样的 compose 命令(`docker compose pull`、`docker compose up -d`)在 tasks 1、2、3、4 step 3 都一致。同样的端口四元组(54321–54324)在 tasks 2、3 和 runbook 里都是一致引用。同样的注册表路径(`HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss\…`)在 plan 和 runbook 里一致。
4. **重试预算:** 在 Global Constraints 中明确声明,并在涉及重试的步骤(网络拉取步骤、容器启动步骤)里再次强调。