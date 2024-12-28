const std = @import("std");
const Lex = @import("./lex.zig").Lex;
const Token = @import("./lex.zig").Lex.Token;
const hashmap = @import("./varhashmap.zig");

const Node = struct {
    /// Char
    value: Lex.Token,
    prev: ?*Node = null,
};

pub const Stack = struct {
    allocator: std.mem.Allocator,
    last_node: ?*Node = null,

    /// Reverses the Stack (this function modifies the current Stack)
    pub fn reverse(self: Stack) void {
        const new = Stack{};
        var node = self.pop();
        while (node != null) {
            new.push(node);
            node = self.pop();
        }
        self = new;
    }

    pub fn print(self: Stack) void {
        var node = self.last_node;

        var counter: usize = 0;
        while (node != null and counter < 5) {
            std.debug.print("{} -> ", .{node.?.value.value});
            node = node.?.prev;
            counter += 1;
        }
        std.debug.print("\n", .{});
    }

    pub fn push(self: *Stack, value: Lex.Token) !void {
        const node = try self.allocator.create(Node);
        node.*.value = value;
        node.prev = self.last_node;
        self.last_node = node;
    }

    /// Retorna o nó ou null caso o stack esteja vazio
    pub fn pop(self: *Stack) ?*Node {
        const last_node = self.last_node;
        if (last_node) |ln| {
            self.last_node = ln.prev;
        }
        return last_node;
    }

    // Retorna o last_node, mas sem tirá-lo do stack
    pub fn peek(self: Stack) ?*Node {
        return self.last_node;
    }
};
