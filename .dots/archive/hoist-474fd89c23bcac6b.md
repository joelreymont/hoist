---
title: "aarch64: ISA integration"
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-01T11:02:02.363845+02:00\""
closed-at: "\"2026-01-01T17:02:12.490680+02:00\""
close-reason: "\"completed: src/backends/aarch64/isa.zig integrating all aarch64 components (inst/emit/abi/lower) into unified ISA interface with register info (31 GPRs, 32 VECs, SP/FP/LR), ABI selection, lowering backend, compile function. All tests pass.\""
blocks:
  - hoist-474fd89c139b7761
---

src/backends/aarch64/mod.zig (~800 LOC)

Port from: cranelift/codegen/src/isa/aarch64/mod.rs

TargetIsa implementation for aarch64:
- name() -> 'aarch64'
- pointer_bytes() -> 8
- compile(func) -> CompiledCode

Settings:
- has_neon (always true for AArch64)
- has_sve, has_sve2
- has_lse (atomics)
- has_fp16

Register file:
- 31 GPRs (X0-X30, no XZR)
- 32 SIMD/FP regs (V0-V31)

MILESTONE: aarch64 backend functional\!
Second backend validates architecture
