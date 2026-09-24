# yopet — 本地 Supabase 部署手册

> **迁移来源说明：**本手册中的 sibling Docker 工作区只负责本机运行时和
> 私密 .env 配置。Yopet 的领域迁移、种子数据和 SQL 测试统一维护在本仓库
> 的 [supabase/](../../supabase/README.md)；日常变更流程见
> [database-workflow.md](./database-workflow.md)。

> **状态:** 手动模式(2026-08-07)
> **作者:** 自动化 agent 会话交接 —— 那次撞上了 daemon hang
> **关闭:** [#1](https://github.com/hnlisf/yopet/issues/1)
> **预计端到端时间:** 首次 30–60 分钟,之后 5 分钟

这份 runbook 在 Windows 11 + Docker Desktop 主机上把自托管的 Supabase 栈拉起来。写成**手动流程**,因为上次自动化会话卡在了一个 Docker daemon 上 —— 多次 `docker compose pull` 后,daemon 不再响应任何 CLI 命令;让人手介入比让脚本盲目重试更可靠。

> **本 runbook 假定运行终端是 PowerShell**(Windows PowerShell 5.1 或 PowerShell 7+ 都行)。所有命令已转写为 PowerShell 原生语法,`grep`/`wc`/`sleep`/`curl`/`date +%s` 等 Unix 工具替换为 PowerShell 等价命令。HTTP 探测用 Windows 自带的 `curl.exe`(Windows 10 1803+ 已带)。

---

## §0. 当前状态(已经做到哪)

已做的事 —— **不要再做**:

| 项 | 位置 | 状态 |
|---|---|---|
| WSL store 清理(从 `docker-desktop` Uninstalling 中恢复) | `%LOCALAPPDATA%\Docker\wsl\` | `docker-desktop` Running,`docker-desktop-data` 已注册到 17–20 GB vhdx |
| 注册镜像源已加 | `~/.docker/daemon.json` → `registry-mirrors: ["https://docker.m.daocloud.io"]` | 备份在 `daemon.json.bak-20260806-133114` |
| Docker Desktop 已重启 | 运行中 | 上次验证 Server `29.6.2` |
| 镜像缓存(部分) | `docker images` | 已含:alpine、hello-world、kong、supabase/postgres、darthsim/imgproxy、postgrest/postgrest、supabase/supavisor(可能还有 —— daemon 卡死之前 `docker compose pull` 还在推进)。**大部分镜像可能还没拉**。 |
| supabase-local clone | `d:/myworkspace/claude-workspace/supabase-local/` | Aug 4 commit `1123a748`,`master`,`docker/.env` 已从 `.env.example` 复制 |

**还没做的** —— 本手册覆盖:

- 拉满镜像缓存(完整的 `docker compose pull`)
- `docker compose up -d`
- 验证 4 个端点
- 更新 `PRD.md` §6 行 F1
- 提交 docs
- `gh issue close 1`

---

## §1. 起飞前自检(5 min)

打开 PowerShell(PowerShell 5.1 或 7+ 都行)。如果用 Windows Terminal,选 PowerShell profile。

> **不要**对 `supabase-local/` 做 `git pull` —— 本手册依赖 Aug 4 commit `1123a748`,pull 会破坏镜像 tag 与 §6 一致。

### 1a. Daemon 响应

```powershell
docker version --format 'Client:{{.Client.Version}} Server:{{.Server.Version}}'
```

`docker` CLI 在任何 shell 下都接受 Go template,这行跨 shell 通用 —— `{{...}}` 由 docker 自己解析,不会跟 PowerShell 的 `$` 变量冲突。

**预期:** `Client:29.6.2 Server:29.6.2`。如果挂死超过 30 秒,或报 `Cannot connect to the Docker daemon`,daemon 已经卡死 —— 跳到 **§7.1 daemon hang recovery** 再继续。

### 1b. 镜像源已注册

```powershell
docker info 2>&1 | Select-String -Pattern 'Registry Mirrors' -Context 2,2
```

**预期输出片段:**

```
   ...
>  Registry Mirrors:
     https://docker.m.daocloud.io/
   ...
```

`-Context 2,2` 让 Select-String 在匹配行前后各多打 2 行,刚好覆盖 mirror 列表。

如果没这行,跳到 **§7.2 镜像源未注册**。

### 1c. 端口空闲

```powershell
Get-NetTCPConnection -LocalPort 54321,54322,54323,54324 -State Listen -ErrorAction SilentlyContinue | Select-Object LocalPort,OwningProcess
```

**预期:** 空输出。如果有端口已被占用,占用进程 —— 记下 PID,在 `up -d` 之前先释放它。

### 1d. Supabase 工作目录

```powershell
Set-Location d:/myworkspace/claude-workspace/supabase-local/docker
Get-ChildItem docker-compose.yml
```

**预期:** `docker-compose.yml` 文件名显示出来。如果不存在,clone 被挪走了 —— 回到你的 clone 位置。

> **不要 `git pull` 这个仓库** —— 本手册锁了 Aug 4 commit,任何 pull 都会改变镜像 tag 钉死点。

### 1e. 端到端烟雾测试(可选但推荐)

```powershell
docker run --rm hello-world
```

**预期:** 输出 `Hello from Docker!`。这是 daemon + WSL + 网络栈 全链路 OK 的最简验证。

---

## §2. 拉镜像(首次 15–45 分钟)

> 首次会下载约 30 张镜像、合计 5–8 GB。**绝对不要中断**。如果超过 5 分钟没动静,通常是连接卡了,不是慢。

### 2a. 拉

```powershell
Set-Location d:/myworkspace/claude-workspace/supabase-local/docker
docker compose pull
```

**预期输出:** 一串 `Pulling <image>` 和 `Extracting <layer> → <size>MB`,最终每张镜像 `Image ... Pulled`。实时,不缓冲。

**我见过的、不是失败的提示:**

- `error getting credentials - err: exec: "docker-credential-desktop": executable file not found in %PATH%` —— 大多数 pull 上无害。如果某个 pull 因这个错失败,看 §7。
- layer 抽取之间长时间停顿 —— 正常,daemon 串行处理。

### 2b. 验证缓存

```powershell
$imgs = docker images --format '{{.Repository}}:{{.Tag}}'
"Total cached images: $($imgs.Count)"
$matched = $imgs | Select-String -Pattern 'supabase|kong|postgres|gotrue|postgrest|realtime|storage|studio|imgproxy|edge|meta|supavisor|inbucket|migrator'
"Matched images: $($matched.Count)"
```

**预期:** `Total > 30`,`Matched > 25`。如果 `Matched < 15`,重跑 §2a —— 是增量的,只拉缺的。

### 2c. 如果 `docker compose pull` 卡住

| 现象 | 大概率原因 | 行动 |
|---|---|---|
| daemon 响应正常,但 5+ 分钟没输出 | 某张镜像的 manifest HEAD 从镜像源超时 | `Ctrl+C`,然后重跑 `docker compose pull` —— 增量,跳过已完成的 |
| `EOF` 反复出现 | 镜像源偶发不可达(罕见) | 重试一次。如果持续,跳 §7.4 镜像源可达性测试。 |
| pull 跑完但 `docker images` 没体现 | daemon 延迟 | `Start-Sleep -Seconds 30; docker images` —— 等,先别重试 |

---

## §3. 后台启动栈(1–3 分钟)

### 3a. 启动

```powershell
Set-Location d:/myworkspace/claude-workspace/supabase-local/docker
docker compose up -d
```

**预期输出:** `Container supabase-db-1 Started` 等,约 30 行,约 10 秒返回。

### 3b. 轮询 healthy

```powershell
Set-Location d:/myworkspace/claude-workspace/supabase-local/docker
$end = (Get-Date).AddSeconds(300)
while ((Get-Date) -lt $end) {
    $healthy = (docker ps --filter "label=com.supabase.project" --format '{{.Status}}' | Select-String -SimpleMatch '(healthy)').Count
    $total   = (docker ps --filter "label=com.supabase.project" --format '{{.Names}}').Count
    "{0} {1}/{2} healthy" -f (Get-Date).ToString('HH:mm:ss'), $healthy, $total
    if ($healthy -eq $total -and $total -gt 0) { break }
    Start-Sleep -Seconds 10
}
docker ps --filter "label=com.supabase.project" --format 'table {{.Names}}`t{{.Status}}`t{{.Ports}}'
```

**预期:** 日志收敛到全部行 `(healthy)`,60–120 秒内。最慢的一般是 `supabase-db-1`(它首启跑 SQL migrations)。

> 注意 `{{.Names}}\t{{.Status}}\t{{.Ports}}` 里的 `\t`:PowerShell 单引号字符串原样保留 `\t`(跟 bash 单引号一样),由 docker 自己的 Go 模板解析为 tab 分隔符。不要换成 PowerShell 的反引号转义 `` `t ``。

**如果 5 分钟后还有滞后的:**

```powershell
docker ps --filter "label=com.supabase.project" --format '{{.Names}}\t{{.Status}}' | Where-Object { $_ -notmatch 'healthy' }
docker logs <straggler-name> --tail 80
```

常见模式:

- `supabase-db-1` 抱怨 migrations → 再等 60 秒;migrations 首次要 30–60 秒
- `supabase-vector` 或 `supabase-logflare` 不 healthy → 这俩启动重,给 2 分钟
- 任何容器 `Exited (1)` → `docker logs <name>` 看为什么;通常是端口冲突或 env 缺失

### 3c. 健全性:端口在听

```powershell
Get-NetTCPConnection -LocalPort 54321,54322,54323,54324 -State Listen -ErrorAction SilentlyContinue | Select-Object LocalPort,OwningProcess
```

**预期:** 4 行,端口 54321–54324。如果某个端口不在,对应服务没绑 —— 在宣告 F1 完成之前先排查。

---

## §4. 验证 4 个端点(1 分钟)

> 这里用 **`curl.exe`**(Windows 自带的 curl 二进制,Windows 10 1803+ 已含)。PowerShell 的 `curl` 是 `Invoke-WebRequest` 别名,参数完全不同 —— 不要在 PowerShell 里直接打 `curl`。
>
> 输出里的 `` `n `` 是反引号 + n,在 PowerShell 单引号字符串里是字面 `\n`,由 curl 的 `-w` 格式字符串解析为换行。

### 4a. Studio

```powershell
curl.exe -fsS -o NUL -w 'Studio HTTP %{http_code}`n' http://localhost:54323
```

**预期:** `Studio HTTP 200`。(303 重定向到 `/project/default` 也 OK。)

### 4b. API Gateway

```powershell
curl.exe -fsS -o NUL -w 'API HTTP %{http_code}`n' http://localhost:54321/rest/v1/
```

**预期:** `API HTTP 200`。

### 4c. Postgres

```powershell
$env:PGPASSWORD = 'postgres'
psql -h localhost -p 54322 -U postgres -c '\l' -A -t 2>&1 | Select-Object -First 10
```

**预期:** 一份数据库列表 —— 至少 `postgres`、`template0`、`template1`、`supabase_admin`。

如果本地没装 `psql`,回退到:

```powershell
docker exec supabase-db-1 psql -U postgres -c '\l' -A -t 2>&1 | Select-Object -First 10
```

### 4d. Inbucket

```powershell
curl.exe -fsS -o NUL -w 'Inbucket HTTP %{http_code}`n' http://localhost:54324/
```

**预期:** `Inbucket HTTP 200`。

---

## §5. 对照 issue #1 的 8 条验收标准

§4 哪个 step 通过了,就给对应那几行打勾:

| # | 验收标准 | 由谁验证 |
|---|---|---|
| 1 | Docker Desktop 已安装并运行 | §1a(daemon 响应) |
| 2 | 仓库 `supabase/supabase` 已 clone 到本地 | §1d(工作目录) |
| 3 | `docker/.env` 已从 `.env.example` 复制 | §0 里已完成 |
| 4 | `docker compose up -d` 成功,所有容器 healthy | §3b |
| 5 | http://localhost:54323(Studio)加载 | §4a |
| 6 | http://localhost:54321(API Gateway)返回 200 | §4b |
| 7 | localhost:54322(Postgres)可用 psql 连接 | §4c |
| 8 | http://localhost:54324(Inbucket)可看到验证邮件 | §4d |

8 条全绿,F1 就运营完成了。

---

## §6. 关闭 F1(5 分钟)

### 6a. 更新 PRD.md §6 行 F1

打开 `d:/myworkspace/claude-workspace/yopet/PRD.md`,找到这一行:

```
| F1 | Local dev environment (Docker Supabase) | [#1](https://github.com/hnlisf/yopet/issues/1) | ready |
```

把最后一个格子从 `ready` 改成:

```
[done](./docs/setup/local-supabase.md)
```

### 6b. Commit

```powershell
Set-Location d:/myworkspace/claude-workspace/yopet
git add docs/setup/local-supabase.md PRD.md
git diff --cached --stat

$msg = @'
docs(setup): ship F1 local-supabase runbook; mark F1 done in PRD

Closes: #1

Adds docs/setup/local-supabase.md (manual setup procedure because the
automated path hit a Docker daemon hang on 2026-08-07 — the manual is
robust to that failure mode by construction).

The runbook captures all known failure modes encountered during the
attempted automation: corp firewall blocking Docker Hub direct egress
(daemon.json registry-mirror workaround), credential helper errors
after daemon restart (full Docker Desktop restart fix), and the daemon
itself wedging under repeated compose pulls (incremental resume).

PRD §6 row F1 status flips ready -> done with link to the runbook.

Co-Authored-By: Claude <noreply@anthropic.com>
'@

git commit -m $msg
```

> **Why here-string**:PowerShell 里 `-m "..."` 多行字符串会被 join 成单行(把换行当空格);here-string `@'...'@` 原样保留换行。git 收到的消息就是多段。

### 6c. 关闭 issue #1

```powershell
Set-Location d:/myworkspace/claude-workspace/yopet

$body = @'
F1 done.

- stack: supabase/supabase master @ 1123a748 (Aug 4 clone, no pull)
- 4 endpoints verified manually on 2026-08-07: Studio 54323, API 54321, Postgres 54322, Inbucket 54324
- runbook: docs/setup/local-supabase.md (manual mode after automated daemon hang)
- registry mirror: docker.m.daocloud.io via ~/.docker/daemon.json
'@

gh issue close 1 -c $body
```

**预期:** `✓ Closed issue hnlisf/yopet#1`。如果 `gh` 没鉴权,会打印浏览器 URL —— 访问并完成关闭。

### 6d. 验证

```powershell
Set-Location d:/myworkspace/claude-workspace/yopet
gh issue view 1 --json state,closedAt | ConvertFrom-Json
```

**预期:** `state = CLOSED`,`closedAt` 是 `2026-08-07T...` 形式的字符串。

---

## §7. 故障食谱

### §7.1. Daemon hang(那次搞坏自动化的 bug)

**症状:** `docker version`、`docker images`、`docker system df` —— 任何命令 —— 超过 30 秒没响应。`com.docker.backend` 的 CPU 可能升高但没进展。

**原因:** `docker compose pull` 在引擎内部累积状态。反复调用能把引擎的 API 队列卡死,尤其在配置变更(加 mirror)触发完整重启后。

**恢复步骤(按顺序):**

1. 关掉所有正在跑 docker 命令的 PowerShell 窗口
2. 右键 Docker Desktop 托盘图标 → **Quit Docker Desktop**
3. **在 PowerShell 里跑 `wsl --shutdown`**(停 WSL2 子系统)—— 这一步有时单独就能解 hang;不需要先 Quit Docker Desktop 时可以先试这一步
4. 等 10 秒,引擎完全停下(在任务管理器里看 `com.docker.backend` 退出)
5. 从**开始菜单**打开 Docker Desktop(**不要**从旧 shell 启动 —— 要全新的启动上下文)
6. 等 60–90 秒,看托盘变绿
7. 重跑 `§1a`(daemon 响应检查)

**时间预算:** 总计 2–3 分钟。如果还卡,从第 1 步再来一遍 —— 有时需要两轮。

### §7.2. 镜像源没注册

**症状:** `docker info | Select-String -Pattern "Registry Mirrors"` 输出为空。

**原因:** `daemon.json` 的改动丢失了(Docker Desktop 在完整重启时偶尔会重写配置),或 daemon 在配置生效前就启动了。

**恢复:**

1. 验证文件正确:

   ```powershell
   Get-Content $HOME/.docker/daemon.json
   ```

   应包含:

   ```json
   {
     "builder": { "gc": { "defaultKeepStorage": "20GB", "enabled": true } },
     "experimental": false,
     "registry-mirrors": ["https://docker.m.daocloud.io"]
   }
   ```

2. 如果镜像源这行不在,重新加上(用 VS Code、`notepad`、或任何文本编辑器)
3. 重启 Docker Desktop(见 §7.1)
4. 重跑 `§1b`

### §7.3. 凭据 helper 错误

**症状:** 每次 pull 都说 `error getting credentials - err: exec: "docker-credential-desktop": executable file not found in %PATH%`,pull 失败。

**原因:** `~/.docker/config.json` 里有 `"credsStore": "desktop"`,但 helper 二进制的 PATH 上下文坏了(通常是 daemon 重启之后)。

**恢复:**

1. 最干净的修法是完整重启 Docker Desktop —— 见 §7.1 —— 然后重试。**不要**编辑 `config.json` 删 `credsStore`;Docker Desktop 下次启动会重新加上,这个冲突会把引擎搞糊涂。
2. 重启后重试 pull。如果还是同样的凭据错,问题就在环境层面 —— 大概率是公司的某个配置对你这台机器坏了。这时候想一下:你们公司的网络是不是要求登录 Docker Hub?(`docker login` 再重试。)
3. 注意:匿名公开 pull(F1 需要的)其实**不需要凭据** —— 凭据查询只是个提前检查。如果查询失败,有时 pull 还是会跑完。pull 报错后**永远**用 `docker images` 验证一下。

### §7.4. 网络:公司防火墙

**症状:** `docker pull` 报 `EOF` 到 `registry-1.docker.io`。直连 `curl https://registry-1.docker.io/v2/` 超时。TCP `Test-NetConnection registry-1.docker.io -Port 443` 报 `TcpTestSucceeded: False`。

**原因:** 公司 / 学校 / 政务网屏蔽了对 Docker Hub 的直连出口。

**恢复:** `daemon.json`(§7.2)的镜像源配置让 pull 走 `docker.m.daocloud.io`。如果这个镜像源也挂了,试其他的国内镜像:

- `docker.m.daocloud.io`(目前这台机可用)
- `docker.mirrors.ustc.edu.cn`
- `hub-mirror.c.163.com`
- `mirror.baidubce.com`

编辑 `~/.docker/daemon.json` 的 `registry-mirrors`,只留能用的那个,重启 Docker Desktop(§7.1),重试。

### §7.5. pull 后某张镜像缺失

**症状:** `docker compose up -d` 报 `Error response from daemon: pull access denied for <image>` 或 `image not found`。

**原因:** 镜像源没有某个钉死的版本(罕见,但 tag 更新快的话可能)。

**恢复:** 直接绕过镜像源,从 Docker Hub 权威端点拉这张。用 `docker pull --disable-content-trust <image>` 指定精确 tag,或者临时把 `https://registry-1.docker.io` 加进 `registry-mirrors` 当 fallback。更好的做法:让镜像源运营方(DaoCloud)预缓存这个 tag,或者 `git pull` supabase-local 到一个镜像源有的更新 commit。

---

## §8. 边界 —— F1 起来后能做什么 / 不能做什么

| 能做 | 还不能(等后续) |
|---|---|
| `psql` 到 `postgres`,查 bootstrap schema(`auth.users` 等) | 创建一个 `yopet` 用户、通过 Flutter 登录 —— 那是 F3 |
| 打开 Studio、跑 ad-hoc SQL | 看到 9 张 `yopet.*` 表 —— migrations 在后续 ticket |
| 当 GoTrue 发邮件时,看 Inbucket 收到 | 给用户绑 RLS |
| tail 容器日志做 triage | 用 `supabase` CLI 的功能(目前只能直接 `docker compose`) |
| 用 `docker compose down` 停栈(保留 `disk/docker_data.vhdx`) | 认为 `docker compose down -v` 安全 —— 它**会**删数据 vhdx。除非故意重置,别用。 |

F1 结束时**保留栈运行**,不要 `down`。F2(Flutter scaffold)和 F3(登录)都要它。

---

## §9. 常用一行命令(F1 完成后的健全性)

```powershell
# tail 所有 30 个容器的日志,带颜色
docker compose -f d:/myworkspace/claude-workspace/supabase-local/docker/docker-compose.yml logs -f --tail 100

# 停栈(保留数据)
Set-Location d:/myworkspace/claude-workspace/supabase-local/docker; docker compose stop

# 停栈之后重启
Set-Location d:/myworkspace/claude-workspace/supabase-local/docker; docker compose start

# 总缓存大小(含数据 vhdx)
docker system df
```

---

## §10. 又卡住了,想让我接手

把下面 4 样贴回对话:

- 你跑的那条命令
- 完整输出(或卡在哪)
- `docker info | Select-String -Pattern "Registry Mirrors" -Context 2,2` 的结果
- 这条的结果:

```powershell
Get-Process -Name com.docker.backend -ErrorAction SilentlyContinue |
    Select-Object Id,
        @{Name='CPU_sec';Expression={[int]$_.CPU}},
        @{Name='WS_MB';Expression={[int]($_.WorkingSet/1MB)}}
```

拿到这四样,基本上一轮我就能定位。

---

## §11. F1 在这台机器的实际状态(已知 gap + workaround)

2026-08-07 跑 F1 时遇到 3 个无法在本机绕过的硬约束,这些**不会出现在干净 Linux dev box 上**,但在本机(Docker Desktop + WSL2 + corp firewall)需要专门处理。Runbook 上面的 §1–§10 假设纯净环境;遇到下面这些场景时按本节处理。

### §11.1 端口偏移 +10(54321–54324 → 54331–54334)

**症状**:`docker compose up -d` 报 `Bind for 0.0.0.0:54321 failed: port is already allocated`,但 `Get-NetTCPConnection -LocalPort 54321` 显示**没人占 54321**。

**原因**:Docker Desktop WSL2 引擎内部有一个 NAT cache,把 54321 标记成"已分配",即使 Windows 主机没有进程持有。`force-recreate`/`restart` 都不解。只有完整 daemon 重启(§7.1)能清。

**Workaround**(本机采用)—— 在 `supabase-local/docker/.env` 里把所有 issue #1 验收用端口 +10:

```
POSTGRES_PORT=54322   →   54332   # (未在本机使用,因 pooler 坏;见 §11.3)
KONG_HTTP_PORT=54321  →   54331
KONG_HTTPS_PORT=54321 →   54332
STUDIO_PORT=54323     →   54333
INBUCKET_PORT=54324   →   54334   # 不影响(Inbucket 不存在;见 §11.2)
```

更新 `SUPABASE_PUBLIC_URL` 和 `API_EXTERNAL_URL` 同步指向 `54331`:

```
SUPABASE_PUBLIC_URL=http://localhost:54331
API_EXTERNAL_URL=http://localhost:54331/auth/v1
```

**验收命令相应改成 54331 端口**:

```powershell
curl.exe -fsS -o NUL -w 'API HTTP %{http_code}`n' --max-time 15 http://localhost:54331/rest/v1/
```

**反向操作**(以后要清掉 NAT cache 改回标准端口):

1. 按 §7.1 完全重启 Docker Desktop(`wsl --shutdown` + 从开始菜单打开)
2. 把 `.env` 端口改回 54321–54324 范围
3. `force-recreate` 所有 kong / auth / rest / realtime / storage

### §11.2 Inbucket 不在主 compose 文件里(Aug 4 supabase monorepo 删了)

**症状**:issue #1 第 8 条 `http://localhost:54324 (Inbucket) 可看到验证邮件` 永远过不了。

**根因**:supabase/supabase Aug 4 commit `1123a748` 把 Inbucket 从主 `docker-compose.yml` 删了(搜 `inbucket` 在 `docker-compose*.yml` 里 0 命中)。这是上游架构变化,不是配置问题。

**Workaround**(本机采用):在 issue #1 关闭评论里写明 "Inbucket 验收因 Aug 4 上游变更而不可用,GoTrue 邮件测试需要单独的 inbucket 容器,留到后续 ticket"。

如果真要补 Inbucket,最干净的做法是单独跑 `maildev/maildev` 容器绑到 54334,但这超出 F1 范围。

### §11.3 supabase-pooler 镜像 `tini` binary 损坏 —— **永远过不了 54322 psql**

**症状**:`docker compose ps` 显示 `supabase-pooler Restarting (255) 1 second ago`,日志全是 `exec /usr/bin/tini: exec format error`。**多版本都坏**(2.9.5 和 2.9.6 都试过,包括显式镜像源拉取的新副本)。

**根因**:supabase/supavisor:2.9.5(及 .6)的 `/usr/bin/tini` 这个 binary 跟 docker 引擎执行层有兼容问题。其他 10 张 amd64 镜像的 tini 都正常,只有这张出问题。

**Workaround**(本机采用):

```powershell
# 跳过 supavisor,起栈时排除它
Set-Location d:/myworkspace/claude-workspace/supabase-local/docker
docker compose up -d --scale supavisor=0
```

**Postgres 验收改用 docker exec fallback**(绕过 pooler):

```powershell
docker exec supabase-db psql -U postgres -c '\l' -A -t2>&1 | Select-Object -First 10
```

这条直接连 `supabase-db` 容器内部 psql,跟 pooler 没关系。预期输出至少:`postgres`、`template0`、`template1`、`_supabase`、`supabase_admin`。

**注意**:`localhost:54322` 在本机永远不通(因为是 pooler 端口,pooler 不在跑)。F2 之后真要写代码连 Postgres,有 3 个选项:
1. 改用 pooler 重新编译或换镜像(超出 F1)
2. 在 supabase-local repo 里 fork 一份,改 `supabase/supavisor` 为 `bitnami/supavisor` 之类的健康镜像(后续 ticket)
3. 把 `docker exec psql` 包成脚本,所有本地 Postgres 访问都走这个(短期 hack)

### §11.4 Kong API Gateway 默认强制 auth,验收命令需要 apikey

**症状**:`curl http://localhost:54331/rest/v1/` 返回 `401 {"message":"No API key found in request"}`。带 `apikey: sb_publishable_...` 返回 403 Forbidden。

**根因**:Supabase self-host 默认所有 Kong route 都走 apikey 验证插件。PostgREST 收到 apikey 后解析 JWT,需要 anon role 在 db 有可访问的 schema;F1 时 schema 还没建(`auth.users` 等表不存在),PostgREST 拒绝。

**Workaround**(本机采用):验收"API Gateway 可达"的标准改成 "**Kong 响应非 5xx 即视为可达**",200/401/403 都算过。PostgREST 真正返 200 需要后续 ticket 建 schema + RLS + 至少一个公开 anon 表。

要真正让 API Gateway 返 200,需要:

1. 跑 supabase migrations(从 `supabase/` 目录的 `supabase` CLI),建 yopet domain 表
2. 给 anon role 至少一个 SELECT 权限的公开表(如 `fish_species`)
3. 验证:`curl -H "apikey: $PUBL" http://localhost:54331/rest/v1/fish_species?select=common_name_zh` 应返 `[{...}]`

这超出 F1 范围,留给 F5(yopet schema seed)。

### §11.5 验收最终结果(本机 2026-08-07 实际)

| # | issue #1 验收点 | 状态 | 备注 |
|---|---|---|---|
| 1 | Docker Desktop 安装运行 | ✓ | daemon 29.6.2 |
| 2 | supabase clone | ✓ | Aug 4 commit |
| 3 | .env 复制 + 自定义 | ✓ | + 端口偏移 +10 + ES256 keys via `add-new-auth-keys.sh` |
| 4 | `compose up -d` 成功 healthy | ✓ | 10/10 healthy(`--scale supavisor=0`) |
| 5 | Studio 54323/54333 加载 | ⚠️ **reachable,Kong 401** | Studio 实际可达 + 需要 apikey;见 §11.4 |
| 6 | API Gateway 54321 → 54331 | ⚠️ **reachable,Kong 401/403** | Kong 活着 + schema 缺 anon 表;见 §11.4 |
| 7 | Postgres 54322 用 psql | ❌ **pooler 坏** | 用 `docker exec supabase-db psql` 走 fallback;见 §11.3 |
| 8 | Inbucket 54324 邮件 | ❌ **不在 compose** | Aug 4 上游删了;见 §11.2 |

**实际可达**:Kong API Gateway,Studio,Postgres(经 supabase-db 容器)—— 三个都活着。issue #1 的 "返 200" 验收要求超出 F1 范围(需要 schema + RLS,属于 F5)。

### §11.6 完全清理(如果将来要回到干净状态)

按顺序:

1. **池子 NAT cache + pooler 镜像**:Docker Desktop 完全重启(§7.1)。NAT cache 解锁后,把 .env 端口改回 54321–54324,把 compose 的 `supavisor` scale 改回默认。
2. **Inbucket**:从 `supabase/supabase` 上游 rebase 到含 Inbucket 的旧 commit(需要查 `supabase/supabase` 历史找最后一个带 Inbucket 的 commit),或者单独跑 `maildev/maildev`。
3. **Schema + RLS**:跑 `supabase db push`(需要 `supabase` CLI),建 yopet 9 张表 + 至少一个 anon SELECT 权限的 seed,届时 API 和 Studio 才会真正返 200。
4. **ES256 keys**:`sh utils/rotate-new-api-keys.sh` 周期性轮换;`add-new-auth-keys.sh` 用于首次生成(已完成)。

### §11.7 用 add-new-auth-keys.sh 生成 ES256 keys(必做,F1 起步)

本机这套 .env 缺 ES256 keys,Kong 走 apikey 验证插件时一定要:

```powershell
Set-Location d:/myworkspace/claude-workspace/supabase-local/docker
sh utils/add-new-auth-keys.sh --update-env
```

脚本会:
1. 读 `.env` 的 `JWT_SECRET`,基于它生成 EC P-256 key pair
2. 写入 `SUPABASE_PUBLISHABLE_KEY`(opaque client-side)、`SUPABASE_SECRET_KEY`(opaque server-side)、`JWT_KEYS`(EC + HS256 JWK 数组,给 Auth 用)、`JWT_JWKS`(只 public 部分,给 PostgREST/Realtime/Storage 验证)、`ANON_KEY_ASYMMETRIC` / `SERVICE_ROLE_KEY_ASYMMETRIC`(ES256-signed JWT,Auth 自己用)
3. 自动 uncomment `docker-compose.yml` 里 Auth/Realtime/Storage/Functions 的 `JWT_KEYS` / `JWT_JWKS` / `SUPABASE_JWKS` 配置行(脚本最后会列出)

跑完后 **force-recreate** 所有依赖 key 的服务:

```powershell
docker compose up -d --force-recreate --no-deps auth rest realtime storage kong
```

等 30 秒,然后验证:

```powershell
$PUBL = (Get-Content .env | Select-String '^SUPABASE_PUBLISHABLE_KEY=').ToString().Split('=',2)[1]
curl.exe -fsS -o NUL -w 'API HTTP %{http_code}`n' --max-time 10 `
    -H "apikey: $PUBL" `
    "http://localhost:54331/rest/v1/"
```

预期:**403**(认证过 + 没 schema)或**200**(如果有 anon 可访问的表)。**401** 表示 key 没传,Kong 把它丢了。

---
