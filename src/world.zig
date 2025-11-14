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

        pub fn query(self: *Self, comptime Components: type, allocator: std.mem.Allocator) ![]const Components {
            var list: std.ArrayList(Components) = .empty;
            errdefer list.deinit(allocator);

            storages: inline for (std.meta.fields(Storages)) |field| {
                const Archetype = field.type.Child;

                // Ensure this archetype has all queried components
                inline for (std.meta.fields(Components)) |component| {
                    comptime var found = false;
                    inline for (@typeInfo(Archetype).@"struct".fields) |archetype_field| {
                        if (comptime std.mem.eql(u8, @typeName(std.meta.Child(component.type)), @typeName(archetype_field.type))) {
                            found = true;
                            break;
                        }
                    }
                    if (!found) continue :storages;
                }

                const slice: std.MultiArrayList(Archetype).Slice =
                    @field(self.storages, field.name).inner.slice();
                const res_slice = try list.addManyAsSlice(allocator, slice.len);

                inline for (std.meta.fields(Components)) |component| {
                    const FieldType = std.meta.Child(component.type);
                    comptime var field_name: []const u8 = &.{};

                    inline for (std.meta.fields(Archetype)) |archetype_field| {
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
