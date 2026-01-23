---
title: Add redundant load elim
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:53:07.174986+02:00\""
closed-at: "2026-01-26T08:53:48.831932+01:00"
---

In src/codegen/peephole.zig:139, implement redundant load elimination. Use alias analysis. Deps: Add dead move elim peephole. Verify: zig build test
