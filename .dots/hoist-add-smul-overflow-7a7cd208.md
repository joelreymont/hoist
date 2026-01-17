---
title: Add smul_overflow lowering
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:52:07.370637+02:00"
---

In aarch64_lower_generated.zig, add smul_overflow: SMULH + sign check. Deps: Add umul_overflow lowering. Verify: zig build test
