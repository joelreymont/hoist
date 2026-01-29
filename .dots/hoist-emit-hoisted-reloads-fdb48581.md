---
title: Emit hoisted reloads at block entry
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T08:34:06.738258+01:00"
---

Place single reload at dominator block instead of per-use.
- File: src/codegen/compile.zig:615
- Change: emit reload at computed dominator block entry
- Track: which vregs already reloaded in each block
- Skip: redundant reloads in dominated blocks
- Depends: hoist-compute-optimal-reload-32c51f0c
- Verify: Count reloads before/after on high-pressure test
