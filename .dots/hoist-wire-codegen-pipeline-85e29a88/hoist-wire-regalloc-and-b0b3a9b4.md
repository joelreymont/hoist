---
title: Wire Regalloc and VReg Rewrite
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.431633+01:00"
---

Context: src/codegen/compile.zig:5017; cause: no register allocation path; fix: call regalloc and rewrite vregs->pregs before emit; deps: hoist-wire-isle-lowering-852d0f1d; verification: e2e_simple
