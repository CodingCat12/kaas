const std = @import("std");
const kaas = @import("root.zig");

pub const Config = struct {
    archetypes: []const type = &.{},
    systems: []const type = &.{},
    resources: []const type = &.{},
};

pub fn App(comptime config: Config) type {
    const World = kaas.world.World(config.archetypes);
    const Resources = kaas.Resources(config.resources);

    const startup_systems, const update_systems = comptime blk: {
        var update: []const type = &.{};
        var startup: []const type = &.{};

        for (config.systems) |System| {
            switch (@as(
                kaas.systems.Schedule,
                if (@hasDecl(System, "schedule")) System.schedule else .update,
            )) {
                .startup => startup = startup ++ .{System},
                .update => update = update ++ .{System},
            }
        }

        break :blk .{ startup, update };
    };

    return struct {
        allocator: std.mem.Allocator,
        resources: Resources,
        world: World,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .world = .empty,
                .resources = undefined,
            };
        }

        pub fn deinit(self: *Self) void {
            self.world.deinit(self.allocator);
            self.* = undefined;
        }

        pub fn startup(self: *Self) !void {
            inline for (startup_systems) |System| {
                try kaas.systems.callSystem(
                    System,
                    self.allocator,
                    &self.world,
                    &self.resources,
                );
            }
        }

        pub fn tick(self: *Self) !void {
            inline for (update_systems) |System| {
                try kaas.systems.callSystem(
                    System,
                    self.allocator,
                    &self.world,
                    &self.resources,
                );
            }
        }
    };
}
