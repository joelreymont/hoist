---
title: Wire ISLE lower gen
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-30T11:26:54.263223+01:00\""
closed-at: "2026-02-01T18:33:44.000133+01:00"
close-reason: "completed: ISLE compile step generates backend lowerers to src/generated (build.zig:556-591, build/IsleCompileStep.zig:52-85)"
---

Context: src/generated/lower_generated.zig:1; cause: ISLE compiler invocation TODO; fix: run ISLE generator in build to produce lower_generated; deps: isle compiler integration; verification: rebuild generated files + zig build test
