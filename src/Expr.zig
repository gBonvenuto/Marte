const std = @import("std");

pub const Stack = struct {
    allocator: std.mem.Allocator,
    last_node: ?*Node = null,

    const Node = struct {
        /// Char
        value: u8,
        prev: ?*Node = null,
    };

    pub fn print(self: Stack) void {
        var node = self.last_node;

        var counter: usize = 0;
        while (node != null and counter < 5) {
            std.debug.print("{c} -> ", .{node.?.value});
            node = node.?.prev;
            counter+=1;
        }
        std.debug.print("\n", .{});
    }

    pub fn push(self: *Stack, value: u8) !void {
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
    pub fn analyse(string: []const u8, allocator: std.mem.Allocator) !void {
        // Vamos ter dois stacks, um que contém a expressão e outro com os caracteres aguardando
        var main = Stack{.allocator = allocator};
        var waiting = Stack{.allocator = allocator};

        for (string) |char| {
            std.debug.print("current main stack:", .{});
            main.print();
            std.debug.print("current waiting stack:", .{});
            waiting.print();
            switch (char) {
                '0'...'9' => {
                    try main.push(char);
                },
                '+', '-' => {
                    outer: while (true) {
                        const last_node_waiting = waiting.peek();

                        if (last_node_waiting) |last_node| {
                            switch (last_node.value) {
                                // Se tiver a mesma ordem de precedência tiramos
                                // o que estava no waiting stack e o colocamos
                                // no mais stack, adicionamos o caracter atual
                                // no waiting stack e finalizamos
                                '+', '-' => {
                                    try main.push(last_node.value);
                                    _ = waiting.pop();
                                    try waiting.push(char);
                                    break :outer;
                                },
                                // Se tiver ordem de precedência maior, tiramos
                                // o caracter do waiting e o colocamos no main.
                                // e repetimos o while
                                else => {
                                    _ = waiting.pop();
                                    try main.push(last_node.value);
                                    continue :outer;
                                },
                            }
                        }

                        // Se o waiting stack estiver vazio, apenas adicionamos o
                        // character no waiting stack
                        else {
                            try waiting.push(char);
                            break :outer;
                        }
                    }
                },

                '*', '/' => {
                    outer: while (true) {
                        const last_node_waiting = waiting.peek();

                        if (last_node_waiting) |last_node| {
                            switch (last_node.value) {
                                // Se tiver ordem de precedência menor, apenas
                                // colocamos o caracter atual na waiting
                                '+', '-' => {
                                    try waiting.push(char);
                                    break :outer;
                                },
                                // Se tiver a mesma ordem de precedência tiramos 
                                // o que estava no waiting stack e o colocamos
                                // no mais stack, adicionamos o caracter atual
                                // no waiting stack e finalizamos
                                '*', '/' => {
                                    try main.push(last_node.value);
                                    _ = waiting.pop();
                                    try waiting.push(char);
                                    break :outer;
                                },
                                // Se tiver ordem de precedência maior, tiramos
                                // o caracter do waiting e o colocamos no main.
                                // e repetimos o while
                                else => {
                                    _ = waiting.pop();
                                    try main.push(last_node.value);
                                    continue :outer;
                                },
                            }
                        }

                        // Se o waiting stack estiver vazio, apenas adicionamos o
                        // character no waiting stack
                        else {
                            try waiting.push(char);
                            break;
                        }
                    }
                },
                else => return error.UnknownOp,
            }
        }
        var node = waiting.peek();
        while (node != null) {
            const popped = waiting.pop();
            try main.push(popped.?.value);
            node = waiting.peek();
        }
        main.print();
    }
};
