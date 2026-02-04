const std = @import("std");

pub fn isKeyword(name: []const u8) bool {
    const keywords = [_][]const u8{
        "align",
        "allowzero",
        "and",
        "anyframe",
        "anytype",
        "asm",
        "async",
        "await",
        "break",
        "catch",
        "comptime",
        "const",
        "continue",
        "defer",
        "else",
        "enum",
        "errdefer",
        "error",
        "export",
        "extern",
        "false",
        "for",
        "if",
        "inline",
        "linksection",
        "noalias",
        "noinline",
        "nosuspend",
        "null",
        "opaque",
        "or",
        "orelse",
        "packed",
        "pub",
        "resume",
        "return",
        "struct",
        "suspend",
        "switch",
        "test",
        "threadlocal",
        "true",
        "try",
        "union",
        "unreachable",
        "usingnamespace",
        "var",
        "volatile",
        "while",
    };
    for (keywords) |kw| {
        if (std.mem.eql(u8, name, kw)) return true;
    }
    return false;
}

pub fn isValidIdent(name: []const u8) bool {
    if (name.len == 0) return false;
    const first = name[0];
    if (!(std.ascii.isAlphabetic(first) or first == '_')) return false;
    for (name[1..]) |c| {
        if (!(std.ascii.isAlphanumeric(c) or c == '_')) return false;
    }
    return !isKeyword(name);
}

pub fn writeIdent(writer: anytype, name: []const u8) !void {
    if (isValidIdent(name)) {
        try writer.writeAll(name);
    } else {
        try writer.print("@\"{s}\"", .{name});
    }
}

pub fn writeDotted(writer: anytype, name: []const u8) !void {
    var it = std.mem.splitScalar(u8, name, '.');
    var first = true;
    while (it.next()) |part| {
        if (!first) try writer.writeByte('.');
        first = false;
        try writeIdent(writer, part);
    }
}

pub fn writeEnumLit(writer: anytype, name: []const u8) !void {
    if (std.mem.indexOfScalar(u8, name, '.')) |_| {
        try writeDotted(writer, name);
    } else {
        try writer.writeByte('.');
        try writeIdent(writer, name);
    }
}
