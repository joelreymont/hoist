---
title: Tighten try_call lowering semantics tests
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T21:07:32.320359+01:00\""
closed-at: "2026-02-06T21:12:26.590785+01:00"
close-reason: Make try_call terminator behavior explicit and test for emitted normal edges
---

src/codegen/compile.zig: strengthen direct/indirect try_call lowering tests to assert explicit normal-successor branch emission and avoid redundant jump terminators in test IR. src/backends/aarch64/isle_helpers.zig: remove stale CBZ-based comment and document LSDA/unwinder path. Depends on PLAN.md section 7.3. Est: 20m
