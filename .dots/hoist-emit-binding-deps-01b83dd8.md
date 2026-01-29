---
title: Emit binding deps in decision tree
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T21:52:21.532240+01:00"
---

Context: src/dsl/isle/codegen/constructors.zig:136; cause: decision tree uses v{binding} without emitting dependent bindings (match_variant/tuple/extractor) leading to invalid code; fix: track emitted bindings and recursively emit dependencies before constraints/results; deps: hoist-support-extern-extractor-3bffb45e; verification: NO_COLOR=1 zig build test
