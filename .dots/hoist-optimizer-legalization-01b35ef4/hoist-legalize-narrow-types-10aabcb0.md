---
title: Legalize narrow types
status: open
priority: 2
issue-type: task
created-at: "2026-01-30T11:26:26.698172+01:00"
---

Context: src/codegen/compile.zig:1307; cause: narrow type widening TODO; fix: insert widen ops to legal width; deps: type legalizer design; verification: add legalization tests + zig build test
