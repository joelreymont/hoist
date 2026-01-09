# Exception Handling ABI for try_call

This document defines the exception handling ABI for `try_call` instructions in Hoist JIT.

## Overview

The `try_call` instruction performs a function call with exception handling support. It has two successors:
- **normal_successor**: Execution continues here if the call completes normally
- **exception_successor**: Execution jumps here if the call throws an exception

## Exception Handling Mechanism

Hoist uses **DWARF-based exception handling** via stack unwinding, consistent with system ABIs.

### Runtime Flow

1. **Call Execution**: `try_call` emits a `BL` instruction to the callee
2. **Normal Return**: Callee returns normally, execution continues to `normal_successor`
3. **Exception Thrown**: Callee (or transitive callee) throws an exception:
   - Runtime begins stack unwinding using `.eh_frame` CFI
   - Consults LSDA (Language Specific Data Area) for exception handlers
   - Finds `try_call` site in LSDA call site table
   - Jumps to landing pad (exception_successor) address
   - Exception object pointer passed in X0 (per AAPCS64)

### No Explicit Check Required

**CRITICAL**: Unlike some designs, there is **no conditional branch after BL**.

The exception handling is performed by the **runtime unwinder**, not explicit compiler-generated checks. The compiler's responsibilities are:

1. **Populate LSDA**: Map try_call PC range → landing pad PC
2. **Generate .eh_frame**: Register exception handlers with runtime
3. **Emit Landing Pad Code**: Code at exception_successor to handle exception

### Why No Conditional Branch?

Traditional exception handling ABIs (C++, Itanium ABI) use:
- **Personality routines**: Runtime function that processes LSDA
- **Stack unwinding**: Walks call stack via CFI until handler found
- **Automatic jump**: Unwinder restores registers and jumps to landing pad

The compiler does NOT emit:
```assembly
BL  callee
CBZ X0, exception_handler  // ❌ NOT DONE - unwinder handles this
// fall through to normal successor
```

Instead, the control flow is:
```assembly
BL  callee                  // ✅ Just the call
// If exception: unwinder consults LSDA, jumps to landing pad
// If normal: execution continues to next instruction (normal successor)
```

## Current Implementation Status

### ✅ Complete

1. **LSDA Generation** (src/codegen/compile.zig:6900-6933):
   - Scans function for try_call instructions
   - Queries MachBuffer for PC offsets of try_call block and exception_successor
   - Populates LSDA with call site entries: `[try_call_offset, length=4, landing_pad_offset]`
   - Heap-allocates LSDA and attaches to FDE

2. **.eh_frame Generation** (src/codegen/compile.zig:6853-6950):
   - Creates CIE (Common Information Entry) with aarch64 parameters
   - Creates FDE (Frame Description Entry) per function
   - Attaches LSDA to FDE augmentation data
   - Registers .eh_frame with runtime via `__unw_add_dynamic_eh_frame_section`

3. **Block Label Tracking** (src/codegen/compile.zig:605-629):
   - Binds MachLabel at start of each VCode block
   - Registers IR block → label mapping in MachBuffer
   - Enables PC offset queries for LSDA population

### ❌ Not Needed

**Explicit exception flag checks**: The DWARF unwinding mechanism handles control transfer automatically.

## Lowering Behavior

### Current Implementation

```zig
// src/backends/aarch64/isle_helpers.zig:3611-3629
pub fn aarch64_try_call(...) !ValueRegs {
    // Delegates to aarch64_call for BL emission
    return aarch64_call(sig_ref, name, args, ctx);
}
```

The `try_call` lowering is functionally identical to `call` - both emit:
1. Argument marshaling (per AAPCS64)
2. `BL` instruction to callee
3. Return value unmarshaling

**The difference is metadata, not code**:
- `call`: No LSDA entry
- `try_call`: LSDA entry maps [call_site_pc, 4, landing_pad_pc]

### Block Successors

Currently, the `try_call` instruction's normal_successor and exception_successor are NOT used during lowering because:

1. **Normal successor**: Implicitly the next instruction (fall-through)
2. **Exception successor**: Runtime unwinder jumps there via LSDA lookup

The successors ARE used for:
- LSDA generation (to find landing pad PC offset)
- CFG analysis (optimizer needs to know control flow)
- Dominance analysis

## Landing Pad Implementation

The `exception_successor` block is a **landing pad** that receives control when an exception is caught.

### ABI Requirements

Per AAPCS64 and Itanium Exception Handling ABI:
- **X0**: Pointer to exception object (or selector value)
- **Stack**: Unwinder has restored frame state per CFI instructions
- **Registers**: Callee-saved registers restored

### Landing Pad Code

The compiler should emit code in the exception_successor block to:
1. **Extract exception info** from X0
2. **Handle or rethrow** the exception
3. **Clean up** local resources if needed

Example IR:
```
block1:
    v1 = try_call @foo(), normal=block2, exception=block3

block2:  // normal_successor
    // Normal execution continues

block3:  // exception_successor (landing pad)
    v2 = landing_pad    // Gets exception object from unwinder (X0)
    // Handle exception or propagate
```

## References

- [docs/dwarf-unwind.md](./dwarf-unwind.md) - Comprehensive DWARF CFI documentation
- [Itanium C++ ABI Exception Handling](https://itanium-cxx-abi.github.io/cxx-abi/exceptions.pdf)
- [LLVM Exception Handling](https://llvm.org/docs/ExceptionHandling.html)
- [C++ Exception Handling ABI](https://maskray.me/blog/2020-12-12-c++-exception-handling-abi)

## Implementation Checklist

- [x] LSDA generation with try_call PC ranges
- [x] FDE attachment of LSDA via augmentation data
- [x] Block label binding for PC offset queries
- [x] .eh_frame registration with runtime
- [ ] landing_pad instruction for exception object access (future)
- [ ] Personality routine registration (if custom needed)
- [ ] Exception propagation tests

## Design Decision: Why DWARF, Not Explicit Checks?

**Alternative Considered**: Emit conditional branch after each try_call:
```assembly
BL  callee
CBNZ X0, exception_handler
```

**Rejected because**:
1. **Not standard**: C++ and other languages use DWARF unwinding
2. **Requires ABI change**: Callees must set X0 to signal exceptions
3. **Breaks interop**: Can't call standard library functions with try_call
4. **Slower**: Extra branch on every try_call, even if exception never thrown
5. **More code**: Conditional branch + unconditional branch to normal successor

**DWARF approach**:
1. **Zero overhead**: No extra instructions on normal path
2. **Standard ABI**: Compatible with system libraries
3. **Smaller code**: Just BL, no branches
4. **Runtime unwinding**: Complexity in runtime, not generated code
