# Cranelift → Zig Complete Port Plan

## Overview

Complete port of Cranelift optimizing code generator (~257k LOC Rust+ISLE) to Zig with proper source tree structure under `src/`.

**Key Advantage:** ISLE compiler already has Zig backend! Can reuse ~47k LOC of ISLE rules directly.

## Project Structure

```
src/
├── foundation/          # Core data structures (entity, bitset, bforest)
├── ir/                  # Intermediate representation
├── dsl/isle/           # ISLE DSL compiler
├── machinst/           # Machine instruction framework
├── backends/
│   ├── x64/            # x86-64 backend
│   └── aarch64/        # ARM64 backend
├── analysis/           # Dominance, loops
├── opts/               # Optimization passes (ISLE-generated)
├── regalloc/           # Register allocator (port or FFI)
├── verifier.zig        # IR verification
└── context.zig         # Top-level API

tests/                  # Integration tests
fuzz/                   # Fuzzing infrastructure
bench/                  # Performance benchmarks
docs/                   # Documentation
examples/               # Usage examples
build.zig               # Build system with ISLE compilation
```

## Dependency Graph & Task Breakdown

### Phase 1: Foundation (3 tasks, ~7k LOC)

**[hoist-474de63e8e04c366]** Port bitset module
- Self-contained, zero dependencies
- ScalarBitSet, CompoundBitSet
- ~100-200 LOC

**[hoist-474de68d56804654]** Port entity module
- Depends on: bitset
- EntityRef, PrimaryMap, SecondaryMap, EntitySet, SparseMap, PackedOption
- ~3,648 LOC from cranelift-entity
- Critical: All compiler data structures use this

**[hoist-474de6c75becbce7]** Port bforest module
- Depends on: entity
- BTreeMap, BTreeSet specialized for compiler use
- ~3,554 LOC

### Phase 2: IR Layer (7 tasks, ~14k LOC)

**[hoist-474de713105101e3]** Port IR: type system
- Depends on: entity
- Type enum (i8-i128, f32-f128, vectors)
- Type operations, lane counts
- ~1,000 LOC from types.rs

**[hoist-474de7656791a5b2]** Port IR: entities and references
- Depends on: entity, types
- Value, Inst, Block, FuncRef, SigRef, GlobalValue, StackSlot, JumpTable
- ~800 LOC from entities.rs

**[hoist-474de7b914dd155d]** Port IR: instruction definitions
- Depends on: entities, types
- Opcode enum, InstructionData variants, instruction formats
- ~2,500 LOC from instructions.rs + generated

**[hoist-474de80e66ee3f4d]** Port IR: data flow graph (DFG)
- Depends on: instructions, entities, entity maps
- DataFlowGraph, SSA value tracking, constant pool
- ~1,200 LOC from dfg.rs

**[hoist-474de862f689af3b]** Port IR: layout and CFG
- Depends on: entities, entity maps, bforest
- Block ordering, instruction layout, control flow graph
- ~1,500 LOC from layout.rs + function.rs

**[hoist-474de8b519abfca8]** Port IR: function representation
- Depends on: dfg, layout, entities
- Function struct combining all IR components
- ~800 LOC from function.rs

**[hoist-474de8fbeb193cd6]** Port IR: builder API
- Depends on: function, dfg, instructions
- FunctionBuilder for ergonomic IR construction
- ~500 LOC from builder.rs

### Phase 3: ISLE DSL Compiler (6 tasks, ~9.7k LOC)

**[hoist-474de94bb23277ca]** Port ISLE: lexer and parser
- Depends on: entity
- S-expression parsing, token handling, AST construction
- ~2,000 LOC from lexer.rs, parser.rs, ast.rs

**[hoist-474de9a058740af5]** Port ISLE: semantic analysis
- Depends on: ISLE parser, entity
- Type checking, term binding, rule validation
- ~1,500 LOC from sema.rs

**[hoist-474de9ddbb8dc284]** Port ISLE: trie optimization
- Depends on: sema
- Decision tree compilation for efficient pattern matching
- ~1,000 LOC from trie_again.rs

**[hoist-474dea3be0fc3948]** Port ISLE: Zig codegen
- Depends on: sema, trie
- **CRITICAL:** Adapt existing codegen_zig.rs (~800 LOC)
- Generates Zig matching/construction code from ISLE rules
- **This already exists in Rust Cranelift!**

**[hoist-474dea951b7c65e0]** Port ISLE: compiler driver
- Depends on: all ISLE components
- Main compile() entry point
- ~500 LOC from lib.rs, compile.rs
- **MILESTONE:** Can now compile .isle → .zig!

### Phase 4: Machine Instruction Framework (8 tasks, ~12k LOC)

**[hoist-474deaeaf67b3c1d]** Port machinst: register abstraction
- Depends on: entity
- Reg, VReg, ValueRegs, RegClass, WritableReg
- ~600 LOC from reg.rs, valueregs.rs

**[hoist-474deb32162db016]** Port machinst: MachInst trait
- Depends on: regs
- Abstract machine instruction interface (emit, registers_used, is_move, etc.)
- ~800 LOC from mod.rs

**[hoist-474deb7f9da39c2f]** Port machinst: VCode container
- Depends on: MachInst, regs, entity
- VCode struct for virtual-register machine code, block management
- ~1,500 LOC from vcode.rs

**[hoist-474debc1934bfa6e]** Port machinst: machine buffer
- Depends on: foundation
- Label management, fixups, binary emission
- ~800 LOC from buffer.rs

**[hoist-474dec120ced1e54]** Port machinst: ABI framework
- Depends on: VCode, MachInst
- ABIMachineSpec interface, calling conventions, prologue/epilogue
- ~1,200 LOC from abi.rs

**[hoist-474dec7c1b0fd064]** Port regalloc2 OR create FFI wrapper
- Depends on: VCode, regs
- **CRITICAL DECISION POINT:** Port ~10k LOC regalloc2 to Zig OR FFI
- SSA graph coloring register allocator
- **Blocks all backend work**

**[hoist-474decdd1520bdb6]** Port machinst: lowering framework
- Depends on: VCode, IR function, ISLE compiler
- LowerCtx, ISLE integration hooks, instruction emission helpers
- ~2,000 LOC from lower.rs

**[hoist-474ded305f087ca7]** Port machinst: compile pipeline
- Depends on: lowering, regalloc, buffer, ABI
- Orchestrates: lower → regalloc → emit
- ~800 LOC from compile.rs
- **MILESTONE:** IR → binary pipeline complete (without backends)

### Phase 5: x64 Backend (6 tasks, ~19k LOC)

**[hoist-474ded8520631fd3]** Port x64: instruction definitions
- Depends on: MachInst, regs
- Inst enum, all x64 instruction variants
- ~2,500 LOC from isa/x64/inst/mod.rs

**[hoist-474dedece8f40f48]** Port x64: binary emission
- Depends on: x64 inst, buffer
- REX prefix, ModR/M, SIB, immediate encoding
- ~3,000 LOC from isa/x64/inst/emit.rs

**[hoist-474deec08fb91a2e]** Port x64: ABI (SysV + Windows)
- Depends on: x64 inst, ABI framework
- System V AMD64 and Windows x64 calling conventions
- ~800 LOC from isa/x64/abi.rs

**[hoist-474def29551d6504]** Port x64: ISLE rules
- Depends on: ISLE compiler, x64 inst, lowering framework
- Compile x64/*.isle (~9,173 LOC ISLE) → lower_generated.zig
- Pattern matching for IR → x64 lowering

**[hoist-474def802eb47f86]** Port x64: ISA integration
- Depends on: x64 ABI, x64 ISLE, compile pipeline
- TargetIsa implementation, settings, feature detection
- ~500 LOC from isa/x64/mod.rs
- **MILESTONE: x64 backend functional!**

### Phase 6: ARM64 Backend (6 tasks, ~29k LOC)

**[hoist-474defe643e6a7e9]** Port aarch64: instruction definitions
- Depends on: MachInst, regs
- Inst enum, all ARM64 instruction variants including NEON
- ~3,500 LOC from isa/aarch64/inst/mod.rs

**[hoist-474df0348f5ee859]** Port aarch64: binary emission
- Depends on: aarch64 inst, buffer
- All ARM64 instruction encodings, addressing modes
- ~4,000 LOC from isa/aarch64/inst/emit.rs

**[hoist-474df082b02de503]** Port aarch64: ABI (AAPCS64)
- Depends on: aarch64 inst, ABI framework
- AAPCS64 calling convention, argument passing
- ~1,000 LOC from isa/aarch64/abi.rs

**[hoist-474df10843baaf78]** Port aarch64: ISLE rules
- Depends on: ISLE compiler, aarch64 inst, lowering framework
- Compile aarch64/*.isle (~8,613 LOC ISLE) → lower_generated.zig
- Pattern matching for IR → ARM64 lowering

**[hoist-474df16ff3bf7f10]** Port aarch64: ISA integration
- Depends on: aarch64 ABI, aarch64 ISLE, compile pipeline
- TargetIsa implementation, settings, SVE/NEON feature detection
- ~800 LOC from isa/aarch64/mod.rs
- **MILESTONE: aarch64 backend functional!**

### Phase 7: Optimizations & Analysis (4 tasks, ~4k LOC)

**[hoist-474df1c5a313fd16]** Port optimization passes: ISLE opts
- Depends on: ISLE compiler, IR function
- Compile opts/*.isle (~2,280 LOC ISLE) → generated.zig
- Constant propagation, algebraic simplification, etc.

**[hoist-474df32cbc08af1d]** Port dominance analysis
- Depends on: CFG, entity
- DominatorTree, immediate dominators, dominator frontiers
- ~800 LOC from dominator_tree.rs

**[hoist-474df374554903a9]** Port loop analysis
- Depends on: dominance, CFG
- Natural loop detection, nesting levels
- ~600 LOC from loop_analysis.rs

**[hoist-474df3dafd328d6b]** Port verifier
- Depends on: IR function, dominance
- IR validation, SSA checks, type checking, CFG validation
- ~2,000 LOC from verifier/*.rs

### Phase 8: Integration & Quality (6 tasks)

**[hoist-474df21d4c7514df]** Port context and compilation driver
- Depends on: IR function, optimization passes, compile pipeline
- Context struct, compile() entry point, optimization orchestration
- ~600 LOC from context.rs
- **MILESTONE: End-to-end compilation API!**

**[hoist-474df276e4af8ae3]** Create build system integration
- Depends on: ISLE compiler
- build.zig with automated ISLE → Zig compilation
- CompileStep for *.isle → *_generated.zig

**[hoist-474df2d7a658c09e]** Create comprehensive test suite
- Depends on: both backends, context
- Unit tests, integration tests, encoding verification, differential tests
- Ensure correctness across all components

**[hoist-474df4474d70e69e]** Create fuzzing infrastructure
- Depends on: context, both backends
- Random IR generation, differential testing, crash detection
- Continuous validation

**[hoist-474df49b186ed7f3]** Create benchmarking suite
- Depends on: context
- Compile time, throughput, code quality metrics
- Compare vs LLVM and original Cranelift

**[hoist-474df59e6acbcaa2]** Documentation and examples
- Depends on: context API stable
- Architecture docs, API reference, porting guide, ISLE tutorial
- Examples: hello.zig, fibonacci.zig, mandelbrot.zig

## Critical Path

1. **Foundation** → entity is used everywhere
2. **IR Layer** → complete IR representation required for everything
3. **ISLE Compiler** → needed for all lowering and optimization rules
4. **MachInst Framework** → abstract backend interface
5. **Register Allocation** → **CRITICAL BLOCKER** for backends
6. **First Backend** (x64 or aarch64) → prove the architecture works
7. **Second Backend** → validate portability
8. **Optimizations** → production-grade performance
9. **Quality Infrastructure** → ensure correctness

## Estimation

- **Foundation + IR:** ~21k LOC, 3-4 weeks
- **ISLE Compiler:** ~10k LOC, 2-3 weeks (mostly porting existing Zig codegen!)
- **MachInst Framework:** ~12k LOC, 2-3 weeks
- **Register Allocation:** ~10k LOC or FFI, 2-4 weeks (decision dependent)
- **x64 Backend:** ~19k LOC, 3-4 weeks
- **aarch64 Backend:** ~29k LOC, 4-5 weeks
- **Optimizations & Analysis:** ~5k LOC, 1-2 weeks
- **Integration & Quality:** 2-3 weeks

**Total: ~100k LOC Zig (excluding ISLE-generated code), 16-24 weeks**

## Key Advantages

1. **ISLE Zig Backend Exists:** ~47k LOC of ISLE rules can be reused directly
2. **Clean Architecture:** Cranelift has excellent separation of concerns
3. **Small Foundation:** Only ~7k LOC of core data structures
4. **Incremental:** Can validate each layer before moving up
5. **Two Backends:** x64 and aarch64 provide cross-validation

## Key Challenges

1. **Scale:** ~100k LOC of manual porting required
2. **regalloc2:** Complex graph coloring allocator - port vs FFI decision
3. **Backend Complexity:** Each backend is 10-30k LOC with intricate encoding rules
4. **Build System:** ISLE compilation must integrate with Zig build system
5. **Testing:** Comprehensive testing required for correctness

## Success Criteria

- [ ] All 42 tasks complete
- [ ] Both x64 and aarch64 backends functional
- [ ] ISLE compiler generating correct Zig code
- [ ] Test suite passing (100+ tests)
- [ ] Fuzzing finds no crashes in 1M iterations
- [ ] Compile time competitive with Cranelift (<2x slower acceptable)
- [ ] Code quality competitive (within 10% code size)
- [ ] Documentation complete and examples working

## Next Steps

1. Review and approve plan
2. Decide on regalloc2 strategy (port vs FFI)
3. Set up project structure under src/
4. Start with foundation layer (bitset → entity → bforest)
5. Build incrementally, testing at each layer
