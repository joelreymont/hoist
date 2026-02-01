---
title: Fix AArch64 Emit Panics
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T10:05:45.558776+01:00\""
closed-at: "2026-02-01T20:43:53.133179+01:00"
close-reason: "completed: emit returns InvalidShift/VirtualRegister errors (src/backends/aarch64/emit.zig:440-443, 2150-2163, 2214-2227) and CodegenError includes those"
---

Context: src/backends/aarch64/emit.zig:442; cause: panic on vreg/shift; fix: return CodegenError and validate earlier; deps: hoist-remove-panics-and-a0d5efe0; verification: aarch64 emit tests
