# Key Algorithms

## Introduction

Compilers use clever algorithms to analyze and transform code efficiently. This document explains the algorithms that power Hoist's optimization and analysis passes.

Think of these as the "recipes" the compiler follows - proven techniques that work reliably and efficiently.

## 1. Dominator Tree Computation (Semi-NCA)

**File:** `/Users/joel/Work/hoist/src/ir/domtree.zig:42`

### The Problem

Given a control flow graph, find which blocks dominate which others. Block A dominates block B if every path from entry to B goes through A.

### The Algorithm: Cooper-Harvey-Kennedy

**Simple, fast dominance algorithm using iterative data flow:**

```
1. Set idom(entry) = none
2. For all other blocks, set idom(block) = none
3. Repeat until no changes:
     For each block B (except entry):
       new_idom = none
       For each predecessor P of B:
         if idom(P) is defined:
           if new_idom is none:
             new_idom = P
           else:
             new_idom = intersect(new_idom, P)
       if idom(B) ≠ new_idom:
         idom(B) = new_idom
         changed = true

intersect(b1, b2):
  while b1 ≠ b2:
    if b1 is deeper than b2:
      b1 = idom(b1)
    else:
      b2 = idom(b2)
  return b1
```

**Complexity:** O(N × E) where N = blocks, E = edges. In practice, converges in 2-4 iterations.

**Example:**
```
CFG:
  entry → A → B → exit
           ↓
           C → exit

Iteration 1:
  idom(A) = entry
  idom(B) = A
  idom(C) = A
  idom(exit) = intersect(B, C) = A

Iteration 2:
  No changes → converged!

Dominator tree:
      entry
        |
        A
       /|\
      B C exit
```

### Why It Works

The dominator of a block B is the intersection of dominators of all predecessors. By iterating until convergence, we find the fixed point.

**Key insight:** Intersection finds the closest common dominator.

## 2. Natural Loop Detection

**File:** `/Users/joel/Work/hoist/src/ir/loops.zig:86`

### The Problem

Identify loops in the CFG for loop optimizations (LICM, unrolling, etc.).

### The Algorithm: Back Edge Detection

**A natural loop has a back edge (edge to dominator):**

```
1. Compute dominator tree
2. Find all back edges:
     For each edge B → H:
       if H dominates B:
         H is loop header
         B is back edge source

3. For each back edge (B → H):
     Loop blocks = { H }
     Worklist = { B }

     While worklist not empty:
       N = pop(worklist)
       if N not in loop blocks:
         add N to loop blocks
         for each predecessor P of N:
           if H dominates P:
             add P to worklist
```

**Complexity:** O(N + E) for finding back edges, O(N × E) worst case for finding loop blocks.

**Example:**
```
CFG:
  entry → header → body → header
                      ↓
                    exit

Back edge: body → header (header dominates body)

Loop blocks:
  Start: { header }
  Add body (predecessor of back edge source)
  No more predecessors in header's dominance
  Result: { header, body }
```

### Nested Loops

```
outer_header → inner_header → inner_body → inner_header
                   ↓                           ↓
              outer_body → outer_header

Two back edges:
  inner_body → inner_header (inner loop)
  outer_body → outer_header (outer loop)

Inner loop: { inner_header, inner_body }
Outer loop: { outer_header, inner_header, inner_body, outer_body }
```

Loop nesting detected by containment.

## 3. Global Value Numbering (GVN)

**File:** `/Users/joel/Work/hoist/src/codegen/opts/gvn.zig:24`

### The Problem

Detect redundant computations:
```
v0 = iadd v1, v2
v3 = iadd v1, v2    ← same computation
```

### The Algorithm: Hash-Based Deduplication

**Use hash table to track instruction patterns:**

```
InstPattern = (opcode, operands)

1. value_numbers = HashMap<InstPattern, Value>

2. For each instruction I in order:
     pattern = (I.opcode, I.operands)
     hash = hash(pattern)

     if value_numbers.contains(hash):
       canonical = value_numbers[hash]
       result(I) = alias(canonical)  ; Reuse existing
     else:
       value_numbers[hash] = result(I)  ; Remember this one
```

**Complexity:** O(N) for N instructions (hash table lookup is O(1) average).

**Example:**
```
v0 = iadd v1, v2
  pattern = (iadd, [v1, v2])
  hash = H1
  value_numbers[H1] = v0

v3 = iadd v1, v2
  pattern = (iadd, [v1, v2])
  hash = H1
  found! v3 = alias(v0)

v4 = imul v0, v3
  becomes: v4 = imul v0, v0
```

### Hash Function

```zig
fn hash(pattern: InstPattern) u64 {
    var hasher = std.hash.Wyhash.init(0);
    hasher.update(&pattern.opcode);
    for (pattern.args) |arg| {
        hasher.update(&arg);
    }
    return hasher.final();
}
```

**Why Wyhash?** Fast, good distribution, minimal collisions.

## 4. Dead Code Elimination (Backward Reachability)

**File:** `/Users/joel/Work/hoist/src/codegen/opts/dce.zig`

### The Problem

Remove instructions whose results are never used.

### The Algorithm: Mark-Sweep

**Backwards marking from live roots:**

```
1. live_insts = {}
   live_values = {}

2. For each instruction I:
     if hasSideEffects(I):  ; stores, calls, returns
       markLive(I)

markLive(I):
  if I in live_insts:
    return
  live_insts.add(I)
  for each operand V of I:
    markValueLive(V)

markValueLive(V):
  if V in live_values:
    return
  live_values.add(V)
  I = definingInst(V)
  markLive(I)

3. For each instruction I:
     if I not in live_insts:
       remove(I)
```

**Complexity:** O(N) for N instructions (each visited once).

**Example:**
```
v0 = iconst 10      ← DEAD (v0 never used)
v1 = iconst 20
v2 = iadd v1, v1
return v2           ← Root (side effect)

Marking:
  return v2 → mark return (has side effect)
  return uses v2 → markValueLive(v2)
  v2 defined by iadd → mark iadd
  iadd uses v1 → markValueLive(v1)
  v1 defined by iconst → mark iconst

Not marked: v0 = iconst 10 → remove!
```

## 5. Loop-Invariant Code Motion (Fixed-Point Iteration)

**File:** `/Users/joel/Work/hoist/src/codegen/opts/licm.zig:79`

### The Problem

Find computations that don't change in a loop and hoist them out.

### The Algorithm: Fixed-Point Marking

**Iteratively mark invariants until convergence:**

```
1. invariants = {}

2. For each value V defined outside loop:
     invariants.add(V)

3. changed = true
   While changed:
     changed = false
     For each instruction I in loop:
       if allOperandsInvariant(I):
         if I not in invariants:
           invariants.add(I)
           changed = true

allOperandsInvariant(I):
  for each operand V of I:
    if V not in invariants:
      return false
  return true

4. For each invariant instruction I:
     if canHoist(I):
       move I to preheader
```

**Complexity:** O(N × I) where N = instructions in loop, I = iterations to converge (usually 2-4).

**Example:**
```
preheader:
  v0 = iconst 100    ← defined outside loop

loop_header(v1):
  v2 = iadd v1, v0   ← uses v0 (invariant) and v1 (not invariant)
  v3 = imul v0, v0   ← uses only v0 (invariant)
  ...

Iteration 1:
  invariants = { v0 }  (defined outside)

Iteration 2:
  v3 = imul v0, v0 → all operands invariant
  invariants = { v0, v3 }

Iteration 3:
  v2 = iadd v1, v0 → v1 not invariant, skip
  No new invariants → converged

Hoist v3 to preheader:
  v3 = imul v0, v0 only computed once!
```

### Safety Check

Can only hoist if:
- No side effects (pure computation)
- Dominates all loop exits (or speculation-safe)
- Won't cause exceptions (division by zero, etc.)

## 6. Register Allocation (Linear Scan)

**File:** `/Users/joel/Work/hoist/src/machinst/regalloc2/`

### The Problem

Assign N virtual registers to K physical registers (N >> K).

### The Algorithm: Linear Scan

**Process live ranges in order:**

```
1. Compute live ranges for each VReg:
     LiveRange = (start_point, end_point)

2. Sort live ranges by start point

3. active = {}  ; Currently active live ranges
   free_regs = [all physical registers]

4. For each live range R:
     ; Expire old ranges
     For each A in active:
       if A.end < R.start:
         free_regs.add(A.preg)
         active.remove(A)

     ; Allocate register
     if free_regs is empty:
       spill = choose_spill(active)
       free_regs.add(spill.preg)
       active.remove(spill)
       emit_spill(spill)

     R.preg = free_regs.pop()
     active.add(R)

choose_spill(active):
  ; Spill the range ending furthest in future
  return max(active, key=lambda R: R.end)
```

**Complexity:** O(N log N) for sorting + O(N × K) for allocation where K = active ranges.

**Example:**
```
VRegs with live ranges:
  v0: [0, 10]
  v1: [2, 8]
  v2: [5, 15]
  v3: [12, 20]

Registers: X0, X1

Process:
  v0 [0,10]: allocate X0
  v1 [2,8]:  allocate X1
  v2 [5,15]: X0 and X1 busy → spill v1 (ends earliest)
             allocate X1 for v2
  v3 [12,20]: v0 expired, allocate X0

Result:
  v0 → X0
  v1 → spilled
  v2 → X1
  v3 → X0 (reuses v0's register)
```

### Why Linear Scan?

**Pros:** Fast (O(N log N)), predictable, good for JIT compilers

**Cons:** Not optimal quality (graph coloring is better but slower)

**regalloc2 improves this:** Hybrid approach with local graph coloring.

## 7. Constant Propagation (Worklist Algorithm)

**Not yet implemented, but standard algorithm:**

### The Problem

Replace variables with their constant values:
```
v0 = iconst 10
v1 = iadd v0, 5    → v1 = iconst 15
```

### The Algorithm: Sparse Conditional Constant Propagation

```
1. lattice = HashMap<Value, Lattice>
   Lattice = TOP | CONST(val) | BOTTOM

2. worklist = all instructions
   For each value V:
     lattice[V] = TOP

3. While worklist not empty:
     I = worklist.pop()

     ; Evaluate instruction
     result = evaluate(I, lattice)

     ; Update lattice
     if lattice[result(I)] ≠ result:
       lattice[result(I)] = meet(lattice[result(I)], result)
       ; Add users to worklist
       for each use U of result(I):
         worklist.add(U)

evaluate(I, lattice):
  if any operand is TOP: return TOP
  if any operand is BOTTOM: return BOTTOM
  if all operands CONST: return CONST(compute(I))
  return BOTTOM

meet(a, b):
  if a == TOP: return b
  if b == TOP: return a
  if a == b: return a
  return BOTTOM
```

**Complexity:** O(N) for N instructions (each processed at most 3 times: TOP → CONST → BOTTOM).

## 8. SSA Construction (Minimal SSA)

**Not covered in current code, but fundamental to IR:**

### The Algorithm: Cytron et al.

**Place φ-functions (block parameters) at dominance frontiers:**

```
1. Compute dominance frontiers:
     DF(B) = {Y : B dominates pred(Y) but not Y}

2. For each variable V:
     For each definition D of V:
       W = block containing D
       For each Y in DF(W):
         if Y doesn't have φ for V:
           insert φ for V at Y
           add Y to worklist if not processed

3. Rename variables:
     Depth-first traversal from entry
     For each block:
       For each φ:
         create new name for result
       For each instruction:
         replace uses with current names
         create new name for definitions
       For each successor S:
         fill in φ arguments
```

**This creates minimal SSA:** Only as many φ-functions as needed.

## 9. Hash Consing (Structural Sharing)

**Used implicitly in value lists:**

### The Problem

Many instructions have the same argument lists. Avoid duplicating them.

### The Algorithm: Hash-Based Deduplication

```
1. pool = HashMap<[Value], Offset>

2. intern(args: [Value]) -> Offset:
     hash = hash(args)
     if pool.contains(hash):
       return pool[hash]
     else:
       offset = storage.append(args)
       pool[hash] = offset
       return offset
```

**Result:** Identical value lists share storage (saves memory, enables fast comparison).

## 10. Worklist Algorithm (Generic Pattern)

**Used in many passes:**

### The Pattern

```
1. worklist = initial_set
   processed = {}

2. While worklist not empty:
     item = worklist.pop()

     if item in processed:
       continue
     processed.add(item)

     result = process(item)

     for each dependent D of result:
       if D not in processed:
         worklist.add(D)
```

**Examples:**
- Reachability: worklist = reachable blocks
- Liveness: worklist = instructions to analyze
- Constant propagation: worklist = instructions to re-evaluate

**Key insight:** Only process each item when its inputs change.

## Key Algorithmic Insights

1. **Fixed-point iteration:** Many analyses iterate until convergence (dominators, invariants)

2. **Worklist algorithms:** Process only what changed, not everything

3. **Hash-based deduplication:** Fast detection of equivalent patterns (GVN, hash consing)

4. **Backward marking:** Dead code elimination works backwards from roots

5. **Linear scan:** Fast register allocation for modern compilers

6. **Dominance is fundamental:** Powers many optimizations (LICM, PRE, etc.)

7. **SSA simplifies analysis:** Each value defined once = easy data flow

8. **Sparse algorithms:** Only process relevant parts (sparse conditional constant prop)

## Complexity Summary

| Algorithm | Complexity | Notes |
|-----------|-----------|-------|
| Dominator tree | O(N × E) | Converges in 2-4 iterations |
| Loop detection | O(N + E) | Per loop: O(N × E) worst case |
| GVN | O(N) | Hash table lookups |
| DCE | O(N) | Backward marking |
| LICM | O(N × I) | I = iterations to converge |
| Linear scan regalloc | O(N log N) | Sorting dominates |
| Constant propagation | O(N) | Sparse worklist |
| SSA construction | O(N + E) | With dominance frontiers |

N = number of instructions/blocks, E = number of edges, I = iterations (typically 2-4)

## Further Reading

- **"A Simple, Fast Dominance Algorithm"** - Cooper, Harvey, Kennedy
- **"Efficiently Computing Static Single Assignment Form"** - Cytron et al.
- **"Linear Scan Register Allocation"** - Poletto, Sarkar
- **"Value Numbering"** - Alpern, Wegman, Zadeck
- **"Loop-Invariant Code Motion"** - Allen, Kennedy

These algorithms are the foundation of modern compiler optimization - proven, efficient, and elegant!
