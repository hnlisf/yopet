# .archive-superpowers/

> ⚠️ **这一目录是 mattpocock-skills 切换之前 superpowers:* 家族产出的归档**。

## 为什么归档

yopet 项目约定使用 mattpocock-skills 技能家族作为开发流程。但在 2026-08-05 ~ 2026-08-09 期间,F1 和 F2 早期阶段误用了 superpowers:* 家族(`superpowers:brainstorming`、`superpowers:writing-plans` 等),留下了 3 份 spec/plan 文档。

## 归档内容

| 文件 | 原始 commit | 原始生成技能 |
|---|---|---|
| `specs/2026-08-06-f1-local-supabase-design.md` | `b180014` | `superpowers:brainstorming` |
| `plans/2026-08-06-f1-local-supabase.md` | `7b30da7` | `superpowers:writing-plans` |
| `specs/2026-08-09-f2-flutter-scaffold-design.md` | `65770d8` | `superpowers:brainstorming` |

后续 commit `6d61f52` 把其中前两份翻译为中文(`docs: translate F1 spec/plan/setup to Chinese`),归档时翻译版本跟随迁移。

## 内容是否还权威?

**不**——这些文档是早期探索产物,在以下情况下不应作为真理来源:

- F1 已 close(issue #1 closed at commit `fd5e34c`),其产物是运行时验证的真实状态(`docs/setup/local-supabase.md` §11 才是当前权威)
- F2 spec (`65770d8`) 的 7 项决策(state mgmt=riverpod、structure=feature-first、routing=go_router、codegen=工具链不写模型、url=dart-define 默认 54331、targets=Windows+Android、gitignore=全套)被后续 `/to-spec` 或 `/to-tickets` 流程接管后可能调整

## mattpocock 输出在哪里

- 新 spec(由 `/to-spec` 产出):待定,候选路径 `docs/specs/` 或留在 `docs/.archive-superpowers/specs/`(后者不推荐,因为命名含"archive")
- 新 ticket 拆分(由 `/to-tickets` 产出):`docs/tickets/<feature>.md` 或 issue tracker
- 实施:由 `/implement` 走 plan + 代码

## 怎么恢复(如果需要)

git 历史完整保留:

```bash
# 单文件恢复
git checkout <commit-sha> -- docs/superpowers/specs/2026-08-06-f1-local-supabase-design.md

# 整个目录恢复到原名
git mv docs/.archive-superpowers docs/superpowers
```

如果只是想查看(不恢复),直接在 git 历史里看(每个文件都有 original commit 记录在上面)。

## 维护

- 这一目录**只读**——除非 git revert,否则不修改内容
- 任何后续 commit 不应该触碰 `.archive-superpowers/` 里的文件
- 如果将来 mattpocock-skills 自身被替换,这一目录成为"被两次替换的家族产物",按相同模式再次归档