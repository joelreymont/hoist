---
title: Add spill coalescing
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T15:05:46.472865+02:00\""
closed-at: "2026-01-26T09:47:21.802091+01:00"
---

Files: src/regalloc/trivial.zig or regalloc2 port
What: Coalesce adjacent spills into STP (store pair)
Pattern: Two consecutive STR to adjacent stack slots -> one STP
Similarly LDP for reloads
Verification: Count STP vs STR in spill-heavy functions
