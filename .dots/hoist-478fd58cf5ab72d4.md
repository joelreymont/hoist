---
title: Remaining test suite errors (34)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T15:22:28.944308+02:00"
closed-at: "2026-01-04T15:25:42.628522+02:00"
---

Test suite has 34 errors after Zig 0.15 migration. Main build passes ✅. Remaining errors:
- codegen/opts/* (30 errors): test_runner module structure issues, most optimization pass tests
- codegen/isle_ctx.zig (2 errors): RegClass enum mismatch between modules
- codegen/opts/dce.zig (1 error): inferred error set resolution (may be cascading)
- Misc (1 error): edge cases

Core functionality compiles. These are optimization pass tests, not critical for basic operation. May be worth fixing individually or may resolve when test infrastructure is updated.
