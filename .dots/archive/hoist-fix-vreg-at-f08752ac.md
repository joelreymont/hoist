---
title: Fix vreg at emit
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:54:35.304447+02:00\""
closed-at: "2026-01-24T00:57:40.581406+02:00"
---

In src/backends/aarch64/emit.zig:440, ensure all vregs rewritten before emit. Add assert for vreg detection. Deps: Wire regalloc2 to pipeline. Verify: zig build test
