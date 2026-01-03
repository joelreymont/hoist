# Optimization Passes

## What are Optimization Passes?

Think of optimizations like editing a draft essay. Each pass through improves it in a different way:
- Remove redundant sentences (Dead Code Elimination)
- Combine similar ideas (Common Subexpression Elimination)
- Move repeated phrases out of loops (Loop-Invariant Code Motion)
- Simplify complex expressions (Instruction Combining)

**Goal:** Make code faster/smaller without changing behavior.

## The Optimization Pipeline

**File:** `/Users/joel/Work/hoist/src/codegen/compile.zig:141`

```zig
fn optimize(ctx: *Context, target: *const Target) CodegenError!void {
    // 1. Legalize IR
    try legalize(ctx);
    
    // 2. Compute CFG (Control Flow Graph)
    try ctx.cfg.compute(&ctx.func);
    
    // 3. Compute dominator tree
    if (ctx.func.entryBlock()) |entry| {
        try ctx.domtree.compute(ctx.allocator, entry, &ctx.cfg);
    }
    
    // 4. Eliminate unreachable code
    _ = try eliminateUnreachableCode(ctx);
    
    // 5. Remove constant phis
    _ = try removeConstantPhis(ctx);
    
    // 6. Resolve value aliases
    ctx.func.dfg.resolveAllAliases();
}
```

## CFG (Control Flow Graph)

**File:** `/Users/joel/Work/hoist/src/ir/cfg.zig`

### What It Does

Maps which blocks can jump to which:

```
block0:
    br_if v0, block1, block2

block1:
    jump block3

block2:
    jump block3

block3:
    return
```

**CFG:**
```
Successors:
  block0 → [block1, block2]
  block1 → [block3]
  block2 → [block3]
  block3 → []

Predecessors:
  block0 ← []
  block1 ← [block0]
  block2 ← [block0]
  block3 ← [block1, block2]
```

### Why Needed

Almost every optimization needs to know:
- What blocks lead here? (predecessors)
- Where can this block go? (successors)
- Can this code even be reached?

## Dominator Tree

**File:** `/Users/joel/Work/hoist/src/ir/domtree.zig`

### What is Dominance?

Block A **dominates** block B if every path from entry to B goes through A.

**Example:**
```
entry → A → B → exit
         ↓
         C → exit
```

- entry dominates everything
- A dominates B, C, and itself
- B dominates only itself
- C dominates only itself

### Why Dominance Matters

**Code motion:** Can only move instruction from A to B if A dominates B (guarantees A runs before B).

**Invariant detection:** In loops, values from dominating blocks are loop-invariant.

### Immediate Dominator

Block A's **immediate dominator** (idom) is the closest dominator (besides A itself).

```
entry → A → B → C
         ↓
         D
```

- idom(A) = entry
- idom(B) = A
- idom(C) = B
- idom(D) = A

### Dominator Tree Structure

```
      entry
        |
        A
       / \
      B   D
      |
      C
```

This tree shows the immediate dominator relationships.

### Algorithm: Semi-NCA

Hoist uses the **Semi-NCA** algorithm (Simple, Fast Dominance Algorithm).

**Approach:** Iterative data flow
1. Set entry's idom to none
2. For each block B, idom(B) = intersection of all predecessor idoms
3. Repeat until convergence (no changes)

**File:** `/Users/joel/Work/hoist/src/ir/domtree.zig:42`

## Loop Detection

**File:** `/Users/joel/Work/hoist/src/ir/loops.zig`

### Natural Loops

A **natural loop** has:
- One entry point (loop header)
- At least one back edge (edge to a dominator)

**Example:**
```
block0 (entry):
    jump loop_header

loop_header:
    v1 = phi(v0, v2)
    br_if v1, loop_body, exit

loop_body:
    v2 = iadd v1, v1
    jump loop_header  ← back edge

exit:
    return
```

**Back edge:** loop_body → loop_header (jumps to dominator)

### Finding Loops

**Algorithm:**
1. Find all back edges (edges to dominators)
2. For each back edge from B to H:
   - H is the loop header
   - Find all blocks in loop using worklist:
     - Start with B
     - Add all predecessors dominated by H
     - Continue until no new blocks

**File:** `/Users/joel/Work/hoist/src/ir/loops.zig:86`

### Loop Nesting

Loops can nest:
```
outer_loop:
  inner_loop:
    ...
  end_inner
end_outer
```

Each loop tracks:
- `depth`: Nesting level
- `parent`: Outer loop (if nested)

## Dead Code Elimination (DCE)

**File:** `/Users/joel/Work/hoist/src/codegen/opts/dce.zig`

### The Problem

Code that doesn't affect output wastes time:

```
v0 = iconst 10      ← computed but never used
v1 = iconst 20
v2 = iadd v1, v1
return v2
```

### The Solution

**Backwards marking:**
1. Mark instructions with side effects (stores, calls, returns) as live
2. Mark their operands as live (recursively)
3. Remove unmarked instructions

**Example:**
```
v0 = iconst 10        ← DEAD (never used)
v1 = iconst 20        ← LIVE (used by v2)
v2 = iadd v1, v1      ← LIVE (used by return)
return v2             ← LIVE (side effect)
```

After DCE:
```
v1 = iconst 20
v2 = iadd v1, v1
return v2
```

## Global Value Numbering (GVN)

**File:** `/Users/joel/Work/hoist/src/codegen/opts/gvn.zig`

### The Problem

Redundant computations:
```
v0 = iadd v1, v2
v3 = iadd v1, v2     ← computes same thing as v0
v4 = imul v0, v3
```

### The Solution

**Hash-based deduplication:**
1. Hash each instruction: hash(opcode, operands)
2. If hash seen before, create alias
3. Replace with first occurrence

**Algorithm:**
```
v0 = iadd v1, v2     ; hash("iadd", v1, v2) → store v0
v3 = iadd v1, v2     ; hash("iadd", v1, v2) → found! v3 = alias(v0)
v4 = imul v0, v3     ; becomes: v4 = imul v0, v0
```

After GVN:
```
v0 = iadd v1, v2
v3 = alias v0        ; v3 is just another name for v0
v4 = imul v0, v0
```

### Pattern Hashing

```zig
InstPattern = struct {
    opcode: Opcode,
    args: [4]Value,
    arg_count: u8,
    
    fn hash(self: InstPattern) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(&self.opcode);
        hasher.update(&self.args[0..self.arg_count]);
        return hasher.final();
    }
}
```

## Loop-Invariant Code Motion (LICM)

**File:** `/Users/joel/Work/hoist/src/codegen/opts/licm.zig`

### The Problem

Computations repeated every loop iteration:

```
loop_header:
    v1 = phi(v0, v2)
    v_const = iconst 100      ← constant (doesn't change)
    v_sum = iadd v1, v_const  ← recomputed every iteration
    br_if ...
```

### The Solution

**Hoist loop-invariant code to preheader:**

```
preheader:
    v_const = iconst 100      ← hoisted!
    v_sum_base = ...          ← compute once

loop_header:
    v1 = phi(v0, v2)
    v_sum = iadd v1, v_const  ← v_const invariant
    br_if ...
```

### Invariance Detection

A value is **loop-invariant** if:
- Defined outside the loop, OR
- All operands are loop-invariant

**Algorithm:**
```
1. Mark values defined outside loop as invariant
2. Fixed-point iteration:
   For each instruction in loop:
     If all operands invariant:
       Mark this instruction invariant
3. Repeat until no new invariants found
```

### Safety Requirements

Can only hoist if:
1. No side effects (pure computation)
2. Dominates all loop exits (or is speculation-safe)
3. Target (preheader) dominates the loop

## Constant Propagation & Folding

**Propagation:** Replace variable with its constant value
**Folding:** Evaluate constant expressions at compile time

**Example:**
```
Before:
  v0 = iconst 10
  v1 = iconst 20
  v2 = iadd v0, v1    ; 10 + 20 = 30
  v3 = imul v2, v2    ; 30 * 30 = 900

After:
  v0 = iconst 10
  v1 = iconst 20
  v2 = iconst 30      ; folded
  v3 = iconst 900     ; folded
```

(Not yet implemented in Hoist, but standard optimization)

## Strength Reduction

Replace expensive operations with cheaper ones:

**Multiplication by power of 2:**
```
Before: v1 = imul v0, 8
After:  v1 = ishl v0, 3    ; shift left by 3 (faster)
```

**Division by power of 2:**
```
Before: v1 = udiv v0, 16
After:  v1 = ushr v0, 4    ; shift right by 4 (faster)
```

**File:** `/Users/joel/Work/hoist/src/codegen/opts/strength.zig`

## Peephole Optimizations

Small-scale pattern replacements:

**Example patterns:**
```
AND X0, X0, X0  →  (no-op, remove)
ADD X0, X0, #0  →  (no-op, remove)
MOV X1, X0
MOV X2, X1      →  MOV X2, X0
```

**File:** `/Users/joel/Work/hoist/src/codegen/opts/peephole.zig`

## Copy Propagation

Eliminate unnecessary copies:

```
Before:
  v1 = v0          ; copy
  v2 = iadd v1, v3

After:
  v2 = iadd v0, v3  ; use v0 directly
```

**File:** `/Users/joel/Work/hoist/src/codegen/opts/copyprop.zig`

## Unreachable Code Elimination

Remove blocks unreachable from entry:

```
block0:
    return

block1:          ← unreachable!
    v0 = iconst 10
    return v0
```

After:
```
block0:
    return
```

**Algorithm:** Reachability via DFS/BFS from entry block

**File:** `/Users/joel/Work/hoist/src/codegen/compile.zig:257`

## Branch Simplification

Simplify control flow:

**Constant conditions:**
```
Before:
  br_if true, block1, block2
After:
  jump block1
```

**Empty blocks:**
```
Before:
  jump block_empty
  
block_empty:
  jump block_real
  
After:
  jump block_real
```

**File:** `/Users/joel/Work/hoist/src/codegen/opts/simplifybranch.zig`

## The Optimization Order Matters!

Different orderings produce different results:

**Good order:**
```
1. Inline functions
2. Constant propagation
3. Dead code elimination
4. Loop optimizations (LICM, strength reduction)
5. GVN
6. Final DCE cleanup
```

**Why?** Each pass creates opportunities for others:
- Constant propagation → more constant folding
- Constant folding → more dead code
- LICM → more CSE opportunities
- GVN → more dead code

## E-Graphs (Future)

**E-graph** = Equality graph (future optimization framework)

**Idea:** Represent multiple equivalent forms:
```
(a + b) * c
= a*c + b*c    (distributed)
= c * (a + b)  (commuted)
```

Store all forms, choose best during extraction.

**Status:** Planned but not yet implemented in Hoist

## ASCII Art: Optimization Pipeline

```
IR (after parsing)
┌────────────────────────────┐
│ block0:                    │
│   v0 = iconst 10           │
│   v1 = iconst 10           │  ← duplicate
│   v2 = iadd v0, v1         │
│   v3 = imul v2, v2         │
│   v_dead = iconst 99       │  ← never used
│   return v3                │
└────────────────────────────┘
          │
          ↓ GVN (eliminate duplicates)
┌────────────────────────────┐
│ block0:                    │
│   v0 = iconst 10           │
│   v1 = alias v0            │  ← deduplicated
│   v2 = iadd v0, v0         │
│   v3 = imul v2, v2         │
│   v_dead = iconst 99       │
│   return v3                │
└────────────────────────────┘
          │
          ↓ DCE (remove dead code)
┌────────────────────────────┐
│ block0:                    │
│   v0 = iconst 10           │
│   v2 = iadd v0, v0         │  ← simplified
│   v3 = imul v2, v2         │
│   return v3                │
└────────────────────────────┘
          │
          ↓ Constant Folding
┌────────────────────────────┐
│ block0:                    │
│   v0 = iconst 10           │
│   v2 = iconst 20           │  ← folded 10+10
│   v3 = iconst 400          │  ← folded 20*20
│   return v3                │
└────────────────────────────┘
```

## Key Insights

1. **CFG and domtree are foundational**: Most passes need them

2. **Multiple passes compound**: DCE after GVN finds more dead code

3. **Loop optimizations are powerful**: Moving invariants out of loops = huge speedups

4. **Order matters**: Run passes in sequence that creates opportunities

5. **Fixed-point iteration**: Some analyses (dominators, invariants) iterate until convergence

Next: **06-backends.md** (target-specific code generation)
