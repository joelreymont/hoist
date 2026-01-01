# AArch64 Divide Instructions

Reference documentation for ARM64 divide instruction encodings and semantics.

## SDIV - Signed Divide

**Syntax:** `SDIV Xd, Xn, Xm` or `SDIV Wd, Wn, Wm`

**Operation:** `Xd = Xn / Xm` (signed integer division)

**Encoding (64-bit):**
```
31 30 29 28 27 26 25 24 23 22 21 20-16 15-12 11 10 9-5  4-0
1  0  0  1  1  0  1  0  1  1  0  Rm    0  0  0  0  1  Rn   Rd
```

**Encoding (32-bit):**
```
31 30 29 28 27 26 25 24 23 22 21 20-16 15-12 11 10 9-5  4-0
0  0  0  1  1  0  1  0  1  1  0  Rm    0  0  0  0  1  Rn   Rd
```

**Notes:**
- Truncates quotient toward zero (C99 division semantics)
- Division by zero: Result is zero (no trap/exception)
- Overflow case (INT_MIN / -1): Result is INT_MIN
- Remainder is discarded (use MSUB to compute remainder)

**Example:**
```asm
SDIV X3, X10, X5    // X3 = X10 / X5 (signed)
SDIV W3, W10, W5    // W3 = W10 / W5 (signed, 32-bit)
```

## UDIV - Unsigned Divide

**Syntax:** `UDIV Xd, Xn, Xm` or `UDIV Wd, Wn, Wm`

**Operation:** `Xd = Xn / Xm` (unsigned integer division)

**Encoding (64-bit):**
```
31 30 29 28 27 26 25 24 23 22 21 20-16 15-12 11 10 9-5  4-0
1  0  0  1  1  0  1  0  1  1  0  Rm    0  0  0  0  0  Rn   Rd
```

**Encoding (32-bit):**
```
31 30 29 28 27 26 25 24 23 22 21 20-16 15-12 11 10 9-5  4-0
0  0  0  1  1  0  1  0  1  1  0  Rm    0  0  0  0  0  Rn   Rd
```

**Notes:**
- Unsigned division (treats operands as unsigned integers)
- Division by zero: Result is zero (no trap/exception)
- Remainder is discarded (use MSUB to compute remainder)

**Example:**
```asm
UDIV X3, X10, X5    // X3 = X10 / X5 (unsigned)
UDIV W3, W10, W5    // W3 = W10 / W5 (unsigned, 32-bit)
```

## Computing Remainder

ARM64 does not have dedicated remainder instructions. To compute remainder:

**Signed remainder (srem):**
```asm
SDIV X_temp, Xn, Xm        // temp = n / m
MSUB Xd, X_temp, Xm, Xn    // d = n - (temp * m)
```

**Unsigned remainder (urem):**
```asm
UDIV X_temp, Xn, Xm        // temp = n / m
MSUB Xd, X_temp, Xm, Xn    // d = n - (temp * m)
```

This is typically implemented as a single pseudo-instruction in assemblers or as a lowering pattern in compilers.

## Encoding Summary

Both divide instructions use the "Data-processing (2 source)" class with opcode field `11010110`:

| Instruction | sf | op | S | opcode2 | opcode |
|-------------|----|----|---|---------|--------|
| SDIV        | x  | 0  | 0 | 00001   | 110    |
| UDIV        | x  | 0  | 0 | 00000   | 110    |

Where:
- `sf`: 1 for 64-bit (X registers), 0 for 32-bit (W registers)
- `op`: Always 0 for divide
- `S`: Always 0 for divide
- `opcode2`: bits 15-11, distinguishes signed (00001) from unsigned (00000)
- `opcode`: bits 10-5, always `110` (0b000110) for divide

Field layout in 32-bit instruction word:
```
[31]    sf
[30]    0
[29]    S (always 0)
[28-21] 0b11010110 (fixed opcode field)
[20-16] Rm (divisor register)
[15-11] opcode2 (00000=UDIV, 00001=SDIV)
[10]    Always 1
[9-5]   Rn (dividend register)
[4-0]   Rd (destination register)
```

## Performance Notes

- Divide latency varies by implementation (typically 4-20 cycles)
- Much slower than multiply (which is typically 1-3 cycles)
- Consider strength reduction for constant divisors:
  - Powers of 2: Use shift right (LSR for unsigned, ASR for signed)
  - Other constants: Multiply by reciprocal (magic number technique)

## References

- ARM Architecture Reference Manual for A-profile architecture (ARMv8)
- ARM Instruction Set Reference Guide
- Cranelift: `~/Work/wasmtime/cranelift/codegen/src/isa/aarch64/inst.isle`
