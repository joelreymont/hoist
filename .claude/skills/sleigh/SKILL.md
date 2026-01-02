# Sleigh Skill

## When to Use

Activate when user:
- Works with Sleigh patterns or specs
- Debugs decode issues (wrong mnemonic, operands)
- Asks about context fields (mandover, prefix_66, vexMode)
- Deals with bit ordering or mask/value calculations
- Needs to modify Sleigh specs for IDA compatibility

## Key References

- `docs/sleigh.md` - Full Sleigh reference (patterns, context, lengths)
- [Ghidra Sleigh Docs](https://ghidra.re/ghidra_docs/languages/html/sleigh.html)

## Critical: Bit Ordering

**Context fields use (MSB, LSB) - first index is most significant bit**

```sleigh
define context contextreg
    mandover=(12,14)      # Bits 12-14, bit 12 is MSB
      prefix_f2=(12,12)   # Bit 12 = value 4 (2^2)
      prefix_f3=(13,13)   # Bit 13 = value 2 (2^1)
      prefix_66=(14,14)   # Bit 14 = value 1 (2^0) ← LSB
;
```

Setting `prefix_66=1` sets bit 14 → `mandover=1`.

## Context Action Execution Order

1. Pattern bytes match
2. Constructor selected
3. **Context actions execute** (BEFORE operands!)
4. Operands evaluated (see updated context)

```sleigh
:^instruction is byte=0x66; instruction [ mandover=1; ] { }
# Match 0x66 → Execute mandover=1 → THEN evaluate `instruction`
```

## Debugging Patterns

When decode is wrong:

1. Find the pattern in Sleigh spec
2. Check context requirements
3. Trace context actions in bytecode
4. Verify mask/value in trie

## IDA Compatibility (With Permission)

**NEVER modify Sleigh specs without explicit permission.**

When allowed, to match IDA output:

1. Comment out (never delete) original pattern:
```sleigh
# BEBOP: Commented out to match IDA behavior. [reason]
# :ORIGINAL pattern is ... { }
```

2. Document in `docs/sleigh-ida-compat.md`
3. Verify after regenerating bytecode

### Known IDA Differences

| Instruction | IDA | Ghidra |
|-------------|-----|--------|
| 0x9B prefix | WAIT + FN* | F* combined |

## Pattern Priority

1. **More specific wins** - Subset patterns beat supersets
2. **First defined wins** - When overlap without containment

## Constraint Operators

| Operator | Example |
|----------|---------|
| `=` | `opcode=0x15` |
| `!=` | `mod!=3` |
| `<` | `imm<128` |
| `>` | `offset>0` |
| `&` | Both match (same segment) |
| `\|` | Either matches (same field) |
| `;` | Segment separator |

## Length Calculation

- Each segment = ONE token's width
- Subtables contribute at runtime, not compile-time
- Context-only patterns = 0 bytes
