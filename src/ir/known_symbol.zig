//! Well-known runtime symbols.
//!
//! Ported from cranelift-codegen ir/known_symbol.rs.
//! Defines symbols that the compiler knows about and may reference in generated code.

const std = @import("std");

/// A well-known symbol.
pub const KnownSymbol = enum {
    /// ELF well-known linker symbol _GLOBAL_OFFSET_TABLE_
    elf_global_offset_table,
    /// TLS index symbol for the current thread.
    /// Used in COFF/PE file formats.
    coff_tls_index,

    /// Parse a KnownSymbol from a string.
    pub fn parse(s: []const u8) ?KnownSymbol {
        if (std.mem.eql(u8, s, "ElfGlobalOffsetTable")) return .elf_global_offset_table;
        if (std.mem.eql(u8, s, "CoffTlsIndex")) return .coff_tls_index;
        return null;
    }

    /// Format for display.
    pub fn format(
        self: KnownSymbol,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.writeAll(@tagName(self));
    }
};

const testing = std.testing;

test "KnownSymbol parse" {
    try testing.expectEqual(
        KnownSymbol.elf_global_offset_table,
        KnownSymbol.parse("ElfGlobalOffsetTable").?,
    );
    try testing.expectEqual(
        KnownSymbol.coff_tls_index,
        KnownSymbol.parse("CoffTlsIndex").?,
    );
    try testing.expectEqual(@as(?KnownSymbol, null), KnownSymbol.parse("Invalid"));
}
