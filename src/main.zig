const std = @import("std");

pub fn main() !void {
    const Position = struct { x: f32, y: f32 };
    const Velocity = struct { x: f32, y: f32 };

    const Player = struct {
        pos: Position,
        vel: Velocity,
    };

    const Movement = struct {
        fn run(query: Query(struct { pos: *Position, vel: *const Velocity })) void {
            while (query.next()) |entry| {
                entry.pos.x += entry.vel.x;
                entry.pos.y += entry.vel.y;
            }
        }
    };

    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();

    const allocator = debug_allocator.allocator();

    var app: App(.{
        .archetypes = &.{Player},
        .systems = &.{Movement},
    }) = .init(allocator);
    defer app.deinit();

    const player = try app.world.spawn(Player, app.allocator, .{
        .pos = .{ .x = 0.2, .y = 37.5 },
        .vel = .{ .x = 10, .y = 0 },
    });

    const positions = try app.world.query(struct { *Position }, app.allocator);
    defer app.allocator.free(positions);

    std.debug.print("Before applying velocity: {any}\n", .{positions});

    try app.run();

    const updated_positions = try app.world.query(struct { *Position }, app.allocator);
    defer app.allocator.free(updated_positions);

    std.debug.print("After applying velocity: {any}\n", .{updated_positions});

    app.world.despawn(player);

    const empty_positions = try app.world.query(struct { *Position }, app.allocator);
    defer app.allocator.free(empty_positions);

    std.debug.print("After despawning entites: {any}\n", .{empty_positions});
}

pub const Config = struct {
    archetypes: []const type = &.{},
    systems: []const type = &.{},
    resources: []const type = &.{},
};

pub fn App(comptime config: Config) type {
    const WorldType = World(config.archetypes);

    return struct {
        allocator: std.mem.Allocator,
        world: WorldType,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .world = .empty,
            };
        }

        pub fn deinit(self: *Self) void {
            self.world.deinit(self.allocator);
            self.* = undefined;
        }

        pub fn run(self: *Self) !void {
            inline for (config.systems) |System| {
                try self.callSystem(System);
            }
        }

        fn callSystem(self: *Self, comptime System: type) !void {
            const runFn = System.run;
            const RunFn = @TypeOf(runFn);

            const Args = std.meta.ArgsTuple(RunFn);

            var args: Args = undefined;

            inline for (std.meta.fields(Args)) |field| {
                const Field = field.type;

                if (!@hasDecl(Field, "__kaas_query")) {
                    @compileError("Invalid system parameter: " ++ @typeName(Field));
                }

                const slice = try self.world.query(Field.Data, self.allocator);

                var inner = Field.Inner{ .slice = slice };
                @field(args, field.name).ptr = &inner;
            }

            defer inline for (@typeInfo(Args).@"struct".fields) |field| {
                if (@hasDecl(@FieldType(Args, field.name), "__kaas_query")) {
                    self.allocator.free(@field(args, field.name).ptr.slice);
                }
            };

            @call(.auto, runFn, args);
        }
    };
}

pub fn Query(comptime T: type) type {
    return struct {
        ptr: *Inner,

        const Self = @This();

        pub const Data = T;

        pub const __kaas_query: void = {};

        pub fn next(self: Self) ?T {
            if (self.ptr.index >= self.ptr.slice.len) return null;
            defer self.ptr.index += 1;
            return self.ptr.slice[self.ptr.index];
        }

        pub const Inner = struct {
            slice: []const T,
            index: usize = 0,
        };
    };
}

pub const Entity = packed struct(u128) {
    storage_index: u64,
    list_index: u64,
};

pub fn World(comptime archetypes: []const type) type {
    const Storages = ArchetypeStorages(archetypes);

    return struct {
        storages: Storages,

        const Self = @This();

        pub const empty: Self = blk: {
            var storages: Storages = undefined;
            for (@typeInfo(Storages).@"struct".fields) |field| {
                @field(storages, field.name) = .{ .inner = .empty };
            }

            break :blk .{ .storages = storages };
        };

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            inline for (@typeInfo(Storages).@"struct".fields) |field| {
                @field(self.storages, field.name).inner.deinit(allocator);
            }

            self.* = undefined;
        }

        pub fn spawn(self: *Self, comptime Archetype: type, allocator: std.mem.Allocator, bundle: Archetype) !Entity {
            inline for (@typeInfo(Storages).@"struct".fields, 0..) |field, i| {
                if (comptime std.mem.eql(u8, field.name, @typeName(Archetype))) {
                    try @field(self.storages, field.name).inner.append(allocator, bundle);

                    const list_index = @field(self.storages, field.name).inner.len - 1;
                    return .{
                        .storage_index = i,
                        .list_index = list_index,
                    };
                }
            }
        }

        pub fn despawn(self: *Self, entity: Entity) void {
            inline for (@typeInfo(Storages).@"struct".fields, 0..) |field, i| {
                if (i == entity.storage_index) {
                    @field(self.storages, field.name).inner.orderedRemove(entity.list_index);
                }
            }
        }

        pub fn query(self: *Self, comptime Components: type, allocator: std.mem.Allocator) ![]const Components {
            var list: std.ArrayList(Components) = .empty;
            errdefer list.deinit(allocator);

            storages: inline for (@typeInfo(Storages).@"struct".fields) |field| {
                const Archetype = field.type.Child;

                // Ensure this archetype has all queried components
                inline for (@typeInfo(Components).@"struct".fields) |component| {
                    comptime var found = false;
                    inline for (@typeInfo(Archetype).@"struct".fields) |archetype_field| {
                        if (comptime std.mem.eql(u8, @typeName(@typeInfo(component.type).pointer.child), @typeName(archetype_field.type))) {
                            found = true;
                            break;
                        }
                    }
                    if (!found) continue :storages;
                }

                const slice: std.MultiArrayList(Archetype).Slice =
                    @field(self.storages, field.name).inner.slice();
                const res_slice = try list.addManyAsSlice(allocator, slice.len);

                inline for (@typeInfo(Components).@"struct".fields) |component| {
                    const FieldType = @typeInfo(component.type).pointer.child;
                    comptime var field_name: []const u8 = &.{};

                    inline for (@typeInfo(Archetype).@"struct".fields) |archetype_field| {
                        if (comptime std.mem.eql(u8, @typeName(FieldType), @typeName(archetype_field.type))) {
                            field_name = archetype_field.name;
                        }
                    }

                    const field_tag = @field(std.meta.FieldEnum(Archetype), field_name);

                    const items = slice.items(field_tag);
                    for (items, 0..) |*item, i| {
                        @field(res_slice[i], component.name) = item;
                    }
                }
            }

            return list.toOwnedSlice(allocator);
        }
    };
}

fn ArchetypeStorages(comptime archetypes: []const type) type {
    var fields: [archetypes.len]std.builtin.Type.StructField = undefined;
    for (archetypes, 0..) |Archetype, i| {
        const Wrapped = struct {
            pub const Child = Archetype;

            inner: std.MultiArrayList(Archetype),
        };

        fields[i] = .{
            .name = @typeName(Archetype),
            .type = Wrapped,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(Wrapped),
        };
    }

    return @Type(.{ .@"struct" = .{
        .fields = &fields,
        .decls = &.{},
        .is_tuple = false,
        .layout = .auto,
    } });
}
