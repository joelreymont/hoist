---
title: Pass vreg_origins to insertSpillScratch
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T08:33:21.910264+01:00\""
closed-at: "2026-01-29T08:42:22.302008+01:00"
---

Thread origin map through to reload emission.
- File: src/codegen/compile.zig:583-588
- Change: Add vreg_origins param to insertSpillScratch signature
- File: src/codegen/compile.zig:1416
- Change: Pass vreg_origins at call site
- Depends: hoist-populate-vregorigin-during-1507cde6
- Verify: zig build
