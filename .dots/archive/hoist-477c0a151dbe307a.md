---
title: Investigate ISLE multi-result infrastructure
status: closed
priority: 2
issue-type: task
created-at: "2026-01-03T15:45:30.936776+02:00"
closed-at: "2026-01-03T15:50:45.763410+02:00"
close-reason: "Investigation complete. Summary in /tmp/multi_result_investigation.md. Key findings: (1) Infrastructure MORE complete than expected - ValueRegs, InsnColor.multi_result, Value→ValueRegs mapping all exist. (2) Missing only ISLE glue: type decl, helpers, rules (~35 LOC). (3) isplit blocked by multi-result return (needs output_pair or workaround). Recommendation: Implement iconcat MVP first (~50 LOC), defer isplit."
---

File: Entire codebase search. Oracle review shows iconcat/isplit plan has fundamental gaps: (1) No multi-result instruction infrastructure exists - InsnColor.multi_result at vcode_builder.zig:43 exists but handling code missing. (2) ValueRegs is generic ValueRegs(R) not concrete type - ISLE extern type decl unclear. (3) ValueRegs↔Value bridge missing - how does I128 IR Value map to ValueRegs(VReg)? (4) isplit produces TWO results but ISLE rules return ONE thing. Search for: existing multi-result ops, how other backends handle this, whether ISLE generated code supports it. Output: design doc with data flow, type mappings, integration points.
