---
title: Assert CCMP lowering patterns
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T20:17:52.722608+01:00\""
closed-at: "2026-02-06T20:20:12.231279+01:00"
close-reason: Replace TODO placeholders with lowered vcode assertions for cmp/csel patterns in AND/OR compare-select tests
---

Context: /Users/joel/Work/hoist/tests/aarch64_ccmp.zig TODO placeholders; cause: tests only checked non-empty code and skipped instruction verification; fix: compile with codegen context and assert presence of CMP+CCMP+CSEL patterns in lowered AArch64 vcode for AND/OR cases; deps: none; verification: zig build test -j1 --global-cache-dir .zig-global-cache
