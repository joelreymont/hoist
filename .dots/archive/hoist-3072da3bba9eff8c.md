---
title: Add copy propagation to pipeline
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-09T07:48:06.532809+02:00\""
closed-at: "2026-01-09T07:58:50.529727+02:00"
---

Integrate copyprop into src/codegen/compile.zig optimize() function. Run after SCCP, before GVN. Update pass count to 13/14 (93%). Files: src/codegen/compile.zig:195 (new call). ~15 min.
