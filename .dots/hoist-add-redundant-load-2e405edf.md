---
title: Add redundant load elim
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:53:07.174986+02:00"
---

In src/codegen/peephole.zig:139, implement redundant load elimination. Use alias analysis. Deps: Add dead move elim peephole. Verify: zig build test
