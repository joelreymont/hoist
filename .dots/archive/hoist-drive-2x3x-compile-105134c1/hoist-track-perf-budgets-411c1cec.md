---
title: Track perf budgets continuously
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T13:07:40.612757+01:00\""
closed-at: "2026-02-17T13:34:35.270520+01:00"
close-reason: "completed continuous perf tracking epic: bench-gate now appends timestamped JSONL history, supports explicit 2x/3x budget guards, and docs include canonical verification commands and acceptance flow"
---

Context: tools/perf_gate.zig, build.zig:599-610, docs/COMPLETION_STATUS.md; cause: no continuous budget tracking for 2x/3x goals across commits; fix: persist metrics artifacts and enforce regression budgets in CI workflow; deps: Wire release benchmark mode; verification: repeatable JSON history and failing gate on budget breach.
