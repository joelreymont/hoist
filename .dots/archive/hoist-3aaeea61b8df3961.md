---
title: Wire peephole optimizer into compile pipeline
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T16:41:37.234706+02:00\""
closed-at: "2026-01-08T16:43:11.082242+02:00"
---

File: src/codegen/compile.zig - Created AArch64 peephole optimizer in src/backends/aarch64/peephole.zig but it's not called anywhere. Need to integrate into compile() after register allocation and before emission. Should run 2-3 passes until no changes. Location: After VReg→PReg rewriting, before final emission loop.
