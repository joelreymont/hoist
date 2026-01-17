---
title: Wire multi-return marshaling
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:51:32.734787+02:00"
---

In src/backends/aarch64/isle_helpers.zig:3771-3879, use extended ValueRegs for >2 returns. Marshal X0-X3 or V0-V3. Deps: Extend ValueRegs to 4. Verify: zig build test
