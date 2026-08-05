# yopet F1 — Local Supabase dev environment

> Status: ready for user review
> Author: brainstorm with user on 2026-08-06
> Closes: [#1](https://github.com/hnlisf/yopet/issues/1)
> Implements: ADR-0004 (Backend = Supabase, self-hosted)

## Context

yopet's F1 (issue #1, status was `ready`) asks for a locally-runnable Supabase stack so later features (F2-F12) can develop against real endpoints rather than mocks. As of 2026-08-06, Docker Desktop on this machine was inoperable due to a WSL-store corruption (see memory `project-yopet-docker-desktop-crash`); that has been resolved via the lightweight path (no data-disk reset), so F1 can proceed against the existing container runtime.

The user already cloned the official `supabase/supabase` monorepo to `d:/myworkspace/claude-workspace/supabase-local/` on Aug 4 (commit `1123a748`, master) and copied `docker/.env.example` to `docker/.env`. What remains is the actual `docker compose pull && up -d` + endpoint verification.

## Goal

A reproducible local-Supabase stack that:

1. Brings up Postgres + GoTrue + PostgREST + Realtime + Storage + Studio + Inbucket via `docker compose up -d`
2. Passes all 8 acceptance-criteria checks listed on issue #1
3. Leaves a written runbook in the yopet repo that captures the exact commands plus the Docker-Desktop-WSL recovery so the next session doesn't relearn it
4. Updates F1 status from `ready` to `done` in `PRD.md` §6 and closes issue #1 via `gh`

## Scope (in)

- Pull images pinned to the Aug 4 commit (no `git pull`)
- Detached `docker compose up -d`
- Health-check polling loop up to 5 min, fail loudly otherwise
- Verification of the 4 endpoints from issue #1 (Studio, API Gateway, Postgres, Inbucket)
- Authoring `yopet/docs/setup/local-supabase.md` runbook
- Updating `yopet/PRD.md` §6 row F1 to `done`
- Closing issue #1 via `gh issue close 1 -c "..."`

## Out of scope (YAGNI)

| Item | Why out |
|---|---|
| yopet 9-table schema migrations | F1 = empty DB; schema lands in a later ticket |
| `.env` value overrides | Local-dev defaults are sufficient; overridden values create "what did I change" cognitive load |
| `git pull` in supabase-local/ | Decided locked; reproducibility > freshness |
| Submodule-ifying supabase-local into yopet | Current sibling layout works; submodule adds a new failure surface |
| `supabase db reset` after up | No schema exists yet; reset is a no-op |
| Production hardening (TLS, backups, secrets) | That's prod-stack work, not F1 |

## Approach (the 8 steps)

Steps 1–8 are the runtime phase; the on-disk artifacts and issue close-out happen after step 8.

```
1. cd d:/myworkspace/claude-workspace/supabase-local/docker
2. docker compose pull          # ~30 images, 5–8 GB, 5–10 min
3. docker compose up -d         # start detached
4. poll docker ps for health=healthy (~60–120 s expected)
5. curl http://localhost:54323 (Studio) — expect HTTP 200
6. curl http://localhost:54321 (API)   — expect HTTP 200
7. PGPASSWORD=postgres psql -h localhost -p 54322 -U postgres -c '\l' — expect listing
8. curl http://localhost:54324 (Inbucket) — expect HTTP 200
```

**Completion phase** (after step 8):
9. Author `yopet/docs/setup/local-supabase.md` per "Yopet artifacts" §1
10. Update `yopet/PRD.md` §6 row F1: status → `done`, link to new doc
11. Commit docs (`docs:` scope), then `gh issue close 1 -c "..."`

## Failure modes & fallbacks

| Symptom | Action | Stop condition |
|---|---|---|
| `docker compose pull` network timeout | Retry once | Retry fails → ask user to check proxy/VPN |
| Container won't reach `healthy` | `docker logs <name>`, one retry | After 2 retries → STOP, return to root-cause investigation |
| Port already bound | `Get-NetTCPConnection` to find owner; either free or edit `docker/.env` `*_PORT` var | If override needed, document in runbook |
| Repeated failure on same component | STOP — "3+ fixes → question architecture" | Discuss with user before further fixes |

## Yopet artifacts produced

1. `yopet/docs/setup/local-supabase.md` — runbook with:
   - Prereqs (Docker Desktop 4.x+, WSL2 enabled, ports 54321/22/23/24 free)
   - **The WSL/Docker Desktop recovery playbook** (fingerprints + 5-step fix) — high-leverage knowledge for future sessions
   - Runtime commands annotated (the `cd`, `docker compose pull`, `docker compose up -d` triplet)
   - Endpoint cheat sheet (port → service → PRD/ADR cross-ref)
   - "What I can do now / what I can't" (boundary statement)
2. `yopet/PRD.md` §6 row F1: status → `done`, with link to the new doc

## Acceptance criteria (verbatim from issue #1)

- [ ] Docker Desktop 已安装并运行
- [ ] 仓库 `supabase/supabase` 已 clone 到本地（用 `--depth 1` 加速）
- [ ] `docker/.env` 已从 `.env.example` 复制
- [ ] `docker compose up -d` 成功,所有容器 healthy
- [ ] http://localhost:54323 (Studio) 加载,显示空项目
- [ ] http://localhost:54321 (API Gateway) 返回 200
- [ ] localhost:54322 (Postgres) 可用 psql 连接
- [ ] http://localhost:54324 (Inbucket) 可看到验证邮件

Issue #1 close comment should reference the runbook path.

## Open questions

None — both scope-limiting decisions were resolved during brainstorming:
1. Scope = strict issue #1 (no schema seed) — user selected A
2. Clone handling = use Aug 4 clone as-is, do not `git pull` — user selected原地

## References

- [Issue #1](https://github.com/hnlisf/yopet/issues/1) — original ticket
- [ADR-0004](../adr/0004-backend-supabase-self-hosted.md) — why self-hosted
- Memory: `project-yopet-docker-desktop-crash` — the just-resolved WSL corruption that unblocked F1
- Working scratch: `yopet/.scratch/prd-spec.md` — 9-table schema, **not** part of F1
