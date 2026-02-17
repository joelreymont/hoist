---
title: Wire release gate defaults
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T13:08:21.816276+01:00\\\"\""
closed-at: "2026-02-17T13:15:26.878158+01:00"
close-reason: validated bench-gate default path now uses release benchmark profile; with repeat=3 benchmark medians are release-level (fib 57us, large5000 5576us) and gate passes without -Doptimize flag
---

Context: build.zig:571-610; cause: bench-gate can run against non-production profile; fix: route bench-log/baseline-log/bench-gate through release benchmark profile by default; deps: Add release bench option; verification: zig build bench-gate without optimize flag produces release-like medians.
