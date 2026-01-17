---
title: Add I8X2 vector type
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:50:41.257745+02:00"
---

In src/codegen/data_value.zig:53, add proper I8X2 type instead of defaulting to I8X16. Update type system to distinguish 16-bit vectors. Deps: none. Verify: zig build test
