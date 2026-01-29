---
title: Fix Optimizer Iconst Emission
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.349482+01:00"
---

Context: src/ir/optimize.zig:240; cause: nullary iconst with no imm; fix: emit UnaryImmData(.iconst, Imm64) and preserve value; deps: hoist-fix-ir-constants-7237f53a; verification: new optimize test for constant folding
