---
title: "IR: type system"
status: closed
priority: 1
issue-type: task
created-at: "2026-01-01T10:59:36.782051+02:00"
closed-at: "2026-01-01T11:40:49.400693+02:00"
close-reason: Implemented types.zig with correct u16 encoding from generated Cranelift code. All tests pass.
---

src/ir/types.zig (~1k LOC)

Port from: cranelift/codegen/src/ir/types.rs

Implements:
- Type enum: I8, I16, I32, I64, I128, F32, F64, F128
- Vector types with lane counts (I8X16, F32X4, etc.)
- Type operations: bytes(), bits(), lane_count(), lane_type()
- Reference types for GC integration

Key types:
- Type: core type enum with packed representation
- TypeList: small-vec for function signatures

Tests: type size, lane operations, format/parse roundtrip
