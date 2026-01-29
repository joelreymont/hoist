---
title: Compute optimal reload points using dominators
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T08:34:00.155290+01:00\""
closed-at: "2026-01-29T09:03:46.786162+01:00"
---

Find dominating block for reload placement.
- File: src/codegen/compile.zig (in insertSpillScratch)
- For each spilled vreg: find common dominator of all use blocks
- Use: domtree.dominates() to find optimal placement
- Depends: hoist-pass-domtree-to-81261f61, hoist-collect-spilled-vreg-91af239f
- Verify: zig build test
