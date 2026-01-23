---
title: Propagate logic imm errors
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-14T14:14:45.169143+02:00\\\"\""
closed-at: "2026-01-14T14:23:05.006381+02:00"
close-reason: encodeLogicalImmediate failures now return error
---

File: src/backends/aarch64/emit.zig:1268-1457. Root cause: encodeLogicalImmediate uses orelse unreachable, masking errors. Fix: return error (e.g., UnsupportedLogicalImmediate) when encoding fails and propagate through emit. Why: comply with error-handling rules and avoid hidden encode bugs.
