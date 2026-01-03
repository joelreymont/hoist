# Register Allocation with regalloc2

## The Musical Chairs Problem

Imagine you're organizing a concert with 1000 musicians, but you only have 31 chairs. Musicians need chairs to play their instruments (values need registers to be computed). Your job is to:

1. Assign each musician a chair when they need to play
2. When you run out of chairs, ask someone to stand up temporarily (spill to memory)
3. Make sure musicians don't fight over the same chair at the same time
4. Minimize how often people stand up and sit down (minimize spills)

This is **register allocation**.

## Virtual vs Physical Registers

### Virtual Registers (VRegs)

After ISLE lowering, we have VCode with **virtual registers**:

```
block0:
    MOV v0, #10        ; v0, v1, v2, v3 are virtual
    MOV v1, #20
    ADD v2, v0, v1
    MUL v3, v2, v2
    RET
```

Virtual registers are:
- **Unlimited**: Use as many as you need
- **Symbolic**: Just names, not real hardware
- **Typed**: Each has a register class (.int or .float)

### Physical Registers (PRegs)

ARM64 has **31 general-purpose registers**: X0-X30 (64-bit) or W0-W30 (32-bit view)

```
X0-X7:   Argument/result registers
X8:      Indirect result location
X9-X15:  Temporary registers (caller-saved)
X16-X17: Intra-procedure-call temporaries
X18:     Platform register (varies by OS)
X19-X28: Callee-saved registers
X29:     Frame pointer (FP)
X30:     Link register (LR)
XZR/WZR: Zero register (reads as 0, writes ignored)
```

**Plus 32 SIMD/FP registers**: V0-V31

**File:** `/Users/joel/Work/hoist/src/machinst/reg.zig`

### The Translation

Register allocation transforms:
```
VCode (virtual registers):
    ADD v5, v3, v4

→

VCode (physical registers):
    ADD X5, X3, X4
```

## Why Register Allocation is Hard

### Problem 1: Limited Registers

```zig
// 50 virtual registers
v0 = load(addr)
v1 = load(addr+8)
v2 = load(addr+16)
...
v49 = load(addr+392)
result = sum(v0, v1, v2, ..., v49)

// Only 31 physical registers!
// Must spill some to memory (stack)
```

### Problem 2: Interference

Two values **interfere** if they're both alive at the same time:

```
v0 = iconst 10     ; v0 born
v1 = iconst 20     ; v1 born, v0 still alive
v2 = iadd v0, v1   ; v0 and v1 both needed
                   ; v0, v1 interfere (both alive)
return v2          ; v0, v1 dead
```

If v0 and v1 interfere, they **cannot** share the same physical register.

### Problem 3: Move Coalescing

Unnecessary moves waste instructions:

```
MOV X1, X0      ; Copy X0 to X1
ADD X2, X1, X3  ; Use X1

; Better: use X0 directly
ADD X2, X0, X3
```

**Move coalescing** tries to assign the same register to source and destination of moves, eliminating the move.

### Problem 4: Calling Conventions

Function calls have rules:
- Arguments go in X0-X7
- Return value in X0
- Some registers are **callee-saved** (must restore before returning)
- Some are **caller-saved** (might be clobbered by called functions)

Register allocator must respect these!

## Register Allocation Algorithms

### Naive: Stack Everything

```
Allocate stack slot for every virtual register
Load from stack before use
Store to stack after definition
```

**Problem:** Slow! Every operation becomes 3 instructions (load, compute, store).

### Graph Coloring (Classic)

1. Build **interference graph**: Nodes = VRegs, Edges = interference
2. Try to color graph with K colors (K = number of registers)
3. If successful, colors = physical registers
4. If not, spill some nodes and retry

**Problem:** NP-complete for general graphs. Slow for large functions.

### Linear Scan (Fast)

1. Compute **live ranges** for each VReg (where it's alive)
2. Sort live ranges by start point
3. Scan in order, allocating registers greedily
4. When out of registers, spill the one used furthest in the future

**Pros:** Fast (linear time)

**Cons:** Not optimal allocation quality

### regalloc2 (Best of Both Worlds)

Hoist uses **regalloc2**: A modern register allocator from the Bytecode Alliance.

**Algorithm:** Hybrid approach
- Split program into smaller regions
- Use graph coloring within regions
- Linear scan between regions
- Advanced optimizations: move coalescing, bundle splitting, backtracking

**Benefits:**
- Near-optimal allocation quality
- Fast compilation times
- Production-proven (used in Wasmtime, Spidermonkey)

**File:** `/Users/joel/Work/hoist/src/machinst/regalloc2/`

## Register Classes

ARM64 has two register banks:

```zig
pub const RegClass = enum {
    int,    // X0-X30 (general-purpose)
    float,  // V0-V31 (SIMD/FP)
};
```

**Why separate?** You can't do:
```asm
ADD X0, X1, V2    ; ERROR: can't mix int and float registers
```

Each VReg belongs to a class:
```zig
const v0 = allocVReg(.int);    // v0 will get X register
const v1 = allocVReg(.float);  // v1 will get V register
```

## Live Ranges

A **live range** is the span where a value is alive (from definition to last use):

```
     v0 = iconst 10      ; ← v0 defined (born)
     v1 = iconst 20      ;
     v2 = iadd v0, v1    ; ← v0 last used (dies)
     v3 = imul v1, v1    ; ← v1 last used (dies)
     return v3           ; ← v3 last used (dies)
```

**Live ranges:**
- v0: [inst0, inst2]
- v1: [inst1, inst3]
- v2: [inst2, inst4]
- v3: [inst3, inst4]

**Observation:** v0 and v2 don't overlap → can share same register!

## Spilling: When Registers Run Out

When all registers are occupied, we **spill** a value to the stack:

```
Before (out of registers):
    v0 = ...
    v1 = ...
    ...
    v30 = ...
    v31 = ...   ; no more registers!

After (spill v0):
    v0 = ...
    store v0, [sp, #8]     ; save to stack
    ; (v0's register now free)
    v31 = ...              ; reuse v0's register
    ...
    reload_v0 = load [sp, #8]   ; reload when needed
    use reload_v0
```

**Spill cost:** Extra memory accesses (slow!)

**Heuristic:** Spill the value used **furthest in the future**.

## regalloc2 Interface

### Input: VCode with Operands

Each instruction declares its operands:

```zig
pub const Operand = union(enum) {
    reg_use: VReg,         // Read from register
    reg_def: VReg,         // Write to register
    reg_mod: VReg,         // Read and write
    reg_fixed_use: struct { vreg: VReg, preg: PReg },
    reg_fixed_def: struct { vreg: VReg, preg: PReg },
};
```

**Example:**
```zig
// ADD X0, X1, X2
Inst.add_rr {
    .dst = v0,    // def (write)
    .src1 = v1,   // use (read)
    .src2 = v2,   // use (read)
}

Operands: [
    .{ .reg_def = v0 },
    .{ .reg_use = v1 },
    .{ .reg_use = v2 },
]
```

### Output: Allocation Map

regalloc2 returns:
```zig
Allocation = HashMap(VReg, PReg)

// Example:
{
    v0 → X0,
    v1 → X1,
    v2 → X2,
    v5 → X3,
    ...
}
```

Plus spill instructions to insert.

### Rewriting Instructions

After allocation, rewrite VRegs to PRegs:

```zig
// Before:
ADD v5, v3, v4

// After (v5→X0, v3→X1, v4→X2):
ADD X0, X1, X2
```

**File:** `/Users/joel/Work/hoist/src/backends/aarch64/regalloc_bridge.zig`

## Calling Conventions

### ABI Constraints

ARM64 calling convention (AAPCS64):

**Arguments:**
```
arg0 → X0
arg1 → X1
...
arg7 → X7
arg8+ → stack
```

**Return value:**
```
result → X0
```

**Register preservation:**
```
Caller-saved (volatile):
    X0-X18: Caller must save if needed across calls

Callee-saved (non-volatile):
    X19-X28: Callee must save/restore if used
    X29 (FP), X30 (LR): Callee must save/restore
```

### Fixed Register Constraints

Some instructions require specific registers:

```asm
; ARM64 divide: result always in same register as dividend
SDIV X0, X0, X1    ; X0 = X0 / X1
```

In regalloc2:
```zig
Operand.reg_fixed_def {
    .vreg = v_result,
    .preg = X0,
}
```

Forces v_result to be allocated to X0.

## Move Coalescing

### The Problem

After lowering:
```
v0 = load ...
v1 = v0        ; copy (becomes MOV)
v2 = add v1, v3
```

### The Solution

If v0 and v1 don't interfere after the copy, assign them the same register:

```
v0 → X1
v1 → X1    ; same register!

Result:
load X1, ...
; MOV eliminated!
add X2, X1, X3
```

regalloc2 does this automatically using **affinity hints**.

## Detailed Example

### Input IR

```
function sum(a: i32, b: i32, c: i32) -> i32 {
    block0(v0: i32, v1: i32, v2: i32):
        v3 = iadd v0, v1
        v4 = iadd v3, v2
        return v4
}
```

### After Lowering (VCode with VRegs)

```
block0:
    ; v0, v1, v2 are arguments (X0, X1, X2 by ABI)
    ADD v3, v0, v1    ; v3 = v0 + v1
    ADD v4, v3, v2    ; v4 = v3 + v2
    MOV v_ret, v4     ; return value must be in X0
    RET
```

### Live Ranges

```
v0: [start, inst0]     ; arg, used in inst0
v1: [start, inst0]     ; arg, used in inst0
v2: [start, inst1]     ; arg, used in inst1
v3: [inst0, inst1]     ; defined at inst0, used at inst1
v4: [inst1, inst2]     ; defined at inst1, used at inst2
v_ret: [inst2, end]    ; return value
```

### Register Allocation

```
ABI constraints:
    v0 → X0 (arg0)
    v1 → X1 (arg1)
    v2 → X2 (arg2)
    v_ret → X0 (return value)

Interference:
    v0, v1, v2 all alive at start (interfere)
    v3 interferes with v2 (both alive during inst1)

Allocation:
    v0 → X0 (fixed)
    v1 → X1 (fixed)
    v2 → X2 (fixed)
    v3 → X3 (v0 dead, so can't reuse X0; v1, v2 still alive)
    v4 → X0 (v0, v1, v2 all dead; reuse X0)
    v_ret → X0 (fixed, same as v4 → coalesced!)
```

### After Allocation

```
block0:
    ADD X3, X0, X1    ; v3=X3, v0=X0, v1=X1
    ADD X0, X3, X2    ; v4=X0, v3=X3, v2=X2
    RET               ; return value already in X0
```

**Optimization:** v4 and v_ret both allocated to X0 → MOV eliminated!

## Advanced Topics

### Bundle Splitting

Sometimes a VReg's live range is too long and conflicts with many others. regalloc2 can **split** it:

```
Original:
    v0 = load ...
    ; long gap
    ... 50 instructions ...
    ; finally use v0
    use v0

Split:
    v0 = load ...
    store v0, [sp, #8]    ; spill
    ; v0's register freed for 50 instructions
    ... 50 instructions ...
    v0_reload = load [sp, #8]   ; reload
    use v0_reload
```

### Multi-Value Results

Some instructions produce multiple values:

```asm
; ARM64 division with remainder
; SDIV + MSUB to get quotient and remainder
```

regalloc2 handles this with multi-def operands.

### Pre-Spilling

If we know ahead of time that we'll run out of registers, **pre-spill** rarely-used values:

```
Heuristic: Spill values used far from their definition
```

### Parallel Moves

At block boundaries with parameters, we might need to move multiple values:

```
block0:
    v0 = ...
    v1 = ...
    jump block1(v1, v0)    ; pass v1, v0 (swapped)

block1(v2, v3):
    ; Need: v2=v1, v3=v0
```

If v1→X0, v0→X1, we need:
```
; Move X0→v2, X1→v3
; But registers might overlap!
```

regalloc2 generates **parallel move sequences** (including temporaries if needed).

## Spill Slot Allocation

Spilled values need stack slots:

```
Stack layout:
    [sp + 0]:   spill slot 0
    [sp + 8]:   spill slot 1
    [sp + 16]:  spill slot 2
    ...
```

**Optimization:** Reuse spill slots for non-overlapping live ranges!

```
v0 spilled to [sp+0]    ; v0 live [0, 10]
v5 spilled to [sp+0]    ; v5 live [20, 30]  (ok, no overlap)
```

## Verification

After allocation, verify:
1. No VRegs remain (all replaced with PRegs)
2. No two interfering values share a register
3. All fixed constraints satisfied
4. Callee-saved registers properly saved/restored

**File:** `/Users/joel/Work/hoist/src/ir/verifier.zig`

## Performance Impact

**Good allocation:**
- Few spills (memory fast)
- Good register reuse (fewer moves)
- Respects cache/branch predictor

**Bad allocation:**
- Many spills (memory slow)
- Excessive moves (wasted instructions)
- Poor instruction cache usage

**Typical speedup from optimal allocation:** 20-50% compared to naive!

## ASCII Art: Register Allocation Flow

```
VCode (Virtual Registers)
┌──────────────────────────────────┐
│ block0:                          │
│   ADD v0, v1, v2                 │
│   MUL v3, v0, v0                 │
│   SUB v4, v3, v1                 │
│   RET v4                         │
└──────────────────────────────────┘
          │
          ↓
    regalloc2
┌──────────────────────────────────┐
│ 1. Compute live ranges           │
│    v0: [0, 1]                    │
│    v1: [0, 2]                    │
│    v2: [0, 0]                    │
│    v3: [1, 2]                    │
│    v4: [2, 3]                    │
├──────────────────────────────────┤
│ 2. Build interference graph      │
│    v0 ←→ v1, v2                  │
│    v1 ←→ v0, v2, v3              │
│    v2 ←→ v0, v1                  │
│    v3 ←→ v1                      │
├──────────────────────────────────┤
│ 3. Allocate registers            │
│    v0 → X0                       │
│    v1 → X1                       │
│    v2 → X2                       │
│    v3 → X0 (v0 dead, reuse)      │
│    v4 → X0 (v3 dead, reuse)      │
└──────────────────────────────────┘
          │
          ↓
VCode (Physical Registers)
┌──────────────────────────────────┐
│ block0:                          │
│   ADD X0, X1, X2                 │
│   MUL X0, X0, X0                 │
│   SUB X0, X0, X1                 │
│   RET                            │
└──────────────────────────────────┘
```

## Key Insights

1. **Musical chairs**: Limited registers, unlimited values → must share cleverly

2. **Interference is key**: Can't share registers between simultaneously-live values

3. **Spilling is expensive**: Avoid by smart allocation, but unavoidable sometimes

4. **ABI constraints**: Calling conventions force some allocations

5. **regalloc2 is smart**: Modern algorithm balances speed and quality

6. **Register classes**: Keep int and float registers separate

## Next Steps

- **04-vcode-and-machinst.md**: The instruction representation used by regalloc
- **06-backends.md**: How ABI rules are implemented
- **07-type-system.md**: How types determine register classes

Register allocation is the most complex part of code generation, but regalloc2 handles it for us!
