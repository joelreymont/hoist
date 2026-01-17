---
title: Add I8X8 vector type
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:50:41.268805+02:00"
---

In src/codegen/data_value.zig:55, add proper I8X8 type for 64-bit vectors. Deps: Add I8X4 vector type. Verify: zig build test
