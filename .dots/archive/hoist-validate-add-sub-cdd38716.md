---
title: Validate ADD/SUB immediate encoding bounds
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T22:08:52.021993+01:00\""
closed-at: "2026-02-06T22:15:25.389313+01:00"
close-reason: Added add/sub immediate range+shift validation and regression coverage
---

src/backends/aarch64/emit.zig: emitAddImm/emitSubImm/emitAddsImm currently truncate u16 immediate to imm12. Add explicit imm12 bound check to reject out-of-range immediates and regression tests. Depends on hoist-validate-vector-load-bd151f1c. Est: 20m
