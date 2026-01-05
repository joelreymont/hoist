# ARM64 E2E Failure Analysis

**Date**: 2026-01-05
**Status**: Root cause investigation in progress

## Problem Statement

ARM64 E2E JIT tests are failing - all tests return 0 instead of expected values.

Example failures:
- Test "return 42" → returns 0
- Test "add(5, 7)" → returns 0
- Test "multiply(3, 4)" → returns 0

## Investigation Completed

### 1. Register Rewriting Status ✓ COMPLETE

**Finding**: Register rewriting is COMPLETE for all emitted instruction types.

**Evidence**:
- Total instruction variants defined: 219
- Instruction types emitted in MVP: 5 (mov_imm, mov_rr, add_rr, mul_rr, ret/nop)
- Instruction types with rewriting: 5/5 (100%)

**Source locations**:
- Instruction definitions: `src/backends/aarch64/inst.zig` (219 variants)
- Emission site: `src/codegen/compile.zig:675-848` (only 5 types emitted)
- Rewriting logic: `src/codegen/compile.zig:518-579` (all 5 types covered)

**Rewriting implementation**:
```zig
.mov_imm => dst vreg→preg
.mov_rr  => dst vreg→preg, src vreg→preg
.add_rr  => dst vreg→preg, src1 vreg→preg, src2 vreg→preg
.mul_rr  => dst vreg→preg, src1 vreg→preg, src2 vreg→preg
.ret     => no registers to rewrite
.nop     => no registers to rewrite
```

**Conclusion**: Incomplete register rewriting is NOT the root cause.

### 2. Debug Infrastructure Added ✓

**Added in `src/codegen/compile.zig`**:

Lines 477-495: Register allocation debug output
```zig
std.debug.print("\n=== REGISTER ALLOCATIONS ===\n", .{});
// Prints: v{vreg} → p{preg} (hw={hwenc})
```

Lines 510-590: Post-rewrite instruction debug output
```zig
std.debug.print("=== POST-REWRITE INSTRUCTIONS ===\n", .{});
// Prints each instruction with operands after vreg→preg substitution
```

**Purpose**: Will show exactly what vregs are allocated to which pregs, and what the final instructions look like before emission.

### 3. ABI Verification Test Added ✓

**Added in `tests/e2e_jit.zig:109-169`**: Critical test using hand-written ARM64 machine code.

**Test design**:
```asm
movz w0, #123    ; 0x52800f6f - load immediate 123 into w0
ret              ; 0xd65f03c0 - return
```

**Purpose**:
- Verifies Zig can correctly call JIT-compiled ARM64 code
- Confirms w0 is read as the return value
- Tests calling convention at the most basic level
- If this fails → calling convention is fundamentally broken

**Status**: Test added but not yet executed (test suite hangs)

### 4. VReg/PReg Collision Bug ✓ FIXED

**Previously identified and fixed**:
- VRegs 0-191 were colliding with PReg namespace
- Fixed by offsetting VReg indices by PINNED_VREGS (192)
- Commit: ab54e67

### 5. Instruction Cache Coherency ✓ FIXED

**Previously identified and fixed**:
- ARM64 requires explicit icache flush for JIT code
- Fixed by adding `sys_icache_invalidate()` call
- Location: `tests/e2e_jit.zig:60-67`
- Commit: c3108b3

## Outstanding Hypotheses (Not Yet Tested)

### Hypothesis 1: Calling Convention Mismatch (HIGH PRIORITY)

**Theory**: Zig may not be correctly reading w0 as the ARM64 C calling convention return value.

**How to test**:
1. Run the ABI verification test (hand-written machine code)
2. If it returns 123 → calling convention works, bug is elsewhere
3. If it returns 0 → calling convention is broken

**Required action**: Execute `e2e_jit.zig` ABI verification test

### Hypothesis 2: Instruction Encoding Bugs (MEDIUM PRIORITY)

**Theory**: One or more instruction encodings may be incorrect.

**How to test**:
1. Add unit tests for each instruction encoding
2. Compare against ARM Architecture Reference Manual
3. Disassemble generated code with `objdump` or `lldb`
4. Verify each instruction matches expected encoding

**Required action**:
- Implement encoding unit tests (P1.1)
- Disassemble actual generated code (P0.3)

### Hypothesis 3: Register Allocator Issues (LOW PRIORITY)

**Theory**: Trivial allocator may be placing return value in wrong register.

**Counter-evidence**:
- Allocator is extremely simple (sequential allocation)
- Debug output shows allocations
- Should be visible in debug output

**How to test**: Run tests with debug output enabled

## Next Steps (In Priority Order)

1. **[P0.5] Run ABI verification test** - CRITICAL
   - Execute the hand-written machine code test
   - Confirms if calling convention works at all
   - If fails → calling convention is root cause
   - If passes → bug is in our code generation

2. **[P0.2] Add simplest test with debug output**
   - Test: `fn() -> i32 { return 42; }`
   - Run with debug infrastructure enabled
   - Examine register allocations and post-rewrite instructions
   - Print generated machine code bytes

3. **[P0.3] Disassemble generated code**
   - Extract hex bytes from test output
   - Disassemble with `objdump -D -b binary -m aarch64`
   - Compare against expected code:
     ```asm
     movz w0, #42    ; should be: 52 80 05 40
     ret             ; should be: c0 03 5f d6
     ```

4. **[P0.4] Verify icache flush**
   - Add debug output to confirm flush is called
   - Ensure memory address and length are correct

5. **[P0.7] Document findings** (this document)
   - Update with test results
   - Identify root cause with evidence
   - Create fix plan

## Test Infrastructure Issue

**Problem**: `zig build test` hangs indefinitely

**Attempted workarounds**:
- Tried `timeout` wrapper → still hangs
- Tried building first → succeeds, but test execution hangs
- Tried targeting specific test files → requires build system

**Current blocker**: Cannot execute tests to gather evidence

**Potential causes**:
- One of the E2E test files has an infinite loop
- Deadlock in test runner
- Issue with test file configuration

**Workarounds**:
1. Manually write test executables (not using test framework)
2. Add timeout to individual test functions
3. Identify which test file causes hang (binary search)

## Current Blockers

1. ✗ Test execution hangs - cannot run ABI verification test
2. ✗ Cannot gather debug output from actual test runs
3. ✗ Cannot disassemble generated code (need test output)

## Resolved Items

1. ✓ Register rewriting completeness - confirmed complete
2. ✓ Debug infrastructure - added and compiles
3. ✓ ABI verification test - added and compiles
4. ✓ VReg/PReg collision - previously fixed
5. ✓ Instruction cache - previously fixed

## Summary

**What we know**:
- Register rewriting is complete for all emitted instructions
- Debug infrastructure is in place
- ABI verification test is ready
- Previously fixed: VReg/PReg collision and icache flush

**What we don't know**:
- Root cause of E2E failures (all return 0)
- Whether calling convention works
- Whether instruction encodings are correct
- Actual register allocations in failing tests
- Actual generated machine code

**Critical blocker**: Test execution hangs - need to resolve before gathering evidence

**Most likely root causes** (ranked):
1. Calling convention mismatch (ABI test will confirm/deny)
2. Instruction encoding bugs (disassembly will reveal)
3. Register allocator putting return in wrong register (debug output will show)

**Next session**:
1. Resolve test hang issue
2. Run ABI verification test
3. Examine debug output from simplest test
4. Disassemble generated code
5. Update this document with findings and root cause

## CRITICAL DISCOVERY (2026-01-05 - Session 2)

### ABI Verification Test Results

**Test execution**: Standalone test successfully executed

**Result**: ✓ **ABI CALLING CONVENTION WORKS CORRECTLY**

**Evidence**:
- Hand-written ARM64 machine code: `movz w0, #123; ret`
- Correct encoding: `60 0f 80 52 c0 03 5f d6`
- Test returned: 123 (expected value)
- Conclusion: Zig correctly calls JIT code and reads w0 as return value

**Bug found in test itself**:
- Original encoding was `0x6f` (targeted w15) instead of `0x60` (targets w0)
- This caused test to return garbage (38333224) initially
- Fixed in commit 9026481

### Eliminated Hypotheses

1. ~~Calling convention mismatch~~ - ELIMINATED (ABI test passes)
2. ~~Icache flush not working~~ - ELIMINATED (ABI test confirms flush works)
3. ~~Incomplete register rewriting~~ - ELIMINATED (all 5 emitted types have rewriting)
4. ~~Vregs reaching emit~~ - PROTECTED (hwEnc panics on vregs)

### Remaining Hypotheses

**Hypothesis 1: Instruction Encoding Bugs (HIGH PRIORITY)**

The emit code structure looks correct, but we need to verify actual encodings:
- emitMovImm: line 364 - encoding looks correct
- emitMovz: line 381 - encoding looks correct  
- hwEnc: line 327 - CRITICAL: panics if vreg slips through

**How to test**: Run E2E tests with debug output to see actual generated bytes

**Hypothesis 2: IR Generation Issues (MEDIUM PRIORITY)**

The lowering/IR generation may be creating incorrect instruction sequences.

**How to test**: Examine debug output showing:
- Register allocations
- Post-rewrite instructions
- Generated machine code bytes

### Next Steps (UPDATED)

1. **[CRITICAL] Run E2E tests with debug output**
   - Need to resolve test hang issue first
   - OR create standalone version of simplest test (return 42)
   - Examine actual generated machine code bytes
   - Compare against expected encoding

2. **[P0.2] Create standalone "return 42" test**
   - Bypass test framework hang issue
   - Use our actual compiler to generate code
   - Print generated bytes
   - Disassemble and verify

3. **[P1.1] Add encoding verification tests**
   - Unit test each instruction encoding
   - Compare against ARM reference
   - Ensure emitMovImm, emitMovRR, emitAddRR, emitMulRR all correct

4. **[P0.3] Disassemble generated code**
   - Extract hex bytes from test output
   - Use objdump/llvm-objdump to verify
   - Compare against expected assembly

### Test Infrastructure Issue (UPDATED)

**Status**: Still blocking - need workaround

**Proposed solution**: Create standalone executable (not test) that:
1. Uses our compiler to compile `fn() -> i32 { return 42; }`
2. Prints generated machine code bytes  
3. Executes the JIT code
4. Prints result
5. No test framework - just a main() function

This bypasses the test hang and lets us gather the critical evidence we need.

## ROOT CAUSE FOUND (2026-01-05 - Session 3)

### Bug 1: Missing OPC Field in ORR Encoding ✓ FIXED

**Location**: `src/backends/aarch64/emit.zig:345-359` (emitMovRR function)

**Root cause**: The ORR (register) instruction encoding was missing the OPC field (bits [30:29]).

**Correct encoding**: `sf|opc|01010|shift|N|Rm|imm6|Rn|Rd`
- sf[31]: size flag (0=32-bit, 1=64-bit)
- opc[30:29]: opcode (01 for ORR)
- fixed[28:24]: 01010 (logical shifted register)
- shift[23:22]: shift type (00=LSL, 01=LSR, 10=ASR, 11=ROR)
- N[21]: NOT flag (0 for ORR)
- Rm[20:16]: source register
- imm6[15:10]: shift amount
- Rn[9:5]: second source register (31=wzr/xzr)
- Rd[4:0]: destination register

**Bug**: Code only set `(0b01010 << 24)`, missing `(0b01 << 29)` for OPC field.

**Generated bytes**:
- Before (wrong): `e0 03 00 0a` (opc=00)
- After (correct): `e0 03 00 2a` (opc=01)

**Fix**: Added `(0b01 << 29)` to set OPC field to 01.

**Commit**: 606261d

### Bug 2: Redundant MOV Generation ✓ FIXED

**Location**: `src/codegen/compile.zig:770-803` (return handling)

**Root cause**: Return handling unconditionally emits `mov x0, return_vreg`. The trivial register allocator allocates the return vreg to x0, creating a redundant `mov x0, x0`.

**Evidence**:
- MOVZ encoding verified correct: `movz w0, #42; ret` returns 42 ✓
- With redundant MOV: `movz w0, #42; orr w0, wzr, w0; ret` returned 0 ✗ (due to Bug 1)
- After Bug 1 fixed: redundant MOV works but wastes 4 bytes

**Fix**: Added check at emission time (after register rewriting) to skip MOV if src and dst are the same physical register.

**Code reduced**:
- Before: 12 bytes (movz + orr + ret)
- After: 8 bytes (movz + ret)

**Commit**: 26a710a

### Summary of Session

**Bugs found and fixed**:
1. ✓ ORR encoding missing OPC field → all ORR instructions were wrong
2. ✓ Redundant MOV generation → wasted 4 bytes per function

**Testing methodology**:
1. Created standalone E2E test to bypass test framework hang
2. Manually decoded all generated instructions
3. Created test with exact byte sequences to isolate the bug
4. Tested variants to identify which instruction was wrong
5. Used Python to decode and verify encodings against ARM manual

**Key insights**:
- The MOVZ encoding was always correct
- The bug was in the OPC field of ORR, not the shift field
- Testing with different register combinations revealed the pattern
- Redundant MOV was harmless after Bug 1 was fixed, but wastes space

**Verification**:
- Standalone E2E test now passes ✓
- Generated code is optimal (8 bytes instead of 12)
- All encodings verified against ARM Architecture Reference Manual

### Next Steps

1. Run full E2E test suite to verify all tests pass
2. Add encoding unit tests to catch similar bugs
3. Remove debug output from compile.zig
4. Clean up temporary test files in /tmp
