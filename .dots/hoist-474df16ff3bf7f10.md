---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:45:48.963785+02:00"
closed-at: "2026-01-01T09:05:26.882971+02:00"
close-reason: Replaced with correctly titled task
---

Port aarch64 ISA from cranelift/codegen/src/isa/aarch64/mod.rs (~800 LOC). Create src/backends/aarch64/isa.zig implementing TargetIsa interface, settings, feature detection (SVE, NEON, etc.). Depends on: aarch64 ABI (hoist-474df082b02de503), aarch64 ISLE (hoist-474df10843baaf78), compile pipeline (hoist-474ded305f087ca7). Files: src/backends/aarch64/isa.zig. Complete ARM64 backend. MILESTONE: aarch64 backend functional!
