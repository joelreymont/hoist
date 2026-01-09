# Value Range Analysis Design Survey

Survey of value range analysis designs from LLVM and related compiler research for implementing range-based optimizations in Hoist.

## LLVM LazyValueInfo

LLVM's [LazyValueInfo](https://llvm.org/doxygen/classllvm_1_1LazyValueInfo.html) is a demand-driven analysis pass that computes and caches value constraint information.

### Architecture

**Lattice-Based Representation**: Uses `ValueLatticeElement` to represent abstract value states:
- Single constants (most precise)
- Constant ranges (intervals)
- Overdefined (unknown/imprecise)

**Data Structures**:
- `ConstantRange`: Represents possible integer value ranges `[min, max]`
- `NonNullPointerSet`: Tracks pointers known to be non-null
- Demand-driven caching: computes and caches results lazily

**Key Algorithms**:
1. Pattern matching: `matchICmpOperand()` recognizes comparison patterns to refine ranges
2. Overflow analysis: `getValueFromOverflowCondition()` extracts ranges from overflow intrinsics
3. Constant folding: `constantFoldUser()` simplifies operations with known constant operands
4. Predicate evaluation: `getPredicateResult()` evaluates conditionals given value constraints

**Performance**: Limits analysis with `MaxProcessedPerValue = 500` to prevent expensive searches for complex queries.

### Enabled Optimizations

- Dead code elimination (prove comparisons always true/false)
- Branch simplification (eliminate dead branches)
- Bounds check elimination (prove array indices in-range)
- Jump threading (constant propagation through branches)

Reference: [LazyValueInfo.cpp](https://llvm.org/doxygen/LazyValueInfo_8cpp.html)

## Integer Overflow and Wrapping

### Unsigned Wrapping (Well-Defined)

Unsigned arithmetic overflow produces **modulo 2^N** wraparound behavior, which is well-defined in C11 and other standards. This is predictable and intentionally used in algorithms (hash functions, cyclic counters, cryptography).

Reference: [Integer overflow - Wikipedia](https://en.wikipedia.org/wiki/Integer_overflow)

### Signed Overflow (Undefined Behavior)

In C/C++, signed integer overflow is **undefined behavior** (UB), allowing compilers to:
- Assume overflow never occurs
- Apply aggressive optimizations that break on overflow
- Generate arbitrary results

Modern optimizing compilers increasingly exploit UB for performance, which breaks intentional wrapping uses.

Reference: [Understanding Integer Overflow in C/C++](https://users.cs.utah.edu/~regehr/papers/overflow12.pdf)

### Wrapping Arithmetic in Practice

Over 200 distinct intentional wraparound uses exist in SPEC CINT2000 alone. Common patterns:
- Hash table indexing: `(hash & (size - 1))`
- Ring buffer wrap: `(index + 1) % capacity`
- Two's complement negation: `-x == (~x + 1)`

Compilers must handle both:
1. **Wrapping semantics** (unsigned, explicit wrapping types like Rust's `Wrapping<T>`)
2. **Trapping/saturating semantics** (for safety-critical code)

Reference: [Solutions to Integer Overflow – Embedded in Academia](https://blog.regehr.org/archives/1401)

## Bounds Check Elimination

[Bounds-checking elimination](https://en.wikipedia.org/wiki/Bounds-checking_elimination) removes runtime array index validation when the compiler can prove indices are always in-range.

### Techniques

**SSA-Based Type System**: Create "safe index" types for each array:
1. First use casts to safe index type (with runtime check)
2. Subsequent uses skip checks (type system guarantees safety)

**ABCD Algorithm** (Array Bounds Checks on Demand):
- Works on SSA intermediate representation
- Maintains conditions for index expressions
- Removes checks provably always satisfied
- Removes ~45% of dynamic bound checks on average

Reference: [ABCD: eliminating array bounds checks on demand](https://dl.acm.org/doi/10.1145/358438.349342)

**Flow Analysis Optimization**:
- Hoist checks out of loops (check once before loop)
- Propagate proven constraints through control flow
- Merge ranges at phi nodes

Reference: [Optimizing array bound checks using flow analysis](https://dl.acm.org/doi/10.1145/176454.176507)

### Performance Impact

JIT compilers (Java HotSpot, .NET CLR) eliminate bounds checks aggressively:
- HotSpot removes checks when indices provably in-range
- CLR uses range analysis to optimize array-heavy code

Overhead when not eliminated: typically <20% on numeric benchmarks (SPEC95 CFP).

Reference: [Array Bounds Check Elimination in the CLR](https://learn.microsoft.com/en-us/archive/blogs/clrcodegeneration/array-bounds-check-elimination-in-the-clr)

## Interval Arithmetic Considerations

### Wraparound Semantics

For unsigned integers with wraparound:
- Addition: `[a, b] + [c, d]` wraps at `2^N`
- Subtraction: `[a, b] - [c, d]` may wrap backward
- Multiplication: Complex interaction (multiple wraparounds possible)

Conservative approximation: widen to `[0, 2^N - 1]` on potential wrap.

### No-Wrap Assumptions

For signed integers assuming no-overflow UB:
- Standard interval arithmetic applies
- `[a, b] + [c, d] = [a + c, b + d]` (if no overflow)
- Enables more aggressive optimizations

## Design Recommendations for Hoist

### Representation

Use `ValueRange` struct with:
```zig
pub const ValueRange = struct {
    min: i64,  // Minimum possible value
    max: i64,  // Maximum possible value
    bits: u8,  // Bit width (8, 16, 32, 64)

    // Flags
    no_wrap: bool,  // Assume no overflow (signed) or use wrapping (unsigned)
};
```

### Analysis Pass

Implement forward dataflow analysis:
1. Initialize block parameters with full ranges
2. Propagate through instructions (interval arithmetic)
3. Narrow ranges at comparisons (branch conditions)
4. Join ranges at phi nodes (union/widen)
5. Iterate to fixpoint (ranges stabilize)

### Optimizations to Enable

Priority targets:
1. **Bounds check elimination**: Prove array indices in-range
2. **Comparison simplification**: `if (x < 10)` when range is `[0, 5]` → always true
3. **Dead code elimination**: Unreachable branches
4. **Overflow check elimination**: Prove arithmetic won't overflow

## References

- [LLVM LazyValueInfo Class Reference](https://llvm.org/doxygen/classllvm_1_1LazyValueInfo.html)
- [LLVM LazyValueInfo.cpp](https://llvm.org/doxygen/LazyValueInfo_8cpp.html)
- [Integer overflow - Wikipedia](https://en.wikipedia.org/wiki/Integer_overflow)
- [Understanding Integer Overflow in C/C++](https://users.cs.utah.edu/~regehr/papers/overflow12.pdf)
- [Bounds-checking elimination - Wikipedia](https://en.wikipedia.org/wiki/Bounds-checking_elimination)
- [ABCD: eliminating array bounds checks on demand](https://dl.acm.org/doi/10.1145/358438.349342)
- [Array Bounds Check Elimination in the CLR](https://learn.microsoft.com/en-us/archive/blogs/clrcodegeneration/array-bounds-check-elimination-in-the-clr)
- [Optimizing array bound checks using flow analysis](https://dl.acm.org/doi/10.1145/176454.176507)
- [Solutions to Integer Overflow – Embedded in Academia](https://blog.regehr.org/archives/1401)
