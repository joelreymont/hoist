# Verification Skill

## When to Use

Activate when user:
- Asks to verify decoder output against IDA/BN
- Has decode mismatches to investigate
- Wants to compare disassembly outputs
- Says "check against IDA" or "verify this instruction"
- Needs to regenerate test binaries or JSON

## Reference Priority (STRICT)

1. **IDA Pro** - GOLD STANDARD. Always verify against IDA first.
2. **Binary Ninja** - Secondary. Use for BN-specific testing.
3. **Capstone** - Last resort. Only when IDA AND BN don't support arch.

**NEVER skip IDA verification.**

## Dixie CLI Commands

```bash
# Decode single instruction
zig build run -- decode <hex> --bytecode <path.dx>
zig build run -- decode 0f58c0 --bytecode x86-64.dx    # ADDPS XMM0,XMM0

# Verify against IDA JSON
zig build run -- verify <bc> <bin> <json>
zig build run -- verify x86_64.dx test.bin test.ida.json

# Compare two JSON outputs
zig build run -- compare ida.json bn.json
```

## Test Binary Workflow

1. Generate/update test binary
2. Run IDA to generate `.ida.json` (pre-generated, checked in)
3. Verify dixie output: `dx verify x86_64.dx test.bin test.ida.json`
4. Target: **100% IDA match**

## Test Data Locations

- `test_binaries/x86_64_aligned.bin`
- `test_binaries/x86_64_aligned.ida.json`

## Debugging Mismatches

1. Decode the specific bytes: `dx decode <hex>`
2. Check expected output from IDA JSON
3. If mismatch, investigate:
   - Wrong mnemonic → check pattern matching
   - Wrong operands → check operand rendering
   - Missing instruction → check trie routing

## JSON Version Verification

Compare tool verifies JSON files match the same binary:
- `binary_sha256` field present → FAILS on mismatch
- Missing → warns, checks `file` basename
- **Always regenerate BOTH after changing test binary**
