---
title: edit
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T06:15:08.169145+02:00"
---

File: tests/e2e_jit.zig - CRITICAL memory corruption during ctx.compileFunction().

CONFIRMED: Corruption persists even with ALL debug prints removed. This is a REAL bug in the compilation pipeline.

CORRUPTION CHARACTERISTICS:
- Occurs during ctx.compileFunction() execution
- Latent - detected at next allocation attempt
- Manifests as 'reached unreachable code' in debug_allocator.zig:806
- Stack trace shows ___gtxf2 (long double comparison in allocator internals)
- Error: bucket.log2PtrAligns[slot_count][0] = alignment (slot_count is invalid)

ROOT CAUSE ANALYSIS NEEDED:
The debug allocator maintains buckets of free slots. The corruption is in bucket metadata:
- Either slot_count is wrong (out of bounds access)
- Or log2PtrAligns array is corrupted
- Or bucket itself is corrupted (freed/overwritten)

CRITICAL FILES TO AUDIT (in order of likelihood):
1. src/machinst/buffer.zig - MachBuffer.put4(), putSlice() buffer management
   - Check if allocated size matches written data
   - Verify no out-of-bounds writes
   - ArrayList capacity vs length checks

2. src/codegen/compile.zig - emitAArch64WithAllocation()
   - Lines 531-3294: VReg→PReg rewriting and emission
   - Check ArrayList.appendSlice calls for buffer overflow
   - Verify buffer ownership during vreg rewriting

3. src/codegen/context.zig - CompiledCode ownership
   - Lines 94-98: takeCompiledCode() transfer
   - Verify no double-free or use-after-move

4. src/backends/aarch64/emit.zig - Instruction emission
   - All emitXXX functions that write to buffer
   - Check if any write beyond allocated buffer

REPRODUCTION:
zig build test  # Crashes every time on 'JIT: compile and execute return constant i32'

PROPER FIX REQUIRES:
1. AddressSanitizer: zig build test -fsanitize=address
   (May not work - Zig 0.15 ASan support is limited on macOS ARM64)
   
2. Valgrind on Linux: valgrind --leak-check=full --track-origins=yes ./test
   
3. Manual instrumentation:
   - Add bounds checks in MachBuffer.put4/putSlice
   - Log all allocations/frees in compile pipeline
   - Verify ArrayList.items.len == expected before append

4. Simplify test:
   - Remove all allocations except compilation
   - Binary search to find exact allocation that reveals corruption

HYPOTHESIS TO TEST:
MachBuffer writes beyond its allocated capacity during instruction emission.
Evidence: 20-byte function, but buffer might be sized for 16 bytes initially,
then resized incorrectly, or writes happen before proper capacity check.
