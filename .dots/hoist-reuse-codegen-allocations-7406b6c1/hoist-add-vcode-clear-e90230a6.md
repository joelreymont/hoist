---
title: Add vcode clear-retain path
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:08:21.873783+01:00"
---

Context: src/machinst/vcode.zig:93-99; cause: deinit/init cycles trigger allocator churn; fix: add clearRetainingCapacity API for VCode buffers and use it on reuse path; deps: Reuse codegen allocations; verification: compile loop no longer deinitializes/reinitializes VCode each iteration.
