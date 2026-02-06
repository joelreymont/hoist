---
title: Implement LICM pass
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-02T21:35:56.890642+01:00\\\"\""
closed-at: "2026-02-06T09:25:00.776687+01:00"
close-reason: wired LICM pass and fixed LICM compile issues
blocks:
  - hoist-optimizer-legalization-eddf172d
---

Context: src/codegen/optimize.zig:168; cause: LICM pass stub TODO; fix: build loop invariant detection + hoist to preheader; deps: domtree + loop analysis; verification: add LICM tests + zig build test
