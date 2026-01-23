pub const packages = struct {
    pub const deps = struct {
        pub const build_root = "/Users/joel/Work/hoist/deps";
        pub const build_zig = @import("deps");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
            .{ "mvzr", "mvzr-0.3.7-ZSOky5FtAQB2VrFQPNbXHQCFJxWTMAYEK7ljYEaMR6jt" },
            .{ "pretty", "pretty-0.10.6-Tm65r6lPAQCBxgwzehYPeqsCXQDT9kt2ktJuO-2tRfE6" },
            .{ "muad_diff", "muad_diff-0.0.1-p0-XoRGIAwBmN7XLmC4Z6Sj7mqeiUaZvwoisN1hXF81b" },
        };
    };
    pub const @"muad_diff-0.0.1-p0-XoRGIAwBmN7XLmC4Z6Sj7mqeiUaZvwoisN1hXF81b" = struct {
        pub const build_root = "/Users/joel/.cache/zig/p/muad_diff-0.0.1-p0-XoRGIAwBmN7XLmC4Z6Sj7mqeiUaZvwoisN1hXF81b";
        pub const build_zig = @import("muad_diff-0.0.1-p0-XoRGIAwBmN7XLmC4Z6Sj7mqeiUaZvwoisN1hXF81b");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
    pub const @"mvzr-0.3.7-ZSOky5FtAQB2VrFQPNbXHQCFJxWTMAYEK7ljYEaMR6jt" = struct {
        pub const build_root = "/Users/joel/.cache/zig/p/mvzr-0.3.7-ZSOky5FtAQB2VrFQPNbXHQCFJxWTMAYEK7ljYEaMR6jt";
        pub const build_zig = @import("mvzr-0.3.7-ZSOky5FtAQB2VrFQPNbXHQCFJxWTMAYEK7ljYEaMR6jt");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
    pub const @"pretty-0.10.6-Tm65r6lPAQCBxgwzehYPeqsCXQDT9kt2ktJuO-2tRfE6" = struct {
        pub const build_root = "/Users/joel/.cache/zig/p/pretty-0.10.6-Tm65r6lPAQCBxgwzehYPeqsCXQDT9kt2ktJuO-2tRfE6";
        pub const build_zig = @import("pretty-0.10.6-Tm65r6lPAQCBxgwzehYPeqsCXQDT9kt2ktJuO-2tRfE6");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
    pub const @"zcheck-0.1.0-Px1bihTWAAAkvAodyD2kta9DXdUztoCIfdS1s6TzqghA" = struct {
        pub const build_root = "/Users/joel/.cache/zig/p/zcheck-0.1.0-Px1bihTWAAAkvAodyD2kta9DXdUztoCIfdS1s6TzqghA";
        pub const build_zig = @import("zcheck-0.1.0-Px1bihTWAAAkvAodyD2kta9DXdUztoCIfdS1s6TzqghA");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "ohsnap", "deps" },
    .{ "zcheck", "zcheck-0.1.0-Px1bihTWAAAkvAodyD2kta9DXdUztoCIfdS1s6TzqghA" },
};
