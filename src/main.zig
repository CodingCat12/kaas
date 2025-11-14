const std = @import("std");
const kaas = @import("kaas");

pub fn module(comptime mod: *kaas.Module) void {
    const Position = struct { x: f32, y: f32 };
    const Velocity = struct { x: f32, y: f32 };

    const Player = struct {
        pos: Position,
        vel: Velocity,
    };

    mod.bundle(Player);

    const World = mod.World();

    const Setup = struct {
        pub fn run(
            allocator: std.mem.Allocator,
            world: kaas.systems.World(World),
        ) !void {
            _ = try world.ptr.spawn(Player, allocator, .{
                .pos = .{ .x = 0.2, .y = 37.5 },
                .vel = .{ .x = 10, .y = 0 },
            });
        }
    };

    const Movement = struct {
        pub fn run(
            query: kaas.Query(struct { pos: *Position, vel: *const Velocity }),
        ) void {
            while (query.next()) |entry| {
                entry.pos.x += entry.vel.x;
                entry.pos.y += entry.vel.y;
            }
        }
    };

    const Print = struct {
        pub fn run(
            query: kaas.Query(struct { pos: *const Position }),
        ) void {
            var i: usize = 0;
            while (query.next()) |item| : (i += 1) {
                std.debug.print("{d}. x: {d:.2}, y: {d:.2}\n", .{ i, item.pos.x, item.pos.y });
            }
        }
    };

    mod.system(Setup);
    mod.system(Movement);
    mod.system(Print);
}

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();

    const allocator = debug_allocator.allocator();

    var app = kaas.rootApp(allocator);
    defer app.deinit();

    try app.run();
}
