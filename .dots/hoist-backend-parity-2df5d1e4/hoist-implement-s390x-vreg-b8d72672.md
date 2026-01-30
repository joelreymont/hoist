---
title: Implement s390x vreg rewrite
status: open
priority: 2
issue-type: task
created-at: "2026-01-30T11:25:48.545991+01:00"
---

Context: src/backends/s390x/isa.zig:192; cause: vreg->preg rewrite TODO; fix: implement rewrite pass after regalloc; deps: Implement s390x spill/reload; verification: s390x codegen tests
