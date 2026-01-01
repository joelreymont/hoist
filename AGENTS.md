# Hoist: Cranelift → Zig Port

Complete production-grade port of Cranelift optimizing code generator to Zig, ARM64 backend first.

## Build

```bash
zig build        # compile
zig build run    # run
zig build test   # test
```

## Key References

- **[Cranelift Source](https://github.com/bytecodealliance/wasmtime/tree/main/cranelift)** - Original Rust implementation (~257k LOC)
- **[ISLE Integration](docs/isle.md)** - ISLE DSL integration guide
- **[ARM Architecture Reference Manual](https://developer.arm.com/documentation/ddi0487/latest)** - ARM64 instruction encoding
- **[Zig 0.15 I/O API](docs/zig-0.15.md)** - ArrayList, I/O changes

## Project Structure

```
src/
├── foundation/          # Core data structures (~7k LOC)
│   ├── bitset.zig      # Bit sets
│   ├── entity.zig      # Entity references and maps
│   └── bforest.zig     # B+ tree forest
├── ir/                  # Intermediate representation (~15k LOC)
│   ├── types.zig       # Type system
│   ├── entities.zig    # Value, Inst, Block refs
│   ├── instructions.zig # Opcode definitions
│   ├── dfg.zig         # Data flow graph (SSA)
│   ├── layout.zig      # Block/instruction layout
│   ├── cfg.zig         # Control flow graph
│   ├── function.zig    # Function container
│   └── builder.zig     # IR construction API
├── dsl/isle/           # ISLE DSL compiler (~10k LOC)
│   ├── lexer.zig       # Lexer/tokenizer
│   ├── parser.zig      # Parser
│   ├── ast.zig         # AST definitions
│   ├── sema.zig        # Semantic analysis
│   ├── trie.zig        # Pattern matching optimization
│   ├── codegen.zig     # Zig code generation
│   └── compiler.zig    # Main driver
├── machinst/           # Machine instruction framework (~12k LOC)
│   ├── regs.zig        # Register abstractions
│   ├── inst.zig        # MachInst trait
│   ├── vcode.zig       # Virtual code container
│   ├── buffer.zig      # Binary emission buffer
│   ├── abi.zig         # ABI framework
│   ├── lower.zig       # Lowering framework
│   └── compile.zig     # Compilation pipeline
├── backends/aarch64/   # ARM64 backend (~29k LOC)
│   ├── inst.zig        # Instruction definitions
│   ├── emit.zig        # Binary encoding
│   ├── abi.zig         # AAPCS64 calling convention
│   ├── lower_generated.zig # ISLE-generated lowering
│   └── isa.zig         # ISA integration
├── analysis/           # IR analysis passes (~4k LOC)
│   ├── dominance.zig   # Dominator tree
│   └── loops.zig       # Loop detection
├── regalloc/           # Register allocator (~10k LOC)
│   └── ...             # Port of regalloc2
├── opts/               # Optimization passes (ISLE-generated)
│   └── generated.zig   # ISLE-generated optimizations
├── verifier.zig        # IR verification (~2k LOC)
└── context.zig         # Top-level compilation API

docs/                   # Documentation
tests/                  # Integration tests
bench/                  # Performance benchmarks
build.zig               # Build system with ISLE compilation
```

## Zig 0.15 Patterns

### ArrayList is Unmanaged
```zig
// RIGHT
var list = std.ArrayList(T){};
try list.append(allocator, item);

// WRONG
var list = std.ArrayList(T).init(allocator);
```

### Import Once, Reference via Namespace
```zig
// RIGHT: Import module once, use namespace
const ir = @import("ir/types.zig");
// Then use: ir.Type, ir.Opcode

// WRONG: Multiple imports from same module
const Type = @import("ir/types.zig").Type;
const Opcode = @import("ir/types.zig").Opcode;
```

### Allocator First
```zig
// RIGHT
pub fn init(allocator: std.mem.Allocator) Self { ... }

// WRONG
pub fn init(config: Config, allocator: std.mem.Allocator) Self { ... }
```

### ArrayList Batch Append
```zig
// RIGHT: Create static array, appendSlice once
const items = [_]T{ a, b, c };
try list.appendSlice(allocator, &items);

// WRONG: Append items one by one
try list.append(allocator, a);
try list.append(allocator, b);
```

### Error Handling - NEVER MASK ERRORS (BLOCKING)

**FORBIDDEN:**
```zig
foo() catch unreachable;
foo() catch return;
foo() catch return null;
foo() orelse unreachable;
```

**REQUIRED:**
```zig
const result = try foo();
```

### DRY: Table-Driven Dispatch
```zig
// RIGHT: Table-driven
const opcode_names = std.EnumMap(Opcode, []const u8).init(.{
    .iadd = "iadd",
    .isub = "isub",
});

// WRONG: Repetitive if-chain
if (opcode == .iadd) return "iadd";
if (opcode == .isub) return "isub";
```

## Architecture

```
CLIF IR
  ↓ [legalize]
Legalized IR
  ↓ [optimize via ISLE]
Optimized IR
  ↓ [lower via ISLE]
VCode (virtual registers)
  ↓ [regalloc2]
VCode + assignments
  ↓ [emit]
Machine code
```

## ISLE Integration - CRITICAL

- **ALL instruction lowering uses ISLE DSL**
- ISLE compiler has Zig backend (cranelift/isle/isle/src/codegen_zig.rs)
- ~9k LOC ARM64 ISLE rules compile to Zig automatically
- Build system compiles *.isle → *_generated.zig
- **NEVER manually write lowering - use ISLE**

## Verification Requirements (BLOCKING)

1. **Encoding Verification**: Every instruction MUST match ARM Architecture Reference Manual
2. **ABI Correctness**: AAPCS64 specification compliance
3. **SSA Verification**: Maintain SSA invariants
4. **Fuzzing**: Random IR generation finds no crashes

## Local Rules (BLOCKING)

### Cranelift Fidelity
- Follow Cranelift architecture exactly - this is a port, not a rewrite
- ISLE mandatory for ALL lowering/optimization
- Entity-based indexing for all IR types
- SSA form required

### ISA Correctness
- ARM ARM is ground truth
- Verify all encodings against manual
- AAPCS64 compliance required
- No shortcuts - full instruction set

### Code Quality
- No dead code
- No `@panic` - use `!` error returns
- Type safety - enums, tagged unions, comptime
- Named constants, no magic numbers

### Workflow
- Commit after each complete module
- 50-char imperative messages, no emoji
- `zig fmt src/` before commit
- All tests pass before commit

### Dot Tasks
- Track everything with file paths and line numbers
- Use `-b` for dependencies
- Close immediately when done

## Scope

- **Total: ~80k LOC Zig** (excluding ISLE-generated)
- **Plus: ~9k LOC ISLE** for ARM64
- **Target: Production-grade optimizing compiler**
- **Initial: ARM64 only** (x64 deferred)
- **Timeline: 12-16 weeks**

This is NOT a prototype. Full production Cranelift port to Zig, ARM64 first.
