---
title: Add NaN canonicalization + remove-constant-phi passes
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T21:01:28.161929+02:00"
closed-at: "2026-01-05T09:39:03.173708+02:00"
---

Cranelift passes in codegen/src/nan_canonicalization.rs:1-125 and remove_constant_phis.rs:1-160; Hoist has no corresponding passes. Root cause: optimization pipeline missing these transforms. Fix: port passes and hook into codegen/optimize pass ordering.
