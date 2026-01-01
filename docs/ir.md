# IR Reference

Hoist uses an SSA-based intermediate representation inspired by Cranelift.

## Types

### Integer Types

```zig
Type{ .int = .{ .width = bits } }
```

Supported widths: 8, 16, 32, 64, 128

### Float Types

```zig
Type{ .float = .{ .width = bits } }
```

Supported widths: 32 (f32), 64 (f64)

### Vector Types

```zig
Type{ .vector = .{ .element_type = elem, .lanes = count } }
```

## Instructions

### Arithmetic

- `iadd`: Integer addition
- `isub`: Integer subtraction
- `imul`: Integer multiplication
- `sdiv`: Signed division
- `udiv`: Unsigned division
- `srem`: Signed remainder
- `urem`: Unsigned remainder

### Bitwise

- `band`: Bitwise AND
- `bor`: Bitwise OR
- `bxor`: Bitwise XOR
- `bnot`: Bitwise NOT
- `ishl`: Left shift
- `sshr`: Arithmetic right shift
- `ushr`: Logical right shift
- `rotl`: Rotate left
- `rotr`: Rotate right

### Comparison

- `icmp <cond>`: Integer comparison
  - Conditions: `eq`, `ne`, `slt`, `sle`, `sgt`, `sge`, `ult`, `ule`, `ugt`, `uge`

### Memory

- `load`: Load from memory
- `store`: Store to memory
- `stack_load`: Load from stack slot
- `stack_store`: Store to stack slot

### Control Flow

- `jump <dest>`: Unconditional branch
- `brif <cond> <then> <else>`: Conditional branch
- `return <value>`: Return from function
- `call <func> <args...>`: Function call

### Constants

- `iconst <value>`: Integer constant
- `fconst <value>`: Float constant

## Example IR

```zig
// fn add(a: i32, b: i32) -> i32 { return a + b; }

function "add" (i32, i32) -> i32 {
  block0(v0: i32, v1: i32):
    v2 = iadd v0, v1
    return v2
}
```

```zig
// fn fib(n: i32) -> i32 {
//   if (n <= 1) return n;
//   return fib(n-1) + fib(n-2);
// }

function "fib" (i32) -> i32 {
  block0(v0: i32):
    v1 = iconst 1
    v2 = icmp sle v0, v1
    brif v2, block1, block2

  block1:
    return v0

  block2:
    v3 = isub v0, v1
    v4 = call fib(v3)
    v5 = iconst 2
    v6 = isub v0, v5
    v7 = call fib(v6)
    v8 = iadd v4, v7
    return v8
}
```

## SSA Properties

1. **Single Assignment**: Each value defined exactly once
2. **Dominance**: Definition dominates all uses
3. **Φ-nodes**: Block parameters represent φ-nodes in traditional SSA

## Block Parameters

Instead of explicit φ-nodes, Hoist uses block parameters:

```zig
block_header(v_phi: i32):  // φ-node as block parameter
  ...
  jump block_header(v_new)  // Provide value for φ
```

## Verification

IR must satisfy:
- SSA form (no use-before-def)
- Type consistency
- Proper control flow (all blocks end with terminator)
- Dominance relationships

Run verification:
```zig
var verifier = Verifier.init(allocator, &func);
defer verifier.deinit();
try verifier.verify();
```

## Optimization

Optimizations are applied via pattern matching:

```zig
var opt_pass = OptimizationPass.init(allocator, &func);
const changed = try opt_pass.run();
```

Common optimizations:
- Constant folding: `x + 0 → x`, `x * 1 → x`
- Algebraic simplification: `x ^ x → 0`
- Strength reduction: `x * 2 → x << 1`
- Dead code elimination
