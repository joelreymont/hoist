---
title: Port shared settings/flags builder
status: closed
priority: 1
issue-type: task
created-at: "2026-01-04T21:00:39.929490+02:00"
closed-at: "2026-01-05T11:21:02.464908+02:00"
---

Cranelift shared settings module in ~/Work/wasmtime/cranelift/codegen/src/settings.rs:1-120 has Configurable/Flags builder; Hoist has no settings module (no src/settings.zig). Root cause: settings infra not ported. Fix: implement settings builder/Flags/Configurable in Hoist and wire into ISA/context construction.
