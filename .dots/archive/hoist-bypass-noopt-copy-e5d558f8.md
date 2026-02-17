---
title: Bypass noopt copy
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-18T08:24:43.984416+01:00\""
closed-at: "2026-02-18T08:28:09.682819+01:00"
close-reason: "discarded: no >=5% retained gain"
---

Full context: emitAArch64WithAllocation still allocates/copies each block into block_insts even when run_peephole=false. Fix: bypass temp list and emit directly from vcode block slice on no-opt path; keep existing peephole flow unchanged for optimize=true. Verify via tests + repeat-9 gate against /tmp/hoist-noopt-peephole-r9.log baseline; retain only if >=5% gains and no regressions.
