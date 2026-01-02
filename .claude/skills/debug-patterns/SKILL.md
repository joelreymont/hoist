# Debugging Pattern and inst_len Issues

## Common Symptoms

1. **Length mismatch**: IDA says 5 bytes, Dixie says 2 bytes
2. **Wrong pattern selected**: Correct mnemonic but wrong operands
3. **Missing patterns**: Pattern exists in Sleigh but never matches

## Debugging Workflow

### Step 1: Identify the problematic byte

Find the instruction address in IDA JSON, get its bytes:
```bash
# Example: instruction at 0x4444 with bytes 2d 62 01 87 00
zig build run -- decode 2d620187 --bytecode /tmp/x86-64.dx
```

### Step 2: Dump patterns matching that byte

```bash
zig build run -- compile x86-64.slaspec -o /tmp/x86-64.dx --dump-patterns 0x2d 2>&1 | less
```

Output now shows:
```
  SUB
    rule_index=795 inst_len=5
    mask=0x00000000000000ff value=0x000000000000002d
    ctx_mask=0x00000000803000c0 ctx_value=0x0000000000000080
    segments: [1M] [4M]
```

- **rule_index**: Trace back to Sleigh source (grep for rule number in compiler output)
- **inst_len**: Should match IDA's reported length
- **segments**: `[1M]` = 1 byte mask, `[4S]` = 4 byte subtable, `[0M]` = epsilon

### Step 3: Check segment structure

If inst_len is wrong, check segments:
- Sum of segment widths should equal inst_len
- `[0M]` segments are epsilon (valid)
- `[4S]` means 4-byte subtable reference - check if subtable is epsilon

### Step 4: Trace through inline pass

If a subtable is involved, the bug is often in p06_inline.zig.

Add debug to `merge()` function:
```zig
if (parent.rule_index == 795) {
    std.debug.print("rule=795 parent.inst_len={} sub segments: ", .{parent.inst_len});
    for (sub.segments) |seg| std.debug.print("[{}{}] ", .{seg.width, @tagName(seg.kind)[0]});
    std.debug.print("\n", .{});
}
```

### Step 5: Common bugs

1. **Epsilon extension**: When `EAX & check_EAX_dest & imm32` is inlined and `check_EAX_dest` is epsilon, the epsilon EXTENDS to fill the parent token width (4 bytes from imm32). This is not "preserving" width - epsilon conceptually occupies the token space.

2. **Minimum inst_len=1**: Empty patterns get inst_len=1, not 0. This can cause issues when merging.

3. **Context field confusion**: Context fields contribute 0 bytes to inst_len (they're register bits, not instruction bytes).

## Key Files

- `src/compiler/passes/p03_flatten.zig`: Creates segments from Sleigh patterns
- `src/compiler/passes/p06_inline.zig`: Merges subtable segments, computes merged inst_len
- `src/compiler/passes/p08_compute_length.zig`: Initial inst_len computation

## Pattern Matching Flow

```
Sleigh pattern: `:SUB EAX,imm32 is vexMode=0 & opsize=1 & byte=0x2d; EAX & check_EAX_dest & imm32`

p03_flatten:
  segment[0] = { width=1, kind=mask, value=0x2d }  // byte=0x2d
  segment[1] = { width=4, kind=subtable }          // check_EAX_dest reference, token width from imm32
  inst_len = 5

p06_inline (if check_EAX_dest is epsilon):
  // Epsilon subtable has width=0, extends to fill parent token (4 bytes)
  segment[0] = { width=1, kind=mask }
  segment[1] = { width=0+4=4, kind=mask }  // epsilon extended to parent token width
  inst_len = 5 (recomputed from segment widths)
```
