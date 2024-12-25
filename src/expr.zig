const std = @import("std");
const Lex = @import("./lex.zig").Lex;
const Token = @import("./lex.zig").Lex.Token;

pub const Stack = struct {
    allocator: std.mem.Allocator,
    last_node: ?*Node = null,

    const Node = struct {
        /// Char
        value: Lex.Token,
        prev: ?*Node = null,
    };

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

pub const ExprAnalyzer = struct {
    // Higher numbers means higher priorities
    fn getOpPrecedence(token: Token) !u8 {
        if (token.type != Token.Types.op) {
            return error.NotAnOperator;
        }
        return switch (token.value.op) {
            .@"+", .@"-" => 1,
            .@"*", .@"/" => 2,
            else => error.UnkownOperator,
        };
    }
    pub fn analyse(tok_array: []const Token, allocator: std.mem.Allocator) !void {
        // Vamos ter dois stacks, um que contém a expressão e outro com os caracteres aguardando
        var main = Stack{ .allocator = allocator };
        var waiting = Stack{ .allocator = allocator };

        for (tok_array) |token| {
            std.debug.print("current main stack:\n", .{});
            main.print();
            std.debug.print("current waiting stack:\n", .{});
            waiting.print();
            switch (token.type) {
                // Se for um número, ele vai diretamente para o main stack
                .integer, .float => {
                    try main.push(token);
                },
                // Se for um operador
                .op => {
                    outer: while (true) {
                        if (waiting.peek()) |last_node| {
                            const token_prec = try getOpPrecedence(token);
                            const last_node_prec = try getOpPrecedence(last_node.value);
                            
                            // Se a precedência atual é maior do que a do
                            // waiting stack, então colocamos o atual na
                            // waiting stack
                            if (token_prec > last_node_prec) {
                                try waiting.push(token);
                                break :outer;
                            }
                            // Se a precedência atual é igual, então colocamos
                            // a que estava no waiting stack na main e colocamos
                            // o atual no waiting stack e terminamos o loop
                            else if (token_prec == last_node_prec) {
                                _ = waiting.pop();
                                try main.push(last_node.value);
                                try waiting.push(token);
                                break :outer;
                            }
                            // Se a precedência atual é menor, então fazemos
                            // do mesmo modo que o igual, mas não terminamos o
                            // loop
                            else {
                                _ = waiting.pop();
                                try main.push(last_node.value);
                                try waiting.push(token);
                                continue :outer;
                            }
                        } 
                        // Se não tiver ninguém no waiting, então colocamos este
                        // e terminamos o loop
                        else {
                            try waiting.push(token);
                            break :outer;
                        }
                    }
                },
                else => return error.UnkownToken
            }
        }
        // Agora que terminamos os tokens, vamos liberar o waiting stack
        var node = waiting.peek();
        while (node != null) {
            const popped = waiting.pop();
            try main.push(popped.?.value);
            node = waiting.peek();
        }
        main.print();
    }
};