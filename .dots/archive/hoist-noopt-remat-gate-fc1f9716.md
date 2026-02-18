---
title: noopt remat gate
status: closed
priority: 1
issue-type: task
created-at: "\"2026-02-18T10:51:00.790684+01:00\""
closed-at: "2026-02-18T10:51:07.304838+01:00"
close-reason: "discarded: repeat-9 gate regressions"
---

file:src/codegen/compile.zig:682-6636; cause: rematerialization hash/map work in spill rewrite may dominate heavy no-opt functions; fix attempted: disable or gate remat in no-opt spill rewrite; result: repeat-9 gate regressions on large(100)/memory; discarded.
