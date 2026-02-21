---
title: Wire loop build flags
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-21T19:21:15.509316+01:00\\\"\""
closed-at: "2026-02-21T19:23:24.567795+01:00"
close-reason: completed
blocks:
  - hoist-add-5-win-14f6c973
---

Context: build.zig:60-120,633-707; cause: no first-class loop command for +5 retain policy; fix: add build options + step for min-positive gate; deps:hoist-add-5-win-14f6c973; verification: zig build -l and bench-compare with flags.
