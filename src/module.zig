const std = @import("std");
const kaas = @import("root.zig");

pub const Bundle = struct { inner: type };

pub fn bundle(comptime T: type) Bundle {
    return .{ .inner = T };
}

pub const System = struct {
    schedule: enum { startup, update },
    inner: type,
};

pub fn system(comptime T: type) System {
    return .{
        .schedule = if (@hasDecl(T, "schedule")) T.schedule else .update,
        .inner = T,
    };
}

pub const Resource = struct { inner: type };

pub fn resource(comptime T: type) Resource {
    return .{ .inner = T };
}

pub fn module(comptime Module: type) kaas.AppConfig {
    var bundles: []const type = &.{};
    var systems: []const type = &.{};
    var resources: []const type = &.{};

    inline for (@typeInfo(Module).@"struct".decls) |decl| {
        const val = @field(Module, decl.name);

        switch (@TypeOf(val)) {
            Bundle => bundles = bundles ++ .{val.inner},
            System => systems = systems ++ .{val.inner},
            Resource => resources = resources ++ .{val.inner},
            else => continue,
        }
    }

    return .{
        .archetypes = bundles,
        .systems = systems,
        .resources = resources,
    };
}
