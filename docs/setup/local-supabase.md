# yopet — Local Supabase Manual Setup

> **Status:** manual mode (2026-08-07)
> **Author:** handoff from automated agent session that hit a daemon hang
> **Closes:** [#1](https://github.com/hnlisf/yopet/issues/1)
> **Estimated end-to-end time:** 30–60 minutes the first time, 5 minutes thereafter

This runbook brings the self-hosted Supabase stack to life on this Windows 11 + Docker Desktop host. It's written as a **manual procedure** because the prior automated session got stuck on a Docker daemon that wouldn't service CLI commands after multiple `docker compose pull` invocations — a manual human-in-the-loop is more reliable than letting the same script retry blindly.

---

## §0. Current state (where we already are)

Things already done — **do not redo these**:

| Item | Where | State |
|---|---|---|
| WSL store cleanup (recovery from `docker-desktop` Uninstalling) | `%LOCALAPPDATA%\Docker\wsl\` | `docker-desktop` Running, `docker-desktop-data` registered to the 17–20 GB vhdx |
| Registry mirror added | `~/.docker/daemon.json` → `registry-mirrors: ["https://docker.m.daocloud.io"]` | One backup at `daemon.json.bak-20260806-133114` |
| Docker Desktop restarted | running | Server `29.6.2` last verified |
| Partial image cache | `docker images` | Contains: alpine, hello-world, kong, supabase/postgres, darthsim/imgproxy, postgrest/postgrest, supabase/supavisor (and possibly more — a `docker compose pull` did make progress before the daemon hung). Most images probably **not** yet pulled. |
| supabase-local clone | `d:/myworkspace/claude-workspace/supabase-local/` | Aug 4 commit `1123a748`, `master`, `docker/.env` already copied from `.env.example` |

Things **not** yet done — this is what the manual covers:

- Complete the image cache (full `docker compose pull`)
- `docker compose up -d`
- Verify the 4 endpoints
- Update `PRD.md` §6 row F1
- Commit the docs
- `gh issue close 1`

---

## §1. Pre-flight checks (5 min)

Open a fresh terminal (PowerShell or Git Bash — both work; the runbook uses Git Bash style but commands are equivalent).

### 1a. Daemon responsive

```bash
docker version --format 'Client:{{.Client.Version}} Server:{{.Server.Version}}'
```

**Expected:** `Client:29.6.2 Server:29.6.2`. If this hangs for more than 30 seconds or errors with `Cannot connect to the Docker daemon`, the daemon is wedged — go to **§7. Daemon hang recovery** before proceeding.

### 1b. Mirror registered

```bash
docker info 2>&1 | grep -A 2 -i 'registry mirrors'
```

**Expected:**
```
Registry Mirrors:
 https://docker.m.daocloud.io/
```

If the mirror line is missing, go to **§7. Mirror not registered**.

### 1c. Free ports

```bash
powershell -NoProfile -Command 'Get-NetTCPConnection -LocalPort 54321,54322,54323,54324 -State Listen -ErrorAction SilentlyContinue | Select-Object LocalPort,OwningProcess' 2>&1
```

**Expected:** empty output. If any port is already bound, the existing process owns it — note its PID; you'll need to free it before `up -d` can succeed.

### 1d. Supabase working dir

```bash
cd d:/myworkspace/claude-workspace/supabase-local/docker
ls docker-compose.yml
```

**Expected:** file exists. If not, the clone got moved — go back to your clone location.

---

## §2. Pull the full image stack (15–45 min the first time)

> The first pull downloads ~30 images totaling ~5–8 GB. It WILL take 15+ minutes — **do not interrupt it**. If you see no progress for 5+ minutes, the connection is likely wedged, not slow.

### 2a. Pull

```bash
cd d:/myworkspace/claude-workspace/supabase-local/docker
docker compose pull
```

**Expected output:** a stream of `Pulling <image>` and `Extracting <layer> → <size>MB` lines, ending in `Image ... Pulled` for each image. Real-time, not buffered.

**What I saw that you should NOT mistake for failure:**
- `error getting credentials - err: exec: "docker-credential-desktop": executable file not found in %PATH%` — harmless on most pulls. If a pull fails with this exact error, see §7.
- Long pauses between layer extractions — normal, the daemon processes them serially.

### 2b. Verify the cache

```bash
docker images --format '{{.Repository}}:{{.Tag}}' | wc -l
docker images --format '{{.Repository}}:{{.Tag}}' | grep -cE 'supabase|kong|postgres|gotrue|postgrest|realtime|storage|studio|imgproxy|edge|meta|supavisor|inbucket|migrator'
```

**Expected:** total > 30, matching > 25. If matching < 15, repeat §2a — it's incremental and will only fetch what's missing.

### 2c. If `docker compose pull` gets stuck

| Symptom | Likely cause | Action |
|---|---|---|
| No output for 5+ min despite daemon responding | A specific image manifest HEAD is timing out from the mirror | `Ctrl+C`, then retry `docker compose pull` — incremental, will skip done images |
| `EOF` errors repeating | Mirror reachability flap (rare) | Retry once. If persistent, go to §7. Mirror reachable test. |
| Pull completes but `docker images` doesn't reflect it | Daemon lag | `sleep 30 && docker images` — wait, don't retry yet |

---

## §3. Start the stack detached (1–3 min)

### 3a. Start

```bash
cd d:/myworkspace/claude-workspace/supabase-local/docker
docker compose up -d
```

**Expected output:** `Container supabase-db-1 Started`, etc., for ~30 containers, returning in ~10s.

### 3b. Poll for healthy

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

**Expected:** log converges to all rows showing `(healthy)` within 60–120 seconds. The slowest container is typically `supabase-db-1` (it runs SQL migrations on first boot).

**If a straggler is unhealthy after 5 min:**

```bash
docker ps --filter "label=com.supabase.project" --format '{{.Names}}\t{{.Status}}' | grep -v healthy
docker logs <straggler-name> --tail 80
```

Common patterns:
- `supabase-db-1` complaining about migrations → wait another 60s; migrations take 30–60s the first time
- `supabase-vector` or `supabase-logflare` unhealthy → these are heavy startup; give them 2 min
- Any container saying `Exited (1)` → `docker logs <name>` to see why; usually a port conflict or missing env var

### 3c. Sanity: ports listening

```bash
powershell -NoProfile -Command 'Get-NetTCPConnection -LocalPort 54321,54322,54323,54324 -State Listen -ErrorAction SilentlyContinue | Select-Object LocalPort,OwningProcess' 2>&1
```

**Expected:** 4 rows with ports 54321–54324. If a port is missing, that service didn't bind — investigate before claiming F1 done.

---

## §4. Verify the 4 endpoints (1 min)

### 4a. Studio

```bash
curl -fsS -o /dev/null -w 'Studio HTTP %{http_code}\n' http://localhost:54323
```

**Expected:** `Studio HTTP 200`. (303 redirect to `/project/default` is also fine.)

### 4b. API Gateway

```bash
curl -fsS -o /dev/null -w 'API HTTP %{http_code}\n' http://localhost:54321/rest/v1/
```

**Expected:** `API HTTP 200`.

### 4c. Postgres

```bash
PGPASSWORD=postgres psql -h localhost -p 54322 -U postgres -c '\l' -A -t 2>&1 | head -10
```

**Expected:** a list of databases — at minimum `postgres`, `template0`, `template1`, `supabase_admin`.

If `psql` is not installed locally, fall back to:

```bash
docker exec supabase-db-1 psql -U postgres -c '\l' -A -t 2>&1 | head -10
```

### 4d. Inbucket

```bash
curl -fsS -o /dev/null -w 'Inbucket HTTP %{http_code}\n' http://localhost:54324/
```

**Expected:** `Inbucket HTTP 200`.

---

## §5. Cross-check issue #1's 8 acceptance criteria

Tick each box mentally as the corresponding §4 step passes:

| # | Acceptance criterion | Verified by |
|---|---|---|
| 1 | Docker Desktop 已安装并运行 | §1a (daemon responsive) |
| 2 | 仓库 `supabase/supabase` 已 clone 到本地 | §1d (working dir) |
| 3 | `docker/.env` 已从 `.env.example` 复制 | already done in §0 |
| 4 | `docker compose up -d` 成功,所有容器 healthy | §3b |
| 5 | http://localhost:54323 (Studio) 加载 | §4a |
| 6 | http://localhost:54321 (API Gateway) 返回 200 | §4b |
| 7 | localhost:54322 (Postgres) 可用 psql 连接 | §4c |
| 8 | http://localhost:54324 (Inbucket) 可看到验证邮件 | §4d |

If all 8 are green, F1 is operationally done.

---

## §6. Close F1 (5 min)

### 6a. Update PRD.md §6 row F1

Open `d:/myworkspace/claude-workspace/yopet/PRD.md` and find the row:

```
| F1 | Local dev environment (Docker Supabase) | [#1](https://github.com/hnlisf/yopet/issues/1) | ready |
```

Change the last cell from `ready` to:

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

### 6c. Close issue #1

```bash
cd d:/myworkspace/claude-workspace/yopet
gh issue close 1 -c "F1 done.

- stack: supabase/supabase master @ 1123a748 (Aug 4 clone, no pull)
- 4 endpoints verified manually on 2026-08-07: Studio 54323, API 54321, Postgres 54322, Inbucket 54324
- runbook: docs/setup/local-supabase.md (manual mode after automated daemon hang)
- registry mirror: docker.m.daocloud.io via ~/.docker/daemon.json
"
```

**Expected:** `✓ Closed issue hnlisf/yopet#1`. If `gh` is not authenticated, it will print a browser URL to complete the close.

### 6d. Verify

```bash
cd d:/myworkspace/claude-workspace/yopet
gh issue view 1 --json state,closedAt
```

**Expected:** `{ "state": "CLOSED", "closedAt": "2026-08-07T..." }`.

---

## §7. Troubleshooting recipes

### §7.1. Daemon hang (the bug that broke automation)

**Symptom:** `docker version`, `docker images`, `docker system df` — anything — hangs for >30s with no response. CPU on `com.docker.backend` may be elevated but not making forward progress.

**Cause:** `docker compose pull` accumulates state inside the engine. Repeated invocations can wedge the engine's API queue, especially after a config change (mirror add) forces a full engine restart.

**Recovery (do this in order):**

1. Close every Git Bash / PowerShell window that was running docker commands
2. Right-click the Docker Desktop tray icon → **Quit Docker Desktop**
3. Wait 10 seconds for the engine to fully stop (watch `com.docker.backend` exit in Task Manager)
4. Open Docker Desktop from the **Start menu** (NOT from a previous shell — you want a fresh launch context)
5. Wait 60–90 seconds for the green tray indicator
6. Re-run `§1a` (daemon responsive check)

**Time budget:** 2–3 minutes total. If it still hangs after this, repeat from step 1 — sometimes two cycles are needed.

### §7.2. Mirror not registered

**Symptom:** `docker info | grep "Registry Mirrors"` returns empty.

**Cause:** `daemon.json` change was lost (Docker Desktop sometimes overwrites config files on full restart) OR daemon was started before the config was in place.

**Recovery:**

1. Verify the file is correct:
   ```bash
   cat ~/.docker/daemon.json
   ```
   Should contain:
   ```json
   {
     "builder": { "gc": { "defaultKeepStorage": "20GB", "enabled": true } },
     "experimental": false,
     "registry-mirrors": ["https://docker.m.daocloud.io"]
   }
   ```
2. If mirror line is missing, re-add it (use Edit tool or any text editor)
3. Restart Docker Desktop (see §7.1)
4. Re-run `§1b`

### §7.3. Credential helper errors

**Symptom:** every pull says `error getting credentials - err: exec: "docker-credential-desktop": executable file not found in %PATH%` and the pull fails.

**Cause:** `~/.docker/config.json` has `"credsStore": "desktop"` but the helper binary's PATH context is broken (typically after daemon restart).

**Recovery:**

1. The cleanest fix is a full Docker Desktop restart — see §7.1 — then retry. Do NOT edit `config.json` to remove `credsStore`; Docker Desktop will re-add it on next launch, and the conflict can confuse the engine.
2. After restart, retry the pull. If it still fails with the same credential error, the issue is environmental — likely a corporate config that's broken for you specifically. In that case, ask: does your corp environment require you to log in to Docker Hub? (`docker login` then retry.)
3. Note: anonymous public pulls (which is what F1 needs) don't actually require credentials — the credential lookup is just an eager check. If the lookup fails, the pull sometimes still completes. Always verify with `docker images` after a pull that errored.

### §7.4. Network: corp firewall

**Symptom:** `docker pull` fails with `EOF` to `registry-1.docker.io`. Direct `curl https://registry-1.docker.io/v2/` times out. TCP `Test-NetConnection registry-1.docker.io -Port 443` reports `TcpTestSucceeded: False`.

**Cause:** corporate / school / gov network blocks direct egress to Docker Hub.

**Recovery:** the mirror config in `daemon.json` (§7.2) routes pulls through `docker.m.daocloud.io`. If the mirror itself becomes unreachable, try alternate Chinese mirrors:

- `docker.m.daocloud.io` (currently working from this host)
- `docker.mirrors.ustc.edu.cn`
- `hub-mirror.c.163.com`
- `mirror.baidubce.com`

Edit `~/.docker/daemon.json`'s `registry-mirrors` to an array containing just the working one, restart Docker Desktop (§7.1), retry.

### §7.5. Specific image missing after pull

**Symptom:** `docker compose up -d` fails with `Error response from daemon: pull access denied for <image>` or `image not found`.

**Cause:** mirror doesn't have a specific pinned version (rare but possible for fast-moving tags).

**Recovery:** pull the missing image directly through Docker Hub's authoritative endpoint, bypassing the mirror. Use `docker pull --disable-content-trust <image>` with the exact tag, OR temporarily add `https://registry-1.docker.io` as a fallback in `registry-mirrors`. Better: ask the mirror operator (DaoCloud) to pre-cache that tag, OR `git pull` the supabase-local repo to a newer commit whose tags the mirror does have.

---

## §8. Boundary — what you can / can't do after F1 is up

| You CAN | You CAN'T (yet) |
|---|---|
| `psql` to `postgres`, query the bootstrap schema (`auth.users`, etc.) | Create a `yopet` user, log in via Flutter — that's F3 |
| Open Studio, run ad-hoc SQL | See the 9 `yopet.*` tables — schema migrations land in a later ticket |
| Watch Inbucket receive emails when GoTrue sends them | Tie RLS to your user |
| Tail container logs for triage | Use the `supabase` CLI features (only `docker compose` directly for now) |
| Stop the stack with `docker compose down` (preserves `disk/docker_data.vhdx`) | Trust that `docker compose down -v` is safe — it WILL delete the data vhdx. Avoid unless intentional reset. |

The stack is **left running** at the end of F1 — don't `down` it. F2 (Flutter scaffold) and F3 (sign-in) both need it.

---

## §9. Useful one-liners (post-F1 sanity)

```bash
# tail all logs across all 30 containers, color-coded
docker compose -f d:/myworkspace/claude-workspace/supabase-local/docker/docker-compose.yml logs -f --tail 100

# stop the stack (preserves data)
cd d:/myworkspace/claude-workspace/supabase-local/docker && docker compose stop

# restart after stop
cd d:/myworkspace/claude-workspace/supabase-local/docker && docker compose start

# total cache size (incl. data vhdx)
docker system df
```

---

## §10. If you get stuck again and want me to take over

Paste into chat:
- the exact command you ran
- the output (or where it hung)
- result of `docker info | grep -A 2 "Registry Mirrors"`
- result of `Get-Process -Name com.docker.backend | Select-Object Id,@{Name="CPU";Expression={[int]$_.CPU}},@{Name="WS_MB";Expression={[int]($_.WorkingSet/1MB)}}`

With those four pieces I can usually diagnose in one round.