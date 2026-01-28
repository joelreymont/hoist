---
title: Disable red zone on Darwin platforms
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T07:32:17.352963+02:00"
closed-at: "2026-01-07T07:42:39.724133+02:00"
---

File: src/backends/aarch64/abi.zig:~350 (setupFrame). AAPCS64 allows 128-byte red zone below SP for leaf functions. Darwin disables this. Add red_zone_allowed field to ABICallee, default true, false on Darwin. In setupFrame: if (!callee.red_zone_allowed) force frame creation even for leaf. Test: verify leaf function with locals >0 creates frame on Darwin. ~25 lines. Depends: Platform enum (hoist-47c59c95d112fb5e).
