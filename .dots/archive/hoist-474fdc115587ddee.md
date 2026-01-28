---
title: "integration: build system"
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-01T11:03:00.375955+02:00\""
closed-at: "\"2026-01-01T17:13:57.514424+02:00\""
close-reason: "\"completed: build.zig with test-integration, bench steps, ISLE compilation hooks (commented for bootstrap)\""
blocks:
  - hoist-474fdc1140da6cb6
---

build.zig enhancements

ISLE compilation integration:
- Custom build step: .isle -> .zig
- Dependency tracking for incremental builds
- Run ISLE compiler during build

Structure:
  const isle_step = b.addIsleCompile(.{
      .sources = &.{
          'src/backends/x64/lower.isle',
          'src/backends/x64/inst.isle',
      },
      .output = 'src/backends/x64/lower_generated.zig',
  });

Bootstrap strategy:
1. Check in generated files initially
2. Add isle_step once Zig ISLE compiler works
3. Or: shell out to Rust cranelift-isle

Test infrastructure:
- zig build test (unit tests)
- zig build test-integration
- zig build bench
