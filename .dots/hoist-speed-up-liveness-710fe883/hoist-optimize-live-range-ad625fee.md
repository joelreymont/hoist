---
title: Optimize live-range reconstruction
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:08:21.840013+01:00"
---

Context: src/regalloc/liveness.zig:500-620; cause: reconstruction walks hash structures repeatedly; fix: derive ranges from dense arrays indexed by compact vreg ids; deps: Replace live sets with bitsets; verification: range overlap/interference tests still pass.
