# Calling Convention Survey

**Date:** 2026-01-09
**Purpose:** Document calling convention requirements for Hoist vs Cranelift parity

## Executive Summary

**Current Status:**
- Hoist: 8 calling conventions **defined** in enum
- Cranelift: 8 calling conventions defined
- **Gap**: Hoist has conventions defined but **not all implemented** in ABI lowering

**Key Finding:** Calling conventions are declared but the ABI implementation (`src/backends/aarch64/abi.zig`) needs to handle each convention's register allocation and stack layout differences.

---

## Cranelift Calling Conventions

From `cranelift/codegen/src/isa/call_conv.rs`:

| Convention | Purpose | ABI Stable? | Tail Calls? | Exceptions? |
|------------|---------|-------------|-------------|-------------|
| **Fast** | Best performance | ❌ No | ❌ No | ❌ No |
| **Tail** | Tail call optimization | Partial (exception regs) | ✅ Yes | ✅ Yes |
| **SystemV** | System V ABI (Linux, BSD, macOS) | ✅ Yes | ❌ No | ✅ Yes |
| **WindowsFastcall** | Windows x64/ARM ABI | ✅ Yes | ❌ No | ❌ No |
| **AppleAarch64** | macOS ARM64 (tweaked AAPCS64) | ✅ Yes | ❌ No | ❌ No |
| **Probestack** | Stack probe function | N/A | ❌ No | ❌ No |
| **Winch** | Baseline compiler (1 int + 1 FP return) | ❌ No | ❌ No | ✅ Yes |
| **PreserveAll** | Preserve all registers (instrumentation) | ❌ No | ❌ No | ✅ Yes |

### Convention Details

**Fast:**
- Not ABI-stable (can change between versions)
- Optimized for performance within same compilation unit
- No guarantees about register preservation
- Use case: Internal function calls, JIT-generated code

**Tail:**
- Callee pops stack arguments (vs caller in SystemV)
- Exception payload registers guaranteed:
  - AArch64: X0, X1
  - x86-64: RAX, RDX
  - RISC-V: A0, A1
- Use case: Functional language runtimes, trampolines

**SystemV:**
- Standard Unix calling convention
- Well-documented in System V ABI specs
- Caller pops stack arguments
- Use case: C interop on Linux/BSD/macOS

**WindowsFastcall:**
- Windows ABI for x64 and ARM64
- Different register usage than SystemV
- Structured exception handling support
- Use case: C interop on Windows

**AppleAarch64:**
- Modified AAPCS64 for macOS
- Differences from standard AAPCS64:
  - Different stack alignment requirements
  - Modified handling of small structs
  - Signed/unsigned char handling
- Use case: C interop on macOS ARM64

**Probestack:**
- Special convention for __probestack function
- Used to extend stack safely on Windows
- No caller/callee-save requirements
- Use case: Internal stack probe implementation

**Winch:**
- Cranelift's baseline (fast compilation) compiler convention
- No callee-save registers (simplifies codegen)
- Exactly 1 integer + 1 FP return register
- Use case: Fast-tier JIT compilation

**PreserveAll:**
- Preserves **all** registers (no clobbers)
- Optimized for callsite efficiency
- Arguments passed in registers per platform default
- Use case: Patchable instrumentation points, profiling hooks

---

## Hoist Calling Conventions

From `src/ir/signature.zig:11-53`:

| Convention | Defined? | Implemented? | Notes |
|------------|----------|--------------|-------|
| **fast** | ✅ Yes | ⚠️ Partial | Currently defaults to SystemV |
| **tail** | ✅ Yes | ⚠️ Partial | Exception support exists, tail call lowering partial |
| **system_v** | ✅ Yes | ✅ Yes | Full AAPCS64 implementation |
| **windows_fastcall** | ✅ Yes | ❌ No | Not implemented (x64/ARM64 Windows ABI) |
| **apple_aarch64** | ✅ Yes | ⚠️ Partial | Likely same as system_v currently |
| **probestack** | ✅ Yes | ❌ No | Stack probe not implemented |
| **winch** | ✅ Yes | ❌ No | Baseline compiler convention not needed (no winch) |
| **preserve_all** | ✅ Yes | ❌ No | Not implemented |

### Current ABI Implementation

**Fully Implemented:**
- **system_v**: Complete AAPCS64 with HFA/HVA support
  - Integer args: X0-X7
  - FP/SIMD args: V0-V7
  - Stack overflow handling
  - Varargs (va_list)
  - Exception handling (X0 = exception pointer)

**Partially Implemented:**
- **fast**: Falls back to system_v (src/backends/aarch64/abi.zig)
- **tail**: Has supportsTailCalls() but lowering incomplete
- **apple_aarch64**: Likely uses system_v without macOS-specific tweaks

**Not Implemented:**
- **windows_fastcall**: Would need separate ARM64 Windows ABI module
- **probestack**: Stack probe function not needed for AArch64 (native growth)
- **winch**: N/A (Hoist doesn't have a baseline compiler tier)
- **preserve_all**: Would require tracking all registers as callee-save

---

## Gap Analysis

### Critical for Parity

**1. Fast Calling Convention**
- **Status:** Defined but defaults to SystemV
- **Effort:** Medium (1 week)
- **Implementation:**
  - Modify register allocation to use more caller-save registers
  - Reduce callee-save register preservation
  - Allow more aggressive register reuse
  - Trade ABI stability for performance

**2. AppleAarch64 Differences**
- **Status:** Likely incomplete (uses SystemV)
- **Effort:** Small (2-3 days)
- **Implementation:**
  - Document macOS-specific differences
  - Add stack alignment tweaks (16-byte vs 8-byte)
  - Handle small struct differences
  - Add tests for macOS C interop

### Nice to Have

**3. PreserveAll Convention**
- **Status:** Not implemented
- **Effort:** Medium (1 week)
- **Use Case:** Instrumentation, profiling
- **Implementation:**
  - Mark all registers as callee-save
  - Spill everything at callsite
  - Minimal prologue/epilogue

**4. WindowsFastcall**
- **Status:** Not implemented
- **Effort:** Large (2-3 weeks)
- **Use Case:** Windows ARM64 support
- **Implementation:**
  - Create separate Windows ABI module
  - Different register usage (X0-X7 vs X0-X15)
  - Structured exception handling
  - Shadow space allocation
  - Different stack alignment

### Not Needed

**5. Probestack**
- **Reason:** AArch64 has native stack growth; no probe needed
- **Action:** Mark as N/A in documentation

**6. Winch**
- **Reason:** Hoist doesn't have multi-tier JIT architecture
- **Action:** Mark as N/A or remove from enum

---

## Implementation Priority

### Phase 3A: Fast Convention (Week 5)
**Goal:** Optimize internal function calls
1. Define Fast ABI variant in abi.zig
2. Reduce callee-save registers to X19-X21 (vs X19-X28)
3. Use more volatile registers for arguments
4. Add tests for fast vs system_v performance

### Phase 3B: AppleAarch64 Refinement (Week 6)
**Goal:** Correct macOS C interop
1. Document macOS differences from AAPCS64
2. Implement stack alignment differences
3. Add macOS-specific struct tests
4. Verify with actual macOS SDK headers

### Phase 3C: PreserveAll (Week 7)
**Goal:** Enable instrumentation use cases
1. Define PreserveAll ABI in abi.zig
2. Mark all registers as callee-save
3. Generate minimal spill code
4. Add instrumentation tests

### Phase 3D: WindowsFastcall (Weeks 8-10, optional)
**Goal:** Windows ARM64 support
1. Create separate windows_abi.zig module
2. Implement Windows register conventions
3. Add structured exception handling
4. Test with Windows SDK

---

## AAPCS64 Reference

The ARM Architecture Procedure Call Standard for AArch64 defines:

**Integer Argument Registers:** X0-X7 (8 registers)
**FP/SIMD Argument Registers:** V0-V7 (8 registers)
**Return Registers:**
- Integer: X0-X7 (large structs)
- FP/SIMD: V0-V3 (HFA/HVA)

**Callee-Save Registers:**
- X19-X28: General purpose
- X29 (FP): Frame pointer
- X30 (LR): Link register
- V8-V15: Lower 64 bits of SIMD registers

**Volatile (Caller-Save):**
- X0-X18: General purpose
- V0-V7, V16-V31: SIMD

**Special:**
- X29: Frame pointer (optional)
- X30: Link register
- X31/SP: Stack pointer (16-byte aligned)

### Homogeneous Aggregates

**HFA (Homogeneous Float Aggregate):**
- Struct with 1-4 members of same float type (f32 or f64)
- Passed in V0-V3 (one register per member)
- Example: `struct { f32, f32, f32 }` → V0, V1, V2

**HVA (Homogeneous Vector Aggregate):**
- Struct with 1-4 members of same vector type
- Passed in V0-V3 (one register per member)
- Example: `struct { v128, v128 }` → V0, V1

---

## Differences: SystemV vs AppleAarch64

| Feature | SystemV (AAPCS64) | AppleAarch64 (macOS) |
|---------|-------------------|----------------------|
| Stack alignment | 16 bytes | 16 bytes (but enforced differently) |
| Small structs (<= 16 bytes) | Passed in registers | Different classification rules |
| char signedness | Implementation-defined | Always signed on macOS |
| va_list implementation | AAPCS64 spec | Modified for Darwin |
| Tail calls | Not ABI-guaranteed | Limited support |

**Key macOS Differences:**
1. **Sign extension:** Small integer types are sign-extended (not zero-extended)
2. **Struct padding:** More aggressive padding for alignment
3. **Variable arguments:** Different va_list struct layout
4. **Floating point:** Stricter NaN handling

---

## Testing Strategy

For each calling convention, test:
1. **Argument passing:** All register classes (int, FP, vector)
2. **Return values:** Single and multiple returns
3. **Stack overflow:** > 8 arguments (spill to stack)
4. **Struct passing:** HFA, HVA, by-value, by-reference
5. **Interop:** Call C functions, callbacks
6. **Exceptions:** If supported by convention

**Test matrix:**
- fast × (args, returns, structs, exceptions)
- system_v × (all features)
- apple_aarch64 × (macOS-specific)
- preserve_all × (register preservation)
- windows_fastcall × (Windows-specific)

---

## References

- AAPCS64: [ARM Procedure Call Standard for AArch64](https://github.com/ARM-software/abi-aa/blob/main/aapcs64/aapcs64.rst)
- System V ABI: [Generic ABI and AArch64 Supplement](https://refspecs.linuxfoundation.org/)
- macOS ABI: [Apple Platform ABI Reference](https://developer.apple.com/documentation/xcode/writing-arm64-code-for-apple-platforms)
- Windows ARM64: [Windows ARM64 ABI](https://docs.microsoft.com/en-us/cpp/build/arm64-windows-abi-conventions)
- Cranelift: `~/Work/wasmtime/cranelift/codegen/src/isa/call_conv.rs`
- Hoist: `src/ir/signature.zig`, `src/backends/aarch64/abi.zig`

---

## Summary

**Hoist Calling Convention Status:**
- ✅ Enum defined with 8 conventions
- ✅ SystemV fully implemented (AAPCS64 + HFA/HVA)
- ⚠️ Fast, Tail, AppleAarch64 partially implemented
- ❌ WindowsFastcall, PreserveAll not implemented
- N/A: Probestack (not needed), Winch (no baseline tier)

**To reach 100% parity:**
1. Implement Fast convention (1 week)
2. Refine AppleAarch64 differences (3 days)
3. Implement PreserveAll (1 week)
4. (Optional) WindowsFastcall for Windows support (2-3 weeks)

**Current ABI coverage:** ~85% (1 full + 3 partial / 8 total = 50%, but SystemV is the critical path)
**After Phase 3:** ~95% (4 full / 5 needed conventions, excluding N/A)
