---
title: Wire ISLE opts gen
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-30T11:26:57.099582+01:00\""
closed-at: "2026-02-01T18:33:47.723540+01:00"
close-reason: "completed: ISLE compile step includes opts.isle -> src/generated/opts_generated.zig (build.zig:556-591)"
---

Context: src/generated/opts_generated.zig:1; cause: ISLE compiler invocation TODO; fix: run ISLE generator in build to produce opts_generated; deps: isle compiler integration; verification: rebuild generated files + zig build test
