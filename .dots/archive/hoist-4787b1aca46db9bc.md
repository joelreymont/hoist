---
title: Fix Cargo.toml ISLE compiler binary
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T05:39:47.302533+02:00"
closed-at: "2026-01-04T05:40:31.122708+02:00"
---

File: /Users/joel/Work/hoist/build_support/isle_compile.rs:29 - Error: Errors type doesn't implement Display. Fix: Use Debug formatter {:?} instead of Display formatter {}. This is blocking the ISLE compiler from building.
