const std = @import("std");
const Lex = @import("./lex.zig").Lex;
const hashmap = @import("./varhashmap.zig");

pub fn Stack(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        last_node: ?*Node,
        const Self = @This();

        const Node = struct {
            /// Char
            value: T,
            prev: ?*Node = null,
        };


        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .last_node = null,
            };
        }

        // TODO: stack.deinit()
        pub fn deinit() void {
            std.debug.print("deinit ainda não foi implementado\n", .{});
        }

        /// Reverses the Stack (this function modifies the current Stack)
        pub fn reverse(self: Self) void {
            const new = Stack{};
            var node = self.pop();
            while (node != null) {
                new.push(node);
                node = self.pop();
            }
            self = new;
        }

        pub fn print(self: Self) void {
            var node = self.last_node;

            var counter: usize = 0;
            while (node != null and counter < 5) {
                std.debug.print("{} -> ", .{node.?.value.value});
                node = node.?.prev;
                counter += 1;
            }
            std.debug.print("\n", .{});
        }

        /// coloca o nó no topo da pilha
        pub fn push(self: *Self, value: T) !void {
            const node = try self.allocator.create(Node);
            node.*.value = value;
            node.prev = self.last_node;
            self.last_node = node;
        }

        /// Retorna o nó ou null caso o stack esteja vazio
        pub fn pop(self: *Self) ?*Node {
            const last_node = self.last_node;
            if (last_node) |ln| {
                self.last_node = ln.prev;
            }
            return last_node;
        }

        // Retorna o last_node, mas sem tirá-lo do stack
        pub fn peek(self: Self) ?*Node {
            return self.last_node;
        }
    };
}
