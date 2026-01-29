---
title: Fix tuple field access
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T21:40:32.430371+01:00"
---

Context: src/dsl/isle/codegen/constructors.zig:336, src/dsl/isle/sema.zig:587, src/dsl/isle/codegen.zig:70; cause: tuple fields accessed by index and tuple returns lack tests; fix: emit .fieldN for match_tuple, add sema/codegen tests for tuple returns/tuple emit; deps: hoist-support-extern-extractor-3bffb45e; verification: NO_COLOR=1 zig build test
