---
title: "IR: DFG"
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-01T10:59:36.796055+02:00\""
closed-at: "\"2026-01-01T12:11:15.345922+02:00\""
blocks:
  - hoist-474fcfeee285d9d1
---

src/ir/dfg.zig (~1.2k LOC)

Port from: cranelift/codegen/src/ir/dfg.rs

DataFlowGraph - core SSA representation:
- insts: PrimaryMap<Inst, InstructionData>
- results: SecondaryMap<Inst, ValueList> - values produced
- values: PrimaryMap<Value, ValueData> - value definitions
- value_lists: ValueListPool - small-vec pool for multi-result
- signatures: PrimaryMap<SigRef, Signature>
- ext_funcs: PrimaryMap<FuncRef, ExtFuncData>
- constants: ConstantPool

Key operations:
- make_inst() -> Inst
- append_result(inst, ty) -> Value
- inst_results(inst) -> []Value
- value_def(value) -> ValueDef (inst+result_idx or param)
- replace_results() for rewrites
