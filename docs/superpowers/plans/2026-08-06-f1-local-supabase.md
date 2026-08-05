# F1 — Local Supabase Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring up the official `supabase/supabase` docker-compose stack locally and prove the four operational endpoints (Studio, API Gateway, Postgres, Inbucket) all return healthy. Then capture the procedure in a runbook and close issue #1.

**Architecture:** Operational task, not a code project. We do `docker compose pull && docker compose up -d` against the existing `d:/myworkspace/claude-workspace/supabase-local/` clone (Aug 4 commit `1123a748`, do not `git pull`). Poll until all containers are `healthy`. Hit the four endpoints. Author a single runbook capturing prereqs + the just-discovered WSL recovery recipe. Update PRD status and close the issue.

**Tech Stack:**
- Docker Desktop (just recovered via 5-step WSL recovery — memory `project-yopet-docker-desktop-crash`)
- `docker compose` (bundled with Docker Desktop; v2, NOT legacy `docker-compose` v1)
- `supabase/supabase` monorepo, `docker/` directory
- `gh` CLI (issue tracking per yopet `CLAUDE.md`)
- PowerShell for PSQL backend (or WSL postgres-client)

## Global Constraints

These constraints are copied verbatim from [the spec](docs/superpowers/specs/2026-08-06-f1-local-supabase-design.md) and from `ADR-0004`. Every task's requirements implicitly include this section.

- **Use the Aug 4 clone as-is.** Do NOT `git pull` `supabase-local/` — image tags and template variables are pinned to the `1123a748` commit.
- **Do NOT delete** `%LOCALAPPDATA%\Docker\wsl\disk\docker_data.vhdx` (the data vhdx can grow to 17–20 GB even when empty; preserve it).
- **Scope** = strict issue #1 acceptance criteria. No `yopet.*` schema migrations, no `.env` value overrides, no submodule-ification.
- **Failure budget**: at most 2 retries per component per task. 3+ failures → STOP and re-investigate via `superpowers:systematic-debugging` (return to Phase 1).
- **Working directory for compose commands** = `d:/myworkspace/claude-workspace/supabase-local/docker/`. Always run compose commands from there.
- **Issue tracker** = GitHub via `gh` CLI. The yopet `CLAUDE.md` says "Issues live in this repo's GitHub Issues, accessed via the `gh` CLI."
- **Yopet commit convention** = conventional commits (the prior commits in this repo: `chore: initial commit (agent skills scaffolding)`, `docs(superpowers): ...`, `docs(prd): ...`).
- **End every git commit message** with `Co-Authored-By: Claude <noreply@anthropic.com>`.

---

## Task 1: Pull all Supabase images

**Files:** None (purely operational)

**Interfaces:** None (no yopet file is touched; Docker image cache is the deliverable)

- [ ] **Step 1: Verify Docker daemon is responsive**

Run:
```bash
docker info --format 'Server:{{.Server.Version}}'
```

Expected: prints `Server:29.6.2` (or similar). If it errors with "Cannot connect to the Docker daemon", open Docker Desktop from the Start menu and wait until the tray icon shows green, then retry.

- [ ] **Step 2: Verify the current image cache is empty (failing precondition)**

Run:
```bash
docker images --format '{{.Repository}}:{{.Tag}}' | grep -c 'supabase\|postgres\|gotrue\|kong\|postgrest' || true
```

Expected: `0`. If non-zero, the previous run already populated the cache — that's still fine, but it confirms step 3 will be incremental not full.

- [ ] **Step 3: Run `docker compose pull`**

Run:
```bash
cd "d:/myworkspace/claude-workspace/supabase-local/docker"
docker compose pull
```

Expected output: a stream of `Pulling xxx Pull complete` lines for ~30 images (Postgres 15, GoTrue, PostgREST, Realtime, Storage, Studio, Inbucket, Analytics/Logflare, Imgproxy, Supavisor/Pooler, pg-meta, Edge Runtime, Migrator, etc.). Expected duration: 5–10 minutes on first run, ~30s if cache is warm.

Failure handling:
- Network/proxy timeout → retry ONCE; second failure → STOP, return to Phase 1 of systematic-debugging
- Layer pull error → re-run `docker compose pull` (resumes from failed layer), retry ONCE; second failure → STOP

- [ ] **Step 4: Verify the pull landed**

Run:
```bash
docker images --format '{{.Repository}}:{{.Tag}}' | grep -E 'supabase|postgres|gotrue|kong|postgrest' | wc -l
```

Expected: at least `15` matching images. (This is a fuzzy lower bound because Supabase's compose file references both `supabase/*` and `postgres:*` images.)

- [ ] **Step 5: No-commit confirmation**

This task touches no yopet source files, so no commit. The image cache lives in `%LOCALAPPDATA%\Docker\wsl\disk\docker_data.vhdx` and survives commits — untracked.

---

## Task 2: Start the stack detached and wait for healthy

**Files:** None (operational)

**Interfaces:**
- Consumes: Task 1's image cache
- Produces: ~30 running containers on ports 54321–54324, each `State: Up (healthy)` within 5 minutes

- [ ] **Step 1: Verify the failing precondition — no Supabase containers running**

Run:
```bash
docker ps --filter "label=com.supabase.project" --format '{{.Names}}'
```

Expected: empty line. If non-empty, prior run leaked containers — Task 4 troubleshooting says `docker compose down` first, then proceed.

- [ ] **Step 2: Start the stack detached**

Run:
```bash
cd "d:/myworkspace/claude-workspace/supabase-local/docker"
docker compose up -d
```

Expected output: a summary like `Container supabase-db-1 Started`, etc., for ~30 containers, returning in ~10s.

- [ ] **Step 3: Poll until all containers are healthy (≤ 5 min)**

Run (single shell command):
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

Expected output: a progress log that converges to a state where all rows say `(healthy)`. Common durations: 60–120 seconds for a warm cache. Migration container (`supabase-db-1`) is typically the slowest because it runs SQL migrations on first boot.

Failure handling:
- After 5 min, if not all healthy → `docker ps --filter "label=com.supabase.project" --format '{{.Names}}\t{{.Status}}'` to identify the stragglers, then `docker logs <name> --tail 50` for one straggler at a time. Stop after 2 stragglers-debugged and return to Phase 1.

- [ ] **Step 4: Verify port mappings exist (sanity)**

Run:
```bash
powershell -NoProfile -Command 'Get-NetTCPConnection -LocalPort 54321,54322,54323,54324 -State Listen -ErrorAction SilentlyContinue | Select-Object LocalPort,OwningProcess | Format-Table -AutoSize'
```

Expected: 4 rows with `LocalPort` = 54321, 54322, 54323, 54324 in `Listen` state. If any port is missing, the corresponding service failed to start — investigate before proceeding to Task 3.

- [ ] **Step 5: No-commit confirmation**

Same as Task 1.

---

## Task 3: Verify the four endpoints from issue #1

**Files:** None (operational)

**Interfaces:**
- Consumes: Task 2's running stack on ports 54321–54324
- Produces: passing evidence for each of issue #1's 8 acceptance-criteria checkboxes

- [ ] **Step 1: Verify Studio (http://localhost:54323)**

Run:
```bash
curl -fsS -o /dev/null -w 'Studio HTTP %{http_code}\n' http://localhost:54323
```

Expected: `Studio HTTP 200`. A 30x (redirect) is also acceptable since Studio may redirect to `/project/default`.

- [ ] **Step 2: Verify API Gateway (http://localhost:54321)**

Run:
```bash
curl -fsS -o /dev/null -w 'API HTTP %{http_code}\n' http://localhost:54321/rest/v1/
```

Expected: `API HTTP 200`. (PostgREST's `/rest/v1/` returns 200 even when empty.)

- [ ] **Step 3: Verify Postgres (localhost:54322)**

Run (Windows-native, assuming psql on PATH):
```bash
PGPASSWORD=postgres psql -h localhost -p 54322 -U postgres -c '\l' -A -t 2>&1 | head -10
```

Expected: a `postgres`, `template0`, `template1`, `supabase_admin` list of databases.

If `psql` is not on PATH (this Windows host might not have postgres-client installed), fall back to Docker:
```bash
docker exec supabase-db-1 psql -U postgres -c '\l' -A -t 2>&1 | head -10
```

Either form should list the same databases.

- [ ] **Step 4: Verify Inbucket (http://localhost:54324)**

Run:
```bash
curl -fsS -o /dev/null -w 'Inbucket HTTP %{http_code}\n' http://localhost:54324/
```

Expected: `Inbucket HTTP 200`.

- [ ] **Step 5: Cross-check against issue #1's 8 acceptance criteria**

Each of the four verifications maps directly to two of issue #1's checkboxes. Tick them mentally:

| # | Acceptance criterion | Verified by |
|---|---|---|
| 1 | Docker Desktop 已安装并运行 | Task 1 step 1 + Task 2 step 1 (preconditions) |
| 2 | 仓库 `supabase/supabase` 已 clone 到本地 | precondition; clone at `d:/myworkspace/claude-workspace/supabase-local/` predates this session |
| 3 | `docker/.env` 已从 `.env.example` 复制 | precondition; `docker/.env` exists (identical 11773-byte size to `.env.example`) |
| 4 | `docker compose up -d` 成功，所有容器 healthy | Task 2 step 3 |
| 5 | http://localhost:54323 (Studio) 加载,显示空项目 | Task 3 step 1 |
| 6 | http://localhost:54321 (API Gateway) 返回 200 | Task 3 step 2 |
| 7 | localhost:54322 (Postgres) 可用 psql 连接 | Task 3 step 3 |
| 8 | http://localhost:54324 (Inbucket) 可看到验证邮件 | Task 3 step 4 |

- [ ] **Step 6: No-commit confirmation**

Same as Task 1.

---

## Task 4: Author runbook + update PRD status + commit

**Files:**
- Create: `yopet/docs/setup/local-supabase.md`
- Modify: `yopet/PRD.md` line range covering §6 row F1 (currently `status: ready`)

**Interfaces:**
- Consumes: the WSL recovery recipe from memory `project-yopet-docker-desktop-crash`; the endpoint list established by Task 3
- Produces: a single runbook another agent can use from a clean Windows install; an updated PRD that reflects F1's true status

- [ ] **Step 1: Verify failing precondition — the runbook does not yet exist**

Run:
```bash
ls "d:/myworkspace/claude-workspace/yopet/docs/setup/local-supabase.md" 2>&1
```

Expected: `No such file or directory`.

- [ ] **Step 2: Verify failing precondition — PRD §6 row F1 still says `ready`**

Run:
```bash
grep -n '| F1 | Local dev environment' "d:/myworkspace/claude-workspace/yopet/PRD.md"
```

Expected: a line containing `| F1 | Local dev environment (Docker Supabase) | [#1](...) | ready |`. If the state is already `done`, this task is partly redundant — still update row, just note the duplication in commit body.

- [ ] **Step 3: Create the runbook directory and write the file**

Run:
```bash
mkdir -p "d:/myworkspace/claude-workspace/yopet/docs/setup"
```

Then create `d:/myworkspace/claude-workspace/yopet/docs/setup/local-supabase.md` with this exact content:

````markdown
# yopet — Local Supabase Setup

> Status: live (F1 done, issue #1 closed)
> Last verified: 2026-08-06
> Closes: [#1](https://github.com/hnlisf/yopet/issues/1)

This runbook brings the self-hosted Supabase stack to life on a Windows 11 + Docker Desktop host. It also captures the WSL recovery recipe in case Docker Desktop enters a stuck state (the recovery that unblocked F1 itself).

## 1. Prerequisites

| | |
|---|---|
| OS | Windows 11 with WSL2 enabled (most modern Win11 installs have it) |
| Docker Desktop | 4.x+, with WSL2 backend selected (Settings → General → Use WSL2) |
| Free ports | 54321 (Kong/API), 54322 (Postgres), 54323 (Studio), 54324 (Inbucket) |
| `gh` CLI | for issue tracking per `CLAUDE.md` |
| `psql` (optional) | for direct DB access; `docker exec supabase-db-1 psql …` works as a fallback |

Verify with:

```bash
wsl --status                     # should show 默认版本: 2
docker --version                 # should be Docker Desktop, Engine 25+
docker run --rm hello-world      # smoke test (proves Docker + WSL + netns all work)
```

## 2. ⚠ Docker Desktop WSL recovery playbook

If `docker compose up` fails with errors of this exact shape:

```
terminating WSL distro "docker-desktop": ... 不存在具有所提供名称的分发
错误代码: Wsl/Service/WSL_E_DISTRO_NOT_FOUND
... running WSL command wsl.exe ... --terminate docker-desktop ...
checking if isocache exists: CreateFile \\wsl$\docker-desktop-data\isocache\:
The network name cannot be found.
```

…the WSL-store has a half-removed `docker-desktop` entry. Recover with these 5 steps. **This does NOT delete your images** — the data vhdx is preserved.

```bash
# 1. Make sure Docker Desktop is not running (check tray icon)

# 2. Quiesce WSL
wsl --shutdown

# 3. Clear the stuck docker-desktop registry entry.
#    To find its GUID first:
#       powershell -NoProfile -Command "Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' | Select Name"
#    Then, with the docker-desktop GUID substituted:
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss\{<docker-desktop-guid>}" /f

# 4. Delete the runtime vhdx (small, ~128 MB — Docker Desktop recreates)
rm "$LOCALAPPDATA/Docker/wsl/main/ext4.vhdx"

# 5. Relaunch Docker Desktop from the Start menu — it rebuilds runtime + re-detects the data vhdx
```

After recovery, `disk/docker_data.vhdx` (which may show as 17–20 GB even when empty, because it's a dynamic ext4 filesystem that grows on demand) is preserved untouched.

## 3. Start the stack

```bash
cd d:/myworkspace/claude-workspace/supabase-local/docker

# Pull ~30 images (~5–8 GB, 5–10 min on first run, ~30s if cache is warm)
docker compose pull

# Start detached
docker compose up -d

# Watch for healthy (~60–120 seconds)
docker ps --filter health=healthy --format 'table {{.Names}}\t{{.Status}}'
```

The expected outcome is all rows show `(healthy)` within a few minutes. The slowest container is typically `supabase-db-1` because it runs SQL migrations on first boot.

## 4. Endpoint cheat sheet

| Port | URL | Service | Purpose | PRD/ADR cross-ref |
|---|---|---|---|---|
| 54321 | http://localhost:54321 | Kong (API Gateway) | REST/GraphQL entry | ADR-0004 |
| 54322 | `psql -h localhost -p 54322 -U postgres` | Postgres direct | DB connection for migrations | PRD §5 step 1 |
| 54323 | http://localhost:54323 | Studio | DB GUI, run ad-hoc SQL | F2 |
| 54324 | http://localhost:54324 | Inbucket | Email inbox for GoTrue in dev | PRD §5 step 1 (email verify) |

Postgres password: `postgres` (default — value of `POSTGRES_PASSWORD` in `docker/.env`).
Default schema bootstrap (`auth.users`, `storage.objects`, etc.) is created automatically; no manual migrations in F1.

## 5. Boundary — what you can / can't do here

| You CAN | You CAN'T (yet) |
|---|---|
| `psql` to `postgres`, query the bootstrap schema (`auth.users`, etc.) | Create a `yopet` user, log in via Flutter — that's F3 |
| Open Studio, run ad-hoc SQL | See the 9 `yopet.*` tables — migrations land in a later ticket |
| Watch Inbucket receive emails when GoTrue sends them | Tie RLS to your user |
| Tail container logs for triage | Use `supabase` CLI features (only via `docker compose` directly) |
````

- [ ] **Step 4: Update PRD.md §6 row F1 from `ready` to `done`**

Open `d:/myworkspace/claude-workspace/yopet/PRD.md` and find:

```
| F1 | Local dev environment (Docker Supabase) | [#1](https://github.com/hnlisf/yopet/issues/1) | ready |
```

Replace the row's last cell from `ready` to `done`, and append the runbook link. Final row text:

```
| F1 | Local dev environment (Docker Supabase) | [#1](https://github.com/hnlisf/yopet/issues/1) | [done](./docs/setup/local-supabase.md) |
```

- [ ] **Step 5: Verify the changes**

Run:
```bash
head -5 "d:/myworkspace/claude-workspace/yopet/docs/setup/local-supabase.md"
grep -n '| F1 | Local dev environment' "d:/myworkspace/claude-workspace/yopet/PRD.md"
```

Expected: the runbook head matches its first 5 lines (title block); the grep returns a single line whose last cell is `done`.

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

PRD §6 row F1 status flips ready -> done with a link to the runbook.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

Expected: a single new commit on `main`. The diff stat should show ~100 lines added across the two files.

---

## Task 5: Close issue #1 with a referencing comment

**Files:** None in repo (operational — uses `gh` CLI)

**Interfaces:**
- Consumes: Task 4's commit SHA
- Produces: issue #1 state = `CLOSED`, with a comment pointing operators at the runbook

- [ ] **Step 1: Capture the F1 commit SHA**

Run:
```bash
cd "d:/myworkspace/claude-workspace/yopet"
git log -1 --format='%H' HEAD
```

Expected: a 40-char SHA. Copy the value — it goes in step 3's close comment.

- [ ] **Step 2: Verify issue #1 is currently OPEN**

Run:
```bash
cd "d:/myworkspace/claude-workspace/yopet"
gh issue view 1 --json state --jq .state
```

Expected: `OPEN`. If already `CLOSED`, stop and ask the user — duplicate closures cause noise in the issue history.

- [ ] **Step 3: Close issue #1 with a referencing comment**

Run:
```bash
cd "d:/myworkspace/claude-workspace/yopet"
gh issue close 1 -c "F1 done.

- stack: supabase/supabase master @ 1123a748 (Aug 4 clone, no pull)
- 4 endpoints verified on 2026-08-06: Studio 54323, API 54321, Postgres 54322, Inbucket 54324
- runbook: docs/setup/local-supabase.md (includes the WSL recovery recipe from this session)
- closing commit: <paste Task 4's commit SHA here>"
```

Expected: GH CLI reports `✓ Closed issue hnlisf/yopet#1`. If authentication is required and not configured, `gh` will print a URL to visit — visit it and complete the close in the browser.

- [ ] **Step 4: Verify the close**

Run:
```bash
cd "d:/myworkspace/claude-workspace/yopet"
gh issue view 1 --json state,closedAt,comments --jq '{state: .state, closedAt: .closedAt, commentCount: (.comments | length)}'
```

Expected: `{ "state": "CLOSED", "closedAt": "2026-08-06T...", "commentCount": 1 }` (or higher if prior comments existed).

- [ ] **Step 5: No-commit confirmation**

Issue close is an external state change, not a repo file change. No commit needed.

---

## Self-Review (filled inline while writing)

1. **Spec coverage:** Walked the spec — every section maps to a task: Approach steps 1–8 → Tasks 1–3; Yopet artifacts §1 (runbook) → Task 4 step 3; Yopet artifacts §2 (PRD update) → Task 4 step 4; "Completion phase" steps 9–11 in spec → Task 4 (commit) + Task 5 (close issue). Failure modes covered by retry-budget language in every operational step.
2. **Placeholder scan:** No "TBD", no "TODO", no "implement later". Every step has explicit run commands and expected output.
3. **Type / name consistency:** Same compose commands (`docker compose pull`, `docker compose up -d`) used in tasks 1, 2, 3, 4 step 3. Same port quartet (54321–54324) referenced in tasks 2 and 3 and the runbook. Same registry path (`HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss\…`) used here and in the runbook.
4. **Failure budget:** explicitly stated in Global Constraints and re-stated in retry-prone steps (steps that pull from network, steps that depend on container startup).
