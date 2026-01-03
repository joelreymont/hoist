# VCode and Machine Instructions

## What is VCode?

VCode (Virtual Code) is the representation of machine code **before register allocation**.

Think of it like a rough draft of a painting - you have the composition and colors sketched out, but you haven't filled in all the fine details yet (physical registers).

**Key point:** VCode contains target-specific machine instructions with virtual registers.

## VCode vs IR

| IR | VCode |
|---|---|
| Target-independent | Target-specific (ARM64, x86-64, etc.) |
| High-level operations (iadd) | Low-level instructions (ADD X0, X1, X2) |
| Unlimited values | Unlimited **virtual** registers |
| No register concerns | Register classes (.int, .float) |

## VCode Structure

**File:** `/Users/joel/Work/hoist/src/machinst/vcode.zig`

```zig
VCode(Inst) = struct {
    insns: ArrayList(Inst),           // All instructions
    blocks: ArrayList(VCodeBlock),    // Basic blocks
    entry: BlockIndex,                 // Entry block
    succs: ArrayList(BlockIndex),      // Successor edges
    preds: ArrayList(BlockIndex),      // Predecessor edges
    block_params: ArrayList(VReg),    // Block parameters
}
```

### VCodeBlock

```zig
VCodeBlock = struct {
    insn_start: InsnIndex,     // First instruction
    insn_end: InsnIndex,       // Last instruction (exclusive)
    succs: []BlockIndex,       // Successor blocks
    preds: []BlockIndex,       // Predecessor blocks
    params: []VReg,            // Block parameters (phi values)
}
```

**Example:**

```
block0:
    insn[0]: MOV v0, #10
    insn[1]: MOV v1, #20
    insn[2]: ADD v2, v0, v1
    insn[3]: JMP block1

block1:
    insn[4]: MUL v3, v2, v2
    insn[5]: RET v3
```

Stored as:
```
insns: [MOV, MOV, ADD, JMP, MUL, RET]
blocks: [
    VCodeBlock { insn_start: 0, insn_end: 4, succs: [1] },
    VCodeBlock { insn_start: 4, insn_end: 6, succs: [] },
]
```

## Machine Instructions

Each backend defines its instruction set.

**File:** `/Users/joel/Work/hoist/src/backends/aarch64/inst.zig`

### ARM64 Instruction Example

```zig
Inst = union(enum) {
    mov_rr: struct {
        dst: WritableReg,
        src: Reg,
        size: OperandSize,
    },
    add_rr: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        size: OperandSize,
    },
    add_imm: struct {
        dst: WritableReg,
        src: Reg,
        imm: u16,
        size: OperandSize,
    },
    madd: struct {
        dst: WritableReg,
        src1: Reg,
        src2: Reg,
        addend: Reg,
        size: OperandSize,
    },
    // ... 200+ instruction variants
}
```

### Operand Sizes

```zig
OperandSize = enum {
    size32,   // W registers (32-bit)
    size64,   // X registers (64-bit)
}
```

### WritableReg vs Reg

```zig
Reg = union(enum) {
    physical: PReg,    // X0, X1, etc.
    virtual: VReg,     // v0, v1, etc.
};

WritableReg = struct {
    reg: Reg,
    
    pub fn toReg(self: WritableReg) Reg {
        return self.reg;
    }
};
```

**Why separate?** Type safety\! You can't accidentally use a destination register as a source.

## VCode Builder

The VCode builder constructs VCode during lowering.

```zig
VCodeBuilder = struct {
    vcode: VCode(Inst),
    current_block: ?BlockIndex,
    
    pub fn startBlock(self: *VCodeBuilder, params: []VReg) \!BlockIndex
    pub fn addInst(self: *VCodeBuilder, inst: Inst) \!InsnIndex
    pub fn finishBlock(self: *VCodeBuilder, succs: []BlockIndex) \!void
    pub fn finish(self: *VCodeBuilder) \!*VCode(Inst)
}
```

### Building VCode Example

```zig
var builder = VCodeBuilder.init(allocator, &func);

// Create entry block
const block0 = try builder.startBlock(&.{});

// Emit instructions
try builder.addInst(.{ .mov_imm = .{ .dst = v0, .imm = 10, .size = .size32 } });
try builder.addInst(.{ .mov_imm = .{ .dst = v1, .imm = 20, .size = .size32 } });
try builder.addInst(.{ .add_rr = .{ .dst = v2, .src1 = v0.toReg(), .src2 = v1.toReg(), .size = .size32 } });

// Finish block
try builder.finishBlock(&.{});

// Get final VCode
const vcode = try builder.finish();
```

## Labels and Branches

VCode tracks labels for branch targets:

```zig
MachLabel = struct {
    index: u32,
    
    pub fn new(index: u32) MachLabel {
        return .{ .index = index };
    }
}
```

### Branch Instructions

```zig
// Unconditional branch
b: struct {
    label: MachLabel,
},

// Conditional branch
b_cond: struct {
    label: MachLabel,
    cond: CondCode,
},

// Branch and link (call)
bl: struct {
    label: MachLabel,
},
```

**Example:**

```
block0:
    CMP X0, X1
    B.EQ label_equal
    B label_done

block1 (label_equal):
    MOV X2, #42
    
block2 (label_done):
    RET
```

## Emitting Machine Code

After register allocation, VCode gets emitted to bytes.

**File:** `/Users/joel/Work/hoist/src/backends/aarch64/emit.zig`

```zig
pub fn emit(inst: Inst, buffer: *MachBuffer) \!void {
    switch (inst) {
        .add_rr => |i| try emitAddRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .mov_imm => |i| try emitMovImm(i.dst.toReg(), i.imm, i.size, buffer),
        // ...
    }
}
```

### MachBuffer

A buffer that accumulates machine code bytes:

```zig
MachBuffer = struct {
    data: ArrayList(u8),           // Byte stream
    fixups: ArrayList(Fixup),      // Branch fixups
    relocs: ArrayList(Reloc),      // Relocations
    
    pub fn put4(self: *MachBuffer, bytes: u32) \!void
    pub fn addReloc(self: *MachBuffer, offset: u32, kind: RelocKind, symbol: []const u8) \!void
}
```

**File:** `/Users/joel/Work/hoist/src/machinst/buffer.zig`

### Instruction Encoding

Each instruction has a binary format:

```zig
fn emitAddRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *MachBuffer) \!void {
    // ADD encoding: 31-bit opcode + register fields
    const sf: u32 = if (size == .size64) 1 else 0;
    const rd = encodeReg(dst);
    const rn = encodeReg(src1);
    const rm = encodeReg(src2);
    
    const encoding: u32 = (sf << 31) | (0b0001011 << 24) | (rm << 16) | (rn << 5) | rd;
    try buffer.put4(encoding);
}
```

### Example: ADD X0, X1, X2

```
Binary breakdown:
  sf=1 (64-bit)
  opcode=0b0001011 (ADD shifted register)
  rm=2 (X2)
  rn=1 (X1)
  rd=0 (X0)

Encoded: 0x8B020020
  1000 1011 0000 0010 0000 0000 0010 0000
```

## Relocations

When referencing external symbols, we emit **relocations**:

```zig
RelocKind = enum {
    abs8,                        // Absolute 64-bit address
    pcrel4,                      // PC-relative 32-bit
    aarch64_adr_prel_pg_hi21,   // ARM64 ADRP instruction
    aarch64_add_abs_lo12_nc,    // ARM64 ADD low 12 bits
    aarch64_call26,              // ARM64 26-bit branch
}
```

**Example: Loading global address**

```asm
ADRP X0, global_var      ; High 21 bits (page)
ADD X0, X0, :lo12:global_var   ; Low 12 bits (offset in page)
```

Requires two relocations:
1. `ADRP`: R_AARCH64_ADR_PREL_PG_HI21
2. `ADD`: R_AARCH64_ADD_ABS_LO12_NC

## VCode CFG

VCode maintains its own CFG (separate from IR CFG):

```zig
// Compute predecessors from successors
pub fn computePreds(vcode: *VCode) \!void {
    for (vcode.blocks.items) |block| {
        for (block.succs) |succ_idx| {
            // Add this block as predecessor of successor
            try addPred(vcode, succ_idx, block_idx);
        }
    }
}
```

**Why separate CFG?** IR blocks and VCode blocks don't necessarily match 1:1 (some IR blocks might be split/merged during lowering).

## Key Differences: IR vs VCode

| Aspect | IR | VCode |
|---|---|---|
| Abstraction | High-level (iadd) | Low-level (ADD X0, X1, X2) |
| Registers | Values (v0, v1) | VRegs (virtual registers) |
| Target | Independent | Specific (ARM64, x86) |
| CFG | IR blocks | Machine blocks |
| After | Optimization | Register allocation |

## ASCII Art: VCode Flow

```
IR (after optimization)
┌─────────────────────────┐
│ block0(v0, v1):         │
│   v2 = iadd v0, v1      │
│   v3 = imul v2, v2      │
│   return v3             │
└─────────────────────────┘
          │
          │ ISLE Lowering
          ↓
VCode (virtual registers)
┌─────────────────────────┐
│ block0:                 │
│   ADD vreg0, vr1, vr2   │
│   MUL vreg1, vr0, vr0   │
│   RET                   │
└─────────────────────────┘
          │
          │ Register Allocation
          ↓
VCode (physical registers)
┌─────────────────────────┐
│ block0:                 │
│   ADD X0, X1, X2        │
│   MUL X3, X0, X0        │
│   RET                   │
└─────────────────────────┘
          │
          │ Emission
          ↓
Machine Code (bytes)
┌─────────────────────────┐
│ [8B 02 00 20]           │
│ [9B 00 00 83]           │
│ [D6 5F 03 C0]           │
└─────────────────────────┘
```

## Key Insights

1. **VCode bridges IR and machine code**: Target-specific but not yet finalized

2. **Virtual registers enable optimization**: Don't commit to physical registers until necessary

3. **Machine instructions are target-specific**: Each backend defines its own Inst type

4. **MachBuffer accumulates bytes**: Handles encoding, fixups, relocations

5. **Separate CFGs**: IR CFG and VCode CFG serve different purposes

Next: **05-optimization-passes.md** (how IR gets improved before lowering)
