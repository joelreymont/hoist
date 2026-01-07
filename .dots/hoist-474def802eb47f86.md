---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:45:16.473023+02:00"
closed-at: "2026-01-01T08:53:10.945786+02:00"
close-reason: Deferred - ARM64 only initially, x64 later
---

Port x64 ISA from cranelift/codegen/src/isa/x64/mod.rs (~500 LOC). Create src/backends/x64/isa.zig implementing TargetIsa interface, settings, feature detection. Depends on: x64 ABI (hoist-474deec08fb91a2e), x64 ISLE (hoist-474def29551d6504), compile pipeline (hoist-474ded305f087ca7). Files: src/backends/x64/isa.zig. Complete x64 backend integration. MILESTONE: x64 backend functional!
