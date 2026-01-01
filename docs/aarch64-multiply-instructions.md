# AArch64 Multiply Instructions

Reference documentation for ARM64 multiply instruction encodings and semantics.

## MUL - Multiply

**Syntax:** `MUL Xd, Xn, Xm` or `MUL Wd, Wn, Wm`

**Operation:** `Xd = Xn * Xm` (lower 64/32 bits)

**Encoding (64-bit):**
```
31 30 29 28 27 26 25 24 23 22 21 20-16 15  14-10 9-5  4-0
1  0  0  1  1  0  1  1  0  0  0  Rm    0   11111  Rn   Rd
```

**Encoding (32-bit):**
```
31 30 29 28 27 26 25 24 23 22 21 20-16 15  14-10 9-5  4-0
0  0  0  1  1  0  1  1  0  0  0  Rm    0   11111  Rn   Rd
```

**Notes:**
- MUL is an alias for `MADD Xd, Xn, Xm, XZR`
- Returns only the lower 64/32 bits of the product
- For full 128-bit result, use SMULL/UMULL or SMULH/UMULH

## MADD - Multiply-Add

**Syntax:** `MADD Xd, Xn, Xm, Xa` or `MADD Wd, Wn, Wm, Wa`

**Operation:** `Xd = Xa + (Xn * Xm)`

**Encoding (64-bit):**
```
31 30 29 28 27 26 25 24 23 22 21 20-16 15  14-10 9-5  4-0
1  0  0  1  1  0  1  1  0  0  0  Rm    0   Ra     Rn   Rd
```

**Encoding (32-bit):**
```
31 30 29 28 27 26 25 24 23 22 21 20-16 15  14-10 9-5  4-0
0  0  0  1  1  0  1  1  0  0  0  Rm    0   Ra     Rn   Rd
```

**Notes:**
- Fused multiply-add in a single instruction
- More efficient than separate multiply and add

## MSUB - Multiply-Subtract

**Syntax:** `MSUB Xd, Xn, Xm, Xa` or `MSUB Wd, Wn, Wm, Wa`

**Operation:** `Xd = Xa - (Xn * Xm)`

**Encoding (64-bit):**
```
31 30 29 28 27 26 25 24 23 22 21 20-16 15  14-10 9-5  4-0
1  0  0  1  1  0  1  1  0  0  0  Rm    1   Ra     Rn   Rd
```

**Encoding (32-bit):**
```
31 30 29 28 27 26 25 24 23 22 21 20-16 15  14-10 9-5  4-0
0  0  0  1  1  0  1  1  0  0  0  Rm    1   Ra     Rn   Rd
```

**Notes:**
- MNEG is an alias for `MSUB Xd, Xn, Xm, XZR`
- Difference from MADD is bit 15 (o0 field)

## SMULH - Signed Multiply High

**Syntax:** `SMULH Xd, Xn, Xm`

**Operation:** `Xd = (Xn * Xm)[127:64]` (upper 64 bits of signed product)

**Encoding:**
```
31 30 29 28 27 26 25 24 23 22 21 20-16 15  14-10 9-5  4-0
1  0  0  1  1  0  1  1  0  1  0  Rm    0   11111  Rn   Rd
```

**Notes:**
- Only 64-bit form exists
- Returns upper 64 bits of 64×64→128 signed multiply
- Used for overflow detection or implementing wider multiply

## UMULH - Unsigned Multiply High

**Syntax:** `UMULH Xd, Xn, Xm`

**Operation:** `Xd = (Xn * Xm)[127:64]` (upper 64 bits of unsigned product)

**Encoding:**
```
31 30 29 28 27 26 25 24 23 22 21 20-16 15  14-10 9-5  4-0
1  0  0  1  1  0  1  1  1  1  0  Rm    0   11111  Rn   Rd
```

**Notes:**
- Only 64-bit form exists
- Returns upper 64 bits of 64×64→128 unsigned multiply

## SMULL - Signed Multiply Long

**Syntax:** `SMULL Xd, Wn, Wm`

**Operation:** `Xd = SignExtend(Wn) * SignExtend(Wm)` (32×32→64 signed)

**Encoding:**
```
31 30 29 28 27 26 25 24 23 22 21 20-16 15  14-10 9-5  4-0
1  0  0  1  1  0  1  1  0  0  1  Rm    0   11111  Rn   Rd
```

**Notes:**
- Sign-extends 32-bit operands to 64-bit before multiply
- Result is full 64-bit signed product
- SMULL is an alias for `SMADDL Xd, Wn, Wm, XZR`

## UMULL - Unsigned Multiply Long

**Syntax:** `UMULL Xd, Wn, Wm`

**Operation:** `Xd = ZeroExtend(Wn) * ZeroExtend(Wm)` (32×32→64 unsigned)

**Encoding:**
```
31 30 29 28 27 26 25 24 23 22 21 20-16 15  14-10 9-5  4-0
1  0  0  1  1  0  1  1  1  0  1  Rm    0   11111  Rn   Rd
```

**Notes:**
- Zero-extends 32-bit operands to 64-bit before multiply
- Result is full 64-bit unsigned product
- UMULL is an alias for `UMADDL Xd, Wn, Wm, XZR`

## Encoding Summary

All multiply instructions use the "Data-processing (3 source)" class with opcode field `11011`:

| Instruction | sf | op54 | U | op31 | Ra    | o0 |
|-------------|----|----- |---|------|-------|----|
| MADD        | x  | 00   | 0 | 000  | !11111| 0  |
| MSUB        | x  | 00   | 0 | 000  | !11111| 1  |
| MUL         | x  | 00   | 0 | 000  | 11111 | 0  |
| MNEG        | x  | 00   | 0 | 000  | 11111 | 1  |
| SMULH       | 1  | 00   | 0 | 010  | 11111 | 0  |
| UMULH       | 1  | 00   | 1 | 110  | 11111 | 0  |
| SMULL       | 1  | 00   | 0 | 001  | 11111 | 0  |
| UMULL       | 1  | 00   | 1 | 101  | 11111 | 0  |

Where:
- `sf`: 1 for 64-bit, 0 for 32-bit (except SMULH/UMULH which are always 64-bit)
- `op54`: Always `00` for multiply family
- `U`: Unsigned flag
- `op31`: Operation selector
- `Ra`: Accumulator register (11111 = XZR/WZR for non-accumulating forms)
- `o0`: Add/subtract selector for MADD/MSUB

## References

- ARM Architecture Reference Manual for A-profile architecture
- ARM Instruction Set Reference Guide
- Cranelift: `~/Work/wasmtime/cranelift/codegen/src/isa/aarch64/inst.isle`
