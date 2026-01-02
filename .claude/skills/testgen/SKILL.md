# Test Binary Generation and Verification

Z3-based test binary generator and IDA verification workflow.

## When to Use

Activate when user:
- Asks to generate test binaries for an architecture
- Wants to verify instruction coverage
- Says "generate test binary", "z3 generator", "instruction coverage"
- Needs to create binaries that cover all Sleigh instructions
- Asks about the verification workflow or pipeline
- Wants to understand how test binaries are created

## Location

- Generator: `src/testgen/generator.zig`
- Z3 bindings: `src/testgen/z3.zig`
- Constraints: `src/testgen/constraints.zig`
- Collision detection: `src/testgen/collision.zig`
- Verification binaries: `verification/binaries/`

## How Generator Works

1. **Collect patterns** from compiled bytecode (root scanner patterns with mnemonics)
2. **Sort by specificity** (most constrained patterns first)
3. **Group by control flow** (none, jump, branch, call, ret, indirect)
4. **Generate bytes with Z3** - SMT solver finds satisfying bytes for each pattern
5. **Avoid collisions** - exclude bytes that match more-specific patterns
6. **Handle context** - generate prefix bytes to set up required context state
7. **Layout binary** - dispatch table at offset 0, instruction groups follow

## Verification Workflow

The correct end-to-end verification flow:

```
┌─────────────────┐     ┌─────────────┐     ┌──────────────┐
│ Sleigh .slaspec │────>│ Compile     │────>│ bytecode.dx  │
└─────────────────┘     └─────────────┘     └──────────────┘
                                                   │
┌─────────────────┐     ┌─────────────┐           │
│ Z3 Generator    │────>│ test.bin    │           │
└─────────────────┘     └─────────────┘           │
                              │                    │
                              v                    v
                        ┌─────────────┐     ┌──────────────┐
                        │ IDA Pro     │     │ BN + Plugin  │
                        └─────────────┘     └──────────────┘
                              │                    │
                              v                    v
                        ┌─────────────┐     ┌──────────────┐
                        │ ida.json    │<───>│ Compare      │
                        │ (ground     │     │ Results      │
                        │  truth)     │     └──────────────┘
                        └─────────────┘
```

**Steps:**

1. **Compile Sleigh spec** to bytecode:
   ```bash
   zig build run -- compile <arch>.slaspec -o <arch>.dx
   ```

2. **Generate test binary** covering all instructions (z3-based)

3. **Run IDA Pro** on test binary - export JSON (GOLD STANDARD)

4. **Run Binary Ninja** with dixie plugin + compiled bytecode

5. **Compare** BN/dixie output against IDA JSON

6. **Target: 100% match** with IDA

## CLI Commands

```bash
# Compile Sleigh spec to bytecode
zig build run -- compile <spec.slaspec> -o <output.dx>

# Verify bytecode against IDA reference
zig build run -- verify <bytecode.dx> <binary> <ida.json> [--details] [--limit N]

# Decode single instruction
zig build run -- decode <hex> --bytecode <path.dx>

# Disassemble bytecode
zig build run -- disasm <bytecode.dx>

# Run Z3/testgen tests
zig build test-z3
```

## Manifest Format

```json
{
  "arch": "x86-64",
  "binary_sha256": "abc123...",
  "entries": [
    {"offset": 0, "mnemonic": "NOP", "length": 1, "rule_index": 42},
    ...
  ]
}
```

## Reference Priority

1. **IDA Pro** - GOLD STANDARD (always verify here first)
2. **Binary Ninja** - Secondary verification  
3. **Capstone** - Last resort if IDA/BN don't support architecture

## Why Instructions May Be Skipped

| Reason | Description |
|--------|-------------|
| UNSAT | Z3 can't find bytes satisfying pattern constraints |
| Context | Pattern requires unreachable context state |
| Collision | More-specific pattern would match the bytes |
| Group limit | Automatic split at 100 instructions/group |

## Architecture Support

Generator is architecture-agnostic but dispatch table/prefix generation is x86-64 specific.

Supported specs (via `verification/specs/ghidra/`):
- x86 / x86-64, ARM / AArch64, MIPS, PowerPC, RISC-V, Z80, 68000, etc.

## Key Functions

```zig
// Generator
Generator.init(alloc, ir) -> Generator
Generator.generate(arch_name) -> TestBinary
Generator.generatePatternBytes(smt, pattern, all_patterns) -> ?[]u8
Generator.canSatisfyContext(pattern) -> bool

// Z3
SmtContext.mkBvVar(name, bits) -> Ast
SmtContext.mkBvConst(value, bits) -> Ast  
SmtContext.mkEq(l, r) -> Ast
SmtContext.assert_(constraint)
SmtContext.check() -> Lbool
SmtContext.getModel() -> ?Model

// TestBinary
TestBinary.writeToFile(path)
TestBinary.writeManifestJson(writer)
TestBinary.computeHash()
```

## Verification Output

```
=== IDA Verification Results ===
Total instructions: 1234
Matches:            1200 (97.2%)
Mnemonic mismatch:  20
Length mismatch:    10
Decode failures:    4

=== First N Failures ===
0x0100: MNEMONIC - IDA: add vs DX: (decode fail)
0x0200: LENGTH - IDA: 3 vs DX: 2 (mnemonic: MOV)
```
