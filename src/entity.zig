/// Create a new entity reference from an index.
pub fn new(idx: usize) T {
    std.debug.assert(idx < std.math.maxInt(u32));
    return @enumFromInt(@as(u32, @intCast(idx)));
}

/// Get the index from this entity reference.
pub fn index(self: T) usize {
    return @as(usize, @intCast(@intFromEnum(self)));
}

/// Reserved sentinel value (u32::MAX).
pub fn reserved() T {
    return @enumFromInt(std.math.maxInt(u32));
}

/// Check if this is the reserved value.
pub fn isReserved(self: T) bool {
    return @intFromEnum(self) == std.math.maxInt(u32);
}
