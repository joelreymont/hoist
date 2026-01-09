---
title: Lower large struct args by reference
status: open
priority: 2
issue-type: task
created-at: "2026-01-09T08:19:38.845673+02:00"
---

Handle >16 byte struct args in isle_helpers.zig. Allocate stack space, copy struct (use memcpy helper), pass pointer in X0-X7. File: isle_helpers.zig:3337+. ~60 min.
