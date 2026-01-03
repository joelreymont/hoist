# Hoist Compiler Architecture Documentation

## Overview

This directory contains comprehensive, ELI5-style (Explain Like I'm 5) documentation for the Hoist compiler architecture. Each document builds on previous ones, progressing from high-level concepts to implementation details.

**Total:** 10 documents, ~5,100 lines, covering all major subsystems.

## Reading Order

### For Complete Understanding (Read in Order)

1. **[00-overview.md](00-overview.md)** - Start here!
   - High-level compiler pipeline
   - What happens when you compile
   - Data flow through each phase
   - Big picture architecture

2. **[01-ir-representation.md](01-ir-representation.md)** - The Foundation
   - What is IR and why we need it
   - Values, instructions, and blocks
   - DFG (Data Flow Graph)
   - SSA form and entities
   - Examples with diagrams

3. **[02-isle-lowering.md](02-isle-lowering.md)** - IR to Machine Code
   - ISLE pattern matching system
   - How rules work (.isle files)
   - External constructors
   - Example: iadd → ARM64 ADD
   - Instruction selection strategies

4. **[03-register-allocation.md](03-register-allocation.md)** - The Musical Chairs Problem
   - Virtual vs physical registers
   - regalloc2 integration
   - Register classes and interference
   - Spilling and move coalescing
   - ABI constraints

5. **[04-vcode-and-machinst.md](04-vcode-and-machinst.md)** - Machine Instructions
   - VCode representation
   - Machine instruction formats
   - Labels and branches
   - Instruction encoding to bytes
   - MachBuffer

### Deep Dives (Read After Fundamentals)

6. **[05-optimization-passes.md](05-optimization-passes.md)** - Making Code Faster
   - CFG and dominator trees
   - Dead code elimination (DCE)
   - Global value numbering (GVN)
   - Loop-invariant code motion (LICM)
   - Optimization pipeline order

7. **[06-backends.md](06-backends.md)** - Target-Specific Code Generation
   - Backend architecture
   - ARM64 example (ISLE + helpers + encoding + ABI)
   - ISA features (LSE atomics, NEON)
   - Calling conventions
   - Prologue/epilogue generation

8. **[07-type-system.md](07-type-system.md)** - Types and Type Checking
   - Scalar types (I8, I16, I32, I64, I128, F32, F64)
   - Vector types (I8X16, I32X4, F64X2, etc.)
   - Type encoding (packed u16)
   - Type conversions
   - Type legalization

9. **[08-atomics-and-memory.md](08-atomics-and-memory.md)** - Concurrent Operations
   - What are atomics
   - Memory ordering (acquire, release, seq_cst)
   - ARM64 LSE vs LL/SC
   - Compare-and-swap (CAS)
   - Lock-free data structures

10. **[09-algorithms.md](09-algorithms.md)** - The Clever Algorithms
    - Dominator tree computation (Semi-NCA)
    - Natural loop detection
    - Global value numbering
    - Dead code elimination
    - Register allocation (linear scan)
    - Algorithm complexity analysis

## Quick Reference

### By Topic

**IR Fundamentals:**
- Values, Instructions, Blocks: [01-ir-representation.md](01-ir-representation.md)
- Types: [07-type-system.md](07-type-system.md)

**Code Generation:**
- Lowering (IR → Machine): [02-isle-lowering.md](02-isle-lowering.md)
- Register Allocation: [03-register-allocation.md](03-register-allocation.md)
- VCode and Emission: [04-vcode-and-machinst.md](04-vcode-and-machinst.md)
- Backends: [06-backends.md](06-backends.md)

**Optimization:**
- Optimization Passes: [05-optimization-passes.md](05-optimization-passes.md)
- Algorithms: [09-algorithms.md](09-algorithms.md)

**Advanced Topics:**
- Atomics and Memory: [08-atomics-and-memory.md](08-atomics-and-memory.md)

### By File Path

**IR System:**
- `/Users/joel/Work/hoist/src/ir/` - IR data structures
- `/Users/joel/Work/hoist/src/ir/function.zig` - Function container
- `/Users/joel/Work/hoist/src/ir/dfg.zig` - Data flow graph
- `/Users/joel/Work/hoist/src/ir/types.zig` - Type system

**Code Generation:**
- `/Users/joel/Work/hoist/src/codegen/compile.zig` - Main pipeline
- `/Users/joel/Work/hoist/src/codegen/isle_ctx.zig` - Lowering context

**Optimization:**
- `/Users/joel/Work/hoist/src/codegen/opts/` - Optimization passes
- `/Users/joel/Work/hoist/src/ir/domtree.zig` - Dominator tree
- `/Users/joel/Work/hoist/src/ir/loops.zig` - Loop detection

**Backend (ARM64):**
- `/Users/joel/Work/hoist/src/backends/aarch64/lower.isle` - ISLE rules
- `/Users/joel/Work/hoist/src/backends/aarch64/isle_helpers.zig` - Helpers
- `/Users/joel/Work/hoist/src/backends/aarch64/emit.zig` - Encoding
- `/Users/joel/Work/hoist/src/backends/aarch64/abi.zig` - Calling convention

**Machine Code:**
- `/Users/joel/Work/hoist/src/machinst/vcode.zig` - VCode
- `/Users/joel/Work/hoist/src/machinst/buffer.zig` - MachBuffer
- `/Users/joel/Work/hoist/src/machinst/regalloc2/` - Register allocator

## Documentation Style

All documents follow these principles:

1. **ELI5 (Explain Like I'm 5)**: Use simple analogies and everyday examples
2. **Progressive complexity**: Start simple, build up gradually
3. **Concrete examples**: Real code from the codebase with file:line references
4. **Visual aids**: ASCII diagrams and tables
5. **Why not just what**: Explain rationale behind design decisions
6. **Practical focus**: How things actually work, not just theory

## Key Concepts Covered

- **SSA (Static Single Assignment)**: Every value assigned exactly once
- **Basic Blocks**: Straight-line code sequences
- **Control Flow Graph (CFG)**: Block connectivity
- **Dominator Tree**: Which blocks always execute before others
- **ISLE**: Pattern matching for instruction selection
- **VCode**: Machine code with virtual registers
- **regalloc2**: Production register allocator
- **Memory Ordering**: Atomics and synchronization
- **Type System**: Scalars, vectors, conversions

## Statistics

- **Total lines:** 5,111
- **Total size:** 144 KB
- **Documents:** 10
- **Average per doc:** ~500 lines
- **Code examples:** 200+
- **ASCII diagrams:** 30+
- **File references:** 100+

## Contributing

When updating documentation:

1. Maintain ELI5 style (simple analogies, clear examples)
2. Include file:line references to actual code
3. Add ASCII diagrams where helpful
4. Explain WHY, not just WHAT
5. Keep progressive complexity (simple → advanced)
6. Update this README if adding new docs

## Related Documentation

- **[/Users/joel/Work/hoist/README.md](../../README.md)** - Project overview
- **[/Users/joel/Work/hoist/PLAN.md](../../PLAN.md)** - Development roadmap
- **[/Users/joel/Work/hoist/docs/](../)** - Other documentation

## Questions?

Each document is self-contained but builds on previous ones. If something is unclear:

1. Check if it's explained in an earlier document
2. Look at the referenced source files
3. The examples are real code - try tracing through them
4. ASCII diagrams show structure - follow the arrows

Happy learning! The architecture is complex but the documentation breaks it down step by step.
