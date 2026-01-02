# Hoist Cranelift Compatibility Plan (Revised)

## Current State (Baseline - Updated)
- 114 Zig implementation files
- 3 ISLE files (1063 lines): lower.isle (1038), inst.isle stub, prelude.isle stub
- 185 commits total
- 183 ISLE lowering rules (vs Cranelift's 543)
- All encoding tests passing (15/15)
- **81+ compilation errors** (not 4) - multiple test suites failing
- No code emission pipeline (regalloc2 not integrated)
- **Missing VCode builder infrastructure** (Cranelift's ~2000 lines in lower.rs)
- **Missing ISLE glue layer** (Cranelift's ~860 lines in lower/isle.rs)

## Cranelift Reference (Target - Updated)
- aarch64 backend: 8613 ISLE lines total
  - inst.isle: 5219 lines (~377 constructor decls)
  - lower.isle: 3288 lines (lowering rules)
  - inst_neon.isle: 8 lines
  - lower_dynamic_neon.isle: 98 lines
- **ISLE prelude**: 1820 lines
  - prelude.isle: 613 lines (common types, extractors)
  - prelude_lower.isle: 1207 lines (lowering-specific constructors)
- 543 lowering rules total
- ~3114 lines in inst/mod.rs (instruction definitions)
- **VCode infrastructure**: ~2000 lines (lower.rs: 1799, VCodeBuilder)
- **ISLE context**: ~860 lines (lower/isle.rs: IsleContext + 40+ extern constructors)
- **MachBuffer**: 2912 lines (branch optimization, veneers, islands)
- **Block ordering**: 485 lines (optimal layout for fallthrough)
- Full code emission pipeline with register allocation

## Gap Analysis (Updated)
- **ISLE Coverage**: 183/543 rules (34%), 1063/3288 lower.isle lines (32%)
- **ISLE Prelude**: Minimal (need 1820 lines from Cranelift)
- **Instruction Definitions**: Missing inst.isle (~5000 lines, 377 constructors)
- **ISLE Glue Layer**: Missing isle_impl.zig extensions (40+ extern constructors)
- **VCode Builder**: Missing (need ~2000 lines)
- **SIMD/NEON**: 0% (not ported)
- **Code Emission**: 0% (regalloc2 not integrated)
- **Build Health**: 81+ compilation errors (API mismatches, missing DFG methods, Type enum issues)

---

## Phase 1: Fix Critical Build Errors

### Task 1.1: Fix Maps ArrayList API Issues
**File**: `src/foundation/maps.zig`
**Lines**: ~20 changes
**Error**: ArrayList API compatibility with Zig 0.15
**Action**: Verify linter fixes for SecondaryMap, ensure all append/resize calls pass allocator
**Test**: `zig build --summary all` shows foundation module compiles
**Commit**: "Fix ArrayList API in maps.zig for Zig 0.15"

### Task 1.2: Fix value_list ArrayList API
**File**: `src/ir/value_list.zig`
**Lines**: ~15 changes
**Action**: Apply same ArrayList pattern as maps (allocator field, unmanaged)
**Test**: `zig build` compiles IR module
**Commit**: "Fix ArrayList API in value_list.zig"

### Task 1.3: Add DFG Block Methods for E2E Tests
**File**: `src/ir/dfg.zig`
**Lines**: ~80 additions
**Action**:
1. Add `blocks: PrimaryMap(Block, BlockData)` field to DFG
2. Implement `blockParams(block: Block) []Value` accessor
3. Add block builder methods (addBlock, setBlockParams)
**Test**: `tests/e2e_branches.zig` compiles
**Commit**: "Add DFG block management methods for E2E tests"

### Task 1.4: Fix Type Enum in Legalize
**File**: `src/backends/aarch64/legalize.zig`
**Lines**: ~30 changes
**Error**: Type enum access patterns incorrect
**Action**: Fix Type enum usage, ensure all type checks use correct API
**Test**: `zig build` compiles legalize module
**Commit**: "Fix Type enum usage in legalize.zig"

### Task 1.5: Fix RegClass in machinst
**File**: `src/machinst/reg.zig`
**Lines**: ~15 changes
**Error**: RegClass parameter type mismatch in PReg.new()
**Action**: Review enum type annotations, fix parameter signatures
**Test**: `zig build` compiles machinst module
**Commit**: "Fix RegClass enum type annotations"

### Task 1.6: Fix Remaining Compilation Errors
**Scope**: All remaining build errors
**Lines**: ~100 changes across multiple files
**Action**:
1. Run `zig build 2>&1 | tee build_errors.txt`
2. Fix remaining errors in dependency order
3. Ensure all 11 build steps pass
**Test**: `zig build --summary all` shows "11/11 steps succeeded"
**Commit**: "Fix remaining compilation errors"

---

## Phase 1.5: VCode Builder Infrastructure (NEW)

### Task 1.5.1: Implement VCodeBuilder Core
**File**: Create `src/machinst/vcode_builder.zig`
**Lines**: ~200
**Cranelift ref**: `machinst/lower.rs:VCodeBuilder`
**Action**:
1. Define VCodeBuilder struct with instruction buffer
2. Implement backwards emission (instructions added at end)
3. Add block tracking (entry block, current block)
4. Implement basic instruction emission API
**Output**: VCodeBuilder can construct VCode in reverse order
**Test**: Unit test creating simple VCode (mov, ret)
**Commit**: "Implement VCodeBuilder core structure"

### Task 1.5.2: Add Instruction Color Tracking
**File**: Extend `src/machinst/vcode_builder.zig`
**Lines**: ~100
**Cranelift ref**: `machinst/lower.rs:InsnColor`
**Action**:
1. Add InsnColor enum (get_value, set_output, multi_result, etc.)
2. Track color per instruction
3. Implement side-effect analysis helpers
**Output**: VCodeBuilder tracks instruction colors for optimization
**Test**: Unit test verifying color propagation
**Commit**: "Add instruction color tracking to VCodeBuilder"

### Task 1.5.3: Implement Value Use Tracking
**File**: Extend `src/machinst/vcode_builder.zig`
**Lines**: ~150
**Cranelift ref**: `machinst/lower.rs:use_vreg_at, use_vreg_multiple`
**Action**:
1. Track vreg use counts
2. Implement value sinking logic (emit instruction when last use encountered)
3. Add multi-result value handling
**Output**: VCodeBuilder supports optimized value emission
**Test**: Unit test verifying sinking behavior
**Commit**: "Implement value use tracking and sinking"

### Task 1.5.4: Implement VRegAllocator
**File**: Create `src/machinst/vreg_allocator.zig`
**Lines**: ~100
**Cranelift ref**: `machinst/lower.rs:VRegAllocator`
**Action**:
1. Define VRegAllocator struct tracking next vreg ID per class
2. Implement alloc(reg_class: RegClass) -> VReg
3. Add temp vreg allocation for intermediate values
**Output**: Allocate virtual registers during lowering
**Test**: Unit test allocating vregs across classes
**Commit**: "Implement VRegAllocator for lowering"

### Task 1.5.5: Implement LowerCtx (Lowering Context)
**File**: Create `src/machinst/lower_ctx.zig`
**Lines**: ~200
**Cranelift ref**: `machinst/lower.rs:Lower`
**Action**:
1. Define LowerCtx struct wrapping VCodeBuilder, VRegAllocator, DFG
2. Add helpers for value lookup, type query, constant materialization
3. Implement block/label management
4. Add ABI context integration
**Output**: Complete lowering context for ISLE rules
**Test**: Unit test lowering simple IR instruction
**Commit**: "Implement lowering context (LowerCtx)"

---

## Phase 2: Complete Register Allocation Integration

### Task 2.1: Design Regalloc2 Zig API Wrapper
**File**: Create `src/regalloc/interface.zig`
**Lines**: ~150
**Action**:
1. Define Zig types wrapping regalloc2 FFI structs
2. Map RegClass/PReg/VReg between Hoist and regalloc2
3. Create allocator-managed wrappers for regalloc2 contexts
4. Add error handling for regalloc2 failures
**Output**: Clean Zig API hiding FFI details
**Test**: Unit test creating regalloc2 context
**Commit**: "Implement regalloc2 Zig API wrapper"

### Task 2.2: Implement VCode → Regalloc2 Lowering
**File**: Create `src/backends/aarch64/regalloc_bridge.zig`
**Lines**: ~250
**Action**:
1. Convert VCode instructions to regalloc2 instruction format
2. Extract register use/def/mod operands per instruction
3. Build regalloc2 Function representation from VCode
4. Handle calling conventions and ABI constraints
**Dependencies**: Phase 1.5 complete (VCode exists)
**Test**: Unit test converting simple VCode to regalloc2
**Commit**: "Implement VCode to regalloc2 conversion"

### Task 2.3: Implement Regalloc2 → Final VCode Mapping
**File**: Extend `src/backends/aarch64/regalloc_bridge.zig`
**Lines**: ~200
**Action**:
1. Apply regalloc2 allocation results to VCode
2. Replace virtual registers with physical registers
3. Insert spill/reload instructions as needed
4. Preserve instruction semantics during rewriting
**Test**: Unit test verifying register substitution
**Commit**: "Apply regalloc2 results to VCode"

### Task 2.4: Wire Regalloc2 into Compilation Pipeline
**Files**: `src/backends/aarch64/isa.zig`, `src/pipeline.zig`
**Lines**: ~100
**Action**:
1. Add regalloc2 step between lowering and emission
2. Pass allocated VCode to emit phase
3. Handle regalloc2 errors (allocation failures, invalid constraints)
4. Add pipeline integration tests
**Test**: Full pipeline test (IR → lower → regalloc → emit)
**Commit**: "Wire regalloc2 into compilation pipeline"

---

## Phase 3: Implement Machine Code Emission (Split Granularly)

### Task 3.1.1: Emit Move Instructions
**File**: `src/backends/aarch64/emit.zig`
**Lines**: ~80
**Variants**: mov_rr, mov_imm, movz, movk, movn (5 total)
**Action**: Implement emit methods using encoding.zig helpers
**Test**: `zig build test --filter="emit_mov"`
**Verify**: Compare objdump output against GNU `as`
**Commit**: "Emit move instructions (MOV, MOVZ, MOVK, MOVN)"

### Task 3.1.2: Emit Basic ALU Instructions
**File**: `src/backends/aarch64/emit.zig`
**Lines**: ~100
**Variants**: add_rr, add_imm, sub_rr, sub_imm, neg, adc (6 total)
**Action**: Implement ALU emission with immediate encoding
**Test**: `zig build test --filter="emit_alu_basic"`
**Commit**: "Emit basic ALU (ADD, SUB, NEG, ADC)"

### Task 3.1.3: Emit Multiply Instructions
**File**: `src/backends/aarch64/emit.zig`
**Lines**: ~120
**Variants**: mul, madd, msub, smulh, umulh, smull, umull, smaddl (8 total)
**Action**: Implement multiply and multiply-add/sub
**Test**: `zig build test --filter="emit_mul"`
**Commit**: "Emit multiply instructions"

### Task 3.1.4: Emit Divide Instructions
**File**: `src/backends/aarch64/emit.zig`
**Lines**: ~40
**Variants**: udiv, sdiv (2 total)
**Action**: Implement division (unsigned and signed)
**Test**: `zig build test --filter="emit_div"`
**Commit**: "Emit divide instructions (UDIV, SDIV)"

### Task 3.1.5: Emit Logical Instructions
**File**: `src/backends/aarch64/emit.zig`
**Lines**: ~120
**Variants**: and, orr, eor, bic, orn, eon, mvn, tst (8 total)
**Action**: Implement logical ops with immediate encoding
**Test**: `zig build test --filter="emit_logical"`
**Commit**: "Emit logical instructions (AND, ORR, EOR, etc.)"

### Task 3.1.6: Emit Shift Instructions
**File**: `src/backends/aarch64/emit.zig`
**Lines**: ~100
**Variants**: lsl_rr, lsl_imm, lsr_rr, lsr_imm, asr_rr, asr_imm, ror (7 total)
**Action**: Implement shifts (immediate and register)
**Test**: `zig build test --filter="emit_shift"`
**Commit**: "Emit shift instructions"

### Task 3.1.7: Emit Bitfield Instructions
**File**: `src/backends/aarch64/emit.zig`
**Lines**: ~100
**Variants**: ubfm, sbfm, bfi, bfxil, sxtb, sxth, sxtw, uxtb, uxth (9 total)
**Action**: Implement bitfield operations and extends
**Test**: `zig build test --filter="emit_bitfield"`
**Commit**: "Emit bitfield and extend instructions"

### Task 3.1.8: Emit Bit Manipulation Instructions
**File**: `src/backends/aarch64/emit.zig`
**Lines**: ~80
**Variants**: cls, clz, rbit, rev, rev16, rev32, crc32* (8 total)
**Action**: Implement bit counting and reversal
**Test**: `zig build test --filter="emit_bitmanip"`
**Commit**: "Emit bit manipulation instructions"

### Task 3.1.9: Emit Load Unsigned Instructions
**File**: `src/backends/aarch64/emit.zig`
**Lines**: ~100
**Variants**: ldrb, ldrh, ldr (w/x), ldur (5 total)
**Action**: Implement unsigned loads with addressing modes
**Test**: `zig build test --filter="emit_load_unsigned"`
**Commit**: "Emit unsigned load instructions"

### Task 3.1.10: Emit Load Signed Instructions
**File**: `src/backends/aarch64/emit.zig`
**Lines**: ~80
**Variants**: ldrsb, ldrsh, ldrsw, ldursw (4 total)
**Action**: Implement signed loads
**Test**: `zig build test --filter="emit_load_signed"`
**Commit**: "Emit signed load instructions"

### Task 3.1.11: Emit Store Instructions
**File**: `src/backends/aarch64/emit.zig`
**Lines**: ~100
**Variants**: strb, strh, str (w/x), stur (5 total)
**Action**: Implement stores with addressing modes
**Test**: `zig build test --filter="emit_store"`
**Commit**: "Emit store instructions"

### Task 3.1.12: Emit Load Pair Instructions
**File**: `src/backends/aarch64/emit.zig`
**Lines**: ~60
**Variants**: ldp, ldnp, ldp_pre, ldp_post (4 total)
**Action**: Implement load pair with indexing modes
**Test**: `zig build test --filter="emit_load_pair"`
**Commit**: "Emit load pair instructions (LDP)"

### Task 3.1.13: Emit Store Pair Instructions
**File**: `src/backends/aarch64/emit.zig`
**Lines**: ~60
**Variants**: stp, stnp, stp_pre, stp_post (4 total)
**Action**: Implement store pair with indexing modes
**Test**: `zig build test --filter="emit_store_pair"`
**Commit**: "Emit store pair instructions (STP)"

### Task 3.1.14: Emit Branch Instructions
**File**: `src/backends/aarch64/emit.zig`
**Lines**: ~120
**Variants**: b, bl, br, blr, ret, b_cond, cbz, cbnz, tbz, tbnz (10 total)
**Action**: Implement all branch types with offset encoding
**Test**: `zig build test --filter="emit_branch"`
**Commit**: "Emit branch instructions"

### Task 3.1.15: Emit Compare Instructions
**File**: `src/backends/aarch64/emit.zig`
**Lines**: ~80
**Variants**: cmp_rr, cmp_imm, cmn, tst, ccmp (5 total)
**Action**: Implement comparison with flag setting
**Test**: `zig build test --filter="emit_compare"`
**Commit**: "Emit compare instructions"

### Task 3.1.16: Emit Conditional Select Instructions
**File**: `src/backends/aarch64/emit.zig`
**Lines**: ~80
**Variants**: csel, csinc, csinv, csneg, cset (5 total)
**Action**: Implement conditional select variants
**Test**: `zig build test --filter="emit_csel"`
**Commit**: "Emit conditional select instructions"

### Task 3.1.17: Emit FP Arithmetic Instructions
**File**: `src/backends/aarch64/emit.zig`
**Lines**: ~120
**Variants**: fadd, fsub, fmul, fdiv, fneg, fabs, fsqrt, fmin, fmax (9 total)
**Action**: Implement FP arithmetic (S/D variants)
**Test**: `zig build test --filter="emit_fp_arith"`
**Commit**: "Emit FP arithmetic instructions"

### Task 3.1.18: Emit FP Compare Instructions
**File**: `src/backends/aarch64/emit.zig`
**Lines**: ~60
**Variants**: fcmp, fcmpe, fccmp (3 total)
**Action**: Implement FP comparison
**Test**: `zig build test --filter="emit_fp_cmp"`
**Commit**: "Emit FP compare instructions"

### Task 3.1.19: Emit FP Convert Instructions
**File**: `src/backends/aarch64/emit.zig`
**Lines**: ~120
**Variants**: fcvt*, fcvtzs, fcvtzu, scvtf, ucvtf (8 total)
**Action**: Implement FP conversions
**Test**: `zig build test --filter="emit_fp_cvt"`
**Commit**: "Emit FP convert instructions"

### Task 3.1.20: Emit SIMD Basic Instructions
**File**: `src/backends/aarch64/emit.zig`
**Lines**: ~150
**Variants**: Vector add/sub/mul/etc. per-lane (10 total)
**Action**: Implement basic SIMD operations
**Test**: `zig build test --filter="emit_simd_basic"`
**Commit**: "Emit basic SIMD instructions"

### Task 3.2: Implement Literal Pool Emission
**File**: `src/backends/aarch64/emit.zig`
**Lines**: ~150
**Action**:
1. Track literal pool during emission
2. Emit literal pool at function end
3. Patch PC-relative loads with correct offsets
4. Handle pool size overflow (multiple pools if needed)
**Dependencies**: encoding.zig LiteralPool (already implemented)
**Test**: Test function with large constant requiring pool
**Commit**: "Implement literal pool emission and patching"

### Task 3.3: Implement Relocation Handling
**File**: Create `src/backends/aarch64/reloc.zig`
**Lines**: ~200
**Action**:
1. Define Relocation types (absolute, PC-relative, GOT, PLT)
2. Track relocations during emission
3. Provide relocation info to linker/JIT
4. Patch relocations for JIT execution
**Test**: Test cross-function call requiring relocation
**Commit**: "Implement relocation tracking and patching"

### Task 3.4: Implement Stack Frame Management
**File**: `src/backends/aarch64/emit.zig`
**Lines**: ~200
**Action**:
1. Emit function prologue (save FP/LR, allocate stack)
2. Emit function epilogue (restore FP/LR, deallocate stack)
3. Handle stack slot access (spills from regalloc)
4. Align stack per AArch64 ABI (16-byte alignment)
**Dependencies**: Task 2.3 (regalloc provides spill info)
**Test**: Test function with stack usage and spills
**Commit**: "Implement stack frame prologue/epilogue"

### Task 3.5: Implement Branch and Label Resolution
**File**: `src/backends/aarch64/emit.zig`
**Lines**: ~150
**Action**:
1. Track label positions during emission
2. Emit forward branches with placeholders
3. Patch branch offsets after label positions known
4. Handle branch range limits (B vs BL, conditional branches)
**Test**: Test function with loops and conditionals
**Commit**: "Implement branch offset patching and label resolution"

---

## Phase 3.5: ISLE Prelude (NEW)

### Task 3.5.1: Port prelude.isle Type Declarations
**File**: Extend `src/backends/aarch64/prelude.isle`
**Lines**: ~200
**Cranelift source**: `cranelift/codegen/src/prelude.isle` (613 lines)
**Action**:
1. Port common type declarations (ValueRegs, ValueArray, etc.)
2. Port register class types (WritableReg, XReg, VReg)
3. Port condition code types (Cond, FloatCC, IntCC)
4. Port addressing mode types
**Verification**: ISLE compiler parses prelude.isle
**Commit**: "Port prelude.isle type declarations"

### Task 3.5.2: Port Value and Register Helpers
**File**: Create `src/backends/aarch64/prelude_lower.isle`
**Lines**: ~300
**Cranelift source**: `cranelift/codegen/src/prelude_lower.isle` (1207 lines, section 1)
**Action**:
1. Port value accessors (value_type, def_inst, etc.)
2. Port register allocation helpers (temp_writable_reg, etc.)
3. Port value extraction (put_in_reg, etc.)
4. Port multi-value helpers (split_value, etc.)
**Verification**: ISLE compiler parses, rules can use helpers
**Commit**: "Port prelude_lower.isle value/register helpers"

### Task 3.5.3: Port Lowering Primitives
**File**: Extend `src/backends/aarch64/prelude_lower.isle`
**Lines**: ~400
**Cranelift source**: `cranelift/codegen/src/prelude_lower.isle` (section 2)
**Action**:
1. Port instruction emission primitives (emit, emit_side_effect)
2. Port block/label management (label_from_block, etc.)
3. Port constant materialization (iconst, etc.)
4. Port type conversion helpers
**Verification**: Lower rules can emit instructions
**Commit**: "Port prelude_lower.isle lowering primitives"

### Task 3.5.4: Port Memory Helpers
**File**: Extend `src/backends/aarch64/prelude_lower.isle`
**Lines**: ~300
**Cranelift source**: `cranelift/codegen/src/prelude_lower.isle` (section 3)
**Action**:
1. Port addressing mode constructors (amode_offset, etc.)
2. Port load/store helpers (load, store, etc.)
3. Port memory flag handling
4. Port atomic operation helpers
**Verification**: Memory rules work correctly
**Commit**: "Port prelude_lower.isle memory helpers"

---

## Phase 4: Port ISLE Instruction Definitions (Split Granularly)

### Task 4.1: Extract inst.isle Framework
**File**: Create `src/backends/aarch64/inst.isle`
**Lines**: ~300
**Cranelift source**: `cranelift/codegen/src/isa/aarch64/inst.isle` (lines 1-300)
**Action**:
1. Copy top-level type declarations
2. Port Inst enum skeleton
3. Port common helper types (OperandSize, etc.)
4. Set up file structure for constructors
**Verification**: ISLE compiler parses inst.isle skeleton
**Commit**: "Create inst.isle framework from Cranelift"

### Task 4.2.1: Port Move Instruction Constructors
**File**: Extend `src/backends/aarch64/inst.isle`
**Lines**: ~100
**Constructors**: mov, movz, movk, movn, mov_vec (~5 constructors)
**Action**: Port constructor decls, map to isle_impl.zig extern functions
**Verification**: Constructors can be called from lower.isle
**Commit**: "Port move instruction constructors to inst.isle"

### Task 4.2.2: Port ALU Instruction Constructors
**File**: Extend `src/backends/aarch64/inst.isle`
**Lines**: ~150
**Constructors**: add, sub, mul, madd, msub, div, neg, adc (~15 constructors)
**Action**: Port ALU constructor decls with all variants
**Verification**: ALU constructors work in rules
**Commit**: "Port ALU instruction constructors"

### Task 4.2.3: Port Logical Instruction Constructors
**File**: Extend `src/backends/aarch64/inst.isle`
**Lines**: ~120
**Constructors**: and, orr, eor, bic, orn, eon, mvn (~12 constructors)
**Action**: Port logical constructor decls
**Verification**: Logical constructors work
**Commit**: "Port logical instruction constructors"

### Task 4.2.4: Port Shift Instruction Constructors
**File**: Extend `src/backends/aarch64/inst.isle`
**Lines**: ~100
**Constructors**: lsl, lsr, asr, ror, extr (~10 constructors)
**Action**: Port shift constructor decls
**Verification**: Shift constructors work
**Commit**: "Port shift instruction constructors"

### Task 4.2.5: Port Bitfield Instruction Constructors
**File**: Extend `src/backends/aarch64/inst.isle`
**Lines**: ~120
**Constructors**: ubfm, sbfm, bfi, bfxil, sxt*, uxt* (~15 constructors)
**Action**: Port bitfield constructor decls
**Verification**: Bitfield constructors work
**Commit**: "Port bitfield instruction constructors"

### Task 4.2.6: Port Bit Manipulation Constructors
**File**: Extend `src/backends/aarch64/inst.isle`
**Lines**: ~80
**Constructors**: cls, clz, rbit, rev, crc32 (~10 constructors)
**Action**: Port bit manipulation constructor decls
**Verification**: Bit manip constructors work
**Commit**: "Port bit manipulation constructors"

### Task 4.3.1: Port Load Instruction Constructors
**File**: Extend `src/backends/aarch64/inst.isle`
**Lines**: ~150
**Constructors**: ldr*, ldur*, ldp*, ~20 constructors
**Action**: Port load constructor decls with all addressing modes
**Verification**: Load constructors work
**Commit**: "Port load instruction constructors"

### Task 4.3.2: Port Store Instruction Constructors
**File**: Extend `src/backends/aarch64/inst.isle`
**Lines**: ~120
**Constructors**: str*, stur*, stp*, ~15 constructors
**Action**: Port store constructor decls
**Verification**: Store constructors work
**Commit**: "Port store instruction constructors"

### Task 4.3.3: Port Atomic Instruction Constructors
**File**: Extend `src/backends/aarch64/inst.isle`
**Lines**: ~150
**Constructors**: ldar, stlr, ldadd, cas, swp (~20 constructors)
**Action**: Port atomic constructor decls
**Verification**: Atomic constructors work
**Commit**: "Port atomic instruction constructors"

### Task 4.4.1: Port FP Arithmetic Constructors
**File**: Extend `src/backends/aarch64/inst.isle`
**Lines**: ~120
**Constructors**: fadd, fsub, fmul, fdiv, fsqrt, fabs, fneg (~15 constructors)
**Action**: Port FP arithmetic constructor decls (S/D variants)
**Verification**: FP arith constructors work
**Commit**: "Port FP arithmetic constructors"

### Task 4.4.2: Port FP Compare Constructors
**File**: Extend `src/backends/aarch64/inst.isle`
**Lines**: ~60
**Constructors**: fcmp, fcmpe, fccmp (~5 constructors)
**Action**: Port FP compare constructor decls
**Verification**: FP cmp constructors work
**Commit**: "Port FP compare constructors"

### Task 4.4.3: Port FP Convert Constructors
**File**: Extend `src/backends/aarch64/inst.isle`
**Lines**: ~120
**Constructors**: fcvt*, scvtf, ucvtf (~15 constructors)
**Action**: Port FP conversion constructor decls
**Verification**: FP cvt constructors work
**Commit**: "Port FP convert constructors"

### Task 4.4.4: Port FP Move Constructors
**File**: Extend `src/backends/aarch64/inst.isle`
**Lines**: ~80
**Constructors**: fmov (variants: reg, imm, GPR↔FP) (~8 constructors)
**Action**: Port FP move constructor decls
**Verification**: FP move constructors work
**Commit**: "Port FP move constructors"

### Task 4.5.1: Port SIMD Lane Arithmetic Constructors
**File**: Extend `src/backends/aarch64/inst.isle`
**Lines**: ~200
**Constructors**: Vector add/sub/mul/div per-lane (~25 constructors)
**Action**: Port SIMD arithmetic constructor decls
**Verification**: SIMD arith constructors work
**Commit**: "Port SIMD lane arithmetic constructors"

### Task 4.5.2: Port SIMD Compare Constructors
**File**: Extend `src/backends/aarch64/inst.isle`
**Lines**: ~120
**Constructors**: Vector cmeq, cmge, cmgt, cmhi (~15 constructors)
**Action**: Port SIMD compare constructor decls
**Verification**: SIMD cmp constructors work
**Commit**: "Port SIMD compare constructors"

### Task 4.5.3: Port SIMD Shift Constructors
**File**: Extend `src/backends/aarch64/inst.isle`
**Lines**: ~100
**Constructors**: Vector shl, shr, sshr, ushr (~12 constructors)
**Action**: Port SIMD shift constructor decls
**Verification**: SIMD shift constructors work
**Commit**: "Port SIMD shift constructors"

### Task 4.5.4: Port SIMD Load/Store Constructors
**File**: Extend `src/backends/aarch64/inst.isle`
**Lines**: ~150
**Constructors**: ld1-ld4, st1-st4 (~20 constructors)
**Action**: Port SIMD load/store constructor decls
**Verification**: SIMD load/store constructors work
**Commit**: "Port SIMD load/store constructors"

### Task 4.5.5: Port SIMD Permute Constructors
**File**: Extend `src/backends/aarch64/inst.isle`
**Lines**: ~150
**Constructors**: tbl, tbx, uzp, zip, trn (~20 constructors)
**Action**: Port SIMD permute constructor decls
**Verification**: SIMD permute constructors work
**Commit**: "Port SIMD permute constructors"

### Task 4.6: Port Branch and Control Constructors
**File**: Extend `src/backends/aarch64/inst.isle`
**Lines**: ~150
**Constructors**: b, bl, br, blr, ret, b.cond, cbz, cbnz, tbz, tbnz (~15 constructors)
**Action**: Port branch constructor decls
**Verification**: Branch constructors work
**Commit**: "Port branch and control flow constructors"

### Task 4.7: Port System Instruction Constructors
**File**: Extend `src/backends/aarch64/inst.isle`
**Lines**: ~200
**Constructors**: mrs, msr, dmb, dsb, isb, dc, ic, hints (~25 constructors)
**Action**: Port system constructor decls
**Verification**: System constructors work
**Commit**: "Port system instruction constructors"

---

## Phase 4.5: ISLE Glue Layer (NEW)

### Task 4.5.1: Implement IsleContext Struct
**File**: Create `src/backends/aarch64/isle_context.zig`
**Lines**: ~100
**Cranelift ref**: `lower/isle.rs:IsleContext`
**Action**:
1. Define IsleContext wrapping LowerCtx
2. Add helpers for common operations
3. Expose context to ISLE via isle_impl.zig
**Output**: Context available to ISLE extern constructors
**Test**: Unit test creating context
**Commit**: "Implement IsleContext for ISLE glue layer"

### Task 4.5.2: Implement Value Type Accessors
**File**: Extend `src/backends/aarch64/isle_impl.zig`
**Lines**: ~100
**Cranelift ref**: `lower/isle.rs:value_type, ty_bits, ty_int_ref_*`
**Action**: Implement 10+ extern constructors for type queries
**Verification**: ISLE rules can query value types
**Commit**: "Implement value type accessor extern constructors"

### Task 4.5.3: Implement Register Allocation Helpers
**File**: Extend `src/backends/aarch64/isle_impl.zig`
**Lines**: ~100
**Cranelift ref**: `lower/isle.rs:temp_writable_*, writable_reg_to_reg`
**Action**: Implement 8+ extern constructors for register allocation
**Verification**: ISLE rules can allocate temps
**Commit**: "Implement register allocation helper extern constructors"

### Task 4.5.4: Implement Instruction Emission Bridge
**File**: Extend `src/backends/aarch64/isle_impl.zig`
**Lines**: ~150
**Cranelift ref**: `lower/isle.rs:emit, emit_side_effect, sink_inst`
**Action**: Implement 10+ extern constructors for instruction emission
**Verification**: ISLE rules can emit instructions
**Commit**: "Implement instruction emission extern constructors"

### Task 4.5.5: Implement Call/Branch Target Helpers
**File**: Extend `src/backends/aarch64/isle_impl.zig`
**Lines**: ~100
**Cranelift ref**: `lower/isle.rs:label_from_block, box_call_info, etc.`
**Action**: Implement 8+ extern constructors for call/branch handling
**Verification**: ISLE rules can handle calls and branches
**Commit**: "Implement call/branch target extern constructors"

### Task 4.5.6: Implement Memory Operation Helpers
**File**: Extend `src/backends/aarch64/isle_impl.zig`
**Lines**: ~100
**Cranelift ref**: `lower/isle.rs:amode_*, mem_flags_*`
**Action**: Implement 10+ extern constructors for memory ops
**Verification**: ISLE rules can generate loads/stores
**Commit**: "Implement memory operation extern constructors"

---

## Phase 5: Port Missing ISLE Lowering Rules (Split Granularly)

### Task 5.1.1: Port Immediate Materialization Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~100
**Rules**: ~10 rules for iconst lowering (movz/movn/movk sequences)
**Cranelift source**: lower.isle lines ~50-150
**Action**: Port immediate encoding rules
**Test**: Lower iconst with various values
**Commit**: "Port immediate materialization rules"

### Task 5.1.2: Port Basic ALU Rules (Part 1)
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~150
**Rules**: ~15 rules for iadd, isub (with immediates, shifts)
**Cranelift source**: lower.isle lines ~150-300
**Action**: Port add/sub lowering rules
**Test**: Lower iadd/isub with various operands
**Commit**: "Port basic ALU rules (add, sub)"

### Task 5.1.3: Port Basic ALU Rules (Part 2)
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~150
**Rules**: ~15 rules for imul, sdiv, udiv
**Cranelift source**: lower.isle lines ~300-450
**Action**: Port mul/div lowering rules
**Test**: Lower imul/div
**Commit**: "Port multiply and divide rules"

### Task 5.1.4: Port Multiply-Add/Sub Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~120
**Rules**: ~12 rules for madd, msub pattern matching
**Cranelift source**: lower.isle lines ~450-570
**Action**: Port fused multiply-add/sub rules
**Test**: Lower patterns like (add (mul x y) z)
**Commit**: "Port multiply-add/sub fusion rules"

### Task 5.1.5: Port Conditional Select Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~100
**Rules**: ~10 rules for csel, csinc, csinv, csneg
**Cranelift source**: lower.isle lines ~570-670
**Action**: Port conditional select rules
**Test**: Lower select with various conditions
**Commit**: "Port conditional select rules"

### Task 5.1.6: Port Bitfield Operation Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~150
**Rules**: ~15 rules for ubfiz, ubfx, sbfiz, sbfx
**Cranelift source**: lower.isle lines ~670-820
**Action**: Port bitfield extraction/insertion rules
**Test**: Lower bitfield operations
**Commit**: "Port bitfield operation rules"

### Task 5.1.7: Port Bit Manipulation Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~100
**Rules**: ~10 rules for clz, cls, rbit, rev
**Cranelift source**: lower.isle lines ~820-920
**Action**: Port bit count and reversal rules
**Test**: Lower bit manipulation ops
**Commit**: "Port bit manipulation rules"

### Task 5.1.8: Port Shift-and-Add Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~120
**Rules**: ~12 rules for add with LSL/LSR/ASR/ROR
**Cranelift source**: lower.isle lines ~920-1040
**Action**: Port shift-and-operate fusion rules
**Test**: Lower (add x (shl y z))
**Commit**: "Port shift-and-add fusion rules"

### Task 5.2.1: Port Basic Load/Store Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~120
**Rules**: ~12 rules for load, store with basic addressing
**Cranelift source**: lower.isle lines ~1040-1160
**Action**: Port load/store with offset addressing
**Test**: Lower load/store
**Commit**: "Port basic load/store rules"

### Task 5.2.2: Port Load Pair Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~100
**Rules**: ~10 rules for LDP detection and generation
**Cranelift source**: lower.isle lines ~1160-1260
**Action**: Port load pair optimization rules
**Test**: Lower two adjacent loads
**Commit**: "Port load pair optimization rules"

### Task 5.2.3: Port Store Pair Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~100
**Rules**: ~10 rules for STP detection and generation
**Cranelift source**: lower.isle lines ~1260-1360
**Action**: Port store pair optimization rules
**Test**: Lower two adjacent stores
**Commit**: "Port store pair optimization rules"

### Task 5.2.4: Port Complex Addressing Mode Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~120
**Rules**: ~12 rules for scaled offset, register offset, extend
**Cranelift source**: lower.isle lines ~1360-1480
**Action**: Port advanced addressing mode selection
**Test**: Lower loads with complex address calculations
**Commit**: "Port complex addressing mode rules"

### Task 5.3.1: Port FP Arithmetic Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~120
**Rules**: ~12 rules for fadd, fsub, fmul, fdiv, fsqrt
**Cranelift source**: lower.isle lines ~1480-1600
**Action**: Port FP arithmetic lowering
**Test**: Lower FP arithmetic ops
**Commit**: "Port FP arithmetic rules"

### Task 5.3.2: Port FMA Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~100
**Rules**: ~10 rules for fma, fnmadd, fnmsub patterns
**Cranelift source**: lower.isle lines ~1600-1700
**Action**: Port fused multiply-add rules
**Test**: Lower (fadd (fmul x y) z)
**Commit**: "Port FP fused multiply-add rules"

### Task 5.3.3: Port FP Comparison Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~100
**Rules**: ~10 rules for fcmp with flag setting
**Cranelift source**: lower.isle lines ~1700-1800
**Action**: Port FP comparison lowering
**Test**: Lower fcmp, branch on FP condition
**Commit**: "Port FP comparison rules"

### Task 5.3.4: Port FP Conversion Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~120
**Rules**: ~12 rules for fcvt, int↔FP conversions
**Cranelift source**: lower.isle lines ~1800-1920
**Action**: Port FP conversion lowering
**Test**: Lower FP conversions
**Commit**: "Port FP conversion rules"

### Task 5.3.5: Port FP Min/Max Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~80
**Rules**: ~8 rules for fmin, fmax with NaN handling
**Cranelift source**: lower.isle lines ~1920-2000
**Action**: Port FP min/max with IEEE compliance
**Test**: Lower fmin/fmax
**Commit**: "Port FP min/max rules"

### Task 5.4.1: Port Vector Arithmetic Rules (Part 1)
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~150
**Rules**: ~15 rules for vector iadd, isub, imul per-lane
**Cranelift source**: lower.isle lines ~2000-2150
**Action**: Port SIMD integer arithmetic
**Test**: Lower vector iadd/isub/imul
**Commit**: "Port SIMD integer arithmetic rules (part 1)"

### Task 5.4.2: Port Vector Arithmetic Rules (Part 2)
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~150
**Rules**: ~15 rules for vector fadd, fsub, fmul, fdiv
**Cranelift source**: lower.isle lines ~2150-2300
**Action**: Port SIMD FP arithmetic
**Test**: Lower vector FP ops
**Commit**: "Port SIMD FP arithmetic rules"

### Task 5.4.3: Port Vector Compare Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~120
**Rules**: ~12 rules for vector compare and select
**Cranelift source**: lower.isle lines ~2300-2420
**Action**: Port SIMD comparison
**Test**: Lower vector compare
**Commit**: "Port SIMD comparison rules"

### Task 5.4.4: Port Vector Constant Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~100
**Rules**: ~10 rules for MOVI, MVNI, ORR immediate
**Cranelift source**: lower.isle lines ~2420-2520
**Action**: Port SIMD constant materialization
**Test**: Lower vector constants
**Commit**: "Port SIMD constant materialization rules"

### Task 5.4.5: Port Scalar/Vector Move Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~100
**Rules**: ~10 rules for DUP, INS, UMOV, SMOV
**Cranelift source**: lower.isle lines ~2520-2620
**Action**: Port scalar↔vector element moves
**Test**: Lower extractlane/insertlane
**Commit**: "Port scalar/vector move rules"

### Task 5.4.6: Port Vector Widen/Narrow Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~120
**Rules**: ~12 rules for XTN, SXTL, UXTL
**Cranelift source**: lower.isle lines ~2620-2740
**Action**: Port vector widening/narrowing
**Test**: Lower vector extend/narrow
**Commit**: "Port vector widen/narrow rules"

### Task 5.5.1: Port Vector Shuffle Rules (Basic)
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~150
**Rules**: ~15 rules for common shuffle patterns (broadcast, etc.)
**Cranelift source**: lower.isle lines ~2740-2890
**Action**: Port basic shuffle lowering
**Test**: Lower common shuffle patterns
**Commit**: "Port basic vector shuffle rules"

### Task 5.5.2: Port Vector Shuffle Rules (TBL)
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~120
**Rules**: ~12 rules for TBL-based arbitrary shuffles
**Cranelift source**: lower.isle lines ~2890-3010
**Action**: Port TBL shuffle synthesis
**Test**: Lower arbitrary shuffles
**Commit**: "Port TBL-based shuffle rules"

### Task 5.5.3: Port Vector Reduction Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~100
**Rules**: ~10 rules for horizontal add/min/max
**Cranelift source**: lower.isle lines ~3010-3110
**Action**: Port reduction lowering
**Test**: Lower vector reductions
**Commit**: "Port vector reduction rules"

### Task 5.5.4: Port Vector Load/Store Interleave Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~120
**Rules**: ~12 rules for LD2-LD4, ST2-ST4
**Cranelift source**: lower.isle lines ~3110-3230
**Action**: Port interleaved load/store
**Test**: Lower interleaved memory ops
**Commit**: "Port vector load/store interleave rules"

### Task 5.5.5: Port Saturating Arithmetic Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~100
**Rules**: ~10 rules for SQADD, SQSUB, etc.
**Cranelift source**: lower_dynamic_neon.isle (98 lines)
**Action**: Port saturating arithmetic
**Test**: Lower saturating ops
**Commit**: "Port saturating arithmetic rules"

### Task 5.6.1: Port Atomic RMW Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~120
**Rules**: ~12 rules for atomic add/sub/and/or (LSE vs LL/SC)
**Cranelift source**: lower.isle lines ~3230-3350
**Action**: Port atomic read-modify-write
**Test**: Lower atomic ops
**Commit**: "Port atomic RMW rules"

### Task 5.6.2: Port Atomic CAS Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~80
**Rules**: ~8 rules for CAS with ordering
**Cranelift source**: lower.isle lines ~3350-3430
**Action**: Port compare-and-swap
**Test**: Lower CAS
**Commit**: "Port atomic CAS rules"

### Task 5.6.3: Port Memory Barrier Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~60
**Rules**: ~6 rules for DMB/DSB barrier selection
**Cranelift source**: lower.isle lines ~3430-3490
**Action**: Port fence lowering
**Test**: Lower fence with various orderings
**Commit**: "Port memory barrier rules"

### Task 5.7.1: Port Strength Reduction Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~100
**Rules**: ~10 rules for mul by constant → shifts+adds
**Cranelift source**: lower.isle optimization section
**Action**: Port strength reduction patterns
**Test**: Lower mul by power-of-2 ± 1
**Commit**: "Port strength reduction rules"

### Task 5.7.2: Port Flag-Setting Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~80
**Rules**: ~8 rules for ADDS vs ADD when flags needed
**Cranelift source**: lower.isle flag patterns
**Action**: Port flag-setting instruction selection
**Test**: Lower with flag consumers
**Commit**: "Port flag-setting instruction rules"

### Task 5.7.3: Port Extension Elision Rules
**File**: `src/backends/aarch64/lower.isle`
**Lines**: ~80
**Rules**: ~8 rules for redundant extend elimination
**Cranelift source**: lower.isle optimization section
**Action**: Port extension elision
**Test**: Lower with redundant extends
**Commit**: "Port extension elision rules"

---

## Phase 6: Implement Missing Backend Features

### Task 6.1: Implement ISA Feature Detection
**File**: Create `src/backends/aarch64/features.zig`
**Lines**: ~200
**Action**:
1. Define AArch64 feature flags (LSE, NEON, FP16, etc.)
2. Implement runtime feature detection (read ID registers)
3. Compile-time feature selection via build options
4. Feature-dependent lowering (e.g., LSE atomics when available)
**Cranelift ref**: settings.rs
**Test**: Test feature detection on ARM CPU (or emulation)
**Commit**: "Implement ISA feature detection"

### Task 6.2: Extend ABI for Aggregates
**File**: Extend `src/backends/aarch64/abi.zig`
**Lines**: ~200
**Current**: 109KB (basic ABI)
**Action**:
1. Handle aggregates (structs passed by value)
2. Implement variadic function support
3. Add Windows ARM64 calling convention (if needed)
**Test**: ABI conformance tests with structs
**Commit**: "Extend ABI for aggregate and variadic handling"

### Task 6.3: Implement Tail Call Optimization
**File**: Extend `src/backends/aarch64/abi.zig`
**Lines**: ~150
**Action**:
1. Detect tail call opportunities
2. Emit tail call sequence (restore stack, jump)
3. Handle parameter passing for tail calls
**Test**: Test tail recursive functions
**Commit**: "Implement tail call optimization"

### Task 6.4: Implement Unwind Info Generation
**File**: `src/backends/aarch64/unwind.zig`
**Lines**: ~300
**Current**: 8576 bytes (stub)
**Action**:
1. Generate DWARF CFI (Call Frame Information)
2. Track CFA (Canonical Frame Address) changes
3. Record callee-saved register locations
4. Emit .eh_frame section data
**Cranelift ref**: inst/unwind/systemv.rs
**Test**: Test exception unwinding
**Commit**: "Implement DWARF unwind info generation"

### Task 6.5: Implement Debug Info Generation
**File**: Create `src/backends/aarch64/debug.zig`
**Lines**: ~250
**Action**:
1. Map IR values to source locations
2. Generate DWARF debug info (.debug_info, .debug_line)
3. Emit variable location information
4. Handle inlined function debug info
**Dependencies**: Need source location tracking in IR
**Test**: Debug with gdb/lldb, verify stack traces
**Commit**: "Implement DWARF debug info generation"

### Task 6.6: Extend MachBuffer with Branch Optimization
**File**: Extend `src/machinst/buffer.zig`
**Lines**: ~400
**Cranelift ref**: buffer.rs (2912 lines)
**Action**:
1. Implement fallthrough branch elimination
2. Add veneer insertion for out-of-range branches
3. Implement island management for literal pools
4. Add branch peephole optimizations
**Test**: Test long functions requiring veneers
**Commit**: "Extend MachBuffer with branch optimizations"

### Task 6.7: Implement Block Ordering
**File**: Create `src/machinst/blockorder.zig`
**Lines**: ~200
**Cranelift ref**: blockorder.rs (485 lines)
**Action**:
1. Compute optimal block layout for fallthrough
2. Implement RPO (reverse postorder) traversal
3. Add heuristics for hot/cold block separation
**Test**: Test block layout optimization
**Commit**: "Implement optimal block ordering"

---

## Phase 7: Testing and Validation

### Task 7.1: Implement Instruction Emission Unit Tests
**File**: Create `tests/aarch64_emit_test.zig`
**Lines**: ~800
**Action**:
1. Test each Inst variant encodes correctly (192 variants)
2. Compare against reference assembler (as)
3. Test edge cases (max immediates, register combinations)
4. Add disassembly verification (objdump -d)
**Coverage Target**: All 192 Inst variants
**Test**: `zig build test --filter="aarch64_emit"`
**Commit**: "Add comprehensive instruction emission tests"

### Task 7.2: Fix End-to-End Compilation Tests
**File**: Extend `tests/e2e_*.zig`
**Lines**: ~300 additions
**Action**:
1. Fix existing E2E test failures (DFG API issues from Phase 1)
2. Add tests for all IR operations
3. Test calling conventions (cross-function calls)
4. Test stack usage and spilling
5. Test constant materialization
**Coverage Target**: All lowering rules exercised
**Test**: `zig build test --filter="e2e"`
**Commit**: "Fix and extend E2E compilation tests"

### Task 7.3: Implement JIT Execution Tests
**File**: Create `tests/jit_exec_test.zig`
**Lines**: ~400
**Action**:
1. Allocate executable memory
2. Emit machine code and execute
3. Verify results match expected values
4. Test integer arithmetic, memory ops, branches
5. Test FP and SIMD operations
**Dependencies**: Phase 3 (emission) complete
**Test**: `zig build test --filter="jit_exec"`
**Commit**: "Add JIT execution verification tests"

### Task 7.4: Extend Fuzzing Infrastructure
**File**: Extend `benchmarks/fuzz_compile.zig`, `benchmarks/fuzz_regalloc.zig`
**Lines**: ~200 additions
**Action**:
1. Generate random valid IR programs
2. Fuzz compilation pipeline (catch crashes)
3. Fuzz register allocator (stress test)
4. Add fuzzing to CI (if applicable)
**Coverage Target**: High code coverage via fuzzing
**Test**: Run fuzzer for 1M iterations
**Commit**: "Extend fuzzing infrastructure for pipeline"

### Task 7.5: Implement Performance Benchmarks
**File**: Extend `benchmarks/bench_*.zig`
**Lines**: ~300 additions
**Action**:
1. Benchmark compilation speed (IR → machine code)
2. Benchmark code quality (compare vs Cranelift, LLVM)
3. Benchmark JIT execution speed
4. Add regression tracking
**Test**: Run benchmarks, record baseline
**Commit**: "Add performance benchmarks for pipeline"

---

## Phase 8: Documentation and Polish

### Task 8.1: Document ISLE Lowering Rules
**File**: Create `docs/lowering_rules.md`
**Lines**: ~500
**Action**:
1. Document pattern matching strategy
2. Explain helper function usage
3. Provide examples for each rule category
4. Document AArch64-specific optimizations
**Commit**: "Document ISLE lowering rules and patterns"

### Task 8.2: Document Backend Architecture
**File**: Create `docs/backend_architecture.md`
**Lines**: ~600
**Action**:
1. Diagram compilation pipeline stages
2. Explain VCode representation
3. Document register allocation integration
4. Explain emission and relocation
**Commit**: "Document backend architecture"

### Task 8.3: Add Code Comments
**Files**: All `src/backends/aarch64/*.zig`
**Lines**: ~1000 additions (comments)
**Action**:
1. Add module-level documentation
2. Comment complex algorithms (encoding, lowering)
3. Add usage examples in doc comments
4. Document public API surface
**Commit**: "Add comprehensive code comments to aarch64 backend"

### Task 8.4: Create Migration Guide
**File**: Create `docs/cranelift_differences.md`
**Lines**: ~400
**Action**:
1. Document API differences (Rust vs Zig)
2. List unsupported Cranelift features
3. Provide porting guide for users
4. Document performance characteristics
**Commit**: "Create Cranelift migration guide"

---

## Success Criteria

### Functional Completeness
- [ ] All ~360 missing Cranelift lowering rules ported
- [ ] All 192 Inst variants have working emission
- [ ] Register allocation fully integrated
- [ ] Full compilation pipeline (IR → machine code) works
- [ ] All E2E tests pass
- [ ] JIT execution tests pass
- [ ] VCode builder infrastructure complete
- [ ] ISLE glue layer complete (40+ extern constructors)
- [ ] ISLE prelude complete (1820 lines)

### Code Quality
- [ ] Zero compilation warnings
- [ ] Zero failing tests
- [ ] No dead code
- [ ] All TODOs resolved
- [ ] Code coverage >80%

### Performance
- [ ] Compilation speed within 2x of Cranelift
- [ ] Generated code quality within 10% of Cranelift
- [ ] No memory leaks (verified with allocator)

### Compatibility
- [ ] Passes Cranelift's aarch64 test suite (if portable)
- [ ] ABI-compatible with system calling convention
- [ ] DWARF unwind info compatible with system unwinder

---

## Estimated Effort (Revised)

### By Phase (Story Points, 1 SP = ~1 hour)
- Phase 1: 12 SP (6 tasks, build fixes)
- Phase 1.5: 30 SP (5 tasks, VCode infrastructure) **NEW**
- Phase 2: 25 SP (4 tasks, regalloc integration)
- Phase 3: 80 SP (25 tasks, emission split granularly)
- Phase 3.5: 40 SP (4 tasks, ISLE prelude) **NEW**
- Phase 4: 80 SP (25 tasks, inst.isle split granularly)
- Phase 4.5: 20 SP (6 tasks, ISLE glue layer) **NEW**
- Phase 5: 100 SP (35 tasks, lowering rules split granularly)
- Phase 6: 50 SP (7 tasks, backend features)
- Phase 7: 40 SP (5 tasks, testing)
- Phase 8: 10 SP (4 tasks, documentation)

**Total**: ~487 story points (~61 days at 8 hours/day)
**Previous estimate**: ~328 SP (~41 days)
**Increase**: +159 SP due to missing components and finer granularity

### Task Count
- **Previous plan**: ~35 tasks
- **Revised plan**: ~116 tasks
- **Average task size**: ~4 hours (1 commit per task)

### Critical Path (Revised)
1. Phase 1 (build fixes, 6 tasks)
2. Phase 1.5 (VCode builder, 5 tasks)
3. Phase 2 (regalloc, 4 tasks)
4. Phase 3 (emission, 25 tasks)

**Parallel tracks:**
- Phase 3.5 (ISLE prelude) parallel with Phase 2-3
- Phase 4 (inst.isle) parallel with Phase 3
- Phase 4.5 (ISLE glue) parallel with Phase 4
- Phase 5 (lowering) after Phase 3.5 + 4 + 4.5
- Phase 6-8 after Phase 5

---

## Dependencies (Corrected)

### External
- Cranelift source at `~/Work/wasmtime/cranelift/` (reference)
- regalloc2 library (already in build.zig)
- Zig 0.15 toolchain

### Internal
- ISLE compiler (`isle_compiler` binary in build.zig)
- Foundation data structures (maps, entity)
- IR representation (DFG, Value, Inst)
- **VCode builder** (Phase 1.5, prerequisite for regalloc)
- **ISLE prelude** (Phase 3.5, prerequisite for lowering)

### Blocking Relationships (Corrected)
- Phase 1.5 blocked by Phase 1
- Phase 2 blocked by Phase 1.5
- Phase 3 blocked by Phase 2
- Phase 4 can start after Phase 1 (parallel with 2-3)
- Phase 4.5 blocked by Phase 1.5 (needs LowerCtx)
- Phase 5 blocked by Phase 3.5 + 4 + 4.5
- Phase 7 blocked by Phase 5

---

## Checkpoints (Revised)

### Checkpoint 1: Build Health (After Phase 1)
- ✓ All 11 build steps pass
- ✓ E2E tests compile
- ✓ No compilation errors
- ✓ 81+ errors fixed

### Checkpoint 1.5: VCode Infrastructure (After Phase 1.5)
- ✓ VCodeBuilder works (backwards emission)
- ✓ LowerCtx provides context for ISLE
- ✓ Can lower simple IR to VCode

### Checkpoint 2: Code Emission (After Phase 3)
- ✓ All 192 instruction variants emit correctly
- ✓ Can emit simple functions (add, mov, ret)
- ✓ Register allocation produces valid code
- ✓ Full pipeline works (IR → VCode → regalloc → machine code)

### Checkpoint 3: ISLE Complete (After Phase 5)
- ✓ All ~360 missing rules ported (~543 total)
- ✓ ISLE prelude complete (1820 lines)
- ✓ Instruction coverage matches Cranelift (377 constructors)
- ✓ SIMD/NEON support complete

### Checkpoint 4: Full Compatibility (After Phase 7)
- ✓ All tests pass
- ✓ JIT execution correct
- ✓ Performance acceptable

---

## Notes

- **Incremental approach**: Each task is 1-6 hours, independently committable and testable
- **Reference Cranelift often**: Don't blindly port, understand semantics
- **Test continuously**: Run tests after each task
- **Commit per task**: One commit per completed task
- **Document as you go**: Phase 8 should just be cleanup

---

## Risk Assessment (Updated)

### High Risk
- **VCode builder complexity**: Backwards emission and value sinking are subtle
  - Mitigation: Study Cranelift's Lower struct carefully, add extensive tests
- **ISLE glue layer completeness**: 40+ extern constructors must match Cranelift semantics
  - Mitigation: Cross-reference every constructor, add unit tests
- **Regalloc2 FFI complexity**: Rust↔Zig FFI may have subtle bugs
  - Mitigation: Extensive unit tests, validate against Cranelift's usage
- **Emission correctness**: 192 instructions × many variants = large bug surface
  - Mitigation: Reference assembler testing, disassembly verification

### Medium Risk
- **ISLE rule porting errors**: Semantic differences in patterns
  - Mitigation: Port in small batches, test each batch
- **ABI compatibility**: Subtle calling convention bugs
  - Mitigation: ABI conformance test suite
- **Build error count**: 81+ errors (not 4) - larger scope than expected
  - Mitigation: Fix systematically in dependency order

### Low Risk
- **Build system issues**: Zig 0.15 API changes
  - Mitigation: Already addressed most, keep Zig version pinned
- **Performance**: May need optimization passes
  - Mitigation: Benchmark early, profile and optimize
