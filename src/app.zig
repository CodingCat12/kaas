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

        pub fn run(self: *Self) !void {
            inline for (config.systems) |System| {
                try kaas.system.callSystem(
                    System,
                    self.allocator,
                    &self.world,
                    &self.resources,
                );
            }
        }
    };
}
