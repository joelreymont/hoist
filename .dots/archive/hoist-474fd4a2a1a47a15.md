---
title: "machinst: MachInst trait"
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-01T11:00:55.680429+02:00\""
closed-at: "\"2026-01-01T16:12:31.115242+02:00\""
close-reason: Completed machinst foundation (~256 LOC) - OperandVisitor, CallType, FunctionCalls, MachTerminator, MachLabel, operand constraints with all tests passing
blocks:
  - hoist-474fd4a29115fca3
---

src/machinst/inst.zig (~800 LOC)

Port from: cranelift/codegen/src/machinst/mod.rs

MachInst interface - abstract over backend instructions:
- get_operands() -> []Operand (regs read/written)
- is_move() -> ?MoveInfo
- is_term() -> bool (terminator)
- gen_move(dst, src) -> Self
- stack_op_info() -> ?StackOpInfo

Operand types:
- Reg(reg, constraint)
- Reuse(idx) - output reuses input
- Fixed(preg) - must use specific physical reg

MachInstEmit interface:
- emit(buffer, targets) - write bytes
- size() -> usize

Backend-specific Inst enums implement these
