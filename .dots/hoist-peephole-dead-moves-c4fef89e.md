---
title: Peephole dead moves
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T18:27:04.096308+01:00"
---

Context: src/codegen/peephole.zig:121-128; cause: dead move elimination not implemented; fix: remove redundant mov_rr; deps: none; verification: zig build test
