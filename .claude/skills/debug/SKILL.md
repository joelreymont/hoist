# Debugging Skill

## When to Use

Activate when user:
- Has a bug to investigate
- Sees wrong decoder output
- Encounters compiler/VM issues
- Needs to trace through pipeline stages
- Mentions "wrong output" or "mismatch"

## First: Identify Abstraction Level

**Generation bug or Execution bug?**

| Symptom | Bug Location |
|---------|--------------|
| Wrong opcode in bytecode | Compiler (generation) |
| Correct bytecode, wrong output | VM (execution) |
| Wrong offset in trie | Compiler (trie building) |
| Correct offset, wrong data read | VM (header parsing) |

**Don't debug execution if bytecode is wrong.**

## Key Files by Area

| Area | File |
|------|------|
| Constraint extraction | src/compiler/passes/flatten.zig |
| Mask/value computation | src/compiler/passes/precompute.zig |
| Trie building | src/compiler/passes/partition.zig |
| Bytecode emission | src/compiler/emitter.zig |
| IR types | src/compiler/ir/*.zig |

## Debug Output Strategy

```zig
// BAD: Only print final result
std.debug.print("abs_offset={}\n", .{abs_offset});

// GOOD: Print all components
std.debug.print("bytecode_offset={}, base={x}, abs={}\n",
    .{bytecode_offset, bytecode_base, abs_offset});
```

Batch debug prints. Add multiple in one edit. Target specific data.

## Pipeline Debugging

```zig
const ir3 = try pipeline.compile(alloc, ir0, .{
    .dump_ir1 = true,
    .dump_ir2 = true,
    .dump_ir3 = true,
});
```

## Bytecode Inspection

**Use `dx disasm`, NOT hexdump:**
```bash
zig build run -- disasm <bytecode.dx>
```

## Critical Rules

1. **Never trust stale data** - re-verify after any code change
2. **Print ALL intermediate values** - not just final result
3. **Pick ONE approach** - don't mix hex dumps with runtime prints
4. **Verify assumptions immediately** - add print when you assume a value

## Red Flags (Phantom Bugs)

- "Offset should be X but it's X+26" → Did you regenerate?
- "This worked before" → What changed? Regenerate.
- Comparing hex dump to runtime output → Same build?

## Cleanup

- Remove all debug prints before committing
- Use `zig build -Doptimize=ReleaseFast` for faster debug runs
