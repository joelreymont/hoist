---
title: Lower call tmp-vcode 1
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-21T19:21:15.530478+01:00\\\"\""
closed-at: "2026-02-21T19:30:52.373842+01:00"
close-reason: "discarded: repeat-9 no >=5% positive win"
blocks:
  - hoist-doc-loop-in-5f24d96f
---

Context: src/codegen/compile.zig:6114-6257; cause: per-call tmp VCode/LowerCtx alloc/deinit overhead; fix: remove tmp_vcode path for direct call and emit directly in builder; deps:hoist-doc-loop-in-5f24d96f; verification: zig build test + repeat-9 gate.
