---
title: Pass domtree to insertSpillScratch
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T08:33:46.659691+01:00"
---

Thread dominator info for reload hoisting decisions.
- File: src/codegen/compile.zig:583-588
- Change: Add domtree param to insertSpillScratch
- File: src/codegen/compile.zig:1416  
- Change: Pass ctx.domtree at call site
- Verify: zig build
