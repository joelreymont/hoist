---
title: Regalloc properties errors
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-01T17:01:58.733331+01:00\""
closed-at: "2026-02-01T17:06:35.474011+01:00"
close-reason: completed
---

src/regalloc/regalloc_properties.zig:42+ cause: property tests mask allocator errors with catch return false; fix: make property fns return !void and use zc.checkError to propagate; why: avoid error masking.
