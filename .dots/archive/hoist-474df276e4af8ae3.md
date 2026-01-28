---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:46:06.195903+02:00"
closed-at: "2026-01-01T09:05:34.405467+02:00"
close-reason: Replaced with correctly titled task
---

Create build.zig with ISLE compilation step. Compiles .isle files to .zig during build using ISLE compiler. Depends on: ISLE compiler (hoist-474dea951b7c65e0). Files: build.zig, build/isle_compile.zig. Automated ISLE→Zig codegen in build process. Pattern: CompileStep runs ISLE compiler on *.isle → generates src/backends/*/lower_generated.zig and src/opts/generated.zig.
