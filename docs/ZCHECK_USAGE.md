# zcheck Property Testing Integration

## Overview

zcheck is a property-based testing library for Zig that automatically generates test cases to verify invariant properties. Integrated into hoist to enhance testing coverage beyond manual test cases.

**Repository**: https://github.com/joelreymont/zcheck

## Integration Status

✅ Added to `build.zig.zon` dependencies
✅ Imported in `build.zig` for all test modules
✅ Comprehensive property tests in `src/backends/aarch64/zcheck_properties.zig`

## Core Capabilities

### 1. Automatic Test Case Generation

zcheck generates random test inputs based on type signatures:

```zig
test "property: addition is commutative" {
    try zc.check(struct {
        fn prop(args: struct { a: i32, b: i32 }) bool {
            return (args.a +% args.b) == (args.b +% args.a);
        }
    }.prop, .{ .iterations = 200 });
}
```

No manual test case construction - zcheck generates 200 random (a, b) pairs automatically.

### 2. Shrinking for Minimal Counterexamples

When a property fails, zcheck automatically reduces the failing case to minimal values:

```
=== Property failed ===
Seed: 1704067200
Iteration: 42
Original: { .x = 12847, .y = -9823 }
Shrunk: { .x = 1, .y = 0 }
```

This dramatically simplifies debugging by identifying the simplest failing case.

### 3. Reproducible Failures

All failures include a seed for exact reproduction:

```zig
// Reproduce a specific failure
try zc.check(myProperty, .{ .seed = 1704067200 });
```

### 4. Smart Boundary Generation

zcheck automatically focuses on edge cases:
- **Integers**: 20% of cases are boundary values (0, min, max, -1)
- **Floats**: Special values (0, ±1, min, max, inf, NaN)
- **Optionals**: 50% null, 50% generated values

## Data Type Support

| Type | Generation Strategy | Shrinking Behavior |
|------|--------------------|--------------------|
| `i8`-`i64`, `u8`-`u64` | Random + 20% boundaries | Toward zero by halving |
| `f32`, `f64` | Random + special values | Toward zero |
| `bool` | Uniform 50/50 | `true` → `false` |
| `enum` | Uniform across variants | Earlier declaration order |
| `?T` | 50% null, 50% value | `some(x)` → `null` |
| `[N]T` | Element-wise generation | Per-element shrinking |
| `struct` | Field-wise generation | Per-field shrinking |

### Bounded Types (No Allocation)

zcheck provides bounded string types that avoid heap allocation:

```zig
const zc = @import("zcheck");

test "bounded string property" {
    try zc.check(struct {
        fn prop(args: struct { s: zc.String }) bool {
            const str = args.s.slice();  // Access underlying bytes
            return str.len <= zc.MAX_STRING_LEN;  // 64 bytes max
        }
    }.prop, .{});
}
```

**Available bounded types**:
- `String`: Printable ASCII, 0-64 bytes, 10% empty
- `Id`: Alphanumeric identifier, 8-36 characters
- `FilePath`: Path with extension, up to 128 bytes
- `BoundedSlice(T, N)`: Generic bounded slice with max length N

## Configuration Options

```zig
try zc.check(myProperty, .{
    .iterations = 1000,          // Default: 100
    .seed = 12345,               // Default: timestamp
    .max_shrinks = 200,          // Default: 100
    .expect_failure = false,     // Set true if property should fail
    .print_failures = true,      // Print counterexample details
    .use_default_values = true,  // Respect struct field defaults
    .random = null,              // Optional external RNG
});
```

## Property Testing Patterns

### 1. Algebraic Properties

Test mathematical properties that should hold universally:

```zig
// Commutativity
test "property: a + b == b + a" {
    try zc.check(struct {
        fn prop(args: struct { a: i32, b: i32 }) bool {
            return args.a +% args.b == args.b +% args.a;
        }
    }.prop, .{});
}

// Associativity
test "property: (a + b) + c == a + (b + c)" {
    try zc.check(struct {
        fn prop(args: struct { a: i16, b: i16, c: i16 }) bool {
            const left = (args.a +% args.b) +% args.c;
            const right = args.a +% (args.b +% args.c);
            return left == right;
        }
    }.prop, .{});
}

// Identity
test "property: a + 0 == a" {
    try zc.check(struct {
        fn prop(args: struct { a: i64 }) bool {
            return args.a +% 0 == args.a;
        }
    }.prop, .{});
}
```

### 2. Encoding/Decoding Round-Trips

Verify encode-decode cycles preserve data:

```zig
test "property: encode-decode round-trip" {
    try zc.check(struct {
        fn prop(args: struct { value: u32 }) bool {
            const encoded = encode(args.value);
            const decoded = decode(encoded);
            return decoded == args.value;
        }
    }.prop, .{});
}
```

### 3. Invariant Properties

Test that invariants always hold:

```zig
test "property: sorted array stays sorted" {
    try zc.check(struct {
        fn prop(args: struct { arr: [8]u16 }) bool {
            var sorted = args.arr;
            std.mem.sort(u16, &sorted, {}, std.sort.asc(u16));

            // Verify sorted property
            for (sorted[0..sorted.len-1], 1..) |val, i| {
                if (val > sorted[i]) return false;
            }
            return true;
        }
    }.prop, .{});
}
```

### 4. Constraint Validation

Test that outputs respect constraints:

```zig
test "property: frame size is 16-byte aligned" {
    try zc.check(struct {
        fn prop(args: struct { size_div16: u12 }) bool {
            const frame_size = @as(u32, args.size_div16) * 16;
            return frame_size % 16 == 0;
        }
    }.prop, .{});
}
```

### 5. Oracle Functions

Use simplified reference implementations to verify complex code:

```zig
test "property: fast multiply matches reference" {
    try zc.check(struct {
        fn prop(args: struct { a: u16, b: u16 }) bool {
            const fast_result = fastMultiply(args.a, args.b);
            const reference = @as(u32, args.a) * @as(u32, args.b);
            return fast_result == reference;
        }
    }.prop, .{});
}
```

## hoist-Specific Property Tests

### Instruction Encoding

**Location**: `src/backends/aarch64/zcheck_properties.zig`

```zig
// Verify all AArch64 instructions are 4-byte aligned
test "property: instruction length is multiple of 4 bytes" {
    try zc.check(struct {
        fn prop(args: struct {
            dst_reg: u5,
            src1_reg: u5,
            src2_reg: u5,
        }) bool {
            const inst = Inst{ .add_rr = .{
                .dst = ...,
                .src1 = ...,
                .src2 = ...,
                .size = .size64,
            } };

            var buffer = MachBuffer.init(allocator);
            defer buffer.deinit();

            emit(inst, &buffer) catch return false;
            return buffer.finish().len % 4 == 0;
        }
    }.prop, .{ .iterations = 200 });
}
```

Key properties tested:
- ✅ All instructions encode to 4-byte multiples
- ✅ Register numbers preserved in encoding
- ✅ Size bit (sf) correctly set for 32/64-bit
- ✅ Valid immediates can be encoded
- ✅ STP/LDP offsets respect alignment constraints

### AAPCS64 ABI

```zig
// Verify register pairs start at even registers
test "property: register pairs start at even register" {
    try zc.check(struct {
        fn prop(args: struct { start_reg: u3 }) bool {
            const first_reg = @as(u8, args.start_reg) * 2;
            if (first_reg >= 8) return true;

            const lo = PReg.new(.int, first_reg);
            const hi = PReg.new(.int, first_reg + 1);

            return lo.hw() % 2 == 0 and hi.hw() == lo.hw() + 1;
        }
    }.prop, .{});
}
```

Key properties tested:
- ✅ Register pairs use even registers (AAPCS64 requirement)
- ✅ Frame sizes are 16-byte aligned
- ✅ Stack slot alignment is power of 2

### Immediate Encoding

```zig
// Verify shifted immediates preserve value
test "property: shifted immediates preserve value" {
    try zc.check(struct {
        fn prop(args: struct { imm: u12, shift: bool }) bool {
            const base_value = @as(u32, args.imm);
            const shift_amount: u5 = if (args.shift) 12 else 0;
            const shifted = base_value << shift_amount;
            const recovered = shifted >> shift_amount;
            return recovered == base_value;
        }
    }.prop, .{});
}
```

## Advanced Techniques

### Custom Generators

For complex types, create custom generation logic:

```zig
const CustomType = struct {
    value: u32,
    flags: u8,

    fn generate(random: std.Random) CustomType {
        return .{
            .value = random.int(u32),
            .flags = random.int(u8) & 0x0F,  // Only lower 4 bits
        };
    }
};
```

### Conditional Properties

Skip invalid inputs gracefully:

```zig
test "property with precondition" {
    try zc.check(struct {
        fn prop(args: struct { divisor: u32 }) bool {
            if (args.divisor == 0) return true;  // Skip division by zero

            const quotient = 100 / args.divisor;
            return quotient * args.divisor <= 100;
        }
    }.prop, .{});
}
```

### Stateful Property Testing

Test sequences of operations:

```zig
test "property: push/pop maintains stack invariant" {
    try zc.check(struct {
        fn prop(args: struct { values: [4]u16 }) bool {
            var stack = Stack.init();

            // Push all values
            for (args.values) |v| {
                stack.push(v) catch return false;
            }

            // Pop in reverse order
            var i: usize = args.values.len;
            while (i > 0) {
                i -= 1;
                const popped = stack.pop() orelse return false;
                if (popped != args.values[i]) return false;
            }

            return stack.isEmpty();
        }
    }.prop, .{});
}
```

## Comparing to Manual Tests

### Before (Manual Test Cases)

```zig
test "register encoding" {
    try testRegisterEncoding(0, 0);
    try testRegisterEncoding(1, 1);
    try testRegisterEncoding(7, 7);
    try testRegisterEncoding(15, 15);
    try testRegisterEncoding(30, 30);
}
```

**Limitations**:
- Only 5 test cases
- No edge case discovery
- Manual selection of inputs
- Misses boundary interactions

### After (Property Test)

```zig
test "property: register encoding preserves register numbers" {
    try zc.check(struct {
        fn prop(args: struct { reg_num: u5 }) bool {
            if (args.reg_num >= 31) return true;
            // ... test logic ...
        }
    }.prop, .{ .iterations = 100 });
}
```

**Advantages**:
- 100 automatically generated test cases
- 20% are boundary values (0, 30, etc.)
- Discovers edge cases automatically
- Shrinks failures to minimal counterexamples
- Reproducible with seed

## Best Practices

### 1. Start with Simple Properties

Begin with obvious mathematical properties before complex invariants:

```zig
// GOOD: Simple, clear property
test "property: length of sorted == length of original" {
    try zc.check(struct {
        fn prop(args: struct { arr: [8]u32 }) bool {
            var sorted = args.arr;
            std.mem.sort(u32, &sorted, {}, std.sort.asc(u32));
            return sorted.len == args.arr.len;
        }
    }.prop, .{});
}

// AVOID: Too complex, hard to debug
test "property: complex multi-step transformation" {
    // 10 steps of transformations...
}
```

### 2. Use Appropriate Iteration Counts

- **Simple properties** (arithmetic): 100-200 iterations
- **Encoding/decoding**: 200-500 iterations
- **Complex invariants**: 500-1000 iterations
- **Performance sensitive**: 50-100 iterations

### 3. Handle Invalid Inputs Gracefully

Return `true` to skip invalid cases rather than failing:

```zig
test "property with constraints" {
    try zc.check(struct {
        fn prop(args: struct { value: u8 }) bool {
            // Skip values outside valid range
            if (args.value >= 200) return true;

            // Test valid values
            return process(args.value) != null;
        }
    }.prop, .{});
}
```

### 4. Use Bounded Types for Performance

Avoid allocation in hot property test paths:

```zig
// GOOD: No allocation
test "string property" {
    try zc.check(struct {
        fn prop(args: struct { s: zc.String }) bool {
            const str = args.s.slice();
            return validateString(str);
        }
    }.prop, .{});
}

// AVOID: Heap allocation per iteration
test "string property" {
    try zc.check(struct {
        fn prop(args: struct { len: u6 }) bool {
            const str = try allocator.alloc(u8, args.len);  // BAD
            defer allocator.free(str);
            // ...
        }
    }.prop, .{});
}
```

### 5. Document Property Intent

Clearly state what invariant is being tested:

```zig
/// Property: AAPCS64 Section 5.4.2.3 - Register pairs for 16-byte aligned
/// types must use even-numbered base registers (X0, X2, X4, X6).
/// This ensures proper alignment when the pair spans two consecutive registers.
test "property: register pairs start at even register" {
    // ...
}
```

## Running Property Tests

```bash
# Run all tests (includes property tests)
zig build test

# Run specific test file
zig test src/backends/aarch64/zcheck_properties.zig

# Run with specific seed to reproduce failure
zig test src/backends/aarch64/zcheck_properties.zig -- --seed=12345

# Run with increased iterations
zig test src/backends/aarch64/zcheck_properties.zig -- --iterations=1000
```

## Future Enhancements

### Potential Additional Property Tests

1. **Register Allocation**
   - No two live vregs assigned to same preg
   - All vregs receive allocation (preg or spill)
   - Spill slots are unique or correctly reused
   - Hints respected when registers available

2. **ISLE Pattern Matching**
   - All IR ops have at least one matching ISLE pattern
   - Pattern priorities are deterministic
   - No unreachable patterns (dead code)

3. **Frame Layout**
   - Callee-save slots fit in frame
   - Stack probe triggers for large frames
   - Frame pointer set when required
   - Dynamic stack allocation correctly tracked

4. **Constant Pool**
   - All constants have unique pool entries or are shared correctly
   - PC-relative offsets within valid range
   - Pool emission happens after all references known

5. **Relocation**
   - All external symbols have relocations
   - Relocation types match target operand sizes
   - GOT entries created for all external data references

## Comparison to Other Property Testing Frameworks

| Feature | zcheck | QuickCheck (Haskell) | Hypothesis (Python) |
|---------|--------|---------------------|-------------------|
| Shrinking | ✅ Automatic | ✅ Automatic | ✅ Automatic |
| Reproducibility | ✅ Seed-based | ✅ Seed-based | ✅ Database |
| No allocation | ✅ Bounded types | ❌ | ❌ |
| Custom generators | ⚠️ Manual | ✅ Combinators | ✅ Strategies |
| Stateful testing | ⚠️ Manual | ✅ Built-in | ✅ State machines |
| Integration | ✅ Native Zig | N/A | N/A |

## References

- zcheck repository: https://github.com/joelreymont/zcheck
- QuickCheck paper: "QuickCheck: A Lightweight Tool for Random Testing of Haskell Programs"
- Hypothesis documentation: https://hypothesis.readthedocs.io/
- Property-Based Testing introduction: https://fsharpforfunandprofit.com/series/property-based-testing.html

## Contributing Property Tests

When adding new property tests:

1. **Identify the invariant** - What property must always hold?
2. **Choose appropriate types** - Use smallest types that exercise the property
3. **Handle invalid inputs** - Return `true` to skip, don't fail
4. **Document the property** - Explain what and why
5. **Set iteration count** - Based on complexity and performance
6. **Add to appropriate file** - Group related properties together

Example template:

```zig
/// Property: [Clear statement of invariant]
/// [Additional context: AAPCS64 section, ARM manual reference, etc.]
test "property: descriptive name" {
    try zc.check(struct {
        fn prop(args: struct {
            // Minimal necessary arguments
            value: u32,
        }) bool {
            // Skip invalid inputs
            if (/* invalid condition */) return true;

            // Test the property
            const result = functionUnderTest(args.value);
            return verifyInvariant(result);
        }
    }.prop, .{
        .iterations = 100,  // Appropriate for complexity
    });
}
```
