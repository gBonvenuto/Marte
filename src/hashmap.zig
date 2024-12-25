// Eu sei que já existe um hashmap no std, mas eu quis fazer o meu pra eu lembrar como faz
const std = @import("std");

pub const VariablesHashMap = struct {
    pub const Node = struct { ptrToVal: *void = undefined, name: []const u8 = undefined, next: ?*Node = null };
    len: usize,
    map: []?*Node = undefined,
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !VariablesHashMap {
        const len = 7529;
        var map: []?*Node = try allocator.alloc(?*Node, len);
        for (0..len) |i| {
            map[i] = null;
        }
        return VariablesHashMap{ .map = map, .len = len, .allocator = allocator };
    }
    //TODO:
    //deinit()

    /// Assign variable
    pub fn assignVar(self: VariablesHashMap, varName: []const u8, ptr: *void) !void {
        var hash: usize = 0;
        for (varName) |char| {
            hash += char;
        }
        hash %= self.len;

        // Verificando se a variável já foi criada
        var node: ?*Node = self.map[hash];
        var node_prev: ?*Node = null;
        std.debug.print("self.map[hash] = {any}\nnode_prev = {any}\n", .{node, node_prev});

        while (node != null) {
            std.debug.print("entramos no loop\n", .{});
            if (std.mem.eql(u8, varName, node.?.name)) {
                // Se chegou aqui é porque a variável já existe, então mudamos o seu valor
                node.?.*.ptrToVal = ptr;
                return;
            } else {
                node_prev = node;
                node = node.?.next;
            }
        }
        // Se chegou aqui é pq a variável ainda não foi criada
        const new_node = try self.allocator.create(Node);
        new_node.* = Node{ .ptrToVal = ptr, .name = varName, .next = null };

        if (node_prev == null) {
            std.debug.print("New node: {any}, Node: {any}\n", .{ new_node, node});
            self.map[hash] = new_node;
        } else {
            std.debug.print("New node: {any}, Prev node: {any}\n", .{ new_node, node_prev });
            node_prev.?.next.? = new_node;
        }
    }

    /// Returns the pointer to the value
    pub fn getVar(self: VariablesHashMap, varName: []const u8) !?u32 {
        var hash: usize = 0;
        for (varName) |char| {
            hash += char;
        }
        hash %= self.len;

        var node: ?*Node = self.map[hash];
        while (node != null) {
            if (std.mem.eql(u8, varName, node.?.name)) {
                return node.?.*.ptrToVal;
            } else {
                node = node.?.next;
            }
        }
        return error.VarNonexistent;
    }
};
