# Compiler Pipeline Overview

## What is Hoist?

Imagine you're building with LEGO blocks. You start with a picture of what you want to build (source code), and you need to turn it into actual LEGO instructions (machine code) that tell you exactly which blocks to place where.

Hoist is a compiler that does exactly this for computer programs - it takes high-level instructions and converts them into the tiny electrical signals (machine code) that your computer's processor understands.

## The Journey: From Code to Machine Instructions

Think of compiling a program like an assembly line in a factory. Your code goes through multiple stations, and at each station, it gets transformed into something more specific and closer to what the computer actually runs.

```
Source Code (your program)
    ↓
[1. IR Building] ← Convert to standard format
    ↓
IR (Intermediate Representation)
    ↓
[2. Verification] ← Check for mistakes
    ↓
[3. Legalization] ← Fix illegal operations
    ↓
[4. Optimization] ← Make it faster
    ↓
Optimized IR
    ↓
[5. Lowering (ISLE)] ← Convert to machine instructions
    ↓
VCode (Virtual Code with virtual registers)
    ↓
[6. Register Allocation] ← Assign real CPU registers
    ↓
VCode (with physical registers)
    ↓
[7. Prologue/Epilogue] ← Add function setup/cleanup
    ↓
[8. Emission] ← Convert to actual bytes
    ↓
Machine Code (raw bytes the CPU executes)
```

## Station 1: IR Building

**What happens:** Your source code gets converted into IR (Intermediate Representation).

**Why:** Imagine you're translating a book into multiple languages. Instead of translating English→French, English→Spanish, English→German separately, you first translate English into a "universal language" that's easy to convert to any target language. IR is that universal language for compilers.

**Example:**
```zig
// Source code (imaginary):
let result = x + y;

// Becomes IR:
v1 = iconst 10      // v1 = constant 10
v2 = iconst 20      // v2 = constant 20
v3 = iadd v1, v2    // v3 = v1 + v2
```

**File:** `/Users/joel/Work/hoist/src/codegen/compile.zig:362` (buildIR function)

## Station 2: Verification

**What happens:** The compiler checks that your IR makes sense.

**Why:** Imagine a recipe that says "add sugar" but never mentions sugar in the ingredients list. The verifier catches these mistakes before we waste time cooking.

**Checks include:**
- Every value used is actually defined somewhere
- Types match (don't add a number to a string)
- Every block can be reached
- Control flow makes sense (no jumping to non-existent places)

**File:** `/Users/joel/Work/hoist/src/ir/verifier.zig`

## Station 3: Legalization

**What happens:** Some operations in IR might not be directly supported by your CPU. Legalization rewrites them into things the CPU can actually do.

**Why:** Imagine you have a recipe calling for a "food processor" but you only have a knife. Legalization is like rewriting the recipe to say "chop finely by hand" instead.

**Examples:**
- I128 (128-bit integer) might get split into two I64 operations on a 64-bit CPU
- Certain vector operations get expanded into multiple simpler operations
- Unsupported division gets replaced with multiplication by reciprocal

**File:** `/Users/joel/Work/hoist/src/codegen/compile.zig:375` (legalize function)

## Station 4: Optimization

**What happens:** Multiple passes analyze and improve your IR.

**Why:** Like editing a draft of an essay - you remove redundant sentences, combine similar ideas, and reorganize for clarity.

**Key optimizations:**
- **CFG Computation**: Build a map of how code flows (which blocks can jump to which)
- **Dominator Tree**: Figure out which code blocks always run before others
- **Dead Code Elimination**: Remove code that never runs or whose results are never used
- **Constant Phi Removal**: Simplify merge points where all incoming values are the same
- **GVN**: Eliminate redundant calculations (if you compute X+Y twice, reuse the first result)

**Files:**
- `/Users/joel/Work/hoist/src/codegen/compile.zig:141` (optimize function)
- `/Users/joel/Work/hoist/src/codegen/opts/` (individual optimization passes)

## Station 5: Lowering (ISLE)

**What happens:** IR instructions get converted into target-specific machine instructions using pattern matching rules.

**Why:** This is like translating from the "universal language" into the specific dialect your CPU speaks. ARM64 CPUs and x86-64 CPUs have completely different instruction sets.

**Example - ARM64:**
```isle
;; IR pattern:
iadd ty x y

;; Matches ISLE rule:
(rule (lower (iadd ty x y))
      (aarch64_add_rr ty x y))

;; Produces ARM64 instruction:
ADD X0, X1, X2
```

**Magic ingredient: ISLE (Instruction Selection/Lowering Expressions)**
- Domain-specific language for pattern matching
- Rules are declarative: "when you see pattern X, emit instruction Y"
- Supports priorities: more specific patterns match first
- External constructors call Zig helper functions

**Files:**
- `/Users/joel/Work/hoist/src/backends/aarch64/lower.isle` (pattern rules)
- `/Users/joel/Work/hoist/src/backends/aarch64/isle_helpers.zig` (constructor implementations)
- `/Users/joel/Work/hoist/src/codegen/compile.zig:424` (lower function)

## Station 6: Register Allocation

**What happens:** Virtual registers (unlimited, imaginary) get assigned to physical registers (limited, real CPU registers).

**Why:** CPUs have a small number of registers (ARM64 has 31 general-purpose registers). Your IR might use hundreds of virtual registers. Register allocation is like musical chairs - finding a seat for everyone when there aren't enough chairs. When we run out, we "spill" to stack memory.

**How it works:**
- **Linear Scan**: Fast algorithm that processes instructions in order
- **regalloc2**: Production-quality register allocator (external library)
- **Register Classes**: Some values go in integer registers (.int), others in float registers (.float)
- **Spilling**: When out of registers, save/load from stack memory
- **Move Coalescing**: Eliminate unnecessary register-to-register copies

**Result:** `VReg(123)` becomes `X5` (physical ARM64 register)

**File:** `/Users/joel/Work/hoist/src/codegen/compile.zig:488` (allocateRegisters function)

## Station 7: Prologue/Epilogue Insertion

**What happens:** Add code at the start (prologue) and end (epilogue) of each function.

**Why:** When you call a function, you need to:
- Save registers the caller expects to be preserved
- Set up a new stack frame
- On return: restore everything and clean up

**Prologue does:**
```asm
; Save frame pointer
stp x29, x30, [sp, #-16]!
; Set up new frame
mov x29, sp
; Allocate stack space
sub sp, sp, #64
```

**Epilogue does:**
```asm
; Restore stack pointer
mov sp, x29
; Restore saved registers
ldp x29, x30, [sp], #16
; Return
ret
```

**File:** `/Users/joel/Work/hoist/src/codegen/compile.zig:509` (insertPrologueEpilogue function)

## Station 8: Emission

**What happens:** Machine instructions get encoded into actual bytes that the CPU executes.

**Why:** `ADD X0, X1, X2` is human-readable assembly. The CPU needs the binary encoding: `0x8b020020`.

**Process:**
1. Encode each instruction to bytes using instruction formats
2. Resolve branch targets (labels → actual addresses)
3. Generate relocations for external symbols (functions/data not in this file)
4. Emit constant pools (large immediate values stored nearby)

**Result:** A byte array you can load and execute:
```
Bytes: [0xd1, 0x00, 0x40, 0xf9, ...]
Relocations: [
  { offset: 12, kind: CALL, symbol: "malloc" }
]
```

**Files:**
- `/Users/joel/Work/hoist/src/backends/aarch64/emit.zig` (instruction encoding)
- `/Users/joel/Work/hoist/src/machinst/buffer.zig` (MachBuffer - byte accumulator)
- `/Users/joel/Work/hoist/src/codegen/compile.zig:539` (emit function)

## Data Structures: The Containers

### Function
**What:** The top-level container for all code and data.

**Contains:**
- Signature (parameters, return type, calling convention)
- DFG (Data Flow Graph)
- Layout (order of blocks and instructions)
- Stack slots, global values, jump tables

**File:** `/Users/joel/Work/hoist/src/ir/function.zig`

### DFG (Data Flow Graph)
**What:** Tracks values and how they're computed.

**Key insight:** In SSA (Static Single Assignment) form, each value is assigned exactly once. This makes analysis easier.

**Contains:**
- Values (v0, v1, v2...) and their definitions
- Instructions and their operands
- Value lists (for variable-length operand lists)

**File:** `/Users/joel/Work/hoist/src/ir/dfg.zig`

### Layout
**What:** The physical ordering of blocks and instructions.

**Why separate from DFG?** The DFG is a logical graph of data dependencies. Layout is the actual order instructions will execute. They're different!

**Contains:**
- Linked list of blocks in function order
- Linked list of instructions within each block

**File:** `/Users/joel/Work/hoist/src/ir/layout.zig`

### CFG (Control Flow Graph)
**What:** A map of which blocks can jump to which other blocks.

**Why:** Needed for analysis and optimization. If you want to move an instruction, you need to know what paths through the program exist.

**Contains:**
- Successors: blocks this block can jump to
- Predecessors: blocks that can jump here

**File:** `/Users/joel/Work/hoist/src/ir/cfg.zig`

### VCode (Virtual Code)
**What:** Machine instructions with virtual registers (before register allocation).

**Why:** Lowering produces machine instructions, but we haven't assigned physical registers yet. VCode is the intermediate form.

**Contains:**
- Machine instructions (target-specific: ARM64, x86-64)
- Virtual registers (unlimited)
- Block structure (CFG at machine instruction level)

**File:** `/Users/joel/Work/hoist/src/machinst/vcode.zig`

## Key Concepts

### SSA (Static Single Assignment)
Every variable is assigned exactly once. Instead of:
```
x = 1
x = x + 1
x = x * 2
```

We have:
```
x1 = 1
x2 = x1 + 1
x3 = x2 * 2
```

**Why?** Makes data flow analysis trivial - just follow the numbers!

### Basic Blocks
A sequence of instructions with:
- One entry point (top)
- One exit point (bottom)
- No branches in the middle

Think of it like a paragraph - you enter at the start and read straight through.

### Phi Nodes / Block Parameters
At merge points (where multiple blocks converge), we need to say "this value is X if we came from block A, or Y if we came from block B."

Hoist uses **block parameters** instead of phi nodes - conceptually the same, different representation.

## The Big Picture

Hoist is a **retargetable compiler backend**. This means:

1. **Frontend-agnostic**: Any language can generate IR and use Hoist
2. **Target-agnostic IR**: The IR doesn't care if you're targeting ARM64, x86-64, or RISC-V
3. **ISLE-based lowering**: Adding a new target means writing ISLE rules, not modifying the core compiler
4. **Production-quality**: Uses proven algorithms (regalloc2, Semi-NCA dominator trees)

The architecture follows the **Cranelift** design (Hoist is based on Cranelift), which powers:
- Wasmtime (WebAssembly runtime)
- Bytecode Alliance projects
- High-performance JIT compilation

## What Makes Hoist Different?

1. **Zig implementation**: Memory-safe systems language with no runtime
2. **ISLE pattern matching**: Declarative instruction selection
3. **Separation of concerns**: IR, optimization, lowering, regalloc are cleanly separated
4. **Type-safe entities**: Block, Value, Inst are type-safe wrappers around indices
5. **Efficient data structures**: Packed representations, arena allocation, minimal overhead

## Next Steps

To understand Hoist deeply, read these documents in order:

1. **01-ir-representation.md** - How IR works (values, instructions, blocks)
2. **02-isle-lowering.md** - Pattern matching and instruction selection
3. **03-register-allocation.md** - Turning virtual registers into real ones
4. **04-vcode-and-machinst.md** - Machine instruction representation
5. **05-optimization-passes.md** - Making code faster
6. **06-backends.md** - Target-specific code generation
7. **07-type-system.md** - Types and type checking
8. **08-atomics-and-memory.md** - Concurrent memory operations
9. **09-algorithms.md** - The clever algorithms that make it all work

Each document builds on the previous ones, going from high-level concepts to implementation details.
