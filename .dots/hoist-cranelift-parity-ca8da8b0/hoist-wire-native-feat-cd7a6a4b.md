---
title: Wire native feat
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.729787+02:00\""
closed-at: "2026-01-23T21:01:17.754158+02:00"
---

Files: src/context.zig:161-174, src/target/features.zig:71-88
Root cause: targetNative ignores feature detection.
Fix: integrate FeatureDetector into ContextBuilder.targetNative and Target config.
Why: propagate host features to codegen.
Deps: Add x86 detect, Add a64 detect.
Verify: context tests.
