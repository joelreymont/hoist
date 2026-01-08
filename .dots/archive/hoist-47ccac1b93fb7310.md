---
title: Signature validation infrastructure
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-07T15:57:26.652939+02:00\""
closed-at: "2026-01-08T12:45:11.587992+02:00"
---

Need infrastructure to look up Signature from SigRef in Function. Currently sig_ref is just marked as unused in call functions. Required for dot 1.17 (signature validation). Files: src/ir/function.zig needs signatures map, src/machinst/lower.zig needs getSig method.
