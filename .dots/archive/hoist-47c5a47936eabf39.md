---
title: Add control flow e2e test
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T07:34:13.800756+02:00"
closed-at: "2026-01-07T08:13:25.808659+02:00"
---

File: src/backends/aarch64/e2e_control_flow_test.zig (new). Test branches and conditionals: brif (B.cond), br_table (indirect jump table), select. Build IR with: (1) if-then-else, (2) switch statement, (3) ternary select. Compile, execute, verify correct paths taken. Test all condition codes. ~110 lines. Depends: pipeline (hoist-47c5a1d26d09f085).
