# DWARF Call Frame Information (CFI) for Exception Handling

This document covers DWARF 4 Call Frame Information used for stack unwinding and exception handling in JIT-compiled code.

## Overview

DWARF Call Frame Information (CFI) enables runtime systems to:
- Reconstruct frame pointers during stack unwinding
- Find return addresses when traversing the call stack
- Handle exceptions by identifying landing pads
- Restore register states across function calls

CFI is stored in the `.eh_frame` section of executables and shared libraries.

## Structure

The `.eh_frame` section contains CFI records organized hierarchically:

```
.eh_frame section:
├── CIE (Common Information Entry) - shared prologue info
│   ├── FDE (Frame Description Entry) - function 1
│   ├── FDE (Frame Description Entry) - function 2
│   └── FDE (Frame Description Entry) - function 3
├── CIE (Common Information Entry) - different calling convention
│   └── FDE (Frame Description Entry) - function 4
...
```

### Common Information Entry (CIE)

CIE records contain starting information common to multiple FDEs, factored out for compactness.

**Structure:**
- `length` - Size of the CIE structure (excluding length field itself)
- `CIE_id` - Always 0 (distinguishes CIE from FDE)
- `version` - DWARF version (1 for DWARF 4)
- `augmentation` - String describing extensions (e.g., 'zR' for pointer encoding)
- `code_alignment_factor` - Instruction alignment (4 for aarch64)
- `data_alignment_factor` - Stack growth direction (-8 for aarch64, stack grows down)
- `return_address_register` - Register containing return address (LR/X30 on aarch64)
- `initial_instructions` - CFI instructions for prologue

**aarch64 Typical Values:**
```c
version = 1
augmentation = "zR"
code_alignment_factor = 4    // 4-byte instructions
data_alignment_factor = -8   // Stack grows down, 8-byte slots
return_address_register = 30 // LR register
```

### Frame Description Entry (FDE)

FDE records describe unwinding information for a specific function.

**Structure:**
- `length` - Size of the FDE structure
- `CIE_pointer` - Offset to associated CIE
- `initial_location` - Function start address (PC)
- `address_range` - Function size in bytes
- `instructions` - Function-specific CFI instructions
- `augmentation_data` - Optional LSDA pointer (for exception handling)

**Key Fields:**
```c
pc_begin = 0x1000          // Function start
code_size = 0x200          // Function is 512 bytes
instructions = [           // Unwind instructions
    DW_CFA_def_cfa SP, 0
    DW_CFA_offset LR, -8
    ...
]
```

## CFA (Canonical Frame Address)

The CFA is the value of the stack pointer at the call site in the previous frame. It's the base address for computing locations of saved registers.

**Conceptually:**
```
Current Frame CFA = Previous Frame SP
```

All saved register locations are expressed as offsets from the CFA.

## CFI Opcodes

### DW_CFA_def_cfa (0x0c)

Defines how to compute the CFA: take address from register and add offset.

**Encoding:** `0x0c + ULEB128(register) + ULEB128(offset)`

**Example:**
```c
DW_CFA_def_cfa SP, 16  // CFA = SP + 16
```

**Use Case:** After allocating stack frame of size 16 in the prologue.

### DW_CFA_offset (0x80 | register)

Specifies that a register's previous value is saved at `CFA + (offset * data_alignment_factor)`.

**Encoding:** `(0x80 | register) + ULEB128(offset)`

**Example:**
```c
DW_CFA_offset LR, -1   // LR saved at CFA + (-1 * -8) = CFA - 8
DW_CFA_offset FP, -2   // FP saved at CFA + (-2 * -8) = CFA - 16
```

**Use Case:** Recording where callee-saved registers are spilled in the prologue.

### DW_CFA_remember_state (0x0a)

Pushes the current set of register rules onto an implicit stack.

**Encoding:** Single byte `0x0a`

**Use Case:** Before a code region that temporarily modifies registers (e.g., inline assembly).

### DW_CFA_restore_state (0x0b)

Pops register rules from the implicit stack and restores them.

**Encoding:** Single byte `0x0b`

**Use Case:** After the temporary register modifications, restoring the original rules.

### Other Common Opcodes

- `DW_CFA_advance_loc` (0x40-0x7f) - Advance PC by delta
- `DW_CFA_def_cfa_register` (0x0d) - Change CFA register, keep offset
- `DW_CFA_def_cfa_offset` (0x0e) - Change CFA offset, keep register
- `DW_CFA_restore` (0xc0-0xff) - Restore register to initial state
- `DW_CFA_undefined` (0x07) - Register value is undefined
- `DW_CFA_same_value` (0x08) - Register value unchanged

## ULEB128/SLEB128 Encoding

CFI opcodes use LEB128 (Little Endian Base 128) variable-length encoding for operands.

**ULEB128 (unsigned):**
- 7 bits of data per byte, MSB = continuation flag
- Values 0-127: single byte
- Values 128+: multiple bytes with bit 7 set until last byte

**SLEB128 (signed):**
- Same as ULEB128 but with sign extension
- Bit 6 of last byte is sign bit

**Example:**
```c
624485 in ULEB128 = [0xE5, 0x8E, 0x26]
  0xE5 = 11100101 -> bits 0-6 = 1100101 (continue)
  0x8E = 10001110 -> bits 0-6 = 0001110 (continue)
  0x26 = 00100110 -> bits 0-6 = 0100110 (stop)
  Result = 0100110 0001110 1100101 = 624485
```

## Language Specific Data Area (LSDA)

The LSDA contains exception handling metadata for languages like C++:

**Contents:**
- Try-catch block ranges (which instruction ranges have handlers)
- Landing pad addresses (where to jump when exception is caught)
- Type information (what exception types are caught)
- Cleanup actions (destructors to run during unwinding)

**Structure:**
```
LSDA:
├── Landing Pad Base Address
├── Type Table Pointer
├── Call Site Table
│   ├── Call Site 1: [start_pc, length, landing_pad, action]
│   ├── Call Site 2: [start_pc, length, landing_pad, action]
│   └── ...
└── Action Table (for filtering exception types)
```

**Integration with FDE:**
- FDE's augmentation data contains a pointer to the LSDA
- Referenced via `.cfi_lsda` directive in assembly
- Personality routine uses LSDA to determine exception handling actions

**Call Site Entry:**
```c
struct CallSite {
    uint32_t start_offset;      // PC offset from function start
    uint32_t length;            // Length of try region in bytes
    uint32_t landing_pad_offset; // PC offset to catch handler
    uint32_t action_index;      // Index into action table (0 = cleanup only)
}
```

**Encoding:**
- Offsets encoded as ULEB128
- In `.gcc_except_table` section
- Call site offsets relative to `.cfi_lsda` location (usually function start)

**aarch64 Specifics:**
- For `-fno-pic` code: uses `DW_EH_PE_indirect|DW_EH_PE_pcrel` encoding
- Landing pad address typically in X0 register
- Exception object pointer in X0 per AAPCS64

## Typical Function CFI Example (aarch64)

```assembly
function:
    .cfi_startproc                    // Begin CFI block

    // Prologue
    stp     x29, x30, [sp, #-32]!    // Save FP, LR
    .cfi_def_cfa_offset 32            // CFA = SP + 32
    .cfi_offset x30, -8               // LR at CFA - 8
    .cfi_offset x29, -16              // FP at CFA - 16

    mov     x29, sp                   // Setup frame pointer
    .cfi_def_cfa_register x29         // CFA = FP + 32

    stp     x19, x20, [sp, #16]      // Save callee-saved regs
    .cfi_offset x19, -24              // X19 at CFA - 24
    .cfi_offset x20, -32              // X20 at CFA - 32

    // Function body
    ...

    // Epilogue
    ldp     x19, x20, [sp, #16]      // Restore regs
    ldp     x29, x30, [sp], #32      // Restore FP, LR
    ret

    .cfi_endproc                      // End CFI block
```

**Resulting CFI Instructions:**
```
CIE:
    version = 1
    code_align = 4
    data_align = -8
    return_reg = 30
    initial_instructions = [DW_CFA_def_cfa SP, 0]

FDE:
    initial_location = <function address>
    address_range = <function size>
    instructions = [
        DW_CFA_advance_loc 4
        DW_CFA_def_cfa_offset 32
        DW_CFA_offset LR, -1        // LR at CFA + (-1 * -8) = CFA - 8
        DW_CFA_offset FP, -2        // FP at CFA + (-2 * -8) = CFA - 16
        DW_CFA_advance_loc 4
        DW_CFA_def_cfa_register FP
        DW_CFA_advance_loc 4
        DW_CFA_offset X19, -3       // X19 at CFA - 24
        DW_CFA_offset X20, -4       // X20 at CFA - 32
    ]
```

## JIT Exception Handling Registration

For dynamically generated code (JIT), unwind info must be registered with the runtime.

### Modern Approach: libunwind Dynamic Registration

**Linux and macOS (preferred):**
```c
// Registration
__unw_add_dynamic_eh_frame_section(void* eh_frame_ptr);

// Deregistration
__unw_remove_dynamic_eh_frame_section(void* eh_frame_ptr);
```

**Alternative (legacy):**
```c
// libunwind-specific (Linux)
_U_dyn_register(unw_dyn_info_t* di);
_U_dyn_cancel(unw_dyn_info_t* di);
```

### Legacy Approach: __register_frame

**Linux (libgcc):**
```c
void __register_frame(void* begin);
void __deregister_frame(void* begin);
```

**Caveats:**
- Behavior differs between libgcc and LLVM libunwind
- libunwind expects FDE pointer, libgcc expects eh_frame section start
- Modern code should use `__unw_add_dynamic_eh_frame_section` instead

### Platform Differences

**macOS (Darwin):**
- Supports two formats: DWARF eh_frame and compact-unwind
- x86-64: compiler produces both by default
- arm64 (aarch64): typically only produces compact-unwind
- OrcJIT prefers `__unw_add_dynamic_fde` when available
- Compact-unwind format used by default for exceptions

**Linux:**
- Standard .eh_frame format with DWARF CFI
- libunwind via `__unw_add_dynamic_eh_frame_section`
- C++ exception unwinder via `__register_frame`

### Detection Pattern

```c
// Probe for available registration functions (in order of preference)
#if defined(__APPLE__)
    // macOS: prefer __unw_add_dynamic_fde if available
    if (__unw_add_dynamic_fde) {
        return __unw_add_dynamic_fde(fde_ptr);
    }
#endif

// Fallback: __unw_add_dynamic_eh_frame_section (modern libunwind)
if (__unw_add_dynamic_eh_frame_section) {
    return __unw_add_dynamic_eh_frame_section(eh_frame_ptr);
}

// Fallback: __register_frame (legacy, libgcc)
if (__register_frame) {
    return __register_frame(eh_frame_ptr);
}

// No dynamic registration available
return error;
```

## Exception Handling Flow

1. **Exception Thrown:** Runtime begins stack unwinding
2. **Consult .eh_frame:** Find FDE for current PC
3. **Apply CFI Instructions:** Reconstruct previous frame state
4. **Check LSDA:** Is there a handler for this exception at this PC?
   - **Yes:** Jump to landing pad, continue execution
   - **No:** Continue unwinding to previous frame (goto step 2)
5. **Landing Pad Executed:** Catch handler runs, may:
   - Handle exception (normal execution resumes)
   - Rethrow exception (continue unwinding)
   - Execute cleanup code (destructors)

## References

- [DWARF 4 Specification PDF](https://dwarfstd.org/doc/DWARF4.pdf) - Official standard (see section 6.4)
- [LSB Exception Frames](https://refspecs.linuxfoundation.org/LSB_3.0.0/LSB-Core-generic/LSB-Core-generic/ehframechpt.html) - Linux Standard Base specification
- [CFI Directives in Assembly](https://www.imperialviolet.org/2017/01/18/cfi.html) - Practical guide by Adam Langley
- [GDB and Call Frame Information](https://opensource.com/article/23/3/gdb-debugger-call-frame-active-function-calls) - How debuggers use CFI
- [C++ Exception Handling ABI](https://maskray.me/blog/2020-12-12-c++-exception-handling-abi) - MaskRay's comprehensive guide
- [Stack Unwinding](https://maskray.me/blog/2020-11-08-stack-unwinding) - Deep dive into unwinding mechanics
- [LLVM Exception Handling](https://llvm.org/docs/ExceptionHandling.html) - LLVM implementation details
- [Itanium C++ ABI Exception Handling](https://itanium-cxx-abi.github.io/cxx-abi/exceptions.pdf) - Level 2 ABI specification
- [libunwind Documentation](https://www.nongnu.org/libunwind/) - The libunwind project
- [LLVM ORC JIT Compact Unwind](https://github.com/llvm/llvm-project/pull/123888) - Darwin compact-unwind support
- [GNU Binutils CFI Directives](https://www.sourceware.org/binutils/docs/as/CFI-directives.html) - Assembler directives reference
- [DWARF Standard Website](https://dwarfstd.org/) - Official DWARF committee site

## Implementation Notes for Hoist JIT

### Requirements

1. **CIE Creation:**
   - version = 1
   - augmentation = "zR" (pointer encoding follows)
   - code_align_factor = 4 (aarch64 instruction size)
   - data_align_factor = -8 (stack grows down, 8-byte slots)
   - return_address_register = 30 (LR)

2. **FDE per Function:**
   - initial_location = function address in JIT memory
   - address_range = function size in bytes
   - instructions = CFI opcodes for prologue/epilogue

3. **LSDA for try_call:**
   - Map try_call instruction PC ranges to landing pad addresses
   - Encode as ULEB128 pairs
   - Link via FDE augmentation data

4. **.eh_frame Section:**
   - Allocate after code emission
   - Write: [CIE] [FDE1] [FDE2] ...
   - 8-byte alignment required
   - Register with `__unw_add_dynamic_eh_frame_section`

5. **Cleanup:**
   - Call `__unw_remove_dynamic_eh_frame_section` before freeing JIT memory
   - Store registration handle for later deregistration

### Testing Strategy

- Unit tests for ULEB128 encoding/decoding
- Unit tests for CIE/FDE structure encoding
- Integration tests with libunwind for unwinding validation
- End-to-end tests with try_call and exception propagation
