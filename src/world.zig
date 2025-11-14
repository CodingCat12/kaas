const std = @import("std");
const kaas = @import("root.zig");

const Entity = kaas.Entity;

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

        pub fn query(self: *Self, comptime Components: type) Query(Components) {
            return .{ .storages = &self.storages };
        }

        pub fn Query(comptime Components: type) type {
            return struct {
                storages: *Storages,
                current_field: usize = 0,
                index: usize = 0,

                pub fn next(self: *@This()) ?Components {
                    inline for (std.meta.fields(Storages), 0..) |field, i| {
                        const storage = &@field(self.storages, field.name).inner;
                        if (self.index < storage.len and i >= self.current_field) {
                            self.current_field += 1;
                            self.index = 0;

                            var result: Components = undefined;
                            inline for (std.meta.fields(Components)) |component| {
                                const field_tag = @field(std.meta.FieldEnum(field.type.Child), component.name);
                                @field(result, component.name) = &storage.items(field_tag)[self.index];
                            }

                            self.index += 1;
                            return result;
                        }
                    }

                    return null;
                }
            };
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
