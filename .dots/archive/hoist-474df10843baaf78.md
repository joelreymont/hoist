---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:45:42.168516+02:00"
closed-at: "2026-01-01T09:05:26.879292+02:00"
close-reason: Replaced with correctly titled task
---

Use ISLE compiler to compile cranelift/codegen/src/isa/aarch64/*.isle (~8613 LOC ISLE) to Zig. Create src/backends/aarch64/lower_generated.zig from inst.isle, lower.isle, inst_neon.isle. Depends on: ISLE compiler (hoist-474dea951b7c65e0), aarch64 inst (hoist-474defe643e6a7e9), lowering framework (hoist-474decdd1520bdb6). Files: src/backends/aarch64/lower_generated.zig (generated). Pattern matching for IR→ARM64 lowering.
