---
title: Add IR dumps
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-01-17T12:46:36.932883+02:00\\\"\""
closed-at: "2026-01-17T13:33:38.480784+02:00"
---

Files: src/codegen/context.zig:16-46, src/codegen/compile.zig:636-726. Cause: no per-stage dump hooks. Fix: add DebugOptions (stage set + dump_dir) and call dump after verify/legalize/unreachable/alias/egraph/lower/regalloc/emit. Why: fast stage debugging. Verify: test dump writes file in /tmp and snapshot its contents.
