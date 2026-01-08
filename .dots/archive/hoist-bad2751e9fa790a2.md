---
title: Define exception detection mechanism
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T21:19:17.309995+02:00\""
closed-at: "2026-01-08T21:36:19.528043+02:00"
---

File: src/backends/aarch64/abi.zig. Document how we detect exceptions after try_call: Option 1: Use X0 for both return and exception (null = no exception), Option 2: Use W0 status + X1 for value. Choose simpler X0-based approach. ~10 min.
