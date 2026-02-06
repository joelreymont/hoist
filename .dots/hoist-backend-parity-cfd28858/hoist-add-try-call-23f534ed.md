---
title: Add try_call_indirect lowering regression
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-06T10:34:22.096696+01:00\\\"\""
closed-at: "2026-02-06T10:36:54.422453+01:00"
close-reason: Added try_call_indirect BLR and X0 marshaling regression
---

Context: /Users/joel/Work/hoist/src/codegen/compile.zig:5677; cause: need direct compile-pipeline coverage that try_call_indirect emits BLR and marshals return from X0; fix: add regression test with function-pointer arg and verify BLR+X0 mov_rr; deps: hoist-add-try-call-a532282c; verification: zig build test -j1 --global-cache-dir .zig-global-cache
