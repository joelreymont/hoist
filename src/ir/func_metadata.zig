//! Function metadata for external function references.
//!
//! FuncRef in entities.zig is just a u32 index. This module provides
//! the metadata storage for external functions: name, signature, linkage.

const std = @import("std");
const entities = @import("entities.zig");
const signature_mod = @import("signature.zig");
const external_name_mod = @import("external_name.zig");

pub const FuncRef = entities.FuncRef;
pub const SigRef = entities.SigRef;
pub const ExternalName = external_name_mod.ExternalName;
pub const Signature = signature_mod.Signature;

/// Metadata for an external function.
pub const FuncMetadata = struct {
    /// Function name (symbol name for linking).
    name: ExternalName,
    /// Function signature (parameters and returns).
    sig_ref: SigRef,
    /// Linkage type.
    linkage: Linkage,

    pub const Linkage = enum {
        /// Imported from external library.
        import,
        /// Exported from this module.
        export,
        /// Local to this module.
        local,
    };
};

/// Function metadata table.
pub const FuncMetadataTable = struct {
    /// Metadata entries indexed by FuncRef.
    metadata: std.ArrayList(FuncMetadata),
    /// Allocator for table.
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) FuncMetadataTable {
        return .{
            .metadata = std.ArrayList(FuncMetadata){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FuncMetadataTable) void {
        // Free external names
        for (self.metadata.items) |meta| {
            meta.name.deinit(self.allocator);
        }
        self.metadata.deinit(self.allocator);
    }

    /// Register a new external function.
    /// Returns FuncRef for use in call/try_call instructions.
    pub fn registerExternalFunc(
        self: *FuncMetadataTable,
        name: ExternalName,
        sig_ref: SigRef,
        linkage: FuncMetadata.Linkage,
    ) !FuncRef {
        const index = @as(u32, @intCast(self.metadata.items.len));
        try self.metadata.append(self.allocator, .{
            .name = name,
            .sig_ref = sig_ref,
            .linkage = linkage,
        });
        return FuncRef.new(index);
    }

    /// Get metadata for a function reference.
    pub fn getMetadata(self: *const FuncMetadataTable, func_ref: FuncRef) ?*const FuncMetadata {
        const index = func_ref.index();
        if (index >= self.metadata.items.len) return null;
        return &self.metadata.items[index];
    }

    /// Get mutable metadata for a function reference.
    pub fn getMetadataMut(self: *FuncMetadataTable, func_ref: FuncRef) ?*FuncMetadata {
        const index = func_ref.index();
        if (index >= self.metadata.items.len) return null;
        return &self.metadata.items[index];
    }
};

// Tests
const testing = std.testing;

test "FuncMetadataTable: init and deinit" {
    const allocator = testing.allocator;
    var table = FuncMetadataTable.init(allocator);
    defer table.deinit();

    try testing.expectEqual(@as(usize, 0), table.metadata.items.len);
}

test "FuncMetadataTable: register and get" {
    const allocator = testing.allocator;
    var table = FuncMetadataTable.init(allocator);
    defer table.deinit();

    // Register a function
    const name = try ExternalName.testable(allocator, "test_func");
    const func_ref = try table.registerExternalFunc(name, SigRef.new(0), .import);

    try testing.expectEqual(@as(u32, 0), func_ref.index());
    try testing.expectEqual(@as(usize, 1), table.metadata.items.len);

    // Get metadata
    const meta = table.getMetadata(func_ref);
    try testing.expect(meta != null);
    try testing.expectEqual(SigRef.new(0), meta.?.sig_ref);
    try testing.expectEqual(FuncMetadata.Linkage.import, meta.?.linkage);
}

test "FuncMetadataTable: multiple functions" {
    const allocator = testing.allocator;
    var table = FuncMetadataTable.init(allocator);
    defer table.deinit();

    // Register multiple functions
    const name1 = try ExternalName.testable(allocator, "func1");
    const func1 = try table.registerExternalFunc(name1, SigRef.new(0), .import);

    const name2 = try ExternalName.testable(allocator, "func2");
    const func2 = try table.registerExternalFunc(name2, SigRef.new(1), .export);

    const name3 = try ExternalName.testable(allocator, "func3");
    const func3 = try table.registerExternalFunc(name3, SigRef.new(2), .local);

    try testing.expectEqual(@as(usize, 3), table.metadata.items.len);

    // Verify each function
    try testing.expectEqual(@as(u32, 0), func1.index());
    try testing.expectEqual(@as(u32, 1), func2.index());
    try testing.expectEqual(@as(u32, 2), func3.index());

    const meta1 = table.getMetadata(func1).?;
    try testing.expectEqual(SigRef.new(0), meta1.sig_ref);
    try testing.expectEqual(FuncMetadata.Linkage.import, meta1.linkage);

    const meta2 = table.getMetadata(func2).?;
    try testing.expectEqual(SigRef.new(1), meta2.sig_ref);
    try testing.expectEqual(FuncMetadata.Linkage.export, meta2.linkage);
}

test "FuncMetadataTable: invalid func_ref" {
    const allocator = testing.allocator;
    var table = FuncMetadataTable.init(allocator);
    defer table.deinit();

    // Get metadata for non-existent function
    const invalid = FuncRef.new(999);
    const meta = table.getMetadata(invalid);
    try testing.expect(meta == null);
}
