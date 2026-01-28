---
title: Zig 0.15 test suite compilation errors
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T15:08:56.687379+02:00"
closed-at: "2026-01-04T15:22:19.929144+02:00"
---

Status: Main build (zig build) passes ✅. Test suite has ~35+ errors in:
1. codegen/opts/* - test_runner module changes, Signature.init error union
2. codegen/isle_ctx.zig - RegClass enum mismatch  
3. src/ir/* - PrimaryMap.getOrDefault removed, API signature changes in domtree/loops/jump_table_data

These are mostly in optimization passes and IR unit tests, not core functionality. Core IR, verifier, and backend code compiles successfully.
