### Reference
- Cranelift source: `~/Work/wasmtime/cranelift/`

### Code Quality
- No dead code
- No `@panic` - use `!` error returns
- Type safety - enums, tagged unions, comptime
- Named constants, no magic numbers
- **Prefer Zig stdlib over blind porting**: Carefully consider `std.bit_set`, `std.HashMap`, `std.ArrayList`, etc. before reimplementing Rust data structures; add thin wrappers only when necessary

### Zig Idioms

**Import once, namespace access:**
```zig
// WRONG: Multiple imports from same module
const Type = @import("type.zig").Type;
const Primitive = @import("type.zig").Primitive;

// RIGHT: Import module once, use namespace
const types = @import("type.zig");
// Then use: types.Type, types.Primitive
```

**Allocator first:**
Allocator is ALWAYS the first argument:
```zig
// RIGHT
pub fn init(allocator: std.mem.Allocator) Self { ... }

// WRONG
pub fn init(config: Config, allocator: std.mem.Allocator) Self { ... }
```

**ArrayList batch append:**
```zig
// WRONG: Append items one by one
try list.append(allocator, a);
try list.append(allocator, b);

// RIGHT: Create static array, appendSlice once
const items = [_]T{ a, b, c };
try list.appendSlice(allocator, &items);
```

**Error handling - NEVER MASK ERRORS:**
ALL error-masking patterns are FORBIDDEN:
```zig
// FORBIDDEN:
foo() catch unreachable;
foo() catch return;
foo() catch return null;
foo() orelse unreachable;

// RIGHT - Always propagate errors
const result = try foo();
```
Functions that call fallible operations MUST return error unions.

**The only acceptable use of `unreachable`:**
- Switch cases that are logically impossible (exhaustive enum after filtering)
- Array indices proven in-bounds by prior checks
- Never for "this shouldn't fail" - if it can fail, propagate the error

**State machines - labeled switch pattern:**
Use labeled switch for complex control flow instead of while-switch:
```zig
// RIGHT: Labeled switch pattern
state: switch (state) {
    .start => { state = .middle; continue :state; },
    .middle => { state = .end; continue :state; },
    .end => break,
}

// WRONG: while-switch
while (true) {
    switch (state) {
        .start => state = .middle,
        .middle => state = .end,
        .end => break,
    }
}
```