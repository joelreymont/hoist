---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:46:29.532994+02:00"
closed-at: "2026-01-01T09:05:34.418090+02:00"
close-reason: Replaced with correctly titled task
---

Port IR verifier from cranelift/codegen/src/verifier/*.rs (~2000 LOC). Create src/verifier.zig with IR validation, SSA checks, type checking, CFG validation. Depends on: IR function (hoist-474de8b519abfca8), dominance (hoist-474df32cbc08af1d). Files: src/verifier.zig, verifier_test.zig. Ensures IR correctness. QUALITY: Catch bugs early!
