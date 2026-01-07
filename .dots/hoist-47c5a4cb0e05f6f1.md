---
title: Add recursive function e2e test
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T07:34:19.164177+02:00"
closed-at: "2026-01-07T08:13:26.196710+02:00"
---

File: src/backends/aarch64/e2e_recursion_test.zig (new). Test recursive calls: factorial, fibonacci. Build IR with recursive call instruction, compile, execute. Verify: (1) stack frames properly nested, (2) return address preserved (X30/LR), (3) correct base case termination, (4) correct results (factorial(5) == 120). ~70 lines. Depends: pipeline (hoist-47c5a1d26d09f085).
