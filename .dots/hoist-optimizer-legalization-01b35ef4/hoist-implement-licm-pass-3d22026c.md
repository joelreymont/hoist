---
title: Implement LICM pass
status: open
priority: 2
issue-type: task
created-at: "2026-01-30T11:26:21.406818+01:00"
---

Context: src/codegen/optimize.zig:168; cause: LICM pass stub TODO; fix: build loop invariant detection + hoist to preheader; deps: domtree + loop analysis; verification: add LICM tests + zig build test
