# Cranelift Architecture

Complete architecture documentation for the Cranelift → Zig port.

## Overview

Cranelift is a fast, optimizing code generator designed for WebAssembly and other JIT scenarios. It uses:
- **SSA-form IR** for intermediate representation
- **ISLE DSL** for declarative pattern matching (instruction lowering and optimizations)
- **Multi-phase pipeline** for staged compilation
- **Backend abstraction** supporting multiple architectures

## Compilation Pipeline

```
Source IR (CLIF)
    ↓
[Parse & Validate]
    ↓
CLIF IR (SSA form)
    ↓
[Legalization]
    ↓
Legalized IR
    ↓
[Optimization Passes via ISLE]
    ↓
Optimized IR
    ↓
[Lowering via ISLE]
    ↓
VCode (Virtual Registers)
    ↓
[Register Allocation - regalloc2]
    ↓
VCode + Physical Registers
    ↓
[Binary Emission]
    ↓
Machine Code (Vec<u8>)
```

## Core Components

### 1. Foundation Layer (~7k LOC)

**Purpose**: Type-safe data structures used throughout the compiler.

**Modules**:
- `bitset.zig`: Bit set implementations (scalar and compound)
- `entity.zig`: Entity-based indexing system
  - `EntityRef<T>`: Type-safe u32 wrapper for indices
  - `PrimaryMap<K, V>`: Dense array indexed by entity
  - `SecondaryMap<K, V>`: Sparse map for optional data
  - `EntitySet<K>`: Set of entities
- `bforest.zig`: B+ tree forest for ordered maps/sets

**Why Entity-Based Indexing?**
- Type safety: Can't mix up different index types
- Compact: u32 indices instead of pointers (64-bit)
- Cache-friendly: Dense arrays, good locality
- Stable references: Indices don't invalidate when collections grow

Example:
```zig
const Value = EntityRef("value");
const Inst = EntityRef("inst");

var values = PrimaryMap(Value, ValueDef){};
const v0 = values.push(allocator, .{ .inst = inst0 }); // v0 is Value type
const v1 = values.push(allocator, .{ .param = 0 });    // v1 is Value type

// Type error - can't use Inst as Value index:
// const wrong = values.get(inst0); // Compile error!
```

### 2. IR Layer (~15k LOC)

**Purpose**: Intermediate representation in SSA form with control flow.

**Modules**:

#### `types.zig` - Type System
- Scalar types: `i8`, `i16`, `i32`, `i64`, `i128`, `f32`, `f64`
- Vector types: `i32x4`, `f64x2`, etc.
- Reference types: `r32`, `r64` (pointers)
- Special types: `iflags`, `fflags` (condition flags)

Type operations:
```zig
pub const Type = enum(u16) {
    i8, i16, i32, i64, i128,
    f32, f64,
    // ...

    pub fn bits(self: Type) u16 { ... }
    pub fn bytes(self: Type) u16 { ... }
    pub fn isInt(self: Type) bool { ... }
    pub fn isFloat(self: Type) bool { ... }
    pub fn vectorOf(scalar: Type, lanes: u8) Type { ... }
};
```

#### `entities.zig` - Entity References
```zig
pub const Value = EntityRef("value");     // SSA value
pub const Inst = EntityRef("inst");       // Instruction
pub const Block = EntityRef("block");     // Basic block
pub const FuncRef = EntityRef("func");    // Function reference
pub const SigRef = EntityRef("sig");      // Signature reference
pub const StackSlot = EntityRef("stack"); // Stack slot
pub const GlobalValue = EntityRef("gv");  // Global value
pub const JumpTable = EntityRef("jt");    // Jump table
pub const Constant = EntityRef("const");  // Constant pool entry
```

#### `instructions.zig` - Opcode Definitions

Instruction format hierarchy:
```zig
pub const Opcode = enum {
    // Integer arithmetic
    iadd, isub, imul, udiv, sdiv, urem, srem,

    // Bitwise
    band, bor, bxor, bnot,
    rotl, rotr, ishl, ushr, sshr,

    // Comparison
    icmp, fcmp,

    // Memory
    load, store, stack_load, stack_store,

    // Control flow
    jump, br_if, br_table, return_, call, call_indirect,

    // Conversions
    sextend, uextend, ireduce, fpromote, fdemote,
    fcvt_to_sint, fcvt_to_uint, fcvt_from_sint, fcvt_from_uint,

    // Float arithmetic
    fadd, fsub, fmul, fdiv, fsqrt, fma, fmin, fmax,

    // And 100+ more...
};

pub const InstructionData = union(enum) {
    unary: struct { opcode: Opcode, arg: Value },
    binary: struct { opcode: Opcode, args: [2]Value },
    binary_imm: struct { opcode: Opcode, arg: Value, imm: i64 },
    ternary: struct { opcode: Opcode, args: [3]Value },

    branch: struct {
        opcode: Opcode,
        destination: Block,
        args: []Value, // Block parameters
    },

    call: struct {
        opcode: Opcode,
        func_ref: FuncRef,
        args: []Value,
    },

    // ... 20+ instruction formats
};
```

#### `dfg.zig` - Data Flow Graph

The DFG is the heart of SSA representation:

```zig
pub const DataFlowGraph = struct {
    // Value definitions
    values: PrimaryMap(Value, ValueDef),

    // Instruction results
    results: SecondaryMap(Inst, ValueList),

    // Instruction data
    insts: PrimaryMap(Inst, InstructionData),

    // Block parameters
    block_params: SecondaryMap(Block, ValueList),

    // Constant pool
    constants: ConstantPool,

    pub fn makeInst(self: *Self, allocator: Allocator, data: InstructionData) !Inst;
    pub fn makeBlock(self: *Self, allocator: Allocator) !Block;
    pub fn appendBlockParam(self: *Self, allocator: Allocator, block: Block, ty: Type) !Value;
    pub fn firstResult(self: Self, inst: Inst) ?Value;
    pub fn instResults(self: Self, inst: Inst) []const Value;
};

pub const ValueDef = union(enum) {
    inst: struct { inst: Inst, num: u16 }, // Result #num of instruction
    param: struct { block: Block, num: u16 }, // Parameter #num of block
};
```

SSA Invariants:
1. Every value has exactly one definition
2. Every use is dominated by its definition
3. Phi nodes (block parameters) at control flow merge points

#### `layout.zig` - Block and Instruction Layout

```zig
pub const Layout = struct {
    // Block ordering
    blocks: EntityList(Block),
    first_block: ?Block,
    last_block: ?Block,

    // Per-block instruction ordering
    block_insts: SecondaryMap(Block, InstRange),
    insts: EntityList(Inst),

    pub fn appendBlock(self: *Self, allocator: Allocator, block: Block) !void;
    pub fn insertBlock(self: *Self, allocator: Allocator, block: Block, before: Block) !void;
    pub fn appendInst(self: *Self, allocator: Allocator, inst: Inst, block: Block) !void;

    pub fn blockInsts(self: Self, block: Block) InstIterator;
    pub fn blocks(self: Self) BlockIterator;
};
```

Layout is separate from DFG for flexibility:
- DFG represents data flow (SSA)
- Layout represents control flow order
- Allows reordering blocks/instructions without changing SSA

#### `cfg.zig` - Control Flow Graph

```zig
pub const ControlFlowGraph = struct {
    // Predecessor lists
    pred_blocks: SecondaryMap(Block, BlockList),

    // Computed on demand
    valid: bool,

    pub fn compute(allocator: Allocator, func: *Function) !ControlFlowGraph;
    pub fn preds(self: Self, block: Block) []const Block;
    pub fn successors(func: *Function, block: Block) BlockIterator;
};
```

#### `function.zig` - Function Container

```zig
pub const Function = struct {
    // IR components
    dfg: DataFlowGraph,
    layout: Layout,

    // Function signature
    signature: Signature,

    // Stack slots
    stack_slots: StackSlotData,

    // Global values
    global_values: GlobalValueData,

    // Jump tables
    jump_tables: JumpTableData,

    pub fn init(allocator: Allocator, sig: Signature) !Function;
    pub fn verify(self: *Self, allocator: Allocator) !void;
};

pub const Signature = struct {
    params: []Type,
    returns: []Type,
    call_conv: CallConv,
};
```

#### `builder.zig` - IR Construction API

Ergonomic API for building IR:

```zig
pub const FunctionBuilder = struct {
    func: *Function,
    current_block: ?Block,

    pub fn init(func: *Function) FunctionBuilder;

    // Block management
    pub fn createBlock(self: *Self, allocator: Allocator) !Block;
    pub fn switchToBlock(self: *Self, block: Block) void;
    pub fn sealBlock(self: *Self, block: Block) void;

    // Instruction insertion
    pub fn ins(self: *Self) *InstBuilder;
};

pub const InstBuilder = struct {
    builder: *FunctionBuilder,

    pub fn iadd(self: *Self, allocator: Allocator, x: Value, y: Value) !Value;
    pub fn imul(self: *Self, allocator: Allocator, x: Value, y: Value) !Value;
    pub fn load(self: *Self, allocator: Allocator, ty: Type, addr: Value) !Value;
    pub fn store(self: *Self, allocator: Allocator, val: Value, addr: Value) !Inst;
    pub fn brIf(self: *Self, allocator: Allocator, cond: Value, then_block: Block, else_block: Block) !Inst;
    pub fn jump(self: *Self, allocator: Allocator, dest: Block, args: []Value) !Inst;
    pub fn return_(self: *Self, allocator: Allocator, vals: []Value) !Inst;
    // ... 100+ instruction builders
};
```

Example usage:
```zig
var func = try Function.init(allocator, signature);
var builder = FunctionBuilder.init(&func);

const entry = try builder.createBlock(allocator);
const loop_header = try builder.createBlock(allocator);
const loop_body = try builder.createBlock(allocator);
const exit = try builder.createBlock(allocator);

builder.switchToBlock(entry);
const initial = try builder.ins().iconst(allocator, Type.i32, 0);
try builder.ins().jump(allocator, loop_header, &[_]Value{initial});

builder.switchToBlock(loop_header);
const counter = try builder.func.dfg.appendBlockParam(allocator, loop_header, Type.i32);
const limit = try builder.ins().iconst(allocator, Type.i32, 10);
const cond = try builder.ins().icmp(allocator, IntCC.ULT, counter, limit);
try builder.ins().brIf(allocator, cond, loop_body, exit);

builder.switchToBlock(loop_body);
const one = try builder.ins().iconst(allocator, Type.i32, 1);
const next = try builder.ins().iadd(allocator, counter, one);
try builder.ins().jump(allocator, loop_header, &[_]Value{next});

builder.switchToBlock(exit);
try builder.ins().return_(allocator, &[_]Value{counter});
```

This generates SSA IR for:
```c
int loop() {
    int counter = 0;
    while (counter < 10) {
        counter = counter + 1;
    }
    return counter;
}
```

### 3. ISLE DSL Compiler (~10k LOC)

**Purpose**: Pattern matching DSL compiler for instruction lowering and optimization.

ISLE (Instruction Selection and Lowering Engine) is a domain-specific language for declaratively specifying:
1. How to lower IR instructions to machine instructions
2. How to optimize IR via pattern rewriting

**Why ISLE?**
- **Declarative**: Describe what, not how
- **Maintainable**: Rules are easy to understand and modify
- **Correct**: Less manual code = fewer bugs
- **Reusable**: Same rules work across backends with different extractors

**Example ISLE Rule**:
```lisp
;; Lower iadd of two registers to ARM64 ADD instruction
(rule (lower (has_type $I64 (iadd x y)))
      (add_reg $I64 x y))

;; Strength reduction: multiply by power of 2 → shift
(rule 1 (lower (has_type ty (imul x (iconst (u64_from_imm64 (i64_shl_mask amt))))))
      (ishl ty x (iconst amt)))

;; Fold load into add (memory operand)
(rule -1 (lower (has_type ty (iadd x (load addr))))
      (add_mem ty x addr))
```

**ISLE Compilation**:
```
*.isle files
    ↓ [lexer]
Tokens
    ↓ [parser]
AST
    ↓ [sema]
Typed AST
    ↓ [trie]
Decision Tree
    ↓ [codegen]
Generated Zig Code
```

**Modules**:

#### `lexer.zig`
S-expression tokenization:
```zig
pub const Token = union(enum) {
    lparen,
    rparen,
    symbol: []const u8,
    int: i64,
    string: []const u8,
};

pub const Lexer = struct {
    source: []const u8,
    pos: usize,

    pub fn next(self: *Self) !?Token;
};
```

#### `parser.zig`
Parse S-expressions into AST:
```zig
pub const Sexp = union(enum) {
    symbol: []const u8,
    int: i64,
    string: []const u8,
    list: []Sexp,
};

pub fn parse(allocator: Allocator, source: []const u8) ![]Sexp;
```

#### `ast.zig`
High-level AST for ISLE constructs:
```zig
pub const Def = union(enum) {
    type_def: TypeDef,
    decl: Decl,
    extern_: Extern,
    rule: Rule,
    extractor: Extractor,
    constructor: Constructor,
};

pub const Rule = struct {
    pattern: Pattern,
    expr: Expr,
    prio: i32, // Priority for rule ordering
};

pub const Pattern = union(enum) {
    wildcard,
    var_: []const u8,
    bind: struct { var_: []const u8, subpat: *Pattern },
    term: struct { sym: []const u8, args: []Pattern },
    and_: []Pattern,
    int_: i64,
};

pub const Expr = union(enum) {
    var_: []const u8,
    term: struct { sym: []const u8, args: []Expr },
    int_: i64,
    let_: struct { var_: []const u8, ty: Type, val: *Expr, body: *Expr },
};
```

#### `sema.zig`
Semantic analysis and type checking:
```zig
pub const Sema = struct {
    type_env: TypeEnv,
    term_env: TermEnv,
    rules: []TypedRule,

    pub fn check(allocator: Allocator, defs: []Def) !Sema;
};

pub const TypedRule = struct {
    pattern: TypedPattern,
    expr: TypedExpr,
    prio: i32,
    bindings: []Binding,
};
```

#### `trie.zig`
Compile rules into decision tree for efficient matching:
```zig
pub const MatchOp = union(enum) {
    test_term: struct { sym: TermId, arity: u8 },
    test_int: i64,
    bind_var: VarId,
    decompose: u8, // Extract argument N
    backtrack,
    emit: ExprId,
};

pub const DecisionTree = struct {
    ops: []MatchOp,

    pub fn compile(allocator: Allocator, rules: []TypedRule) !DecisionTree;
};
```

Decision tree example for:
```lisp
(rule (lower (iadd x y)) (add_rr x y))
(rule (lower (iadd x (iconst k))) (add_ri x k))
```

Compiles to:
```
1. test_term(iadd, 2)
2. decompose(0) -> x
3. decompose(1) -> temp
4. test_term(iconst, 1)  // Try to match iconst
   - if match:
     5. decompose(0) -> k
     6. emit(add_ri(x, k))
   - if no match:
     7. bind(temp) -> y
     8. emit(add_rr(x, y))
```

#### `codegen.zig`
**CRITICAL**: This adapts cranelift/isle/isle/src/codegen_zig.rs

Generate Zig code from decision tree:
```zig
pub fn generate(allocator: Allocator, sema: Sema, tree: DecisionTree) ![]const u8;
```

Generated code looks like:
```zig
pub fn lower_iadd(ctx: *LowerCtx, inst: Inst) !Inst {
    const data = ctx.dfg.insts.get(inst);
    if (data != .binary) return error.NoMatch;
    if (data.binary.opcode != .iadd) return error.NoMatch;

    const x = data.binary.args[0];
    const y = data.binary.args[1];

    // Try rule: iadd x (iconst k) -> add_ri x k
    const y_def = ctx.dfg.values.get(y);
    if (y_def == .inst) {
        const y_inst = ctx.dfg.insts.get(y_def.inst.inst);
        if (y_inst == .binary_imm and y_inst.binary_imm.opcode == .iconst) {
            const k = y_inst.binary_imm.imm;
            return ctx.emit_add_ri(x, k);
        }
    }

    // Fallback rule: iadd x y -> add_rr x y
    return ctx.emit_add_rr(x, y);
}
```

#### `compiler.zig`
Main entry point:
```zig
pub fn compileIsle(allocator: Allocator, source: []const u8) ![]const u8 {
    const sexp = try parser.parse(allocator, source);
    const defs = try ast.buildAst(allocator, sexp);
    const sema = try sema.check(allocator, defs);
    const tree = try trie.compile(allocator, sema.rules);
    return codegen.generate(allocator, sema, tree);
}
```

### 4. Machine Instruction Framework (~12k LOC)

**Purpose**: Abstract interface for backend-independent code generation.

This layer sits between IR and specific backends (ARM64, x64, etc.).

**Key Abstractions**:
- **VReg**: Virtual register (infinite supply)
- **PReg**: Physical register (hardware registers)
- **MachInst**: Machine instruction trait
- **VCode**: Container for virtual-register machine code
- **ABIMachineSpec**: Calling convention abstraction

#### `regs.zig`

```zig
// Virtual register - unlimited supply during lowering
pub const VReg = struct {
    index: u32,
    class: RegClass,

    pub fn new(index: u32, class: RegClass) VReg;
};

// Physical register - actual hardware register
pub const PReg = struct {
    hw_enc: u8, // Hardware encoding
    class: RegClass,

    pub const fn new(hw_enc: u8, class: RegClass) PReg;
};

pub const RegClass = enum {
    int,   // Integer/general-purpose
    float, // Floating-point/vector
    flags, // Condition flags
};

// Maps VReg -> PReg after register allocation
pub const RegAlloc = struct {
    map: []PReg, // Indexed by VReg.index

    pub fn get(self: Self, vreg: VReg) PReg;
};
```

#### `inst.zig`

```zig
// Backend must implement this trait
pub fn MachInst(comptime T: type) type {
    return struct {
        // Required methods that backend must provide:

        // Binary encoding
        pub const emit = T.emit;
        // fn emit(inst: T, buffer: *MachBuffer) !void;

        // Register usage
        pub const getOperands = T.getOperands;
        // fn getOperands(inst: T, collector: *OperandCollector) void;

        // Properties
        pub const isMoveish = T.isMoveish;
        // fn isMoveish(inst: T) ?struct{ src: VReg, dst: VReg };

        pub const isTerm = T.isTerm;
        // fn isTerm(inst: T) bool; // Is terminator (branch, return)

        pub const isCall = T.isCall;
        // fn isCall(inst: T) bool;
    };
}

pub const OperandCollector = struct {
    ops: std.ArrayList(Operand),

    pub fn reg_use(self: *Self, allocator: Allocator, reg: VReg) !void;
    pub fn reg_def(self: *Self, allocator: Allocator, reg: VReg) !void;
    pub fn reg_mod(self: *Self, allocator: Allocator, reg: VReg) !void;
};
```

Example backend implementation:
```zig
pub const Inst = union(enum) {
    add_rr: struct { rd: VReg, rs1: VReg, rs2: VReg },
    add_ri: struct { rd: VReg, rs1: VReg, imm: i64 },
    ret,

    pub fn emit(self: Inst, buffer: *MachBuffer) !void {
        switch (self) {
            .add_rr => |add| {
                // Emit ARM64 ADD encoding
                try buffer.put4(...);
            },
            // ...
        }
    }

    pub fn getOperands(self: Inst, collector: *OperandCollector) void {
        switch (self) {
            .add_rr => |add| {
                collector.reg_use(add.rs1);
                collector.reg_use(add.rs2);
                collector.reg_def(add.rd);
            },
            // ...
        }
    }
};

pub const InstTraitImpl = MachInst(Inst);
```

#### `vcode.zig`

Container for machine instructions with virtual registers:

```zig
pub const VCode = struct {
    // Instructions
    insts: std.ArrayList(AnyInst),

    // Block boundaries
    block_starts: std.ArrayList(ProgPoint),

    // Virtual register info
    vreg_types: std.ArrayList(Type),
    num_vregs: u32,

    // ABI info
    abi: *dyn ABIMachineSpec,

    pub fn init(allocator: Allocator, abi: *dyn ABIMachineSpec) VCode;
    pub fn push(self: *Self, allocator: Allocator, inst: anytype) !void;
    pub fn newBlock(self: *Self, allocator: Allocator) !BlockIndex;
    pub fn newVReg(self: *Self, allocator: Allocator, ty: Type, class: RegClass) !VReg;
};

pub const ProgPoint = struct {
    inst: u32,
    slot: enum { before, after },
};
```

#### `buffer.zig`

Binary code buffer with label resolution:

```zig
pub const MachBuffer = struct {
    data: std.ArrayList(u8),
    fixups: std.ArrayList(Fixup),
    labels: std.ArrayList(?u32), // label_id -> offset

    pub fn init(allocator: Allocator) MachBuffer;

    // Raw byte emission
    pub fn put1(self: *Self, allocator: Allocator, byte: u8) !void;
    pub fn put2(self: *Self, allocator: Allocator, val: u16) !void;
    pub fn put4(self: *Self, allocator: Allocator, val: u32) !void;
    pub fn put8(self: *Self, allocator: Allocator, val: u64) !void;

    // Label management
    pub fn createLabel(self: *Self, allocator: Allocator) !Label;
    pub fn bindLabel(self: *Self, label: Label) void;
    pub fn useLabel(self: *Self, allocator: Allocator, label: Label, kind: FixupKind) !void;

    // Finalization
    pub fn finalize(self: *Self) !void;
    pub fn finish(self: Self) []const u8;
};

pub const Label = struct { id: u32 };

pub const Fixup = struct {
    offset: u32,
    kind: FixupKind,
    label: Label,
};

pub const FixupKind = enum {
    pcrel19,  // ARM64 conditional branch (19-bit PC-relative)
    pcrel26,  // ARM64 unconditional branch (26-bit PC-relative)
    pcrel32,  // x64 32-bit PC-relative
};
```

#### `abi.zig`

Calling convention abstraction:

```zig
pub const ABIMachineSpec = struct {
    const Self = @This();

    // VTable for backend-specific ABI
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        // Compute stack frame layout
        computeArgLocs: *const fn(*anyopaque, Allocator, *const Signature) anyerror!ArgLocations,

        // Generate prologue (allocate frame, save registers)
        genPrologue: *const fn(*anyopaque, Allocator, *VCode) anyerror!void,

        // Generate epilogue (restore registers, deallocate frame)
        genEpilogue: *const fn(*anyopaque, Allocator, *VCode) anyerror!void,

        // Generate call sequence
        genCall: *const fn(*anyopaque, Allocator, *VCode, FuncRef, []const Value) anyerror![]Value,
    };
};

pub const ArgLoc = union(enum) {
    reg: PReg,
    stack: i32, // Offset from stack pointer
};

pub const ArgLocations = struct {
    args: []ArgLoc,
    rets: []ArgLoc,
    stack_args_size: u32,
};
```

Example: ARM64 AAPCS64 ABI implementation:
```zig
pub const AAPCS64 = struct {
    // x0-x7 for integer arguments
    // v0-v7 for float arguments

    pub fn computeArgLocs(
        _: *anyopaque,
        allocator: Allocator,
        sig: *const Signature,
    ) !ArgLocations {
        var locs = ArgLocations{
            .args = try allocator.alloc(ArgLoc, sig.params.len),
            .rets = try allocator.alloc(ArgLoc, sig.returns.len),
            .stack_args_size = 0,
        };

        var int_reg: u8 = 0;  // x0-x7
        var float_reg: u8 = 0; // v0-v7
        var stack_offset: i32 = 0;

        for (sig.params, 0..) |param_ty, i| {
            if (param_ty.isInt()) {
                if (int_reg < 8) {
                    locs.args[i] = .{ .reg = PReg.x(int_reg) };
                    int_reg += 1;
                } else {
                    locs.args[i] = .{ .stack = stack_offset };
                    stack_offset += 8;
                }
            } else {
                // Float/vector logic...
            }
        }

        locs.stack_args_size = @intCast(stack_offset);
        return locs;
    }

    pub fn genPrologue(
        _: *anyopaque,
        allocator: Allocator,
        vcode: *VCode,
    ) !void {
        // Save FP, LR
        // Allocate stack frame
        // Save callee-saved registers
    }
};
```

#### `lower.zig`

Lowering context and utilities:

```zig
pub const LowerCtx = struct {
    // Input IR
    func: *Function,

    // Output machine code
    vcode: *VCode,

    // Value mapping: IR Value -> VReg
    value_map: std.AutoHashMap(Value, VReg),

    // Backend-specific lowering functions (ISLE-generated)
    backend: *const LoweringBackend,

    pub fn init(
        allocator: Allocator,
        func: *Function,
        vcode: *VCode,
        backend: *const LoweringBackend,
    ) LowerCtx;

    // Get or create VReg for IR value
    pub fn valueReg(self: *Self, allocator: Allocator, value: Value) !VReg;

    // Lower one instruction
    pub fn lowerInst(self: *Self, allocator: Allocator, inst: Inst) !void;
};

pub const LoweringBackend = struct {
    // ISLE-generated lowering functions
    lower_iadd: *const fn(*LowerCtx, Allocator, Inst) anyerror!void,
    lower_isub: *const fn(*LowerCtx, Allocator, Inst) anyerror!void,
    lower_imul: *const fn(*LowerCtx, Allocator, Inst) anyerror!void,
    // ... one for each opcode
};
```

#### `compile.zig`

Main compilation orchestrator:

```zig
pub fn compile(
    allocator: Allocator,
    func: *Function,
    isa: *const TargetIsa,
) !CompiledCode {
    // 1. Create VCode container
    var vcode = VCode.init(allocator, isa.abi);

    // 2. Lower IR -> VCode (via ISLE)
    var lower_ctx = LowerCtx.init(allocator, func, &vcode, isa.lowering_backend);
    for (func.layout.blocks()) |block| {
        try vcode.newBlock(allocator);
        for (func.layout.blockInsts(block)) |inst| {
            try lower_ctx.lowerInst(allocator, inst);
        }
    }

    // 3. Register allocation
    const regalloc_result = try isa.regalloc.allocate(allocator, &vcode);

    // 4. Binary emission
    var buffer = MachBuffer.init(allocator);
    for (vcode.insts.items) |inst| {
        try isa.emit(inst, regalloc_result.allocs, &buffer);
    }
    try buffer.finalize();

    return CompiledCode{
        .code = buffer.finish(),
        .stack_size = vcode.abi.stackFrameSize(),
    };
}

pub const CompiledCode = struct {
    code: []const u8,
    stack_size: u32,
};
```

### 5. Backend - ARM64 (~29k LOC)

**Purpose**: ARM64-specific instruction encoding and lowering.

This is where the rubber meets the road - actual machine code generation.

See [arm64.md](arm64.md) for complete ARM64 backend documentation.

### 6. Register Allocation (~10k LOC)

**Purpose**: Assign physical registers to virtual registers.

**Algorithm**: SSA-based graph coloring (from regalloc2)

**Two Options**:
1. Port regalloc2 to Zig (~10k LOC)
2. FFI wrapper to Rust regalloc2

See [regalloc.md](regalloc.md) for details.

### 7. Analysis Passes (~4k LOC)

#### Dominance Analysis
```zig
pub const DominatorTree = struct {
    // Immediate dominator of each block
    idom: SecondaryMap(Block, ?Block),

    pub fn compute(allocator: Allocator, func: *Function, cfg: *ControlFlowGraph) !DominatorTree;
    pub fn dominates(self: Self, a: Block, b: Block) bool;
};
```

#### Loop Analysis
```zig
pub const LoopAnalysis = struct {
    loops: std.ArrayList(Loop),

    pub fn compute(allocator: Allocator, func: *Function, dom: *DominatorTree) !LoopAnalysis;
};

pub const Loop = struct {
    header: Block,
    blocks: std.ArrayList(Block),
    depth: u32,
};
```

### 8. Optimization Passes

All optimizations are specified in ISLE:

```lisp
;; Constant folding
(rule (simplify (iadd (iconst x) (iconst y)))
      (iconst (iadd_i64 x y)))

;; Strength reduction
(rule (simplify (imul x (iconst (i64_is_power_of_two k))))
      (ishl x (iconst (i64_log2 k))))

;; Algebraic simplification
(rule (simplify (iadd x (iconst 0))) x)
(rule (simplify (imul x (iconst 1))) x)
(rule (simplify (imul x (iconst 0))) (iconst 0))
```

Compiled to Zig code in `opts/generated.zig`.

### 9. Verification

```zig
pub fn verify(allocator: Allocator, func: *Function) !void {
    // 1. CFG is valid
    const cfg = try ControlFlowGraph.compute(allocator, func);

    // 2. SSA form
    try verifySSA(allocator, func, cfg);

    // 3. Types match
    try verifyTypes(func);

    // 4. Dominance
    try verifyDominance(allocator, func, cfg);
}

fn verifySSA(allocator: Allocator, func: *Function, cfg: *ControlFlowGraph) !void {
    // Every value has exactly one definition
    // Every use is dominated by definition
}
```

### 10. Top-Level API

```zig
pub const Context = struct {
    func: Function,

    pub fn init(allocator: Allocator, sig: Signature) !Context;

    // Optimize the function
    pub fn optimize(self: *Self, allocator: Allocator) !void {
        try self.func.verify(allocator);
        // Run ISLE optimization passes
        try runOptPasses(allocator, &self.func);
        try self.func.verify(allocator);
    }

    // Compile to machine code
    pub fn compile(self: *Self, allocator: Allocator, isa: *const TargetIsa) !CompiledCode {
        try self.optimize(allocator);
        return machinst.compile(allocator, &self.func, isa);
    }
};
```

Example usage:
```zig
const std = @import("std");
const cranelift = @import("cranelift");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create function signature: fn(i64, i64) -> i64
    const sig = cranelift.Signature{
        .params = &[_]cranelift.Type{ .i64, .i64 },
        .returns = &[_]cranelift.Type{ .i64 },
        .call_conv = .SystemV,
    };

    // Create compilation context
    var ctx = try cranelift.Context.init(allocator, sig);
    defer ctx.deinit();

    // Build IR
    var builder = cranelift.FunctionBuilder.init(&ctx.func);

    const entry = try builder.createBlock(allocator);
    builder.switchToBlock(entry);

    const params = ctx.func.dfg.blockParams(entry);
    const x = params[0];
    const y = params[1];

    const result = try builder.ins().iadd(allocator, x, y);
    try builder.ins().return_(allocator, &[_]cranelift.Value{result});

    // Compile to ARM64
    const isa = cranelift.isa.lookup("aarch64-unknown-linux-gnu");
    const code = try ctx.compile(allocator, isa);
    defer allocator.free(code.code);

    // Execute or save...
    std.debug.print("Generated {} bytes of machine code\n", .{code.code.len});
}
```

## Design Principles

### 1. Entity-Based Indexing
All index types are type-safe entity references:
- Can't mix up Value and Inst indices
- Compact (u32) representation
- Stable across collection resizes

### 2. Arena Allocation
Per-function compilation uses arena allocators:
- Fast allocation (bump pointer)
- Bulk deallocation (free entire function at once)
- No per-object free calls

### 3. Separate Data/Control
DFG (data flow) is separate from Layout (control flow):
- Allows IR transformations without breaking SSA
- Easy to reorder blocks and instructions

### 4. ISLE for Patterns
ALL lowering and optimization is declarative:
- Easier to write and understand
- Automatically generates efficient code
- Less room for bugs

### 5. Backend Abstraction
MachInst trait provides uniform interface:
- Easy to add new backends
- Shared infrastructure (regalloc, buffer, ABI)

## Performance Targets

1. **Compile time**: <1ms per function for small functions
2. **Code quality**: Within 10% of LLVM -O2
3. **Throughput**: >1000 functions/second for typical workloads

## Testing Strategy

1. **Unit tests**: Each module has comprehensive tests
2. **Encoding tests**: Verify instruction encodings against ISA manual
3. **Integration tests**: Full IR → machine code pipeline
4. **Differential tests**: Compare ARM64 output semantics
5. **Fuzzing**: Random IR generation to find bugs
6. **Benchmarks**: Track compile time and code quality

## References

- Cranelift source: https://github.com/bytecodealliance/wasmtime/tree/main/cranelift
- ISLE documentation: `../wasmtime/cranelift/docs/isle-integration.md`
- ARM Architecture Reference Manual: https://developer.arm.com/documentation/ddi0487/latest
- regalloc2: https://github.com/bytecodealliance/regalloc2
