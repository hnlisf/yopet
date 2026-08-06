# 领域文档使用规约

工程类技能在探索本仓库代码时,应如何消费本仓库的领域文档。

## 探索之前先读这些

- 仓库根目录的 **`CONTEXT.md`**,或
- 仓库根目录的 **`CONTEXT-MAP.md`**(若存在)—— 它会指向每个 context 的 `CONTEXT.md`。按主题需要读相应的那几份。
- **`docs/adr/`** —— 读与即将改动区域相关的 ADR。在多 context 仓库里,也查 `src/<context>/docs/adr/` 看 context 级决策。

如果上述文件不存在,**静默继续**。不要主动标记"缺这个文件",也不要建议先创建。`/domain-modeling` 技能(经 `/grill-with-docs` 与 `/improve-codebase-architecture` 触发)会在术语或决策实际落地时按需创建。

## 文件结构

单 context 仓库(多数情况):

```
/
├── CONTEXT.md
├── docs/adr/
│   ├── 0001-event-sourced-orders.md
│   └── 0002-postgres-for-write-model.md
└── src/
```

多 context 仓库(根目录有 `CONTEXT-MAP.md`):

```
/
├── CONTEXT-MAP.md
├── docs/adr/                          ← 系统级决策
└── src/
    ├── ordering/
    │   ├── CONTEXT.md
    │   └── docs/adr/                  ← context 级决策
    └── billing/
        ├── CONTEXT.md
        └── docs/adr/
```

## 用术语表的词汇

凡在产出(issue 标题、重构建议、假设、测试名)中提到领域概念,都用 `CONTEXT.md` 定义的词。不要漂移到术语表明确排除的同义词。

如果你需要的概念不在术语表里,这是信号 —— 要么你在发明项目不用的语言(重新考虑),要么真有缺口(记一笔,留给 `/domain-modeling`)。

## 标记 ADR 冲突

如果你的产出与现有 ADR 冲突,显式提出来,不要默默覆盖:

> _与 ADR-0007 (event-sourced orders) 冲突 —— 但值得重新讨论,因为…_