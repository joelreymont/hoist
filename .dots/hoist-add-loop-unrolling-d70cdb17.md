---
title: Add loop unrolling pass
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:52:57.781849+02:00"
---

Create src/codegen/opts/loop_unroll.zig. Unroll small fixed-trip loops. Deps: Add LICM pass. Verify: zig build test
