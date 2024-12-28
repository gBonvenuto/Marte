const std = @import("std");

/// Este struct possui diversas funções para análise lexical
pub const Lex = struct {
    pub const Keywords = enum {
        @"if",
        @"elif",
        @"then",
        @"else",
        @"for",
        @"while",
        @"end",
        @"break",
        @"continue",
        @"done",
        @"do",
    };
    pub const Operators = enum {
        @"+",
        @"-",
        @"*",
        @"/",
        @">=",
        @"<=",
        @"==",
        @">",
        @"<",
        @"and",
        @"or",
        @"!",
        @"(",
        @")",
        @"=",
    };
    pub const Token = struct {
        value: Value,
        type: Types,
        pub const Value = union(Types) {
            number: f64,
            char: u8,
            boolean: bool,
            op: Operators,
            keyword: Keywords,
            variable: []const u8, //name
        };
        pub const Types = enum {
            number,
            char,
            boolean,
            op,
            keyword,
            variable,
        };
        pub fn print(self: Token) !void {
            std.debug.print("token: {}\n", .{self});
        }
    };

    pub fn numbers(content: []const u8, initial_index: usize) !struct { token: Token, index: usize } {
        var index = initial_index;

        var value: f64 = 0;
        while (index < content.len and std.ascii.isDigit(content[index])) : (index += 1) {
            value *= 10;
            value += @floatFromInt(content[index] - ('0'));
        }

        // Se tiver um ponto, então é um float e devemos continuar lendo
        if (index < content.len and content[index] == '.') {
            var decimal_value: f64 = 0;
            const point_index = index;
            index += 1;
            // Se o valor após o ponto não for um dígito, então é um float mal
            // formado
            if (!std.ascii.isDigit(content[index])) {
                return error.FloatMalformed;
            }
            while (index < content.len and std.ascii.isDigit(content[index])) : (index += 1) {
                decimal_value *= 10;
                decimal_value += @floatFromInt(content[index] - '0');
            }

            const div: f32 = @floatFromInt(index - point_index);
            value = (decimal_value / std.math.pow(f32, 10, div - 1)) + value;
        }
        const tok_type = Token.Types.number;
        const tok_value = Token.Value{ .number = value };
        return .{ .token = Token{
            .value = tok_value,
            .type = tok_type,
        }, .index = index - 1 };
    }

    pub fn keywords(content: []const u8, initial_index: usize) struct { usize, ?Token } {
        var jndex: usize = 0;
        inline for (@typeInfo(Keywords).Enum.fields, 0..) |field, i| {
            for (field.name, 0..) |f_char, j| {
                // Se tiver um caracter diferente, então não é este operador
                if (j + initial_index >= content.len or content[initial_index + j] != f_char) {
                    break;
                }
                jndex = j;
            }
            // Se terminamos o loop sem break então encontramos o nosso operador
            else {
                const keyword: Keywords = @enumFromInt(i);
                return .{ initial_index + jndex, Token{ .value = .{ .keyword = keyword }, .type = .keyword } };
            }
        }
        // Se chegarmos aqui é porque não encontramos nosso operador, então
        // devolvemos um token nulo e o index inicial
        return .{initial_index, null};
    }

    pub fn operators(content: []const u8, initial_index: usize) error{UnknownOperator}!struct { usize, Token } {
        var jndex: usize = 0;
        inline for (@typeInfo(Operators).Enum.fields, 0..) |field, i| {
            for (field.name, 0..) |f_char, j| {
                // Se tiver um caracter diferente, então não é este operador
                if (j + initial_index >= content.len or content[initial_index + j] != f_char) {
                    break;
                }
                jndex = j;
            }
            // Se terminamos o loop sem break então encontramos o nosso operador
            else {
                const op: Operators = @enumFromInt(i);
                return .{ initial_index + jndex, Token{ .value = .{ .op = op }, .type = .op } };
            }
        }
        // Se chegarmos aqui é porque não encontramos nosso operador
        return error.UnknownOperator;
    }

    pub fn variables(content: []const u8, initial_index: usize, allocator: std.mem.Allocator) !struct { usize, Token } {
        var index: usize = initial_index;
        while (index < content.len and std.ascii.isAlphabetic(content[index])) {
            index += 1;
        }

        const name: []u8 = try allocator.alloc(u8, index - initial_index);
        std.mem.copyForwards(u8, name, content[initial_index..index]);

        return .{ index - 1, Token{
            .value = Token.Value{ .variable = name },
            .type = .variable,
        } };
    }
};
