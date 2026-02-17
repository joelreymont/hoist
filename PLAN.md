# AArch64 Parity Canonical Plan

## Objective
Unify all parity/gap plans into one executable document where every actionable task is backed by a dot ID and can be checked off directly from dot status.

## Unified Sources
- `/Users/joel/Work/hoist/PLAN.md` (previous merged plan)
- `/Users/joel/Work/hoist/docs/arm64_parity_plan.md`
- `/Users/joel/Work/hoist/docs/gap-closure-plan.md`
- `/Users/joel/Work/hoist/docs/feature_gap_analysis.md`
- `/Users/joel/Work/hoist/docs/cranelift_gap_analysis.md`
- `/Users/joel/Work/hoist/docs/cranelift-gap-analysis.md`
- `/Users/joel/.claude/plans/fuzzy-sniffing-shamir.md`

## Checkoff Contract
1. Every actionable line in this file must include `dot:<id>`.
2. Checkbox state is derived from dot state: `done -> [x]`, open/in-progress -> `[ ]`.
3. Completion loop for each task:
   - `dot on <id>`
   - implement + verify
   - `dot off <id> -r "completed"`
   - update checkbox in this file
4. Validation commands:
   - `dot ls` (must be empty when the active execution tree is fully complete)
   - `dot tree <parent-id>` (must match execution order)
   - `/Users/joel/Work/hoist/docs/plan_dot_inventory.md` (source-plan ID inventory)

## Active Execution Tree (Small Dots)
- [x] Unify plan and dot workflow (`dot:hoist-unify-plan-and-f4b0011b`)
- [x] Merge plan sources (`dot:hoist-merge-plan-sources-a61eadce`)
- [x] Map plan tasks to dots (`dot:hoist-map-plan-tasks-1aee1613`)
- [x] Rewrite PLAN.md canonical (`dot:hoist-rewrite-plan-canonical-fb1588ca`)
- [x] Validate plan-dot sync (`dot:hoist-validate-plan-dot-4bbe3bde`)
- [x] Detailed execution tree archived under `dot:hoist-unify-plan-and-f4b0011b` in `.dots/archive/hoist-unify-plan-and-f4b0011b/`

## Canonical Parity Milestones (Merged From All Sources)

### Tracking + Baselines
- [x] Cranelift parity audit (`dot:hoist-cranelift-parity-audit-3a893f8d`)
- [x] Refresh cranelift gap doc (`dot:hoist-update-cranelift-gaps-22b137a8`)
- [x] Refresh feature gap doc (`dot:hoist-update-feature-gaps-a080115c`)
- [x] Refresh parity status docs (`dot:hoist-update-parity-docs-4f2077a3`)
- [x] Add baseline checks (`dot:hoist-add-baseline-checks-6731b0c3`)
- [x] Add bench baseline logging (`dot:hoist-add-bench-baseline-9f13b2d1`)
- [x] Add CLIF tool (`dot:hoist-add-clif-tool-21564028`)
- [x] Add CLIF harness (`dot:hoist-add-clif-harness-eea44db9`)
- [x] Add CLIF tests (`dot:hoist-add-clif-tests-ba835276`)
- [x] Add diff fuzz harness (`dot:hoist-add-diff-fuzz-961c3bf9`)

### Feature Detection + ISA Plumbing
- [x] AArch64 detect baseline (`dot:hoist-aarch64-detect-1c4e9c2c`)
- [x] Detect AArch64 features (`dot:hoist-detect-aarch64-features-a0643e73`)
- [x] Feature detect plumbing (`dot:hoist-feature-detect-7a88da07`)
- [x] Feature plumbing (`dot:hoist-feature-plumbing-39b6ae02`)
- [x] Wire feature use (`dot:hoist-wire-feat-use-c13b0065`)
- [x] Wire native feature detection (`dot:hoist-wire-native-feat-cd7a6a4b`)
- [x] Add A64 detect path (`dot:hoist-add-a64-detect-4f2c1dbd`)

### ABI + Calling Convention
- [x] Fix A64 callconv base (`dot:hoist-fix-a64-callconv-21cfe2c1`)
- [x] ABI parity core (`dot:hoist-abi-parity-e292ce22`)
- [x] Tailcall ABI (`dot:hoist-abi-tailcalls-ca8ca033`)
- [x] Tailcall stack support (`dot:hoist-add-tailcall-stack-21c75ca4`)
- [x] Tailcall restore support (`dot:hoist-add-tailcall-restore-aa79e26a`)
- [x] Varargs ABI wiring (`dot:hoist-wire-varargs-abi-e26b22b7`)
- [x] Varargs lowering wiring (`dot:hoist-wire-varargs-lower-da29c100`)
- [x] Varargs tests (`dot:hoist-add-varargs-tests-c1a591a0`)
- [x] Return marshaling (`dot:hoist-return-marshal-8237ef3b`)
- [x] Indirect return path (`dot:hoist-indirect-return-b3ed0b57`)
- [x] Multi-return wiring (`dot:hoist-wire-multi-return-65d02a73`)
- [x] Return tests (`dot:hoist-add-return-tests-8b730002`)
- [x] External name call fix (`dot:hoist-fix-extname-call-486417f5`)
- [x] PIC calls (`dot:hoist-add-pic-calls-168bc2ed`)
- [x] Trampoline stubs (`dot:hoist-trampoline-stubs-b4ca4f68`)
- [x] Struct args tests (`dot:hoist-struct-args-tests-4ddf9dee`)

### VMContext + TLS + Trap Semantics
- [x] VMCTX register plumbing (`dot:hoist-vmctx-reg-c1d37eef`)
- [x] TLS VMCTX integration (`dot:hoist-tls-vmctx-954d6fb6`)
- [x] TLS bounds checks (`dot:hoist-tls-bounds-f80e490b`)
- [x] FCVTZS trap semantics (`dot:hoist-trap-fcvtzs-89921e7c`)

### Regalloc + Spill/Reload Correctness
- [x] Integrate regalloc2 (`dot:hoist-integrate-regalloc2-8f36d248`)
- [x] Wire A64 regalloc path (`dot:hoist-wire-a64-regalloc-c709569d`)
- [x] Add regalloc2 core (`dot:hoist-add-regalloc2-core-e1999642`)
- [x] Add regalloc verify (`dot:hoist-add-regalloc-verify-9afedffd`)
- [x] Materialize large spill offsets (`dot:hoist-materialize-large-spill-26c5d859`)
- [x] Differential JIT/model fuzzing (`dot:hoist-add-differential-jit-195c27f8`)

### Vector Lowering + Type Legalization
- [x] Lower shuffle (`dot:hoist-lower-shuffle-b06c30d8`)
- [x] Add shuffle optimization (`dot:hoist-add-shuffle-opt-3dcc9714`)
- [x] Add dot-product patterns (`dot:hoist-add-dotprod-patterns-5f9c19ea`)
- [x] Add dot-product lowering (`dot:hoist-add-dot-product-fedc06ea`)
- [x] Legalize vector types (`dot:hoist-legalize-vector-types-030df554`)
- [x] Legalize narrow types (`dot:hoist-legalize-narrow-types-33b7b6fa`)
- [x] Split wide types (`dot:hoist-split-wide-types-77640c9e`)
- [x] Legalize types pipeline (`dot:hoist-legalize-types-ab02b4f7`)

### Addressing + Optimization Passes
- [x] Addressing modes (`dot:hoist-add-addr-modes-5ceaa6d9`)
- [x] Peephole dead moves (`dot:hoist-peephole-dead-moves-10bef64e`)
- [x] Peephole load pairs (`dot:hoist-peephole-load-pairs-51e4d3ae`)
- [x] Peephole redundant loads (`dot:hoist-peephole-redundant-loads-a6b2ed72`)
- [x] Peephole store pairs (`dot:hoist-peephole-store-pairs-90328735`)
- [x] LICM implementation (`dot:hoist-implement-licm-pass-a4ae5025`)
- [x] Partial loop optimization (`dot:hoist-implement-partial-loop-2c8a074d`)
- [x] Optimizer legalization (`dot:hoist-optimizer-legalization-eddf172d`)

### Exceptions + try_call
- [x] Runtime exception integration (`dot:hoist-exceptions-runtime-d1afab88`)
- [x] try_call parity closeout (`dot:hoist-47a9f60c662ac5e5`)

### Object Emission + Relocations
- [x] Object emission root (`dot:hoist-obj-emission-ad51d2ad`)
- [x] ELF section writer (`dot:hoist-add-elf-section-d90d3c17`)
- [x] ELF symtab writer (`dot:hoist-add-elf-symtab-c233787d`)
- [x] Mach-O section writer (`dot:hoist-add-mach-o-b3d199a0`)
- [x] COFF section writer (`dot:hoist-add-coff-section-729c5f12`)
- [x] COFF writer (`dot:hoist-coff-writer-76e95f19`)
- [x] Finish ELF writer (`dot:hoist-finish-elf-writer-03a39ee4`)
- [x] Finish Mach-O writer (`dot:hoist-finish-mach-o-42e5a740`)
- [x] Finish COFF writer (`dot:hoist-finish-coff-writer-7776ad8b`)
- [x] Fix ELF relocations (`dot:hoist-fix-elf-reloc-0c013c4d`)
- [x] Fix COFF relocations (`dot:hoist-fix-coff-reloc-e80dd588`)
- [x] Fix Mach-O relocations (`dot:hoist-fix-mach-o-e88db236`)
- [x] Fix object writer issues (`dot:hoist-fix-obj-writers-75b5006b`)
- [x] Branch relocations (`dot:hoist-branch-relocs-77085a9b`)

### Compile Throughput 2-3x (Active)
- [ ] 2-3x compile perf (`dot:hoist-2-3x-compile-dcc76f30`)
- [x] Profile phase costs (`dot:hoist-profile-phase-costs-ab37034a`)
- [x] Kill alloc hotspots (`dot:hoist-kill-alloc-hotspots-5f73ff55`)
- [x] Reuse lowering state (`dot:hoist-reuse-lowering-state-06ae009d`)
- [ ] Regalloc fast path (`dot:hoist-regalloc-fast-path-ae575e49`)
- [ ] Addressing mode fusion (`dot:hoist-addressing-mode-fusion-a5d7bc09`)
- [ ] Bench gate + report (`dot:hoist-bench-gate-report-a98c6e5d`)

## Source-ID Reconciliation
- Full cross-source ID inventory: `/Users/joel/Work/hoist/docs/plan_dot_inventory.md`
- Inventory result on this merge:
  - 99 IDs exist in dot storage
  - 29 IDs are stale/missing legacy references
- Stale IDs are retained only in the inventory; canonical execution now uses valid IDs listed above.
