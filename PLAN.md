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
- [x] 2-3x compile perf (`dot:hoist-2-3x-compile-dcc76f30`)
- [x] Profile phase costs (`dot:hoist-profile-phase-costs-ab37034a`)
- [x] Kill alloc hotspots (`dot:hoist-kill-alloc-hotspots-5f73ff55`)
- [x] Reuse lowering state (`dot:hoist-reuse-lowering-state-06ae009d`)
- [x] Regalloc fast path (`dot:hoist-regalloc-fast-path-ae575e49`)
- [x] Addressing mode fusion (`dot:hoist-addressing-mode-fusion-a5d7bc09`)
- [x] Bench gate + report (`dot:hoist-bench-gate-report-a98c6e5d`)
- [x] Persist perf history JSONL (`dot:hoist-persist-perf-history-c733cedf`)
- [x] Add budget guard thresholds (`dot:hoist-add-budget-guard-e707c938`)
- [x] Document 2x/3x verification flow (`dot:hoist-doc-2x3x-verification-149bc1b6`)
- [x] Single-thread perf follow-up (`dot:hoist-hoist-single-thread-e3e5b8d6`)
- [x] Dense liveness map (`dot:hoist-dense-liveness-map-ed60eafe`)
- [x] Fast rewrite scan (discarded: <5% retained gain) (`dot:hoist-fast-rewrite-scan-549ead70`)
- [x] Persist regalloc state (`dot:hoist-persist-regalloc-state-2b711aef`)
- [x] Next single-thread perf pass (`dot:hoist-hoist-next-single-3414e8b7`)
- [x] Peephole fast skip (discarded: <5% retained gain) (`dot:hoist-peephole-fast-skip-6378ba8e`)
- [x] Dense block map (discarded: perf regressions) (`dot:hoist-dense-block-map-9c36344d`)
- [x] Coalesce density gate (`dot:hoist-coalesce-density-gate-8244fdd2`)
- [x] Rewrite pass removal (discarded: perf regressions) (`dot:hoist-rewrite-pass-removal-9a835e88`)
- [x] ABI setup cache (discarded: <5% retained gain) (`dot:hoist-abi-setup-cache-9dbb5b0e`)
- [x] Drop unused value-use pass (`dot:hoist-drop-unused-value-81b396ff`)
- [x] Minimal single-block lower fast path (discarded: unstable rerun regressions) (`dot:hoist-minimal-single-block-62f84a9b`)
- [x] Drop lower value-use pass (discarded: no >=5% retained gain) (`dot:hoist-drop-lower-uses-927c5ec2`)
- [x] Trim vreg origin tracking (discarded: unstable rerun regressions) (`dot:hoist-trim-vreg-origins-b2cf0a2c`)
- [x] Dense spill-slot lookup in rewrite (`dot:hoist-hoist-dense-spill-540128dc`)
- [x] Dense vreg-origin side table (discarded: gate regressions) (`dot:hoist-hoist-dense-vreg-0f4a53a8`)
- [x] Dense origin lookup in spill rewrite (discarded: <5% retained gain) (`dot:hoist-hoist-dense-origin-2e033850`)
- [x] Simple rewrite fast path (`dot:hoist-hoist-simple-rewrite-b369ed64`)
- [x] Extend rewrite fast path (discarded: no retained gains) (`dot:hoist-hoist-extend-rewrite-2a05e91e`)
- [x] Reuse spill rewrite operand collector (`dot:hoist-hoist-reuse-collector-01140b1e`)
- [x] Reserve spill rewrite capacity (`dot:hoist-hoist-reserve-spill-240a20ce`)
- [x] Tune spill reserve heuristic (discarded: no broad retained gains) (`dot:hoist-hoist-tune-spill-8925eb20`)
- [x] Skip no-opt coalesce collection (`dot:hoist-hoist-skip-noopt-9c597059`)
- [x] Fold single-use iadd iconst in lowering (discarded: micro regressions) (`dot:hoist-hoist-fold-iadd-111a26ec`)
- [x] Reuse temporary block map (discarded: gate regressions) (`dot:hoist-reuse-block-map-bd8d2496`)
- [x] Fold iadd iconst + dead mov cleanup (discarded: severe gate regressions) (`dot:hoist-fold-add-iconst-520c294e`)
- [x] Retain VCode capacities across compiles (discarded: gate regressions) (`dot:hoist-retain-vcode-caps-a0300b48`)
- [x] Profile lowering hotspot workflow (`dot:hoist-profile-lower-hot-be4881ad`)
- [x] Retest VCode capacity retention vs fresh baseline (discarded: unstable rerun) (`dot:hoist-retest-vcode-caps-87cd649e`)
- [x] Retest vreg-origin trimming on fresh baseline (`dot:hoist-retest-vreg-trim-89ca94ab`)
- [x] Trim non-const vreg-origin writes (retained: repeat-9 parent-vs-candidate gains) (`dot:hoist-hoist-trim-vreg-2e212714`)
- [x] Compact vreg-origin payload (discarded: <5% retained gain) (`dot:hoist-compact-vreg-origin-94608eed`)
- [x] Skip no-opt AArch64 peephole passes (`dot:hoist-skip-noopt-peephole-ebf4b1c8`)
- [x] Retest no-opt peephole skip (discarded: <5% retained gain) (`dot:hoist-hoist-skip-noopt-17496cce`)
- [x] Bypass no-opt block copy in emit (discarded: <5% retained gain) (`dot:hoist-bypass-noopt-copy-e5d558f8`)
- [x] Remove spill pre-scan maps in rewrite (`dot:hoist-hoist-retest-spill-890e6f5d`)
- [x] Dense rewrite alloc lookup (discarded: <5% retained gain) (`dot:hoist-dense-rewrite-alloc-13e283a7`)
- [x] No-opt rematerialization gating (discarded: gate regressions) (`dot:hoist-noopt-remat-gate-fc1f9716`)
- [x] No-hint regalloc fast path (discarded: mixed-only gain, large regressions) (`dot:hoist-nohint-regalloc-fast-1968af99`)

#### Perf Verification Flow
- Capture baseline: `zig build baseline-log -Dbench-repeat=5 --global-cache-dir .zig-global-cache`
- Capture current: `zig build bench-log -Dbench-repeat=5 --global-cache-dir .zig-global-cache`
- Gate + append history: `zig build bench-gate -Dbench-repeat=5 -Dbench-history-json-path=/tmp/hoist-bench-history.jsonl --global-cache-dir .zig-global-cache`
- Enforce 2x target: `zig build bench-gate -Dbench-repeat=5 -Dbench-budget-reference-path=/tmp/hoist-baseline.log -Dbench-budget-multiplier=2 --global-cache-dir .zig-global-cache`
- Enforce 3x target: `zig build bench-gate -Dbench-repeat=5 -Dbench-budget-reference-path=/tmp/hoist-baseline.log -Dbench-budget-multiplier=3 --global-cache-dir .zig-global-cache`

### 2x Deep Review Execution (Active)
- [x] 2x perf deep loop (cycle complete: 1 retained, remaining dots discarded by gate) (`dot:hoist-2x-perf-deep-ab6e5fe4`)
- [x] Add +5 win gate (`dot:hoist-add-5-win-14f6c973`)
- [x] Wire loop build flags (`dot:hoist-wire-loop-build-220461e9`)
- [x] Document loop in PLAN (`dot:hoist-doc-loop-in-5f24d96f`)
- [x] Lower call tmp-vcode 1 (discarded: no >=5% retained win) (`dot:hoist-lower-call-tmp-a4ddff2d`)
- [x] Lower call tmp-vcode 2 (discarded: no >=5% retained win) (`dot:hoist-lower-call-tmp-f0e53136`)
- [x] Out-stack lazy compute (discarded: repeat-9 gate regressions) (`dot:hoist-out-stack-lazy-92cf6490`)
- [x] CFG liveness bitset 1 (retained: repeat-9 gate pass) (`dot:hoist-cfg-liveness-bitset-8560996b`)
- [x] CFG liveness bitset 2 (discarded: repeat-9 regressions) (`dot:hoist-cfg-liveness-bitset-d3a88f13`)
- [x] Emit stream peephole (discarded: repeat-9 regressions) (`dot:hoist-emit-stream-peephole-e8171af2`)
- [x] Regalloc event queues (discarded: no >=5% retained wins) (`dot:hoist-regalloc-event-queues-1e296560`)

#### Self-Improvement Loop (Required)
1. Pick next ready dot: `dot ready` then `dot on <id>`.
2. Capture parent baseline in separate workspace:
   - `jj workspace add /tmp/hoist-parent-<ts> -r @-`
   - `(cd /tmp/hoist-parent-<ts> && GIT_DIR=/Users/joel/Work/hoist/.git zig build gen-isle --global-cache-dir .zig-global-cache)`
   - `(cd /tmp/hoist-parent-<ts> && GIT_DIR=/Users/joel/Work/hoist/.git zig build baseline-log -Dbench-repeat=9 -Dbench-baseline-path=/tmp/hoist-parent-r9.log --global-cache-dir .zig-global-cache)`
3. Capture candidate log in working copy:
   - `zig build bench-log -Dbench-repeat=9 -Dbench-current-path=/tmp/hoist-cand-r9.log --global-cache-dir .zig-global-cache`
4. Gate regressions and positive gain threshold:
   - `zig build bench-compare -Dbench-baseline-path=/tmp/hoist-parent-r9.log -Dbench-current-path=/tmp/hoist-cand-r9.log -Dbench-report-path=/tmp/hoist-parent-vs-cand-r9.md -Dbench-report-json-path=/tmp/hoist-parent-vs-cand-r9.json -Dbench-min-positive-pct=5 -Dbench-min-positive-count=1 --global-cache-dir .zig-global-cache`
5. Keep/discard rule:
   - If gate fails for regressions or `<5%` retained positive wins: restore code and close dot as discarded.
   - If gate passes: keep code, run `zig build test -j1 --global-cache-dir .zig-global-cache`, close dot completed, update `LESSONS.md`.
6. Commit/push after each significant kept or discarded dot and start next dot.

### 2x Performance Loop v2 (Active)
- [ ] 2x perf loop v2 (`dot:hoist-2x-perf-loop-17ccae93`)
- [x] 2x baseline snapshot (`dot:hoist-2x-baseline-snapshot-7bfad64b`)
- [x] liveness cfg sorted ranges (`dot:hoist-liveness-cfg-sorted-0a1621c4`)
- [x] linear scan first-free fast (discarded: gate regressions) (`dot:hoist-linear-scan-first-263de8c9`)
- [x] lower single-block maps fast (discarded: no retained >=5% wins) (`dot:hoist-lower-single-block-8d6b2cab`)
- [x] emit single-block label fast (discarded: gate regressions) (`dot:hoist-emit-single-block-658865a8`)
- [x] single-block liveness monotonic end update (discarded: no retained >=5% wins) (`dot:hoist-single-block-liveness-7294c693`)
- [x] drop lower computeValueUses call (discarded: old-vs-new regressions) (`dot:hoist-drop-lower-computevalueuses-666e3a2f`)
- [x] hybrid rewrite fast path per instruction (discarded: gate regressions) (`dot:hoist-hybrid-rewrite-fast-0caef16a`)
- [x] gate aarch64 emit peephole by optimize flag (discarded: no retained >=5% wins) (`dot:hoist-gate-aarch64-emit-463d3885`)
- [x] fold single-use iconst into iadd immediate (retained) (`dot:hoist-fold-single-use-e8793a96`)
- [x] add compiler pgo tuning workflow (`dot:hoist-add-compiler-pgo-2be9448d`)
- [ ] regalloc 2x loop bookkeeping (`dot:hoist-regalloc-2x-loop-c637c918`)

#### 2x Loop Contract
1. Capture loop baseline once: `zig build baseline-log -Dbench-repeat=9 -Dbench-baseline-path=/tmp/hoist-2x-loop-base-r9.log --global-cache-dir .zig-global-cache`.
2. For each dot candidate:
   - `dot on <id>`
   - implement
   - `zig build test -j1 --global-cache-dir .zig-global-cache`
   - `zig build bench-log -Dbench-repeat=9 -Dbench-current-path=/tmp/hoist-2x-loop-cand-r9.log --global-cache-dir .zig-global-cache`
   - `zig build bench-compare -Dbench-baseline-path=/tmp/hoist-2x-loop-base-r9.log -Dbench-current-path=/tmp/hoist-2x-loop-cand-r9.log -Dbench-report-path=/tmp/hoist-2x-loop-report-r9.md -Dbench-report-json-path=/tmp/hoist-2x-loop-report-r9.json -Dbench-min-positive-pct=5 -Dbench-min-positive-count=1 --global-cache-dir .zig-global-cache`
3. Enforce 2x target each iteration:
   - `zig build bench-compare -Dbench-baseline-path=/tmp/hoist-2x-loop-base-r9.log -Dbench-current-path=/tmp/hoist-2x-loop-cand-r9.log -Dbench-report-path=/tmp/hoist-2x-loop-budget-r9.md -Dbench-report-json-path=/tmp/hoist-2x-loop-budget-r9.json -Dbench-budget-reference-path=/tmp/hoist-2x-loop-base-r9.log -Dbench-budget-multiplier=2 -Dbench-min-positive-pct=5 -Dbench-min-positive-count=1 --global-cache-dir .zig-global-cache`
4. Keep/discard:
   - If no regressions and >=5% retained wins: keep and update loop baseline to candidate.
   - If regressions or insufficient gains: discard candidate.
5. Stop condition:
   - Stop only when 2x budget check passes for all budgeted metrics.

## Source-ID Reconciliation
- Full cross-source ID inventory: `/Users/joel/Work/hoist/docs/plan_dot_inventory.md`
- Inventory result on this merge:
  - 99 IDs exist in dot storage
  - 29 IDs are stale/missing legacy references
- Stale IDs are retained only in the inventory; canonical execution now uses valid IDs listed above.
