---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:44:37.688083+02:00"
closed-at: "2026-01-01T09:05:26.864093+02:00"
close-reason: Replaced with correctly titled task
---

Port compilation pipeline from cranelift/codegen/src/machinst/compile.rs (~800 LOC). Create src/machinst/compile.zig orchestrating: lower→regalloc→emit. Depends on: lowering (hoist-474decdd1520bdb6), regalloc (hoist-474dec7c1b0fd064), buffer (hoist-474debc1934bfa6e), ABI (hoist-474dec120ced1e54). Files: src/machinst/compile.zig. Main compilation orchestrator IR→binary.
