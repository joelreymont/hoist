---
title: Default context verify off
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T15:48:56.916796+01:00\\\"\""
closed-at: "2026-02-17T15:50:49.497592+01:00"
close-reason: done
---

src/context.zig default verify currently true adds measurable single-thread compile overhead. Set default verify=false for high-performance path, keep explicit verification(true) API, update affected tests/docs, and validate bench gate + full tests.
