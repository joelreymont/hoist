---
title: Add rematerialization
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T15:05:09.857361+02:00"
---

Files: src/regalloc/trivial.zig or new regalloc2 port
What: Recompute cheap values instead of spilling
Candidates: Constants, addresses, simple arithmetic
Track cost of recomputation vs spill/reload
Deps: hoist-port-regalloc2-coloring-24fcac51
Verification: Reduced spill count in register pressure tests
