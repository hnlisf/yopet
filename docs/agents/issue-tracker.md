# Issue tracker: GitHub

本仓库的 issue 与 PRD 都放在 GitHub 上。所有操作走 `gh` CLI。

## 约定

- **创建 issue**:`gh issue create --title "..." --body "..."`。多行 body 用 heredoc。
- **读 issue**:`gh issue view <number> --comments`,可用 `jq` 过滤评论,同时取 labels。
- **列 issue**:`gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`,配合 `--label` 与 `--state` 过滤。
- **评论 issue**:`gh issue comment <number> --body "..."`
- **加 / 去标签**:`gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **关闭**:`gh issue close <number> --comment "..."`

仓库信息从 `git remote -v` 推断 —— `gh` 在 clone 内部会自动识别。

## Pull request 当 triage 面

**PR 当需求面:否。** _(若本仓库把外部 PR 当 feature request,置为 `yes`;`/triage` 会读这个标志。)_

当设为 `yes`,PR 跟 issue 走同一套 labels 与 states,用 `gh pr` 对应命令:

- **读 PR**:`gh pr view <number> --comments` 以及 `gh pr diff <number>` 看 diff。
- **列外部 PR 待 triage**:`gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments`,只保留 `authorAssociation` 为 `CONTRIBUTOR`、`FIRST_TIME_CONTRIBUTOR`、`NONE` 的(去掉 `OWNER`/`MEMBER`/`COLLABORATOR`)。
- **评论 / 打 label / 关闭**:`gh pr comment`、`gh pr edit --add-label`/`--remove-label`、`gh pr close`。

GitHub 的 issue 和 PR 共享同一编号空间,所以裸 `#42` 可能是任意一种 —— 用 `gh pr view 42` 试,失败再 fallback `gh issue view 42`。

## 当某个技能说"发布到 issue tracker"

创建一个 GitHub issue。

## 当某个技能说"拉取相关 ticket"

跑 `gh issue view <number> --comments`。

## Wayfinding 操作

由 `/wayfinder` 使用。**地图**是一张 issue,**子**issue 是各 ticket。

- **地图**:一张打了 `wayfinder:map` label 的 issue,承载 Notes / Decisions-so-far / Fog 三段正文。`gh issue create --label wayfinder:map`。
- **子 ticket**:挂到地图下的 issue,作为 GitHub sub-issue(用 `gh api` 走 sub-issues 端点)。若环境未启用 sub-issues,在地图正文里用 task list 列出子项,各子项正文顶部加 `Part of #<map>`。Labels 用 `wayfinder:<type>`(`research`/`prototype`/`grilling`/`task`)。一旦认领,该 ticket 指派给负责的 dev。
- **Blocking**:用 GitHub 原生的 **issue dependencies**(UI 可见)。`gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>` 加边,`<blocker-db-id>` 是阻塞方的数字 **database id**(`gh api repos/<owner>/<repo>/issues/<n> --jq .id`,**不是** `#number` 也不是 `node_id`)。GitHub 报 `issue_dependencies_summary.blocked_by`(只列未关闭的 blocker,这是真正的 gate)。若依赖功能不可用,在子项正文顶部加一行 `Blocked by: #<n>, #<n>`。所有 blocker 关闭即解锁。
- **Frontier 查询**:列地图下所有打开的子项(`gh issue list --state open`,按地图的 sub-issues / task list 范围筛选),去掉仍有未关闭 blocker 的(`issue_dependencies_summary.blocked_by > 0`,或 `Blocked by` 行里有未关 issue),以及已指派的;按地图顺序第一个胜出。
- **认领(Claim)**:`gh issue edit <n> --add-assignee @me` —— 本会话的第一次写操作。
- **解决(Resolve)**:`gh issue comment <n> --body "<answer>"`,然后 `gh issue close <n>`,最后往地图的 Decisions-so-far 末尾追加一段上下文指针(gist + 链接)。