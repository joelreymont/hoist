---
title: Implement s390x vreg rewrite
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.849251+01:00"
blocks:
  - hoist-implement-s390x-spill-46f821db
---

Context: src/backends/s390x/isa.zig:192; cause: vreg->preg rewrite TODO; fix: implement rewrite pass after regalloc; deps: Implement s390x spill/reload; verification: s390x codegen tests
