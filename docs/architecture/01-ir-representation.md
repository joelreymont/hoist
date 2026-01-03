# IR Representation (Intermediate Representation)

## What is IR?

Imagine you're organizing a massive library with books in hundreds of languages. Instead of having separate organization systems for each language, you create one universal cataloging system. IR is that universal system for compiler instructions.

**IR = A language-neutral, target-neutral representation of a program**

## Why IR?

Without IR, supporting 5 source languages × 3 target CPUs = 15 compiler backends to maintain.

With IR: 5 frontends (language → IR) + 3 backends (IR → CPU) = 8 components.

```
Python ─┐
JavaScript ─┼─→ IR ─┼─→ ARM64
Rust ─┘         └─→ x86-64
                └─→ RISC-V
```

## The Big Picture: Three Core Components

Hoist's IR has three interlocking pieces:

1. **DFG (Data Flow Graph)**: Values and how they're computed
2. **Layout**: Physical ordering of code
3. **CFG (Control Flow Graph)**: How execution can flow between blocks

Think of it like describing a city:
- **DFG**: The buildings and what happens inside them
- **Layout**: The street addresses in order
- **CFG**: The roads connecting buildings

## Part 1: Values - The Building Blocks

### What is a Value?

A value is anything you can compute, pass around, or store. In Hoist, every value:
- Has a unique ID (v0, v1, v2...)
- Has a type (I32, I64, F32, etc.)
- Is defined exactly once (SSA form)
- Can be used multiple times

### Example: Simple Arithmetic

```
Source (pseudocode):
  a = 10
  b = 20
  c = a + b
  d = c * 2

IR:
  v0 = iconst.i32 10    ; value v0 is the constant 10
  v1 = iconst.i32 20    ; value v1 is the constant 20
  v2 = iadd v0, v1      ; value v2 is v0 + v1 (= 30)
  v3 = iconst.i32 2     ; value v3 is the constant 2
  v4 = imul v2, v3      ; value v4 is v2 * v3 (= 60)
```

Each `v*` is a **value** with its own type and definition.

### Value Definitions: Where Values Come From

A value can be defined in three ways:

#### 1. Instruction Result
Most values come from instruction results:
```
v5 = iadd v0, v1     ; v5 is defined as result of iadd instruction
v6 = load v2         ; v6 is defined as result of load instruction
```

#### 2. Block Parameter
When multiple control flow paths merge, we use block parameters (like phi nodes):
```
block2(v7: i32):     ; v7 is a parameter to block2
  v8 = iadd v7, v1   ; use v7 in calculation
```

Why needed? Consider:
```
block0:
  v0 = iconst 10
  jump block2(v0)    ; pass v0 to block2

block1:
  v1 = iconst 20
  jump block2(v1)    ; pass v1 to block2

block2(v_merged: i32):
  ; v_merged is either v0 or v1 depending on which path we took
  v2 = iadd v_merged, v_merged
  return v2
```

#### 3. Alias
Sometimes we create an alias (different name for same value):
```
v9 = alias v5       ; v9 is just another name for v5
```

Used for optimizations - when we discover two values are always equal, we can alias one to the other.

### ValueData: Packed Representation

Values are stored efficiently using bit-packing (file: `/Users/joel/Work/hoist/src/ir/dfg.zig:62`):

```
ValueData layout (64 bits):
┌─────────┬──────────┬────────────┬────────────┐
│ tag (2) │ type(14) │ x (24)     │ y (24)     │
└─────────┴──────────┴────────────┴────────────┘

Tag meanings:
  00 = Instruction result (num=x, inst=y)
  01 = Block parameter (num=x, block=y)
  10 = Alias (original=y)
  11 = Union (for e-graph: x and y are equivalent)
```

**Why pack?** A value is just 8 bytes instead of multiple heap allocations. With millions of values, this matters!

**Example encoding:**
```zig
// v5 is result #0 of instruction 42, type I32
ValueData.inst(Type.I32, 0, Inst.new(42))
// Encodes as: tag=00, type=I32, x=0, y=42

// v7 is parameter #1 of block 10, type I64
ValueData.param(Type.I64, 1, Block.new(10))
// Encodes as: tag=01, type=I64, x=1, y=10
```

## Part 2: Instructions - What Computes Values

### What is an Instruction?

An instruction is an operation that:
- Takes zero or more input values (operands)
- Produces zero or more output values (results)
- Has an opcode (what operation to perform)
- Has a format (how operands are arranged)

### Instruction Formats

Different operations need different data. Instead of one giant struct, we use a tagged union:

```zig
InstructionData = union(InstructionFormat) {
    unary: struct {
        opcode: Opcode,
        arg: Value,
    },
    binary: struct {
        opcode: Opcode,
        args: [2]Value,
    },
    jump: struct {
        opcode: Opcode,
        destination: Block,
    },
    branch: struct {
        opcode: Opcode,
        condition: Value,
        then_block: Block,
        else_block: Block,
    },
    ...
}
```

**File:** `/Users/joel/Work/hoist/src/ir/instruction_data.zig`

### Common Opcodes

```
Arithmetic:
  iadd, isub, imul, sdiv, udiv     ; integer ops
  fadd, fsub, fmul, fdiv           ; float ops

Bitwise:
  and, or, xor, shl, shr

Memory:
  load, store

Control flow:
  jump, br_if, return, call

Comparisons:
  icmp_eq, icmp_ne, icmp_slt, icmp_ult
```

**File:** `/Users/joel/Work/hoist/src/ir/opcodes.zig`

### Example: Binary Instruction

```
v10 = iadd v5, v6

Stored as InstructionData:
  format: binary
  opcode: iadd
  args: [v5, v6]
```

In memory, the instruction has an index (say, i42). The DFG tracks:
```
insts[i42] = InstructionData { binary: { iadd, [v5, v6] } }
values[v10] = ValueData { tag=inst, inst=i42, num=0, type=I32 }
```

So value v10 knows it's "result #0 of instruction i42", and instruction i42 knows it's "iadd v5, v6".

## Part 3: Blocks - Organizing Code

### What is a Block?

A **basic block** is a straight-line sequence of instructions:
- One entry point (the top)
- One exit point (the bottom)
- No branches in the middle

Think of blocks like paragraphs - you read from top to bottom without jumping around mid-paragraph.

### Block Structure

```
block5(v20: i32, v21: i32):    ; parameters (if any)
    v22 = iadd v20, v21        ; instruction 1
    v23 = imul v22, v22        ; instruction 2
    v24 = icmp_slt v23, v21    ; instruction 3
    br_if v24, block6, block7  ; terminator (jump to next block)
```

**Key rules:**
1. First instruction is at the top
2. Last instruction must be a **terminator** (jump, branch, return)
3. Terminators can only appear at the end
4. Blocks can have parameters (for control flow merges)

### Block Parameters vs Phi Nodes

Many compilers use phi nodes:
```
block2:
    v7 = phi [v0, block0], [v1, block1]   ; traditional phi node
```

Hoist uses block parameters instead:
```
block2(v7: i32):    ; v7 is parameter
    ...
```

Callers pass arguments:
```
block0:
    jump block2(v0)    ; pass v0 as argument

block1:
    jump block2(v1)    ; pass v1 as argument
```

**Why?** Cleaner representation, easier to work with. Same semantic meaning.

**File:** `/Users/joel/Work/hoist/src/ir/block_call.zig`

## Part 4: DFG (Data Flow Graph)

The DFG is the heart of IR - it tracks all values, instructions, and their relationships.

### What DFG Contains

```zig
DataFlowGraph = struct {
    values: PrimaryMap(Value, ValueData),      // all values
    insts: PrimaryMap(Inst, InstructionData),  // all instructions
    blocks: PrimaryMap(Block, BlockData),       // block metadata
    value_lists: ValueListPool,                 // variable-length lists
}
```

**File:** `/Users/joel/Work/hoist/src/ir/dfg.zig`

### PrimaryMap: Efficient Entity Storage

```zig
PrimaryMap(K, V) = struct {
    elems: ArrayList(V),    // dense array
}

// Access by index:
value_data = dfg.values.get(v5);    // O(1) lookup
```

**Why not HashMap?** Entities (Value, Inst, Block) are already sequential indices. A PrimaryMap is just an array, giving O(1) access without hashing overhead.

### ValueListPool: Variable-Length Operands

Some instructions have variable operands (calls, returns):
```
v30 = call f, v10, v11, v12, v13, v14    ; 5 arguments
```

Can't store unbounded operands inline. Solution: **ValueListPool** - a custom allocator for lists.

```
┌─────────────────────────────────┐
│ ValueListPool                    │
│  storage: [v10,v11,v12,v13,v14, │
│            v20,v21, ...]         │
└─────────────────────────────────┘
        ↑
        │
  ValueList { offset: 0, length: 5 }
```

Each `ValueList` is just (offset, length). The pool manages the actual storage.

**File:** `/Users/joel/Work/hoist/src/ir/value_list.zig`

### Example: DFG in Action

```zig
// Create function
var func = try Function.init(allocator, "example", sig);

// Build IR using FunctionBuilder
var builder = FunctionBuilder.init(&func);

// Create block
const block0 = try builder.createBlock();
try builder.appendBlock(block0);
builder.switchToBlock(block0);

// Emit: v0 = iconst 10
const v0 = try builder.iconst(Type.I32, 10);

// Emit: v1 = iconst 20
const v1 = try builder.iconst(Type.I32, 20);

// Emit: v2 = iadd v0, v1
const v2 = try builder.iadd(Type.I32, v0, v1);

// Emit: return
try builder.ret();

// DFG now contains:
// values[v0] = ValueData { inst, inst=i0, num=0, type=I32 }
// values[v1] = ValueData { inst, inst=i1, num=0, type=I32 }
// values[v2] = ValueData { inst, inst=i2, num=0, type=I32 }
// insts[i0] = InstructionData { iconst, imm=10 }
// insts[i1] = InstructionData { iconst, imm=20 }
// insts[i2] = InstructionData { binary, iadd, [v0, v1] }
```

## Part 5: Layout - Physical Ordering

The DFG is a logical graph. Layout is the actual order of execution.

### Why Separate?

Consider:
```
block0:
    v0 = iconst 10
    jump block2

block1:
    v1 = iconst 20
    jump block2

block2(v2: i32):
    return v2
```

**DFG**: block2 depends on block0 and block1 (predecessors)

**Layout**: We must choose an order. Maybe: block0, block2, block1

The layout can change during optimization (reordering blocks for better branch prediction), but the DFG stays the same.

### Layout Structure

```zig
Layout = struct {
    blocks: EntityList(Block),              // ordered list of blocks
    block_insts: SecondaryMap(Block, InstList),  // insts per block
}
```

**File:** `/Users/joel/Work/hoist/src/ir/layout.zig`

### Iterating Layout

```zig
// Iterate blocks in order
var block_iter = func.layout.blockIter();
while (block_iter.next()) |block| {
    // Iterate instructions in block
    var inst_iter = func.layout.blockInstIter(block);
    while (inst_iter.next()) |inst| {
        // Process instruction
    }
}
```

This traversal order is **critical** for code generation - it's the actual execution order.

## Part 6: Entities - Type-Safe Indices

Hoist uses **entity wrappers** around indices:

```zig
pub const Value = enum(u32) { _ };
pub const Inst = enum(u32) { _ };
pub const Block = enum(u32) { _ };
```

**Why not plain u32?** Type safety! This prevents:
```zig
var v: Value = ...;
var i: Inst = ...;
if (v == i) { ... }    // Compile error! Can't compare Value to Inst
```

You can't accidentally use a Value where an Inst is expected.

### Creating Entities

```zig
// Value from index
const v0 = Value.new(0);
const v1 = Value.new(1);

// Instruction from index
const i0 = Inst.new(0);

// Block from index
const block0 = Block.new(0);
```

**File:** `/Users/joel/Work/hoist/src/ir/entities.zig`

## Part 7: Control Flow Graph (CFG)

The CFG tracks which blocks can jump to which:

```zig
CFG = struct {
    succs: HashMap(Block, ArrayList(Block)),    // successors
    preds: HashMap(Block, ArrayList(Block)),    // predecessors
}
```

### Computing CFG

```zig
// Scan all block terminators
for each block B:
    terminator = last instruction in B
    if terminator is jump(target):
        add_edge(B → target)
    else if terminator is br_if(_, then, else):
        add_edge(B → then)
        add_edge(B → else)
```

**Why important?**
- Optimization passes need to know what affects what
- Dominator tree computation requires CFG
- Dead code elimination finds unreachable blocks via CFG

**File:** `/Users/joel/Work/hoist/src/ir/cfg.zig`

### Example CFG

```
Code:
  block0:
      br_if v0, block1, block2

  block1:
      jump block3

  block2:
      jump block3

  block3:
      return

CFG:
  block0 → [block1, block2]
  block1 → [block3]
  block2 → [block3]
  block3 → []

  block0 ← []
  block1 ← [block0]
  block2 ← [block0]
  block3 ← [block1, block2]
```

## Putting It All Together: A Complete Example

```zig
// Function: max(a: i32, b: i32) -> i32
// Returns the larger of a and b

// IR:
function max(v0: i32, v1: i32) -> i32 {
    block0(v0: i32, v1: i32):
        v2 = icmp_slt v0, v1         ; v2 = (v0 < v1)
        br_if v2, block1, block2     ; if v2 then block1 else block2

    block1:
        jump block3(v1)              ; return v1

    block2:
        jump block3(v0)              ; return v0

    block3(v3: i32):
        return v3
}
```

**DFG contains:**
- Values: v0 (param), v1 (param), v2 (inst result), v3 (block param)
- Instructions: icmp_slt, br_if, jump, jump, return
- Blocks: block0, block1, block2, block3

**Layout order:** block0, block1, block2, block3

**CFG:**
```
successors:
  block0 → [block1, block2]
  block1 → [block3]
  block2 → [block3]
  block3 → []

predecessors:
  block0 ← []
  block1 ← [block0]
  block2 ← [block0]
  block3 ← [block1, block2]
```

## ASCII Art: Complete IR Structure

```
Function "max"
│
├─ Signature: (i32, i32) -> i32
│
├─ DFG (Data Flow Graph)
│  ├─ Values
│  │  ├─ v0: param(block0, #0, i32)
│  │  ├─ v1: param(block0, #1, i32)
│  │  ├─ v2: inst(i0, #0, i1)
│  │  └─ v3: param(block3, #0, i32)
│  │
│  ├─ Instructions
│  │  ├─ i0: icmp_slt(v0, v1)
│  │  ├─ i1: br_if(v2, block1, block2)
│  │  ├─ i2: jump(block3, [v1])
│  │  ├─ i3: jump(block3, [v0])
│  │  └─ i4: return(v3)
│  │
│  └─ Blocks
│     ├─ block0: params=[v0, v1]
│     ├─ block1: params=[]
│     ├─ block2: params=[]
│     └─ block3: params=[v3]
│
├─ Layout
│  ├─ block0: [i0, i1]
│  ├─ block1: [i2]
│  ├─ block2: [i3]
│  └─ block3: [i4]
│
└─ CFG
   ├─ Successors
   │  ├─ block0 → [block1, block2]
   │  ├─ block1 → [block3]
   │  ├─ block2 → [block3]
   │  └─ block3 → []
   │
   └─ Predecessors
      ├─ block0 ← []
      ├─ block1 ← [block0]
      ├─ block2 ← [block0]
      └─ block3 ← [block1, block2]
```

## Key Insights

1. **SSA makes analysis trivial**: Each value defined once means no ambiguity about where it came from

2. **Separation of concerns**: DFG (logical), Layout (physical), CFG (control) are independent

3. **Efficient representation**: Packed ValueData, entity indices, arena allocation

4. **Type safety**: Can't mix up Value/Inst/Block thanks to newtype wrappers

5. **Variable operands**: ValueListPool handles arbitrary-length argument lists efficiently

6. **Block parameters > phi nodes**: Cleaner representation, same power

## Next Steps

Now that you understand IR, you can learn:

- **02-isle-lowering.md**: How IR gets converted to machine instructions
- **05-optimization-passes.md**: How IR gets transformed to be faster
- **07-type-system.md**: The type system built on IR

The IR is the foundation - everything else builds on these concepts!
