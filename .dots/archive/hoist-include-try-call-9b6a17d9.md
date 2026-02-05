---
title: Include try_call_indirect in LSDA scan
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T00:06:22.822930+01:00\""
closed-at: "2026-02-06T00:08:46.193809+01:00"
close-reason: LSDA now collects try_call_indirect callsites with regression coverage
---

Context: /Users/joel/Work/hoist/src/codegen/compile.zig:5837 scans only .try_call when building LSDA. Cause: try_call_indirect exception sites are omitted from unwind metadata, breaking parity with direct try_call semantics. Fix: include .try_call_indirect in LSDA callsite collection, refactor scan into shared helper, and add regression test in /Users/joel/Work/hoist/src/codegen/compile.zig validating callsite emission for indirect try_call with mapped landing pad offset. Deps: hoist-exceptions-runtime-d1afab88. Verification: zig build test -- --test-filter "compile: LSDA" && zig build test -j1 --global-cache-dir .zig-global-cache
