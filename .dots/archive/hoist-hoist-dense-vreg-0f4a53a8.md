---
title: hoist-dense-vreg-origin
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-18T08:58:31.288206+01:00\\\"\""
closed-at: "2026-02-18T09:01:26.408482+01:00"
close-reason: "discarded: repeat-9 parent-vs-candidate gate regressions (serial batch +6.27%, parallel batch +6.73%)"
---

src/codegen/pipeline_state.zig + src/codegen/compile.zig replace vreg_origins AutoHashMap with dense touched-index table to eliminate hash lookups and map allocations in lowering/rematerialization hot path; preserve clear-retain semantics; gate with immediate repeat-9 parent-vs-candidate A/B and keep only >=5% wins without regressions
