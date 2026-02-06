---
title: Add try_call lowering regression test
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"\\\\\\\"2026-02-06T10:31:05.775694+01:00\\\\\\\"\\\"\""
closed-at: "2026-02-06T10:34:20.297054+01:00"
close-reason: Added try_call lowering regression for GOT+BLR+X0
---

Context: /Users/joel/Work/hoist/src/codegen/compile.zig:5647; cause: need direct compile-pipeline coverage that try_call emits AArch64 BL and marshals return from X0; fix: add regression test constructing try_call with func metadata and verify BL+mov_rr from X0; deps: hoist-exceptions-runtime-d1afab88; verification: zig build test -j1 --global-cache-dir .zig-global-cache
