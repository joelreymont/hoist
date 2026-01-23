---
title: Verify div magic numbers
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:54:22.075860+02:00\""
closed-at: "2026-01-24T00:35:00.481052+02:00"
---

In src/codegen/opts/div_const.zig, add tests comparing against Cranelift's magic number constants. Deps: none. Verify: zig build test
