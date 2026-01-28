---
title: Implement return value handling
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:36.515824+02:00"
closed-at: "2026-01-06T19:07:20.605000+02:00"
---

File: src/backends/aarch64/abi.zig. Return values: integers in X0 (or X0+X1 for i128), floats in V0, HFA in V0-V3. Large structs: caller allocates space, passes pointer in X8, callee stores result. Handle multiple return values (Cranelift IR allows). Dependencies: argument classification. Effort: 2 days.
