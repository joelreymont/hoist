---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:45:23.163119+02:00"
closed-at: "2026-01-01T09:05:26.867886+02:00"
close-reason: Replaced with correctly titled task
---

Port aarch64 instructions from cranelift/codegen/src/isa/aarch64/inst/mod.rs (~3500 LOC). Create src/backends/aarch64/inst.zig with Inst enum, all ARM64 instruction variants, register/immediate encoding helpers. Depends on: MachInst (hoist-474deb32162db016), regs (hoist-474deaeaf67b3c1d). Files: src/backends/aarch64/inst.zig. Complete ARM64 instruction set including NEON.
