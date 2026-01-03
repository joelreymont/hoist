# Backend Architecture

## What is a Backend?

A backend is the target-specific part of the compiler that knows how to generate code for a particular CPU architecture (ARM64, x86-64, RISC-V, etc.).

Think of it like a translator who specializes in one language. The backend speaks "ARM64" while another speaks "x86-64", but both understand the universal IR language.

## Backend Components

Each backend has four main parts:

```
Backend (e.g., ARM64)
├── ISLE rules (lower.isle)         → Pattern matching
├── Helper functions (isle_helpers.zig) → Instruction emission
├── Instruction encoding (emit.zig)     → Bytes generation
└── ABI implementation (abi.zig)        → Calling conventions
```

**File structure:** `/Users/joel/Work/hoist/src/backends/aarch64/`

## ARM64 Backend Example

### 1. ISLE Rules

**File:** `/Users/joel/Work/hoist/src/backends/aarch64/lower.isle`

Declares how IR operations map to ARM64 instructions:

```isle
;; Basic arithmetic
(rule (lower (iadd ty x y))
      (aarch64_add_rr ty x y))

(rule (lower (isub ty x y))
      (aarch64_sub_rr ty x y))

;; Multiply-add fusion
(rule 3 (lower (iadd ty (imul ty x y) a))
      (aarch64_madd ty x y a))
```

### 2. Helper Functions

**File:** `/Users/joel/Work/hoist/src/backends/aarch64/isle_helpers.zig`

Implements the external constructors called by ISLE rules:

```zig
pub fn aarch64_add_rr(
    ctx: *LowerCtx,
    ty: Type,
    x: Value,
    y: Value,
) !VReg {
    const x_reg = try ctx.valueOf(x);
    const y_reg = try ctx.valueOf(y);
    const dst = try ctx.allocReg(ty);

    const size = operandSizeFromType(ty);
    try ctx.emit(.{
        .add_rr = .{
            .dst = dst,
            .src1 = x_reg,
            .src2 = y_reg,
            .size = size,
        },
    });

    return dst;
}
```

### 3. Instruction Encoding

**File:** `/Users/joel/Work/hoist/src/backends/aarch64/emit.zig`

Converts instructions to binary:

```zig
fn emitAddRR(
    dst: Reg,
    src1: Reg,
    src2: Reg,
    size: OperandSize,
    buffer: *MachBuffer,
) !void {
    // ADD Xd, Xn, Xm encoding
    const sf: u32 = if (size == .size64) 1 else 0;
    const encoding: u32 =
        (sf << 31) |           // 64-bit vs 32-bit
        (0b0001011 << 24) |    // ADD opcode
        (encodeReg(src2) << 16) |
        (encodeReg(src1) << 5) |
        encodeReg(dst);

    try buffer.put4(encoding);
}
```

### 4. ABI (Application Binary Interface)

**File:** `/Users/joel/Work/hoist/src/backends/aarch64/abi.zig`

Implements calling conventions:

```zig
pub const ABI = struct {
    // Argument registers: X0-X7
    const ARG_REGS = [_]PReg{
        .x0, .x1, .x2, .x3, .x4, .x5, .x6, .x7,
    };

    // Return register: X0
    const RET_REG = PReg.x0;

    // Callee-saved registers: X19-X28
    const CALLEE_SAVED = [_]PReg{
        .x19, .x20, .x21, .x22, .x23,
        .x24, .x25, .x26, .x27, .x28,
    };

    pub fn lowerCall(
        ctx: *LowerCtx,
        callee: FuncRef,
        args: []Value,
    ) !VReg {
        // Place arguments in correct registers/stack
        for (args, 0..) |arg, i| {
            if (i < ARG_REGS.len) {
                // Argument goes in register
                const arg_reg = try ctx.valueOf(arg);
                try ctx.emit(.{
                    .mov_rr = .{
                        .dst = ARG_REGS[i],
                        .src = arg_reg,
                    },
                });
            } else {
                // Argument goes on stack
                try emitStackArg(ctx, arg, i - ARG_REGS.len);
            }
        }

        // Emit call
        try ctx.emit(.{ .bl = .{ .callee = callee } });

        // Return value is in X0
        return RET_REG;
    }
}
```

## ISA Features

Modern CPUs have optional instruction set extensions.

**File:** `/Users/joel/Work/hoist/src/backends/aarch64/isa.zig`

```zig
pub const ISAFeatures = struct {
    /// LSE (Large System Extensions) - atomic instructions
    lse: bool = false,

    /// NEON - SIMD instructions
    neon: bool = true,

    /// SVE (Scalable Vector Extension)
    sve: bool = false,

    /// Feature detection
    pub fn detect() ISAFeatures {
        // Query CPU capabilities
        return .{
            .lse = detectLSE(),
            .neon = true,  // Always available on ARMv8
            .sve = detectSVE(),
        };
    }
}
```

### LSE Atomics Example

**With LSE:**
```asm
LDADD X0, X1, [X2]    ; Atomic add in one instruction
```

**Without LSE (LL/SC loop):**
```asm
.retry:
    LDXR X1, [X2]         ; Load exclusive
    ADD X1, X1, X0        ; Perform addition
    STXR W3, X1, [X2]     ; Store exclusive
    CBNZ W3, .retry       ; Retry if failed
```

The backend chooses based on ISA features!

## Instruction Selection Trade-offs

Different instruction choices have different costs:

### Example: Loading Constant

**Small constant (fits in 12 bits):**
```asm
MOV W0, #42            ; 1 instruction
```

**Medium constant (fits in 16 bits):**
```asm
MOVZ W0, #12345        ; 1 instruction
```

**Large constant (32 bits):**
```asm
MOVZ W0, #0x1234       ; Low 16 bits
MOVK W0, #0x5678, LSL #16  ; High 16 bits (2 instructions total)
```

**Very large constant (64 bits):**
```asm
MOVZ X0, #0x0001       ; Bits [0:15]
MOVK X0, #0x0002, LSL #16  ; Bits [16:31]
MOVK X0, #0x0003, LSL #32  ; Bits [32:47]
MOVK X0, #0x0004, LSL #48  ; Bits [48:63] (4 instructions!)
```

Or load from memory:
```asm
LDR X0, .const_pool    ; 1 load + data in pool
```

The backend chooses the best approach!

## Addressing Modes

ARM64 has many ways to compute addresses:

```asm
; Base + offset
LDR X0, [X1, #16]

; Base + register
LDR X0, [X1, X2]

; Base + scaled register
LDR X0, [X1, X2, LSL #3]   ; X1 + (X2 << 3)

; Base + extended register
LDR X0, [X1, W2, SXTW #3]  ; X1 + sign_extend(W2) << 3

; Pre-index (update pointer before load)
LDR X0, [X1, #16]!

; Post-index (update pointer after load)
LDR X0, [X1], #16
```

ISLE rules match these patterns from IR.

## Operand Encoding

ARM64 instructions have constraints on immediate values:

### Logical Immediates

For AND/ORR/EOR, immediates must be "bitmask immediates":
- Pattern of repeating bits
- Examples: 0xFF, 0xFFFF, 0x00FF00FF, 0xAAAAAAAA

**Valid:**
```asm
AND X0, X1, #0xFF      ; OK
AND X0, X1, #0xAAAA    ; OK
```

**Invalid:**
```asm
AND X0, X1, #0x123     ; ERROR: not a valid bitmask
```

**Solution:** Load into register first:
```asm
MOV X2, #0x123
AND X0, X1, X2
```

The backend handles this automatically!

**File:** `/Users/joel/Work/hoist/src/backends/aarch64/encoding.zig`

## Floating-Point Operations

ARM64 has separate float instructions:

```zig
// Integer add
add_rr: struct {
    dst: WritableReg,  // W/X register
    src1: Reg,
    src2: Reg,
}

// Float add
fadd: struct {
    dst: WritableReg,  // V/D/S register
    src1: Reg,
    src2: Reg,
    size: FPSize,      // 32-bit or 64-bit
}
```

**File:** `/Users/joel/Work/hoist/src/backends/aarch64/inst.zig:200+`

## SIMD/Vector Operations

ARM64 NEON provides vector instructions:

```asm
; Add 4 x 32-bit integers in parallel
ADD V0.4S, V1.4S, V2.4S
; V0[0] = V1[0] + V2[0]
; V0[1] = V1[1] + V2[1]
; V0[2] = V1[2] + V2[2]
; V0[3] = V1[3] + V2[3]
```

Lowering from IR vector types:
```zig
(rule (lower (iadd (I32X4) x y))
      (aarch64_vadd_4s x y))
```

## Prologue and Epilogue

Every function needs setup/cleanup code.

### Standard ARM64 Prologue

```asm
function_entry:
    ; Save frame pointer and link register
    STP X29, X30, [SP, #-16]!

    ; Set up frame pointer
    MOV X29, SP

    ; Allocate stack space (if needed)
    SUB SP, SP, #64

    ; Save callee-saved registers (if used)
    STP X19, X20, [SP, #16]
    STP X21, X22, [SP, #32]
```

### Standard ARM64 Epilogue

```asm
function_exit:
    ; Restore callee-saved registers
    LDP X21, X22, [SP, #32]
    LDP X19, X20, [SP, #16]

    ; Deallocate stack
    MOV SP, X29

    ; Restore frame pointer and return
    LDP X29, X30, [SP], #16
    RET
```

**File:** Implementation TBD in `/Users/joel/Work/hoist/src/codegen/compile.zig:509`

## Stack Layout

```
High addresses
┌──────────────────────┐
│ Caller's frame       │
├──────────────────────┤ ← SP before call
│ Return address (LR)  │
├──────────────────────┤
│ Frame pointer (X29)  │
├──────────────────────┤ ← X29 (current FP)
│ Saved registers      │
│ (X19-X28 if used)    │
├──────────────────────┤
│ Local variables      │
├──────────────────────┤
│ Spill slots          │
├──────────────────────┤
│ Outgoing args        │
│ (if >8 args)         │
└──────────────────────┘ ← SP (current)
Low addresses
```

## Relocation Types

When calling external functions or accessing globals:

```zig
// Call external function
BL external_func
// Needs R_AARCH64_CALL26 relocation

// Load global address
ADRP X0, global_var
ADD X0, X0, :lo12:global_var
// Needs:
//   R_AARCH64_ADR_PREL_PG_HI21 (ADRP)
//   R_AARCH64_ADD_ABS_LO12_NC (ADD)
```

**File:** `/Users/joel/Work/hoist/src/machinst/buffer.zig`

## Multi-Backend Strategy

Supporting multiple backends:

```
src/backends/
├── aarch64/
│   ├── lower.isle
│   ├── isle_helpers.zig
│   ├── emit.zig
│   ├── abi.zig
│   └── inst.zig
├── x64/
│   ├── lower.isle
│   ├── isle_helpers.zig
│   ├── emit.zig
│   ├── abi.zig
│   └── inst.zig
└── riscv64/  (future)
    └── ...
```

Each backend implements the same interface:
```zig
pub const Backend = struct {
    pub fn lower(ctx: *LowerCtx) !VCode
    pub fn emit(vcode: *VCode, buffer: *MachBuffer) !void
}
```

## Key Insights

1. **Backends are self-contained**: Each has ISLE + helpers + encoding + ABI

2. **ISLE provides flexibility**: Adding instruction patterns is declarative

3. **ISA features matter**: LSE atomics vs LL/SC loops = huge performance difference

4. **ABI compliance is critical**: Wrong calling convention = crashes

5. **Encoding is complex**: Immediate constraints, addressing modes, etc.

6. **Multiple backends share IR**: Same IR → different targets

Next: **07-type-system.md** (how types work in Hoist)
