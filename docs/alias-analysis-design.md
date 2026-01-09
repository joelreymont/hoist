# Alias Analysis Design for Hoist

## Overview

Alias analysis enables memory-related optimizations by tracking which memory locations loads and stores may access. This design is based on Cranelift's approach but simplified for Hoist's current needs.

## Goals

1. **Redundant Load Elimination (RLE)** - Remove loads that read values already in SSA registers
2. **Store-to-Load Forwarding** - Replace loads with store data when the store writes the exact location
3. **Foundation for LICM** - Enable hoisting invariant loads out of loops

## Non-Goals (Future Work)

- Dead Store Elimination (DSE) - Complex due to trap handling
- Full inter-procedural analysis - Start with intra-procedural only
- Complex pointer analysis - Start with simple address comparison

## Architecture

### 1. Memory Categories (Alias Regions)

Unlike Cranelift's four categories (heap, table, vmctx, other), we'll start with simpler categories:

```zig
pub const AliasRegion = enum(u8) {
    /// Stack slots (stack_load/stack_store)
    stack,
    /// Heap memory (load/store with unknown base)
    heap,
    /// Global values (global_value accesses)
    global,
    /// Unknown/other memory
    unknown,
};
```

**Rationale**: Hoist doesn't have WebAssembly-specific concepts like tables or vmctx yet.

### 2. Memory Flags

Add optional memory flags to load/store instructions:

```zig
pub const MemFlags = struct {
    /// Which alias region this access belongs to
    alias_region: AliasRegion,
    /// Whether this is a volatile access (prevents optimization)
    volatile: bool = false,
    /// Whether this access is aligned
    aligned: bool = false,
};
```

### 3. Last Store Tracking

Track the last instruction that might have written to each alias region:

```zig
pub const LastStores = struct {
    stack: ?Inst,
    heap: ?Inst,
    global: ?Inst,
    unknown: ?Inst,

    pub fn update(self: *LastStores, inst: Inst, opcode: Opcode, flags: ?MemFlags) void;
    pub fn getLastStore(self: *LastStores, flags: ?MemFlags) ?Inst;
    pub fn meet(self: *LastStores, other: *const LastStores, meet_point: Inst) void;
};
```

### 4. Memory Location Keys

Identify unique memory locations for the memory-values table:

```zig
pub const MemoryLoc = struct {
    /// Last store that affected this alias region
    last_store: ?Inst,
    /// Address SSA value
    address: Value,
    /// Type being accessed
    ty: Type,
    /// Extending opcode for extending loads (uload8, sload16, etc.)
    extending_opcode: ?Opcode,

    // Hash and equality for use in HashMap
    pub fn hash(self: MemoryLoc) u64;
    pub fn eql(a: MemoryLoc, b: MemoryLoc) bool;
};
```

### 5. Alias Analysis Pass

```zig
pub const AliasAnalysis = struct {
    allocator: Allocator,
    /// Dominance tree (borrowed from Function analysis)
    domtree: *const DominatorTree,
    /// Input last-store state for each block
    block_input: AutoHashMap(Block, LastStores),
    /// Memory location → (defining inst, SSA value)
    mem_values: AutoHashMap(MemoryLoc, struct { Inst, Value }),

    pub fn init(allocator: Allocator, domtree: *const DominatorTree) AliasAnalysis;
    pub fn deinit(self: *AliasAnalysis) void;
    pub fn run(self: *AliasAnalysis, func: *Function) !bool;
};
```

## Implementation Phases

### Phase 1: Infrastructure (Days 1-2)

1. Add `AliasRegion` and `MemFlags` to IR
2. Update `InstructionData.load` and `.store` to include optional `MemFlags`
3. Update IR builder to accept memory flags
4. Update instruction formatting to display memory flags

**Files**:
- `src/ir/instructions.zig`
- `src/ir/builder.zig`

### Phase 2: Last Store Tracking (Days 3-4)

1. Implement `LastStores` structure
2. Implement dataflow analysis to compute last stores at each program point
3. Handle control flow merges (meet operation)

**Files**:
- `src/codegen/opts/alias.zig` (new)

### Phase 3: Memory Values Table (Days 5-7)

1. Implement `MemoryLoc` with hashing
2. Build memory-values table during forward pass
3. Handle dominance checking for safety

**Files**:
- `src/codegen/opts/alias.zig`

### Phase 4: Optimizations (Days 8-10)

1. Implement redundant load elimination
2. Implement store-to-load forwarding
3. Preserve def-use chains

**Files**:
- `src/codegen/opts/alias.zig`

### Phase 5: Integration & Testing (Days 11-14)

1. Add to optimization pass manager
2. Write comprehensive tests
3. Measure performance impact

**Files**:
- `src/codegen/compile.zig`
- `tests/alias_analysis.zig` (new)

## Algorithm Overview

### Forward Pass (RPO Order)

```
for each block B in reverse postorder:
    // Merge inputs from predecessors
    last_stores = merge(pred_outputs for pred in predecessors(B))

    for each inst I in B:
        if I is a load:
            key = MemoryLoc(last_stores.get(I.flags), I.addr, I.ty, I.opcode)
            if mem_values.contains(key):
                (def_inst, value) = mem_values[key]
                if dominates(def_inst, I):
                    replace I with value  // RLE or store-to-load forwarding
                    continue
            mem_values[key] = (I, I.result)

        if I is a store:
            key = MemoryLoc(last_stores.get(I.flags), I.addr, I.data.ty, .store)
            mem_values[key] = (I, I.data)
            last_stores.update(I)

        if I has memory fence semantics (call, etc.):
            last_stores.invalidate_all()
            mem_values.clear()  // Conservative
```

## Safety Considerations

1. **Dominance**: Only replace a load if the defining instruction dominates it
2. **Trap safety**: Don't eliminate stores that might be observed after a trap
3. **Volatile**: Never optimize volatile accesses
4. **Fences**: Calls and memory fences invalidate tracked state

## Performance Expectations

Based on Cranelift's experience:
- **Redundant loads**: 5-15% reduction in typical code
- **Store forwarding**: 2-5% additional benefit
- **Compile time**: <5% overhead (single forward pass)

## Testing Strategy

1. **Unit tests**: LastStores merge, MemoryLoc hashing
2. **IR tests**: Verify correct transformation on small examples
3. **Integration tests**: Run on realistic functions
4. **Benchmarks**: Measure optimization impact

## Future Extensions

1. **Points-to analysis**: Track which pointers may point to same locations
2. **Array analysis**: Handle array element aliasing
3. **Inter-procedural**: Analyze across function boundaries
4. **Dead store elimination**: Once trap semantics are clear

## References

- Cranelift `alias_analysis.rs` - Main inspiration
- "A Simple, Fast Dominance Algorithm" (Cooper, Harvey, Kennedy)
- LLVM's MemorySSA - Alternative formulation
