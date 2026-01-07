---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:44:09.327021+02:00"
closed-at: "2026-01-01T09:05:26.844162+02:00"
close-reason: Replaced with correctly titled task
---

Port VCode from cranelift/codegen/src/machinst/vcode.rs (~1500 LOC). Create src/machinst/vcode.zig with VCode struct for virtual-register machine code, block management, constant pools. Depends on: MachInst (hoist-474deb32162db016), regs (hoist-474deaeaf67b3c1d), entity (hoist-474de68d56804654). Files: src/machinst/vcode.zig, vcode_test.zig. Container for machine instructions pre-regalloc.
