# Atomics and Memory Operations

## What are Atomics?

Imagine two people trying to update a shared counter at the same time. Without coordination:

```
Person A reads: 5
Person B reads: 5
Person A writes: 6 (5 + 1)
Person B writes: 6 (5 + 1)
Result: 6 (should be 7!)
```

**Atomic operations** ensure updates happen indivisibly - no interference possible.

## Memory Ordering

**File:** `/Users/joel/Work/hoist/src/ir/atomics.zig`

### The Problem: Reordering

CPUs and compilers reorder operations for performance:

```
Original code:
  data = 42;
  flag = true;

Might execute as:
  flag = true;    ← reordered!
  data = 42;
```

If another thread checks `flag`, it might see garbage in `data`!

### Memory Orderings

```zig
pub const AtomicOrdering = enum {
    unordered,     // No ordering (just atomicity)
    monotonic,     // No synchronization, just atomic
    acquire,       // Synchronizes with release
    release,       // Synchronizes with acquire
    acq_rel,       // Both acquire and release
    seq_cst,       // Sequentially consistent (strongest)
}
```

**File:** `/Users/joel/Work/hoist/src/ir/atomics.zig:6`

### Ordering Guarantees

**Unordered:**
```
Atomic, but can reorder freely with other operations
Use case: Rare, mainly for lock-free counters
```

**Monotonic:**
```
Atomic, prevents tearing, but no synchronization
Use case: Increment/decrement counters (when you don't care about order)
```

**Acquire:**
```
Prevents hoisting of loads/stores after this operation
Use case: Lock acquisition, reading from queue
Example: lock.acquire() - operations after can't move before
```

**Release:**
```
Prevents sinking of loads/stores before this operation
Use case: Lock release, publishing to queue
Example: lock.release() - operations before can't move after
```

**Acquire-Release:**
```
Both acquire and release semantics
Use case: Read-modify-write operations (compare-and-swap)
```

**Sequential Consistency:**
```
Total global ordering - all threads see same order
Strongest, slowest
Use case: When you need simplest reasoning (default choice)
```

## Atomic Operations

**File:** `/Users/joel/Work/hoist/src/ir/atomics.zig:59`

```zig
pub const AtomicRmwOp = enum {
    xchg,    // Exchange (swap)
    add,     // Atomic add
    sub,     // Atomic subtract
    and,     // Atomic AND
    nand,    // Atomic NAND
    or,      // Atomic OR
    xor,     // Atomic XOR
    max,     // Atomic max (signed)
    min,     // Atomic min (signed)
    umax,    // Atomic max (unsigned)
    umin,    // Atomic min (unsigned)
}
```

### Example: Atomic Increment

**IR:**
```
v_addr = ...                              ; Address of counter
v_one = iconst.i32 1
v_old = atomic_rmw.add.acq_rel v_addr, v_one
; v_old = previous value, memory now has v_old + 1
```

### ARM64 Implementation

**With LSE (single instruction):**
```asm
LDADD X0, X1, [X2]
; Atomic: tmp = [X2]; [X2] += X0; X1 = tmp
```

**Without LSE (LL/SC loop):**
```asm
.retry:
    LDAXR X1, [X2]          ; Load-acquire exclusive
    ADD X3, X1, X0          ; Compute new value
    STLXR W4, X3, [X2]      ; Store-release exclusive
    CBNZ W4, .retry         ; Retry if failed
```

**File:** `/Users/joel/Work/hoist/src/backends/aarch64/lower.isle` (atomic rules)

## Compare-And-Swap (CAS)

The fundamental synchronization primitive:

```
bool compare_and_swap(addr, expected, new) {
    atomic {
        if (*addr == expected) {
            *addr = new;
            return true;
        }
        return false;
    }
}
```

**IR:**
```
v_addr = ...
v_expected = iconst.i64 0
v_new = iconst.i64 1
v_success, v_old = atomic_cas.acq_rel v_addr, v_expected, v_new
; v_success = true if swap succeeded
; v_old = value that was at v_addr
```

**ARM64 (LL/SC):**
```asm
.retry:
    LDAXR X3, [X0]          ; Load old value
    CMP X3, X1              ; Compare with expected
    B.NE .fail              ; If not equal, fail
    STLXR W4, X2, [X0]      ; Try to store new value
    CBNZ W4, .retry         ; Retry if store failed
    MOV X5, #1              ; Success
    B .done
.fail:
    CLREX                   ; Clear exclusive monitor
    MOV X5, #0              ; Failure
.done:
```

**With LSE:**
```asm
CAS X1, X2, [X0]    ; One instruction!
```

## Memory Fences

Explicit synchronization points:

```zig
fence.acquire    ; Acquire barrier
fence.release    ; Release barrier
fence.acq_rel    ; Full barrier
fence.seq_cst    ; Sequentially consistent barrier
```

**ARM64:**
```asm
DMB ISH      ; Data Memory Barrier (Inner Shareable)
DMB ISHLD    ; Load barrier
DMB ISHST    ; Store barrier
```

**Use case: Publish/subscribe pattern:**
```
Thread A (publisher):
  data = 42;
  fence.release;    ; Ensure data written before flag
  flag = true;

Thread B (subscriber):
  while (!flag);
  fence.acquire;    ; Ensure flag read before data
  print(data);      ; Guaranteed to see 42
```

## Load/Store Operations

### Normal Loads/Stores

```
v0 = load.i32 v_addr        ; Regular load
store.i32 v_addr, v0        ; Regular store
```

No atomicity guarantees! May tear on unaligned accesses.

### Atomic Loads/Stores

```
v0 = atomic_load.acquire.i32 v_addr
atomic_store.release.i32 v_addr, v0
```

Guarantees:
- Atomic (no tearing)
- Ordering constraints
- Properly aligned

**ARM64:**
```asm
; Atomic load with acquire
LDAR W0, [X1]

; Atomic store with release
STLR W0, [X1]
```

## Alignment Requirements

Atomic operations require natural alignment:

```
I8:   1-byte aligned
I16:  2-byte aligned
I32:  4-byte aligned
I64:  8-byte aligned
I128: 16-byte aligned
```

**Unaligned atomics → undefined behavior!**

Verifier checks alignment constraints.

## Lock-Free Data Structures

Using atomics to build concurrent structures:

### Lock-Free Stack

```
struct Stack {
    head: atomic<*Node>,
}

push(stack, node):
    loop:
        old_head = atomic_load.acquire(&stack.head)
        node.next = old_head
        fence.release
        if atomic_cas.acq_rel(&stack.head, old_head, node):
            break

pop(stack):
    loop:
        old_head = atomic_load.acquire(&stack.head)
        if old_head == null:
            return null
        new_head = old_head.next
        if atomic_cas.acq_rel(&stack.head, old_head, new_head):
            return old_head
```

### Spinlock

```
struct Spinlock {
    locked: atomic<bool>,
}

acquire(lock):
    expected = false
    while !atomic_cas.acq_rel(&lock.locked, expected, true):
        expected = false  ; Reset for retry

release(lock):
    atomic_store.release(&lock.locked, false)
```

## Memory Models

### C++11/LLVM Memory Model

Hoist follows the C++11/LLVM memory model:

**Happens-Before Relationship:**
```
If A synchronizes-with B:
    All operations before A happen-before all operations after B

Synchronizes-with:
    Release store synchronizes-with matching acquire load
```

**Example:**
```
Thread A:
    data = 42;           (1)
    atomic_store.release(&flag, true);  (2)

Thread B:
    while (!atomic_load.acquire(&flag));  (3)
    print(data);  (4)

Happens-before chain:
    (1) → (2) → (3) → (4)
Therefore: Thread B guaranteed to see data = 42
```

## ARM64 Memory Model

ARM64 has a **weakly-ordered** memory model:

**Without barriers:**
- Loads can be reordered with loads
- Stores can be reordered with stores
- Stores can be reordered with earlier loads
- Different processors may see different orders

**Barriers enforce order:**
```asm
; Full barrier
DMB ISH

; Load barrier (acquire)
DMB ISHLD

; Store barrier (release)
DMB ISHST
```

## LSE (Large System Extensions)

ARM64 v8.1+ added atomic instructions:

```asm
; Atomic operations
LDADD    ; Atomic add
LDCLR    ; Atomic clear (AND NOT)
LDSET    ; Atomic set (OR)
LDEOR    ; Atomic XOR

; With variants:
LDADDA   ; Acquire
LDADDL   ; Release
LDADDAL  ; Acquire-release

; CAS variants
CAS      ; Compare-and-swap
CASA     ; Acquire
CASL     ; Release
CASAL    ; Acquire-release
```

**Without LSE:** Fall back to LL/SC loops (slower, more code)

**Detection:**
```zig
const has_lse = ISAFeatures.detect().lse;

if (has_lse) {
    // Use LDADD
} else {
    // Use LDAXR/STLXR loop
}
```

**File:** `/Users/joel/Work/hoist/src/backends/aarch64/isa.zig`

## Verification

The verifier checks:

1. **Alignment:** Atomic operations properly aligned
2. **Ordering validity:** Acquire/release used correctly
3. **Type sizes:** Atomic types are supported sizes (I8, I16, I32, I64)
4. **Address validity:** Atomic operations use valid addresses

**File:** `/Users/joel/Work/hoist/src/ir/verifier.zig`

## Performance Considerations

**Costs (approximate, ARM64):**
```
Regular load/store:          ~1 cycle
Atomic load/store (LDAR/STLR): ~4 cycles
Atomic RMW (LSE):              ~10-20 cycles
Atomic RMW (LL/SC):            ~20-100 cycles (depends on contention)
Fence (DMB):                   ~10-20 cycles
```

**Guidelines:**
- Use weakest ordering sufficient (monotonic > acquire/release > seq_cst)
- Prefer LSE when available
- Avoid unnecessary barriers
- Batch updates when possible

## Common Patterns

### Lazy Initialization

```
static initialized: atomic<bool> = false;
static data: Data;

get_data():
    if !atomic_load.acquire(&initialized):
        lock.acquire()
        if !initialized:  ; Double-checked locking
            data = initialize();
            atomic_store.release(&initialized, true)
        lock.release()
    return data
```

### Reference Counting

```
incref(obj):
    atomic_rmw.add.monotonic(&obj.refcount, 1)

decref(obj):
    old = atomic_rmw.sub.acq_rel(&obj.refcount, 1)
    if old == 1:
        destroy(obj)  ; We just released last reference
```

### Ring Buffer

```
struct RingBuffer {
    head: atomic<u64>,  ; Producer index
    tail: atomic<u64>,  ; Consumer index
    data: [SIZE]T,
}

push(ring, value):
    head = atomic_load.acquire(&ring.head)
    tail = atomic_load.acquire(&ring.tail)
    if head - tail >= SIZE:
        return false  ; Full
    ring.data[head % SIZE] = value
    fence.release
    atomic_store.release(&ring.head, head + 1)
    return true

pop(ring):
    tail = atomic_load.acquire(&ring.tail)
    head = atomic_load.acquire(&ring.head)
    if tail == head:
        return null  ; Empty
    value = ring.data[tail % SIZE]
    fence.release
    atomic_store.release(&ring.tail, tail + 1)
    return value
```

## Key Insights

1. **Atomics ≠ Locks**: Atomics are primitives for building lock-free structures

2. **Memory ordering matters**: Wrong ordering = data races

3. **Acquire/Release pairing**: Release on write, acquire on read

4. **LSE is huge**: 10x faster than LL/SC loops

5. **Seq-cst is expensive**: Use weaker orderings when safe

6. **Alignment is critical**: Unaligned atomics = undefined behavior

Next: **09-algorithms.md** (the clever algorithms that power everything)
