---
title: Complete try_call lowering in ISLE
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T22:31:49.362912+02:00"
---

File: src/backends/aarch64/lower.isle and isle_helpers.zig. Currently skeleton exists. Need: extract FuncRef metadata (sig_ref, name) in aarch64_try_call, call existing aarch64_call helper, emit CBZ X0 to check exception (0=no exception), emit B to exception_successor on nonzero. Emit label for normal_successor. Depends on hoist-97a381df4d43d8ed. ~25 min.
