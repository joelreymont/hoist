---
title: "machinst: compile pipeline"
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-01T11:00:55.704282+02:00\""
closed-at: "\"2026-01-01T16:41:14.748520+02:00\""
close-reason: "\"Created compile.zig (~227 LOC) - full compilation pipeline! Entry: compile() ties together lower->regalloc->emit->finish. CompiledCode struct with code/relocs/traps. TrapCode, RelocationKind enums. All 23 tests pass. MILESTONE: IR→binary pipeline complete (awaits backend-specific MachInst+ISLE)! Total: ~11.5k LOC\""
blocks:
  - hoist-474fd4a2eec68546
---

src/machinst/compile.zig (~800 LOC)

Port from: cranelift/codegen/src/machinst/compile.rs

Full compilation pipeline:
1. lower(ir_func) -> VCode (virtual regs)
2. regalloc(vcode) -> VCode (physical regs)
3. emit(vcode) -> MachBuffer
4. finish() -> CompiledCode

CompiledCode:
- code: []u8
- relocations: []Reloc
- traps: []TrapRecord
- stack_frame_size: u32

Entry point:
- compile(ctx, func, isa) -> CompiledCode

MILESTONE: IR -> binary pipeline complete!
(Still needs backend-specific Inst + ISLE rules)
