---
title: Add ohsnap dependency to hoist
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T06:59:31.108616+02:00"
closed-at: "2026-01-07T07:02:06.788615+02:00"
---

File: build.zig.zon - Copy ohsnap dependency from ../dixie/build.zig.zon and ../dixie/deps/ohsnap. Add to dependencies section. Update build.zig to expose ohsnap module for tests. Needed for snapshot testing of code generation.
