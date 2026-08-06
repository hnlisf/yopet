# yopet — 本地 Supabase 部署手册

> **状态:** 手动模式(2026-08-07)
> **作者:** 自动化 agent 会话交接 —— 那次撞上了 daemon hang
> **关闭:** [#1](https://github.com/hnlisf/yopet/issues/1)
> **预计端到端时间:** 首次 30–60 分钟,之后 5 分钟

这份 runbook 在 Windows 11 + Docker Desktop 主机上把自托管的 Supabase 栈拉起来。写成**手动流程**,因为上次自动化会话卡在了一个 Docker daemon 上 —— 多次 `docker compose pull` 后,daemon 不再响应任何 CLI 命令;让人手介入比让脚本盲目重试更可靠。

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

打开一个新终端(PowerShell 或 Git Bash 都行;runbook 用 Git Bash 风格,但命令是等效的)。

### 1a. Daemon 响应

```bash
docker version --format 'Client:{{.Client.Version}} Server:{{.Server.Version}}'
```

**预期:** `Client:29.6.2 Server:29.6.2`。如果挂死超过 30 秒,或报 `Cannot connect to the Docker daemon`,daemon 已经卡死 —— 跳到 **§7.1 daemon hang recovery** 再继续。

### 1b. 镜像源已注册

```bash
docker info 2>&1 | grep -A 2 -i 'registry mirrors'
```

**预期:**

```
Registry Mirrors:
 https://docker.m.daocloud.io/
```

如果没这行,跳到 **§7.2 镜像源未注册**。

### 1c. 端口空闲

```bash
powershell -NoProfile -Command 'Get-NetTCPConnection -LocalPort 54321,54322,54323,54324 -State Listen -ErrorAction SilentlyContinue | Select-Object LocalPort,OwningProcess' 2>&1
```

**预期:** 空输出。如果有端口已被占用,占用进程 —— 记下 PID,在 `up -d` 之前先释放它。

### 1d. Supabase 工作目录

```bash
cd d:/myworkspace/claude-workspace/supabase-local/docker
ls docker-compose.yml
```

**预期:** 文件存在。如果不存在,clone 被挪走了 —— 回到你的 clone 位置。

---

## §2. 拉镜像(首次 15–45 分钟)

> 首次会下载约 30 张镜像、合计 5–8 GB。**绝对不要中断**。如果超过 5 分钟没动静,通常是连接卡了,不是慢。

### 2a. 拉

```bash
cd d:/myworkspace/claude-workspace/supabase-local/docker
docker compose pull
```

**预期输出:** 一串 `Pulling <image>` 和 `Extracting <layer> → <size>MB`,最终每张镜像 `Image ... Pulled`。实时,不缓冲。

**我见过的、不是失败的提示:**

- `error getting credentials - err: exec: "docker-credential-desktop": executable file not found in %PATH%` —— 大多数 pull 上无害。如果某个 pull 因这个错失败,看 §7。
- layer 抽取之间长时间停顿 —— 正常,daemon 串行处理。

### 2b. 验证缓存

```bash
docker images --format '{{.Repository}}:{{.Tag}}' | wc -l
docker images --format '{{.Repository}}:{{.Tag}}' | grep -cE 'supabase|kong|postgres|gotrue|postgrest|realtime|storage|studio|imgproxy|edge|meta|supavisor|inbucket|migrator'
```

**预期:** 总数 > 30,匹配 > 25。如果匹配 < 15,重跑 §2a —— 是增量的,只拉缺的。

### 2c. 如果 `docker compose pull` 卡住

| 现象 | 大概率原因 | 行动 |
|---|---|---|
| daemon 响应正常,但 5+ 分钟没输出 | 某张镜像的 manifest HEAD 从镜像源超时 | `Ctrl+C`,然后重跑 `docker compose pull` —— 增量,跳过已完成的 |
| `EOF` 反复出现 | 镜像源偶发不可达(罕见) | 重试一次。如果持续,跳 §7 镜像源可达性测试。 |
| pull 跑完但 `docker images` 没体现 | daemon 延迟 | `sleep 30 && docker images` —— 等,先别重试 |

---

## §3. 后台启动栈(1–3 分钟)

### 3a. 启动

```bash
cd d:/myworkspace/claude-workspace/supabase-local/docker
docker compose up -d
```

**预期输出:** `Container supabase-db-1 Started` 等,约 30 行,约 10 秒返回。

### 3b. 轮询 healthy

```bash
cd d:/myworkspace/claude-workspace/supabase-local/docker
end=$(( $(date +%s) + 300 ))
while [ $(date +%s) -lt $end ]; do
  healthy=$(docker ps --filter "label=com.supabase.project" --format '{{.Status}}' | grep -c '(healthy)' || true)
  total=$(docker ps --filter "label=com.supabase.project" --format '{{.Names}}' | wc -l)
  echo "$(date +%H:%M:%S) $healthy/$total healthy"
  if [ "$healthy" = "$total" ] && [ "$total" -gt 0 ]; then break; fi
  sleep 10
done
docker ps --filter "label=com.supabase.project" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

**预期:** 日志收敛到全部行 `(healthy)`,60–120 秒内。最慢的一般是 `supabase-db-1`(它首启跑 SQL migrations)。

**如果 5 分钟后还有滞后的:**

```bash
docker ps --filter "label=com.supabase.project" --format '{{.Names}}\t{{.Status}}' | grep -v healthy
docker logs <straggler-name> --tail 80
```

常见模式:

- `supabase-db-1` 抱怨 migrations → 再等 60 秒;migrations 首次要 30–60 秒
- `supabase-vector` 或 `supabase-logflare` 不 healthy → 这俩启动重,给 2 分钟
- 任何容器 `Exited (1)` → `docker logs <name>` 看为什么;通常是端口冲突或 env 缺失

### 3c. 健全性:端口在听

```bash
powershell -NoProfile -Command 'Get-NetTCPConnection -LocalPort 54321,54322,54323,54324 -State Listen -ErrorAction SilentlyContinue | Select-Object LocalPort,OwningProcess' 2>&1
```

**预期:** 4 行,端口 54321–54324。如果某个端口不在,对应服务没绑 —— 在宣告 F1 完成之前先排查。

---

## §4. 验证 4 个端点(1 分钟)

### 4a. Studio

```bash
curl -fsS -o /dev/null -w 'Studio HTTP %{http_code}\n' http://localhost:54323
```

**预期:** `Studio HTTP 200`。(303 重定向到 `/project/default` 也 OK。)

### 4b. API Gateway

```bash
curl -fsS -o /dev/null -w 'API HTTP %{http_code}\n' http://localhost:54321/rest/v1/
```

**预期:** `API HTTP 200`。

### 4c. Postgres

```bash
PGPASSWORD=postgres psql -h localhost -p 54322 -U postgres -c '\l' -A -t 2>&1 | head -10
```

**预期:** 一份数据库列表 —— 至少 `postgres`、`template0`、`template1`、`supabase_admin`。

如果本地没装 `psql`,回退到:

```bash
docker exec supabase-db-1 psql -U postgres -c '\l' -A -t 2>&1 | head -10
```

### 4d. Inbucket

```bash
curl -fsS -o /dev/null -w 'Inbucket HTTP %{http_code}\n' http://localhost:54324/
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

```bash
cd d:/myworkspace/claude-workspace/yopet
git add docs/setup/local-supabase.md PRD.md
git diff --cached --stat
git commit -m "docs(setup): ship F1 local-supabase runbook; mark F1 done in PRD

Closes: #1

Adds docs/setup/local-supabase.md (manual setup procedure because the
automated path hit a Docker daemon hang on 2026-08-07 — the manual is
robust to that failure mode by construction).

The runbook captures all known failure modes encountered during the
attempted automation: corp firewall blocking Docker Hub direct egress
(daemon.json registry-mirror workaround), credential helper errors
after daemon restart (full Docker Desktop restart fix), and the daemon
itself wedging under repeated compose pulls (incremental resume).

PRD \u00a76 row F1 status flips ready -> done with link to the runbook.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### 6c. 关闭 issue #1

```bash
cd d:/myworkspace/claude-workspace/yopet
gh issue close 1 -c "F1 done.

- stack: supabase/supabase master @ 1123a748 (Aug 4 clone, no pull)
- 4 endpoints verified manually on 2026-08-07: Studio 54323, API 54321, Postgres 54322, Inbucket 54324
- runbook: docs/setup/local-supabase.md (manual mode after automated daemon hang)
- registry mirror: docker.m.daocloud.io via ~/.docker/daemon.json
"
```

**预期:** `✓ Closed issue hnlisf/yopet#1`。如果 `gh` 没鉴权,会打印浏览器 URL —— 访问并完成关闭。

### 6d. 验证

```bash
cd d:/myworkspace/claude-workspace/yopet
gh issue view 1 --json state,closedAt
```

**预期:** `{ "state": "CLOSED", "closedAt": "2026-08-07T..." }`。

---

## §7. 故障食谱

### §7.1. Daemon hang(那次搞坏自动化的 bug)

**症状:** `docker version`、`docker images`、`docker system df` —— 任何命令 —— 超过 30 秒没响应。`com.docker.backend` 的 CPU 可能升高但没进展。

**原因:** `docker compose pull` 在引擎内部累积状态。反复调用能把引擎的 API 队列卡死,尤其在配置变更(加 mirror)触发完整重启后。

**恢复步骤(按顺序):**

1. 关掉所有正在跑 docker 命令的 Git Bash / PowerShell 窗口
2. 右键 Docker Desktop 托盘图标 → **Quit Docker Desktop**
3. 等 10 秒,引擎完全停下(在任务管理器里看 `com.docker.backend` 退出)
4. 从**开始菜单**打开 Docker Desktop(**不要**从旧 shell 启动 —— 要全新的启动上下文)
5. 等 60–90 秒,看托盘变绿
6. 重跑 `§1a`(daemon 响应检查)

**时间预算:** 总计 2–3 分钟。如果还卡,从第 1 步再来一遍 —— 有时需要两轮。

### §7.2. 镜像源没注册

**症状:** `docker info | grep "Registry Mirrors"` 输出为空。

**原因:** `daemon.json` 的改动丢失了(Docker Desktop 在完整重启时偶尔会重写配置),或 daemon 在配置生效前就启动了。

**恢复:**

1. 验证文件正确:
   ```bash
   cat ~/.docker/daemon.json
   ```
   应包含:
   ```json
   {
     "builder": { "gc": { "defaultKeepStorage": "20GB", "enabled": true } },
     "experimental": false,
     "registry-mirrors": ["https://docker.m.daocloud.io"]
   }
   ```
2. 如果镜像源这行不在,重新加上(Edit 工具或任何文本编辑器)
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

```bash
# tail 所有 30 个容器的日志,带颜色
docker compose -f d:/myworkspace/claude-workspace/supabase-local/docker/docker-compose.yml logs -f --tail 100

# 停栈(保留数据)
cd d:/myworkspace/claude-workspace/supabase-local/docker && docker compose stop

# 停栈之后重启
cd d:/myworkspace/claude-workspace/supabase-local/docker && docker compose start

# 总缓存大小(含数据 vhdx)
docker system df
```

---

## §10. 又卡住了,想让我接手

把下面 4 样贴回对话:

- 你跑的那条命令
- 完整输出(或卡在哪)
- `docker info | grep -A 2 "Registry Mirrors"` 的结果
- `Get-Process -Name com.docker.backend | Select-Object Id,@{Name="CPU";Expression={[int]$_.CPU}},@{Name="WS_MB";Expression={[int]($_.WorkingSet/1MB)}}` 的结果

拿到这四样,基本上一轮我就能定位。