const std = @import("std");
const VariablesHashMap = @import("./varhashmap.zig").VariablesHashMap;
const Stack = @import("./stack.zig");
const Token = @import("lex.zig").Lex.Token;

pub const Scope = struct {
    varhashmap: VariablesHashMap,
    start: usize, // índice do token inícial
    pub fn init(start: usize, allocator: std.mem.Allocator) !Scope {
        return Scope{ .varhashmap = try VariablesHashMap.init(allocator), .start = start };
    }
    pub fn deinit(self: @This()) void {
        self.varhashmap.deinit();
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
    pub fn pushEmpty(self: *@This(), start: usize ) !void {
        try self.stack.push( try Scope.init(start, self.allocator));
    }

    pub fn push(self: *@This(), value: Scope) !void {
        try self.stack.push(value);
    }

    /// Retorna o nó ou null caso o stack esteja vazio
    pub fn pop(self: *@This()) ?Scope {
        const popped = self.stack.pop();
        if (popped == null) {
            return popped.?.value;
        } else {
            return null;
        }
    }

    // Retorna o last_node, mas sem tirá-lo do stack
    pub fn peek(self: @This()) ?Scope {
        const peeked = self.stack.peek();
        if (peeked == null) {
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
