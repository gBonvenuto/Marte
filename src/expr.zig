const std = @import("std");
const Lex = @import("./lex.zig").Lex;
const Token = @import("./lex.zig").Lex.Token;
const hashmap = @import("./varhashmap.zig");
const Stack = @import("./stack.zig").Stack;

pub fn analyse(varHashmap: *hashmap.VariablesHashMap, tok_array: []const Token, allocator: std.mem.Allocator) !Token {
    // Vamos ter dois stacks, um que contém a expressão e outro com os caracteres aguardando
    var main = Stack(Token).init(allocator);
    var waiting = Stack(Token).init(allocator);
    // defer {
    //     main.deinit();
    //     waiting.deinit();
    // }

    for (tok_array) |token| {
        switch (token.type) {
            .keyword => {
                if (token.value.keyword == .then or token.value.keyword == .do) {
                    break;
                } else {
                    return error.MissingThenOrDoKeyword;
                }
            },
            .variable => {
                const value = try varHashmap.getVar(token);
                try main.push(value);
            },
            // Se for um número, ele vai diretamente para o main stack
            .number => {
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

                            try main.push(try evaluate(&main));

                            break :outer;
                        }
                        // Se a precedência atual é menor, então fazemos
                        // do mesmo modo que o igual, mas não terminamos o
                        // loop
                        else {
                            _ = waiting.pop();
                            try main.push(last_node.value);
                            try waiting.push(token);

                            try main.push(try evaluate(&main));

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
            else => return error.UnknownToken,
        }
    }
    // Agora que terminamos os tokens, vamos liberar o waiting stack
    while (waiting.peek() != null) {
        const popped = waiting.pop();
        try main.push(popped.?.value);
        try main.push(try evaluate(&main));
    }
    // Se tiver mais de um item na main, então a expressão foi mal formada
    if (main.peek().?.prev != null) {
        return error.MalformedExpression;
    }
    return main.pop().?.value;
}

fn evaluate(stack: *Stack(Token)) !Token {
    const op = stack.pop().?.value;
    const val2 = stack.pop().?.value;
    var val1: Token = undefined;
    var onlyOneValue = false;

    // Se só tiver um valor pra ser analisado
    if (stack.peek() == null) {
        onlyOneValue = true;
    } else {
        val1 = stack.pop().?.value;
    }

    if (op.type != .op) {
        return error.opnotoperator;
    }
    if (val2.type != .number) {
        return error.val2NotNumber;
    }
    if (!onlyOneValue and val1.type != .number) {
        return error.val1NotNumber;
    }
    switch (op.value.op) {
        .@"+" => {
            return Token{ .type = .number, .value = .{ .number = val1.value.number + val2.value.number } };
        },
        .@"-" => {
            if (onlyOneValue) {
                switch (val2.type) {
                    .number => return Token{ .type = .number, .value = .{ .number = -val2.value.number } },
                    else => unreachable,
                }
            }
            return Token{ .type = .number, .value = .{ .number = val1.value.number - val2.value.number } };
        },
        .@"*" => {
            return Token{ .type = .number, .value = .{ .number = val1.value.number * val2.value.number } };
        },
        .@"/" => {
            return Token{ .type = .number, .value = .{ .number = val1.value.number / val2.value.number } };
        },
        .@"=" => {
            return error.AssignmentInsideExpression;
        },
        .@">" => {
            return Token{ .type = .boolean, .value = .{ .boolean = val1.value.number > val2.value.number } };
        },
        .@">=" => {
            return Token{ .type = .boolean, .value = .{ .boolean = val1.value.number >= val2.value.number } };
        },
        .@"<" => {
            return Token{ .type = .boolean, .value = .{ .boolean = val1.value.number < val2.value.number } };
        },
        .@"<=" => {
            return Token{ .type = .boolean, .value = .{ .boolean = val1.value.number <= val2.value.number } };
        },
        .@"==" => {
            return Token{ .type = .boolean, .value = .{ .boolean = val1.value.number == val2.value.number } };
        },
        .@"and" => {
            if (val1.type == .boolean and val2.type == .boolean) {
                return Token{ .type = .boolean, .value = .{ .boolean = val1.value.boolean and val2.value.boolean } };
            } else return error.LocalAndNonBoolean;
        },
        .@"or" => {
            if (val1.type == .boolean and val2.type == .boolean) {
                return Token{ .type = .boolean, .value = .{ .boolean = val1.value.boolean or val2.value.boolean } };
            } else return error.LocalAndNonBoolean;
        },
        else => {
            return error.NotImplemented;
        },
    }
}

fn getOpPrecedence(token: Token) !u8 {
    if (token.type != Token.Types.op) {
        return error.NotAnOperator;
    }
    return switch (token.value.op) {
        .@">", .@">=", .@"<", .@"<=", .@"==" => 1,
        .@"+", .@"-" => 2,
        .@"*", .@"/" => 3,
        //TODO: parentesis
        else => error.UnknownOperator,
    };
}
