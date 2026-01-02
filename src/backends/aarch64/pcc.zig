const std = @import("std");

/// Provenance Carry-Through (PCC) support for aarch64.
///
/// PCC tracks pointer provenance through operations to ensure memory safety
/// and capability semantics. This is primarily used for CHERI-enabled systems
/// but can provide additional safety guarantees on standard aarch64.
///
/// For standard aarch64, this provides:
/// - Tracking which values are pointers vs integers
/// - Ensuring pointer comparisons use appropriate instructions
/// - Preventing pointer/integer confusion in arithmetic
///
/// For CHERI aarch64 (Morello), this would additionally track:
/// - Capability bounds and permissions
/// - Capability derivation chains
/// - Tag propagation through memory

/// Provenance tracking for a value.
pub const Provenance = enum {
    /// Value is a pure integer with no pointer derivation
    integer,

    /// Value is derived from a pointer (has provenance)
    pointer,

    /// Value provenance is unknown (conservative: treat as pointer)
    unknown,

    /// Merge two provenance states.
    /// If either is a pointer, result is a pointer.
    pub fn merge(self: Provenance, other: Provenance) Provenance {
        return switch (self) {
            .pointer => .pointer,
            .unknown => switch (other) {
                .pointer => .pointer,
                .integer, .unknown => .unknown,
            },
            .integer => switch (other) {
                .pointer => .pointer,
                .unknown => .unknown,
                .integer => .integer,
            },
        };
    }

    /// Check if provenance allows pointer operations.
    pub fn isPointer(self: Provenance) bool {
        return self == .pointer or self == .unknown;
    }
};

/// Value with tracked provenance.
pub const ProvenanceValue = struct {
    /// The value identifier (SSA value, register, etc.)
    value_id: u32,

    /// Provenance of this value
    provenance: Provenance,

    pub fn init(value_id: u32, provenance: Provenance) ProvenanceValue {
        return .{
            .value_id = value_id,
            .provenance = provenance,
        };
    }

    pub fn asInteger(value_id: u32) ProvenanceValue {
        return init(value_id, .integer);
    }

    pub fn asPointer(value_id: u32) ProvenanceValue {
        return init(value_id, .pointer);
    }

    pub fn asUnknown(value_id: u32) ProvenanceValue {
        return init(value_id, .unknown);
    }
};

/// Provenance analysis context.
pub const ProvenanceAnalysis = struct {
    /// Map from value ID to provenance
    provenance_map: std.AutoHashMap(u32, Provenance),

    pub fn init(allocator: std.mem.Allocator) ProvenanceAnalysis {
        return .{
            .provenance_map = std.AutoHashMap(u32, Provenance).init(allocator),
        };
    }

    pub fn deinit(self: *ProvenanceAnalysis) void {
        self.provenance_map.deinit();
    }

    /// Set provenance for a value.
    pub fn setProvenance(self: *ProvenanceAnalysis, value_id: u32, prov: Provenance) !void {
        try self.provenance_map.put(value_id, prov);
    }

    /// Get provenance for a value (returns .unknown if not tracked).
    pub fn getProvenance(self: *ProvenanceAnalysis, value_id: u32) Provenance {
        return self.provenance_map.get(value_id) orelse .unknown;
    }

    /// Record that a value is derived from pointer arithmetic.
    pub fn deriveFromPointer(self: *ProvenanceAnalysis, result_id: u32, base_id: u32) !void {
        const base_prov = self.getProvenance(base_id);
        if (base_prov.isPointer()) {
            try self.setProvenance(result_id, .pointer);
        } else {
            try self.setProvenance(result_id, .integer);
        }
    }

    /// Record pointer-integer arithmetic (e.g., ptr + offset).
    pub fn ptrIntArithmetic(
        self: *ProvenanceAnalysis,
        result_id: u32,
        ptr_id: u32,
        int_id: u32,
    ) !void {
        const ptr_prov = self.getProvenance(ptr_id);
        const int_prov = self.getProvenance(int_id);

        // Result inherits pointer provenance if either operand is a pointer
        const result_prov = ptr_prov.merge(int_prov);
        try self.setProvenance(result_id, result_prov);
    }

    /// Check if a comparison should use pointer semantics.
    /// Returns true if either operand has pointer provenance.
    pub fn requiresPointerComparison(
        self: *ProvenanceAnalysis,
        lhs_id: u32,
        rhs_id: u32,
    ) bool {
        const lhs_prov = self.getProvenance(lhs_id);
        const rhs_prov = self.getProvenance(rhs_id);
        return lhs_prov.isPointer() or rhs_prov.isPointer();
    }
};

/// Comparison operation type for PCC.
pub const ComparisonKind = enum {
    /// Integer comparison (no provenance)
    integer,

    /// Pointer comparison (preserves provenance)
    pointer,

    pub fn fromProvenance(lhs: Provenance, rhs: Provenance) ComparisonKind {
        if (lhs.isPointer() or rhs.isPointer()) {
            return .pointer;
        }
        return .integer;
    }
};

test "Provenance merging" {
    const testing = std.testing;

    try testing.expectEqual(Provenance.pointer, Provenance.pointer.merge(.integer));
    try testing.expectEqual(Provenance.pointer, Provenance.integer.merge(.pointer));
    try testing.expectEqual(Provenance.integer, Provenance.integer.merge(.integer));
    try testing.expectEqual(Provenance.unknown, Provenance.unknown.merge(.integer));
    try testing.expectEqual(Provenance.pointer, Provenance.unknown.merge(.pointer));
}

test "Provenance value constructors" {
    const testing = std.testing;

    const int_val = ProvenanceValue.asInteger(1);
    try testing.expectEqual(Provenance.integer, int_val.provenance);
    try testing.expectEqual(@as(u32, 1), int_val.value_id);

    const ptr_val = ProvenanceValue.asPointer(2);
    try testing.expectEqual(Provenance.pointer, ptr_val.provenance);

    const unk_val = ProvenanceValue.asUnknown(3);
    try testing.expectEqual(Provenance.unknown, unk_val.provenance);
}

test "ProvenanceAnalysis basic operations" {
    const testing = std.testing;

    var analysis = ProvenanceAnalysis.init(testing.allocator);
    defer analysis.deinit();

    // Set value 1 as integer
    try analysis.setProvenance(1, .integer);
    try testing.expectEqual(Provenance.integer, analysis.getProvenance(1));

    // Set value 2 as pointer
    try analysis.setProvenance(2, .pointer);
    try testing.expectEqual(Provenance.pointer, analysis.getProvenance(2));

    // Unknown value defaults to .unknown
    try testing.expectEqual(Provenance.unknown, analysis.getProvenance(999));
}

test "ProvenanceAnalysis pointer arithmetic" {
    const testing = std.testing;

    var analysis = ProvenanceAnalysis.init(testing.allocator);
    defer analysis.deinit();

    // Value 1 is a pointer
    try analysis.setProvenance(1, .pointer);

    // Value 2 is an integer offset
    try analysis.setProvenance(2, .integer);

    // Result of ptr + int should be pointer
    try analysis.ptrIntArithmetic(3, 1, 2);
    try testing.expectEqual(Provenance.pointer, analysis.getProvenance(3));

    // Result of int + int should be integer
    try analysis.ptrIntArithmetic(4, 2, 2);
    try testing.expectEqual(Provenance.integer, analysis.getProvenance(4));
}

test "ProvenanceAnalysis pointer comparison" {
    const testing = std.testing;

    var analysis = ProvenanceAnalysis.init(testing.allocator);
    defer analysis.deinit();

    try analysis.setProvenance(1, .pointer);
    try analysis.setProvenance(2, .pointer);
    try analysis.setProvenance(3, .integer);

    // Pointer vs pointer requires pointer comparison
    try testing.expect(analysis.requiresPointerComparison(1, 2));

    // Pointer vs integer requires pointer comparison
    try testing.expect(analysis.requiresPointerComparison(1, 3));

    // Integer vs integer uses integer comparison
    try testing.expect(!analysis.requiresPointerComparison(3, 3));
}

test "ComparisonKind from provenance" {
    const testing = std.testing;

    try testing.expectEqual(
        ComparisonKind.pointer,
        ComparisonKind.fromProvenance(.pointer, .integer),
    );
    try testing.expectEqual(
        ComparisonKind.pointer,
        ComparisonKind.fromProvenance(.integer, .pointer),
    );
    try testing.expectEqual(
        ComparisonKind.integer,
        ComparisonKind.fromProvenance(.integer, .integer),
    );
    try testing.expectEqual(
        ComparisonKind.pointer,
        ComparisonKind.fromProvenance(.unknown, .pointer),
    );
}
