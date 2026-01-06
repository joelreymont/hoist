# Dot Decomposition Summary

## Overview

Decomposed 10 large, complex infrastructure tasks (1-5 day efforts) into 140 small, focused implementation dots (<30 min each). Each dot has clear dependencies, file paths, and specific deliverables.

## Decomposed Tasks

### 1. Stack Frame Management (6 dots)
**Original**: 1-2 days, "Generate prologue/epilogue, calculate frame size"
**Decomposed into**:
- Add StackFrameLayout data structure
- Add computeFrameLayout function
- Implement emitPrologue function
- Implement emitEpilogue function
- Wire frame layout to compile pipeline
- Add frame layout tests

**Dependencies**: Linear chain, each builds on previous

### 2. Callee-Save Register Handling (4 dots)
**Original**: 1 day, "Track/save/restore x19-x28"
**Decomposed into**:
- Add callee-save register constants
- Track callee-save usage in regalloc
- Generate callee-save spills in prologue
- Generate callee-save restores in epilogue

**Dependencies**: Chain into stack frame management

### 3. Liveness Analysis (5 dots)
**Original**: 2 days, "Track last-use, reuse registers"
**Decomposed into**:
- Add LiveRange data structure
- Implement forward liveness scan
- Add register conflict detection
- Integrate liveness into trivial allocator
- Add liveness analysis tests

**Dependencies**: LiveRange is base, scan and conflict detection independent, integration depends on both

### 4. Linear Scan Register Allocation (7 dots)
**Original**: 3-5 days, "Sort intervals, allocate, spill if needed"
**Decomposed into**:
- Add LinearScan allocator skeleton
- Implement interval sorting
- Implement expireOldIntervals
- Implement tryAllocateReg
- Implement main allocation loop
- Wire linear scan to compile pipeline
- Add linear scan tests

**Dependencies**: Complex - skeleton first, then parallel work on sorting/expireOld/tryAlloc, then main loop integrates all

### 5. Register Spilling Strategy (6 dots)
**Original**: 3-4 days, "Choose victim, allocate slot, insert spill/reload"
**Decomposed into**:
- Add SpillSlot allocation
- Implement spill heuristic
- Generate spill store instruction
- Generate reload instructions
- Integrate spilling into linear scan
- Add spilling tests

**Dependencies**: SpillSlot allocation independent, heuristic independent, store/reload parallel, integration last

### 6. Integer Argument Classification (5 dots)
**Original**: 1-2 days, "Classify args, handle i8/i16/i32/i64/i128"
**Decomposed into**:
- Add ArgLocation enum
- Implement classifyIntArg
- Implement classifyArgs function
- Generate argument moves in prologue
- Add argument classification tests

**Dependencies**: Linear chain

### 7. Aggregate Argument Classification (HFA/HVA) (6 dots)
**Original**: 2-3 days, "Detect HFA, classify, pass in V-regs"
**Decomposed into**:
- Add struct introspection helpers
- Implement HFA detection
- Implement classifyAggregateArg
- Generate HFA argument moves
- Integrate aggregate classification
- Add HFA/aggregate tests

**Dependencies**: Introspection first, then HFA detection, then classification, integration depends on int arg classification

### 8. Stack Slot Allocation (8 dots)
**Original**: Combined 3 dots (stack slots, overflow protection, large frames) = 4-5 days
**Decomposed into**:
- Add StackSlotAllocator structure
- Implement slot reuse optimization
- Add frame size calculation
- Implement stack probe for large frames
- Handle large frame immediate
- Enforce frame pointer for large/dynamic frames
- Wire stack slots to lowering
- Add stack allocation tests

**Dependencies**: Allocator first, reuse depends on liveness, size calculation independent, probe/large frame/FP enforcement parallel on size calculation, wiring depends on allocator, tests last

### 9. Vector Arithmetic (6 dots)
**Original**: 2 days, "Lower vector add/sub/mul for all lane sizes"
**Decomposed into**:
- Add vector ADD lowering
- Add vector SUB lowering
- Add vector MUL lowering
- Add vector FP arithmetic lowering
- Add vector MIN/MAX lowering
- Add vector arithmetic tests

**Dependencies**: Linear chain of operations, each operation independent

### 10. Interference Graph (4 dots)
**Original**: 2-3 days, "Build graph, detect conflicts"
**Decomposed into**:
- Add InterferenceGraph structure
- Implement buildInterferenceGraph
- Add graph degree and neighbor queries
- Add interference graph tests

**Dependencies**: Structure first, build depends on liveness, queries independent, tests last

### 11. Move Coalescing (5 dots)
**Original**: 2-3 days, "Find mov candidates, check safety, coalesce"
**Decomposed into**:
- Add move coalescing candidates
- Check coalescing safety
- Perform coalescing
- Integrate coalescing into regalloc
- Add coalescing tests

**Dependencies**: Candidates first, safety check depends on interference graph, perform depends on safety, integration last

### 12. Rematerialization (5 dots)
**Original**: 2-3 days, "Cost model, identify candidates, generate code"
**Decomposed into**:
- Add rematerialization cost model
- Identify rematerialization candidates
- Generate rematerialization code
- Integrate rematerialization into spilling
- Add rematerialization tests

**Dependencies**: Cost model first, identify depends on it, generate independent, integration depends on generate+spilling

### 13. Integration Test Framework (6 dots)
**Original**: 5-10 days, "Full pipeline, JIT execution, verify"
**Decomposed into**:
- Create JIT execution harness
- Add IR builder test helpers
- Add simple arithmetic tests
- Add control flow tests
- Add recursive function tests
- Add integration test runner

**Dependencies**: Harness and builder independent, tests build incrementally in complexity

### 14. ABI Compliance Tests (5 dots)
**Original**: 3-5 days, "Test all argument types, returns, alignment"
**Decomposed into**:
- Test integer argument passing
- Test FP argument passing
- Test return value handling
- Test callee-save preservation
- Test stack alignment

**Dependencies**: Each test depends on corresponding implementation dot

## Key Principles Applied

1. **<30 minute focus**: Each dot is a single, concrete implementation task
2. **Clear dependencies**: Explicit "depends on hoist-XXX" in descriptions
3. **File paths**: Every dot specifies exact file location
4. **Testable**: Each sequence ends with test dot
5. **Incremental**: Can implement in dependency order
6. **No "multi-day" estimates**: Eliminated all time estimates

## Dependency Patterns

### Linear Chain
Stack frame management: 1 → 2 → 3 → 4 → 5 → 6

### Parallel + Integration
Linear scan: skeleton → (sort || expire || tryAlloc) → main loop

### Layered
ABI: int args → FP args → aggregates → HFA

### Independent Clusters
- Liveness analysis (independent of register allocation)
- Interference graph (depends on liveness, independent of allocation algorithm)
- Coalescing (depends on interference graph)
- Rematerialization (depends on spilling)

## Current State

- **Total dots**: 140
- **Closed**: 10 (original large dots)
- **Open**: 130 (new small dots)
- **Ready to implement**: All dots with no dependencies
- **Blocked**: Dots with unmet dependencies

## Next Steps

User can now:
1. Pick any dot with satisfied dependencies
2. Implement in <30 minutes
3. Close dot immediately when done
4. Move to next dot in chain

No more "I'll work on this multi-day task" - every task is small and focused.
