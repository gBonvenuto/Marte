const std = @import("std");

/// Este struct possui diversas funções para análise lexical
pub const Lex = struct {
    pub const Keywords = enum {
        pub fn getKeyword(str: []const u8) !Keywords {
            inline for (@typeInfo(Keywords).Enum.fields, 0..) |field, i| {
                if (std.mem.eql(u8, str, field.name)) {
                    const ret: Keywords = @enumFromInt(i);
                    return ret;
                }
                return error.EnumFieldNotFound;
            }
        }
        @"if",
        then,
        @"else",
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
            integer: i32,
            float: f32,
            char: u8,
            boolean: bool,
            op: Operators,
            keyword: Keywords,
            variable: []const u8, //name
        };
        pub const Types = enum {
            integer,
            float,
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
        var tok_type = Token.Types.integer;

        var value: i32 = 0;
        while (index < content.len and std.ascii.isDigit(content[index])) : (index += 1) {
            value *= 10;
            value += content[index] - '0';
        }

        // Se tiver um ponto, então é um float e devemos continuar lendo
        if (index < content.len and content[index] == '.') {
            var decimal_value_i: usize = 0;
            const point_index = index;
            index += 1;
            if (!std.ascii.isDigit(content[index])) {
                return error.FloatMalformed;
            }
            while (index < content.len and std.ascii.isDigit(content[index])) : (index += 1) {
                decimal_value_i *= 10;
                decimal_value_i += content[index] - '0';
            }

            const decimal_value: f32 = @floatFromInt(decimal_value_i);
            const div: f32 = @floatFromInt(index - point_index);
            const value_f: f32 = @floatFromInt(value);
            const float: f32 = (decimal_value / std.math.pow(f32, 10, div - 1)) + value_f;

            tok_type = Token.Types.float;
            const tok_value = Token.Value{ .float = float };
            return .{ .token = Token{
                .value = tok_value,
                .type = tok_type,
            }, .index = index - 1 };
        }
        // Caso contrário é um inteiro e já lemos tudo
        else {
            const tok_value = Token.Value{ .integer = value };
            return .{ .token = Token{
                .value = tok_value,
                .type = tok_type,
            }, .index = index - 1 };
        }
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

        return .{ index-1, Token{
            .value = Token.Value{ .variable = name },
            .type = .variable,
        } };
    }
};
