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
        @"=",
        @"==",
        @"(",
        @")",
    };
    pub const Token = struct {
        value: Value,
        type: Types,
        pub const Value = union(Types) {
            integer: i32,
            float: f32,
            char: u8,
            op: Operators,
            keyword: Keywords,
        };
        pub const Types = enum {
            integer,
            float,
            char,
            op,
            keyword,
        };
        pub fn print(self: Token) !void {
            std.debug.print("token: {any}\n", .{self});
            // switch (self.type) {
            //     .integer => {
            //         const value: *usize = @alignCast(@ptrCast(self.value));
            //         std.debug.print("token: {any}, value: {d}\n", .{ self, value.* });
            //     },
            //     .float => {
            //         const value: *f32 = @alignCast(@ptrCast(self.value));
            //         std.debug.print("token: {any}, value: {e}\n", .{ self, value.* });
            //     },
            //     .op => {
            //         const value: *u8 = @alignCast(@ptrCast(self.value));
            //         std.debug.print("token: {any}, value: {c}\n", .{ self, value.* });
            //     },
            //     else => return error.UnknownType,
            // }
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

    pub fn operators(content: []const u8, initial_index: usize) !Token {
        inline for (@typeInfo(Operators).Enum.fields, 0..) |field, i| {
            for (field.name, 0..) |f_char, j| {
                // Se tiver um caracter diferente, então não é este operador
                if (j >= content.len or content[initial_index + j] != f_char) {
                    break;
                }
            }
            // Se terminamos o loop sem então encontramos o nosso operador
            else {
                const op: Operators = @enumFromInt(i);
                return Token{ .value = .{ .op = op }, .type = .op };
            }
        }
        // Se chegarmos aqui é porque não encontramos nosso operador
        return error.UnknownOperator;
    }
};
