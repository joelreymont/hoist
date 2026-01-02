const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

/// CPU feature bit flags.
pub const Features = struct {
    /// Feature bits (up to 64 features).
    bits: u64,

    pub fn init() Features {
        return .{ .bits = 0 };
    }

    /// Enable a feature.
    pub fn enable(self: *Features, feature_bit: u6) void {
        self.bits |= @as(u64, 1) << feature_bit;
    }

    /// Disable a feature.
    pub fn disable(self: *Features, feature_bit: u6) void {
        self.bits &= ~(@as(u64, 1) << feature_bit);
    }

    /// Check if feature is enabled.
    pub fn has(self: Features, feature_bit: u6) bool {
        return (self.bits & (@as(u64, 1) << feature_bit)) != 0;
    }

    /// Merge features from another set.
    pub fn merge(self: *Features, other: Features) void {
        self.bits |= other.bits;
    }
};

/// AArch64 CPU features.
pub const AArch64Features = struct {
    pub const NEON: u6 = 0;
    pub const FP: u6 = 1;
    pub const CRC: u6 = 2;
    pub const LSE: u6 = 3; // Large System Extensions (atomics)
    pub const SVE: u6 = 4;
    pub const SVE2: u6 = 5;
    pub const SHA2: u6 = 6;
    pub const SHA3: u6 = 7;
    pub const AES: u6 = 8;
    pub const DOTPROD: u6 = 9;
    pub const FLAGM: u6 = 10;
    pub const BF16: u6 = 11;
    pub const I8MM: u6 = 12;

    /// Baseline AArch64 features (FP + NEON).
    pub fn baseline() Features {
        var features = Features.init();
        features.enable(FP);
        features.enable(NEON);
        return features;
    }

    /// All available features.
    pub fn all() Features {
        var features = baseline();
        features.enable(CRC);
        features.enable(LSE);
        features.enable(SHA2);
        features.enable(AES);
        features.enable(DOTPROD);
        return features;
    }
};

/// Feature detection from CPU.
pub const FeatureDetector = struct {
    features: Features,
    allocator: Allocator,

    pub fn init(allocator: Allocator) FeatureDetector {
        return .{
            .features = Features.init(),
            .allocator = allocator,
        };
    }

    /// Detect features from current CPU.
    /// Simplified - in real implementation would use OS-specific APIs.
    pub fn detect(self: *FeatureDetector) !void {
        // Placeholder - would use cpuid on x86 or AT_HWCAP on aarch64
        self.features = AArch64Features.baseline();
    }

    /// Parse features from string like "+neon,+crc,-sve".
    pub fn parseFeatures(self: *FeatureDetector, feature_str: []const u8) !void {
        var iter = std.mem.splitScalar(u8, feature_str, ',');
        while (iter.next()) |feature| {
            if (feature.len < 2) continue;

            const enable = feature[0] == '+';
            const disable = feature[0] == '-';
            if (!enable and !disable) continue;

            const name = feature[1..];
            const bit = try self.featureNameToBit(name);

            if (enable) {
                self.features.enable(bit);
            } else {
                self.features.disable(bit);
            }
        }
    }

    fn featureNameToBit(self: *FeatureDetector, name: []const u8) !u6 {
        _ = self;
        if (std.mem.eql(u8, name, "neon")) return AArch64Features.NEON;
        if (std.mem.eql(u8, name, "fp")) return AArch64Features.FP;
        if (std.mem.eql(u8, name, "crc")) return AArch64Features.CRC;
        if (std.mem.eql(u8, name, "lse")) return AArch64Features.LSE;
        if (std.mem.eql(u8, name, "sve")) return AArch64Features.SVE;
        if (std.mem.eql(u8, name, "sha2")) return AArch64Features.SHA2;
        if (std.mem.eql(u8, name, "aes")) return AArch64Features.AES;
        return error.UnknownFeature;
    }

    pub fn getFeatures(self: *const FeatureDetector) Features {
        return self.features;
    }
};

test "Features enable and has" {
    var features = Features.init();

    features.enable(5);
    try testing.expect(features.has(5));
    try testing.expect(!features.has(6));
}

test "Features disable" {
    var features = Features.init();

    features.enable(3);
    try testing.expect(features.has(3));

    features.disable(3);
    try testing.expect(!features.has(3));
}

test "Features merge" {
    var f1 = Features.init();
    f1.enable(1);
    f1.enable(2);

    var f2 = Features.init();
    f2.enable(2);
    f2.enable(3);

    f1.merge(f2);

    try testing.expect(f1.has(1));
    try testing.expect(f1.has(2));
    try testing.expect(f1.has(3));
}

test "AArch64Features baseline" {
    const features = AArch64Features.baseline();

    try testing.expect(features.has(AArch64Features.FP));
    try testing.expect(features.has(AArch64Features.NEON));
    try testing.expect(!features.has(AArch64Features.SVE));
}

test "FeatureDetector parseFeatures" {
    var detector = FeatureDetector.init(testing.allocator);

    try detector.parseFeatures("+neon,+crc,-fp");

    const features = detector.getFeatures();
    try testing.expect(features.has(AArch64Features.NEON));
    try testing.expect(features.has(AArch64Features.CRC));
    try testing.expect(!features.has(AArch64Features.FP));
}

test "FeatureDetector detect" {
    var detector = FeatureDetector.init(testing.allocator);
    try detector.detect();

    const features = detector.getFeatures();
    try testing.expect(features.has(AArch64Features.FP));
    try testing.expect(features.has(AArch64Features.NEON));
}
