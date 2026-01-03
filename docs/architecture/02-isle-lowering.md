# ISLE Pattern Matching and Lowering

## What is Lowering?

Imagine you have a recipe written in English, but your robot chef only understands French commands. **Lowering** is the process of translating that English recipe into French.

In compilers:
- **High-level IR**: `iadd v0, v1` (add two integers)
- **Low-level machine code**: `ADD X0, X1, X2` (ARM64 instruction)

Lowering converts generic IR operations into target-specific machine instructions.

## Why Not Just Hand-Write It?

You could write a giant `switch` statement:

```zig
fn lowerInstruction(ir_inst: IrInst) MachInst {
    switch (ir_inst.opcode) {
        .iadd => return MachInst.add_rr(...),
        .isub => return MachInst.sub_rr(...),
        .imul => return MachInst.mul_rr(...),
        // ... 500 more cases ...
    }
}
```

**Problems:**
1. Doesn't handle complex patterns (what if `iadd` can become multiple instructions?)
2. Can't express priorities (prefer MADD over separate ADD+MUL)
3. Hard to maintain (100+ opcodes × multiple patterns each)
4. Pattern matching is implicit and ad-hoc
5. No way to share patterns across targets

## Enter ISLE: Instruction Selection Language

**ISLE** is a domain-specific language for writing pattern matching rules declaratively.

**Key idea:** Instead of imperative code, write declarative rules:
```
When you see pattern X in IR,
emit machine instruction Y.
```

The ISLE compiler generates efficient pattern matching code from these rules.

## ISLE Basics: Rules

### Anatomy of a Rule

```isle
(rule PRIORITY (lower (PATTERN))
      REPLACEMENT)
```

**Components:**
- `PRIORITY`: Optional number (higher = matched first)
- `PATTERN`: IR pattern to match
- `REPLACEMENT`: What to emit when matched

### Example 1: Simple Addition

```isle
;; Rule: lower iadd to ARM64 ADD instruction
(rule (lower (iadd ty x y))
      (aarch64_add_rr ty x y))
```

**Translation:**
```
When you see:     iadd ty x y
Emit:            aarch64_add_rr(ty, x, y)
```

The ISLE compiler generates:
```zig
fn lower_iadd(ctx: *LowerCtx, ty: Type, x: Value, y: Value) !Inst {
    return ctx.aarch64_add_rr(ty, x, y);
}
```

**File:** `/Users/joel/Work/hoist/src/backends/aarch64/lower.isle:6`

### Example 2: Pattern Matching with Conditions

```isle
;; Rule: iadd with sign-extended operand
;; Only matches when ty is I64
(rule 2 (lower (iadd ty x (aarch64_sxtb ext_ty y)))
      (if-let $I64 ty)
      (aarch64_add_extended ty x y ExtendOp.sxtb))
```

**Translation:**
```
When you see:     iadd ty x (sxtb ext_ty y)
And:             ty == I64
Emit:            aarch64_add_extended(ty, x, y, SXTB)
```

This matches ARM64's extended register add:
```asm
ADD X0, X1, W2, SXTB    ; X0 = X1 + sign_extend_byte(W2)
```

**File:** `/Users/joel/Work/hoist/src/backends/aarch64/lower.isle:12`

### Example 3: Fusion Patterns

```isle
;; Rule: fuse multiply-add
;; iadd(a, imul(x, y)) => madd(x, y, a)
(rule 3 (lower (iadd ty (imul ty x y) a))
      (aarch64_madd ty x y a))

;; Commuted version:
;; iadd(imul(x, y), a) => madd(x, y, a)
(rule 3 (lower (iadd ty a (imul ty x y)))
      (aarch64_madd ty x y a))
```

**Translation:**
```
When you see:     iadd ty (imul ty x y) a
Emit:            aarch64_madd(ty, x, y, a)
```

Instead of two instructions:
```asm
MUL X0, X1, X2    ; tmp = X1 * X2
ADD X3, X0, X3    ; X3 = tmp + X3
```

We emit one:
```asm
MADD X3, X1, X2, X3    ; X3 = X3 + (X1 * X2)
```

**File:** `/Users/joel/Work/hoist/src/backends/aarch64/lower.isle:75`

## Pattern Matching Priorities

Rules have priorities (the number after `rule`). Higher priority = matched first.

```isle
;; Priority 0 (lowest, default)
(rule (lower (iadd ty x y))
      (aarch64_add_rr ty x y))

;; Priority 2 (higher)
(rule 2 (lower (iadd ty x (aarch64_sxtb ext_ty y)))
      (if-let $I64 ty)
      (aarch64_add_extended ty x y ExtendOp.sxtb))

;; Priority 3 (highest)
(rule 3 (lower (iadd ty (imul ty x y) a))
      (aarch64_madd ty x y a))
```

**Matching order:**
1. Try priority 3 rules (fusion patterns)
2. Try priority 2 rules (extended operands)
3. Try priority 0 rules (generic fallback)

**Why?** We want to prefer fused instructions (MADD) over generic add. Without priorities, we might match the generic rule before seeing the fusion opportunity.

## External Constructors: Calling Zig Code

ISLE patterns can call **external constructors** - Zig functions that emit instructions.

### Defining External Constructors

In ISLE:
```isle
;; Declare external constructor
(decl aarch64_add_rr (Type Value Value) Inst)

;; Use in rule
(rule (lower (iadd ty x y))
      (aarch64_add_rr ty x y))
```

In Zig (`isle_helpers.zig`):
```zig
pub fn aarch64_add_rr(
    ctx: *LowerCtx,
    ty: Type,
    x: Value,
    y: Value,
) !Inst {
    // Get virtual registers for x and y
    const x_reg = try ctx.valueOf(x);
    const y_reg = try ctx.valueOf(y);

    // Allocate destination register
    const dst_reg = try ctx.allocReg(ty);

    // Emit ADD instruction
    const size = operandSizeFromType(ty);
    const inst = Inst{
        .add_rr = .{
            .dst = dst_reg,
            .src1 = x_reg,
            .src2 = y_reg,
            .size = size,
        },
    };

    try ctx.emit(inst);
    return inst;
}
```

**File:** `/Users/joel/Work/hoist/src/backends/aarch64/isle_helpers.zig`

### What Constructors Do

1. **Look up values**: Convert IR values to virtual registers
2. **Allocate registers**: Create new VRegs for results
3. **Emit instructions**: Add machine instructions to VCode
4. **Handle edge cases**: Deal with immediate encodings, register classes, etc.

## The Lowering Context (LowerCtx)

The lowering context provides utilities for code generation:

```zig
LowerCtx = struct {
    allocator: Allocator,
    func: *Function,               // IR function
    vcode_builder: *VCodeBuilder,  // Machine code builder
    current_inst: ?Inst,           // Current IR instruction
    value_regs: HashMap(Value, VReg),  // IR value → virtual register

    // Get VReg for IR value
    pub fn valueOf(self: *LowerCtx, v: Value) !VReg {
        // If already lowered, return existing VReg
        if (self.value_regs.get(v)) |vreg| {
            return vreg;
        }

        // Otherwise, materialize the value
        return try self.lowerValue(v);
    }

    // Allocate a new virtual register
    pub fn allocReg(self: *LowerCtx, ty: Type) !VReg {
        const reg_class = regClassForType(ty);
        return self.vcode_builder.allocVReg(reg_class);
    }

    // Emit instruction to VCode
    pub fn emit(self: *LowerCtx, inst: MachInst) !void {
        try self.vcode_builder.addInst(inst);
    }
}
```

**File:** `/Users/joel/Work/hoist/src/codegen/isle_ctx.zig`

### Value Materialization

Not all IR values are already in registers. Some need to be **materialized**:

```zig
fn lowerValue(ctx: *LowerCtx, v: Value) !VReg {
    const value_data = ctx.func.dfg.values.get(v).?;

    switch (value_data.toDef()) {
        .result => |r| {
            // Value is result of instruction - lower that instruction
            try lowerInstruction(ctx, r.inst);
            return ctx.value_regs.get(v).?;
        },
        .param => |p| {
            // Value is block parameter - already has VReg assigned
            return ctx.blockParamReg(p.block, p.index);
        },
    }
}
```

## Patterns: The Building Blocks

### Simple Patterns

```isle
;; Match specific opcode
(iadd ty x y)

;; Match with type constraint
(iadd $I64 x y)    ; only match when type is I64

;; Match constant
(iconst $42)       ; only match constant 42
```

### Nested Patterns

```isle
;; Match iadd where right operand is also imul
(iadd ty (imul ty x y) a)
       ↑
       └─ nested pattern (matches imul)
```

This recursively matches sub-expressions!

### Pattern Variables

Variables in patterns are bound and can be used in the replacement:

```isle
(rule (lower (iadd ty x y))
      (aarch64_add_rr ty x y))
                      ↑  ↑ ↑
                      └──┴─┴─ uses bound variables
```

### If-Let Conditions

```isle
;; Only match when condition holds
(rule (lower (iadd ty x y))
      (if-let $I64 ty)      ; condition: ty must be I64
      (aarch64_add_64 x y))
```

## Complete Example: Lowering a Function

### IR Input

```
function example(v0: i32) -> i32 {
    block0(v0: i32):
        v1 = iconst.i32 10
        v2 = iadd v0, v1
        v3 = iconst.i32 2
        v4 = imul v2, v3
        v5 = iadd v4, v2
        return v5
}
```

### ISLE Rules Applied

```isle
;; v1 = iconst 10
(rule (lower (iconst ty imm))
      (aarch64_mov_imm ty imm))
;; Emits: MOV W1, #10

;; v2 = iadd v0, v1
(rule (lower (iadd ty x y))
      (aarch64_add_rr ty x y))
;; Emits: ADD W2, W0, W1

;; v3 = iconst 2
(rule (lower (iconst ty imm))
      (aarch64_mov_imm ty imm))
;; Emits: MOV W3, #2

;; v4 = imul v2, v3
;; v5 = iadd v4, v2
;; Fusion opportunity! iadd(imul(x,y), a)
(rule 3 (lower (iadd ty a (imul ty x y)))
      (aarch64_madd ty x y a))
;; Emits: MADD W5, W2, W3, W2
;; (one instruction instead of MUL + ADD)
```

### Generated VCode

```
block0:
    MOV W1, #10           ; v1 = 10
    ADD W2, W0, W1        ; v2 = v0 + v1
    MOV W3, #2            ; v3 = 2
    MADD W5, W2, W3, W2   ; v5 = v2 + (v2 * v3)
    RET
```

**File reference:** This is conceptual - actual lowering happens in `/Users/joel/Work/hoist/src/codegen/compile.zig:424`

## Register Classes

Not all registers are the same. ARM64 has:
- **Integer registers**: X0-X30 (64-bit), W0-W30 (32-bit views)
- **Float/SIMD registers**: V0-V31, D0-D31, S0-S31

When allocating VRegs, we specify a **register class**:

```zig
pub const RegClass = enum {
    int,    // Integer registers (X/W)
    float,  // Float/SIMD registers (V/D/S/Q)
};

fn regClassForType(ty: Type) RegClass {
    if (ty.isInt()) return .int;
    if (ty.isFloat()) return .float;
    // ... vectors, etc.
}
```

**File:** `/Users/joel/Work/hoist/src/machinst/reg.zig`

## Instruction Encoding vs. ISLE

**ISLE** generates the pattern matching and instruction selection logic.

**Encoding** (emit.zig) converts instructions to bytes.

**Two separate concerns:**

```
ISLE:      IR → Machine Instructions (what to emit)
Encoding:  Machine Instructions → Bytes (how to encode)
```

Example:
```
ISLE rule:
  (iadd ty x y) → aarch64_add_rr(ty, x, y)

Encoding:
  ADD X0, X1, X2 → bytes [0x8b, 0x02, 0x00, 0x00]
```

**Files:**
- ISLE rules: `/Users/joel/Work/hoist/src/backends/aarch64/lower.isle`
- Encoding: `/Users/joel/Work/hoist/src/backends/aarch64/emit.zig`

## Why ISLE is Powerful

### 1. Declarative

Instead of:
```zig
if (inst.opcode == .iadd) {
    if (inst.args[1].opcode == .imul) {
        // emit MADD
    } else {
        // emit ADD
    }
}
```

You write:
```isle
(rule 3 (lower (iadd ty (imul ty x y) a))
      (aarch64_madd ty x y a))

(rule (lower (iadd ty x y))
      (aarch64_add_rr ty x y))
```

### 2. Composable

Patterns compose naturally:
```isle
;; Basic pattern
(iadd ty x y)

;; Extended pattern (builds on basic)
(iadd ty x (sxtb ext_ty y))

;; Fusion pattern (builds on both iadd and imul)
(iadd ty (imul ty x y) a)
```

### 3. Prioritized

```isle
(rule 3 ...)  ; Try this first (fused instructions)
(rule 2 ...)  ; Then this (extended operands)
(rule ...)    ; Finally this (generic fallback)
```

Automatically tries best patterns first!

### 4. Target-Independent Core

The ISLE compiler itself is target-independent. Adding a new backend means:
1. Write `.isle` rules for the new target
2. Implement external constructors in Zig
3. Done!

No changes to the core compiler needed.

## The Full Lowering Pipeline

```
1. Start with IR instruction
   ↓
2. ISLE pattern matcher tries rules (high to low priority)
   ↓
3. First matching rule fires
   ↓
4. Call external constructor (Zig function)
   ↓
5. Constructor:
   - Looks up input values (IR → VReg)
   - Allocates output VRegs
   - Emits machine instruction(s)
   ↓
6. Record IR value → VReg mapping
   ↓
7. Continue with next IR instruction
```

**Implementation:**
- Pattern matching: Generated by ISLE compiler
- Lowering loop: `/Users/joel/Work/hoist/src/codegen/compile.zig:443`
- External constructors: `/Users/joel/Work/hoist/src/backends/aarch64/isle_helpers.zig`

## ASCII Art: ISLE Lowering Flow

```
IR Function
┌─────────────────────────────────────┐
│ block0(v0: i32):                    │
│   v1 = iconst.i32 10                │
│   v2 = iadd v0, v1                  │
│   v3 = imul v2, v2                  │
│   v4 = iadd v3, v2    ← Current     │
│   return v4                         │
└─────────────────────────────────────┘
          │
          │ Lower v4 = iadd v3, v2
          ↓
┌─────────────────────────────────────┐
│ ISLE Pattern Matcher                │
├─────────────────────────────────────┤
│ Try priority 3 rules:               │
│   (iadd ty (imul ty x y) a)         │
│   Match! v3 = imul v2, v2           │
│         v4 = iadd v3, v2            │
│   Pattern: iadd(imul(v2,v2), v2)    │
│   ✓ Matches!                        │
└─────────────────────────────────────┘
          │
          │ Call constructor
          ↓
┌─────────────────────────────────────┐
│ aarch64_madd(ty, v2, v2, v2)        │
├─────────────────────────────────────┤
│ 1. valueOf(v2) → W2                 │
│ 2. allocReg(ty) → W4                │
│ 3. emit(MADD W4, W2, W2, W2)        │
│ 4. record v4 → W4                   │
└─────────────────────────────────────┘
          │
          ↓
VCode (Virtual Code)
┌─────────────────────────────────────┐
│ block0:                             │
│   MOV W1, #10                       │
│   ADD W2, W0, W1                    │
│   MADD W4, W2, W2, W2               │
│   RET                               │
└─────────────────────────────────────┘
```

## Advanced Topics

### Multi-Instruction Lowering

Some IR operations lower to multiple machine instructions:

```zig
pub fn aarch64_load_large_const(
    ctx: *LowerCtx,
    ty: Type,
    imm: u64,
) !VReg {
    const dst = try ctx.allocReg(ty);

    // Break into 16-bit chunks
    try ctx.emit(.{ .movz = .{ .dst = dst, .imm = @truncate(imm), .shift = 0 } });
    try ctx.emit(.{ .movk = .{ .dst = dst, .imm = @truncate(imm >> 16), .shift = 16 } });
    try ctx.emit(.{ .movk = .{ .dst = dst, .imm = @truncate(imm >> 32), .shift = 32 } });
    try ctx.emit(.{ .movk = .{ .dst = dst, .imm = @truncate(imm >> 48), .shift = 48 } });

    return dst;
}
```

One IR constant becomes four ARM64 instructions!

### Extractors

ISLE also supports **extractors** - functions that match and extract data from values:

```isle
;; Extractor: check if value is power of 2
(decl is_power_of_two (Value) Option<u32>)

;; Use in pattern
(rule (lower (imul ty x (is_power_of_two n)))
      (aarch64_lsl_imm ty x n))
```

This lets you replace `x * 8` with `x << 3` (shift instead of multiply).

### Type Specialization

Rules can specialize on types:

```isle
;; I32 addition
(rule (lower (iadd $I32 x y))
      (aarch64_add_w x y))

;; I64 addition
(rule (lower (iadd $I64 x y))
      (aarch64_add_x x y))
```

Different instructions for different sizes!

## Key Insights

1. **ISLE separates concerns**: Pattern matching is declarative, implementation is in Zig

2. **Priorities enable fusion**: High-priority patterns match complex patterns first

3. **External constructors are the bridge**: ISLE handles matching, Zig handles emission

4. **Composable patterns**: Build complex patterns from simple ones

5. **Target-independent framework**: Adding backends doesn't require core changes

6. **Type-safe**: ISLE compiler ensures patterns are well-typed

## Next Steps

- **03-register-allocation.md**: What happens after lowering (VRegs → physical registers)
- **04-vcode-and-machinst.md**: The machine instruction representation
- **06-backends.md**: How backends are structured (ISLE + encoding + ABI)

ISLE is the heart of code generation - understanding it unlocks how IR becomes machine code!
