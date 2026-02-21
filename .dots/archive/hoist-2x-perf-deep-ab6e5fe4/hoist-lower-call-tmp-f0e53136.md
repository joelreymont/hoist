---
title: Lower call tmp-vcode 2
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-21T19:21:15.539992+01:00\\\"\""
closed-at: "2026-02-21T19:30:52.380100+01:00"
close-reason: "discarded: repeat-9 no >=5% positive win"
blocks:
  - hoist-lower-call-tmp-a4ddff2d
---

Context: src/codegen/compile.zig:6152-6257; cause: same overhead for call_indirect/try_call*; fix: complete direct-emission conversion for remaining call forms; deps:hoist-lower-call-tmp-a4ddff2d; verification: zig build test + repeat-9 gate.
