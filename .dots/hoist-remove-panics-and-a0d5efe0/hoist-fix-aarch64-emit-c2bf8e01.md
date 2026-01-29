---
title: Fix AArch64 Emit Panics
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.558776+01:00"
---

Context: src/backends/aarch64/emit.zig:442; cause: panic on vreg/shift; fix: return CodegenError and validate earlier; deps: hoist-remove-panics-and-a0d5efe0; verification: aarch64 emit tests
