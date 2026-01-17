---
title: Add overflow trap variants
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:52:07.375838+02:00"
---

In aarch64_lower_generated.zig, add uadd/usub/umul_overflow_trap: overflow check + BRK. Deps: Add smul_overflow lowering. Verify: zig build test
