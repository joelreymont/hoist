---
title: "x64: ISA integration"
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-01T11:01:30.861215+02:00\""
closed-at: "\"2026-01-01T17:01:04.872424+02:00\""
close-reason: "\"completed: src/backends/x64/isa.zig integrating all x64 components (inst/emit/abi/lower) into unified ISA interface with register info, ABI selection, lowering backend, compile function. All tests pass.\""
blocks:
  - hoist-474fd6bb63b8ce6b
---

src/backends/x64/mod.zig (~500 LOC)

Port from: cranelift/codegen/src/isa/x64/mod.rs

TargetIsa implementation for x64:
- name() -> 'x86_64'
- pointer_bytes() -> 8
- compile(func) -> CompiledCode
- emit_function(vcode) -> MachBuffer

Settings:
- has_sse41, has_avx, has_avx2, has_avx512
- has_bmi1, has_bmi2, has_lzcnt, has_popcnt
- Feature detection from CPUID

Register file:
- 16 GPRs (RAX-R15)
- 16 XMM regs (XMM0-XMM15)
- 32 with AVX-512

MILESTONE: x64 backend functional!
Can compile IR -> x64 machine code
