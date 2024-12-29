const std = @import("std");
const VariablesHashMap = @import("./varhashmap.zig").VariablesHashMap;
const Stack = @import("./stack.zig");
const Token = @import("lex.zig").Lex.Token;
const Expr = @import("./expr.zig");

pub const Scope = struct {
    allocator: std.mem.Allocator,
    varhashmap: VariablesHashMap,
    condition: ?[]const Token,
    code: []const Token,
    type: Type,

    const Type = enum {
        none, // If it's none, then its probably just some code outside a block
        @"if",
        elif,
        @"else",
        @"while",
        @"for",
        function,
    };

    pub fn init(condition: ?[]const Token, code: []const Token, scope_type: Type, allocator: std.mem.Allocator) !Scope {
        return Scope{
            .allocator = allocator,
            .varhashmap = try VariablesHashMap.init(allocator),
            .condition = condition,
            .code = code,
            .type = scope_type,
        };
    }
    pub fn deinit(self: @This()) void {
        self.varhashmap.deinit();
    }

    /// Returns true if the scope was executed and false if
    /// it was skipped
    pub fn processScope(self: *@This(), scopesStack: *ScopeStack, stdout_f: std.fs.File) !bool {
        const stdout = stdout_f.writer();
        // Verificando se a condição é verdadeira
        switch (self.type) {
            .@"if", .elif, .@"for", .@"while" => {
                const cond_ret = try Expr.analyse(scopesStack, self.condition.?, self.allocator);
                if (cond_ret.type == .boolean) {
                    if (!cond_ret.value.boolean) {
                        return false;
                    }
                } else {
                    return error.ExpectedBooleanForCondition;
                }
            },
            .none, .@"else", .function => {},
        }

        // Executando o código
        const arr = self.code;
        var i: usize = 0;

        while (i < arr.len) : (i += 1) {
            const token = arr[i];
            switch (token.type) {
                .keyword => {
                    switch (token.value.keyword) {
                        .@"if" => {
                            // Primeiro procuramos a keyword then
                            i += 1;
                            var condition: []const Token = undefined;
                            var initial_index = i;

                            while (i < arr.len and arr[i].type != .keyword) {
                                i += 1;
                            }
                            if (i == arr.len) {
                                return error.MissingThenKeyword;
                            }
                            if (arr[i].value.keyword == .@"then") {
                                condition = arr[initial_index..i];
                            }

                            // Agora que obtivemos a condição, vamos obter o código
                            // dentro do escopo

                            i += 1;
                            initial_index = i;
                            var code: []const Token = undefined;

                            var blockCount: usize = 0;

                            while (i < arr.len) : (i +=1){
                                if (arr[i].type == .keyword) {
                                    switch (arr[i].value.keyword) {
                                        .@"if" => {
                                            blockCount += 1;
                                        },
                                        .@"end" => {
                                            if (blockCount == 0) {
                                                break;
                                            }
                                            blockCount -= 1;
                                        },
                                        else => {}
                                    }
                                }
                            }

                            if (i == arr.len or blockCount > 0) {
                                return error.MissingEndKeyword;
                            }

                            if (blockCount < 0) {
                                return error.TooManyEndKeywords;
                            }

                            code = arr[initial_index..i];

                            try scopesStack.pushEmpty(condition, code, .@"if");
                            var ifScope = scopesStack.peek();
                            _ = try ifScope.?.processScope(scopesStack, stdout_f);
                        },
                        else => return error.NotImplemented
                    }
                },
                .variable => {
                    // Se for apenas uma única variável, então significa que devemos
                    // imprimi-la
                    if (arr.len == 1) {
                        var buf: [50]u8 = undefined;
                        const val = try scopesStack.getVar(token, self.allocator);
                        const val_str: []const u8 = switch (val.type) {
                            .number => blk: {
                                if (@mod(val.value.number, 1) == 0) {
                                    // Inteiro
                                    break :blk try std.fmt.bufPrintZ(&buf, "{d}", .{val.value.number});
                                } else {
                                    break :blk try std.fmt.bufPrintZ(&buf, "{e}", .{val.value.number});
                                }
                            },
                            .boolean => try std.fmt.bufPrintZ(&buf, "{} (boolean)", .{val.value.boolean}),
                            .char => try std.fmt.bufPrintZ(&buf, "{c} (char)", .{val.value.char}),
                            else => return error.UnknownValueType,
                        };
                        try stdout.print("{s} = {s}\n", .{ token.value.variable, val_str });
                    }
                },

                .op => {
                    switch (token.value.op) {
                        // Um igual significa que é um assignment
                        .@"=" => {
                            // Verificando se o igual não está no começo da linha
                            if (i <= 0) {
                                return error.EqualBeginningOfLine;
                                // panic("(=) at beginning of line", .{});
                            }

                            if (arr[i - 1].type != Token.Types.variable) {
                                return error.AssigningValueToNonVariable;
                                // panic("Trying to assign value to not a variable", .{});
                            }

                            if (i >= arr.len) {
                                return error.AssigningNothingToVariable;
                                // panic("Trying to assign nothing to variable", .{});
                            }

                            const ret = try Expr.analyse(scopesStack, arr[i + 1 ..], self.allocator);

                            try scopesStack.assignVar(arr[i - 1], ret);
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }

        return true;
    }
};

pub const ScopeStack = struct {
    stack: Stack.Stack(Scope),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) @This() {
        return @This(){
            .stack = Stack.Stack(Scope).init(allocator),
            .allocator = allocator,
        };
    }
    // TODO: deinit
    pub fn deinit(self: @This()) void {
        _ = self;
    }

    /// coloca o nó no topo da pilha
    pub fn pushEmpty(
        self: *@This(),
        condition: ?[]const Token,
        code: []const Token,
        scope_type: Scope.Type,
    ) !void {
        try self.stack.push(try Scope.init(condition, code, scope_type, self.allocator));
    }

    pub fn push(self: *@This(), value: Scope) !void {
        try self.stack.push(value);
    }

    pub fn print(self: *@This()) void {
        self.stack.print();
    }

    /// Retorna o nó ou null caso o stack esteja vazio
    pub fn pop(self: *@This()) ?Scope {
        const popped = self.stack.pop();
        if (popped != null) {
            return popped.?.value;
        } else {
            return null;
        }
    }

    // Retorna o last_node, mas sem tirá-lo do stack
    pub fn peek(self: @This()) ?Scope {
        const peeked = self.stack.peek();
        if (peeked != null) {
            return peeked.?.value;
        } else {
            return null;
        }
    }

    pub fn getVar(self: *@This(), variable: Token, allocator: std.mem.Allocator) !Token {
        var secondaryStack = ScopeStack.init(allocator);
        var token: ?Token = null;
        var currScope = self.pop();
        defer {
            // Agora vamos devolver os escopos para o stack principal
            while (secondaryStack.peek() != null) {
                self.push(secondaryStack.pop().?) catch {};
            }
        }

        while (currScope != null) {
            try secondaryStack.push(currScope.?);
            const varHashmap = currScope.?.varhashmap;
            token = varHashmap.getVar(variable) catch |err| switch (err) {
                error.VarNonexistent => null,
                else => return err,
            };
            if (token != null) {
                return token.?;
            }

            currScope = self.pop();
        } else {
            return error.VarNonexistent;
        }
        unreachable;
    }

    pub fn assignVar(self: @This(), variable: Token, value: Token) !void {
        const topScope = self.peek();
        if (topScope != null) {
            try topScope.?.varhashmap.assignVar(variable, value);
        } else {
            return error.NoScopeOnStack;
        }
    }
};
