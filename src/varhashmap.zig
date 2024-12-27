// Eu sei que já existe um hashmap no std, mas eu quis fazer o meu pra eu lembrar como faz
const std = @import("std");
const Lex = @import("./lex.zig").Lex;
const Token = Lex.Token;

pub const VariablesHashMap = struct {
    pub const Node = struct { value: Token = undefined, name: Token = undefined, next: ?*Node = null };
    len: usize,
    map: []?*Node = undefined,
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !VariablesHashMap {
        const len = 101;
        var map: []?*Node = try allocator.alloc(?*Node, len);
        for (0..len) |i| {
            map[i] = null;
        }
        return VariablesHashMap{ .map = map, .len = len, .allocator = allocator };
    }
    pub fn print(self: VariablesHashMap) void {
        for (self.map) |val| {
            var node = val;
            while (node != null) {
                std.debug.print("{s}={} -> ", .{node.?.name.value.variable, node.?.value.value});
                node = node.?.next;
            }
            std.debug.print("null\n", .{});
        }
    }

    //TODO:
    //deinit()

    fn hashInsert(self: VariablesHashMap, node: Node) !void {
        var hash: usize = 0;
        if (node.name.type != .variable) {
            return error.NameNotVariableToken;
        }
        for (node.name.value.variable) |char| {
            hash += char;
        }
        hash %= self.len;

        // Verificando se a variável já foi criada
        var node_curr: ?*Node = self.map[hash];
        var node_prev: ?*Node = null;
        const varName = node.name.value.variable;

        while (node_curr != null) {
            if (std.mem.eql(u8, varName, node_curr.?.name.value.variable)) {
                // Se chegou aqui é porque a variável já existe, então mudamos o seu valor
                node_curr.?.*.value = node.value;
                return;
            } else {
                node_prev = node_curr;
                node_curr = node_curr.?.next;
            }
        }
        // Se chegou aqui é pq a variável ainda não foi criada
        const new_node = try self.allocator.create(Node);
        new_node.* = node;

        // Se o previous é null então nunca tivemos nenhum node aqui
        if (node_prev == null) {
            self.map[hash] = new_node;
        }
        // se o previous não é null, então adicionamos este como o próximo do preivous
        else {
            node_prev.?.next = new_node;
        }
    }

    // TODO:
    // fn hashRemove() !void {}

    /// Assign variable
    pub fn assignVar(self: VariablesHashMap, variable: Token, value: Token) !void {
        if (variable.type != .variable) {
            return error.VarIsNotVariableToken;
        }
        if (value.type != .boolean and value.type != .char and value.type != .number) {
            return error.ValIsNotValueToken;
        }

        try hashInsert(self, Node{
            .name = variable,
            .value = value,
        });
    }

    /// Returns the token of the value
    pub fn getVar(self: VariablesHashMap, variable: Token) !Token {
        if (variable.type != .variable) {
            return error.VarIsNotVariableToken;
        }

        const varName = variable.value.variable;

        var hash: usize = 0;
        for (varName) |char| {
            hash += char;
        }
        hash %= self.len;

        var node: ?*Node = self.map[hash];
        while (node != null) {
            if (std.mem.eql(u8, node.?.name.value.variable, varName)) {
                return node.?.value;
            } else {
                node = node.?.next;
            }
        }
        return error.VarNonexistent;
    }
};
