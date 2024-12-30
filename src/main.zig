const std = @import("std");
const VariablesHashMap = @import("./varhashmap.zig").VariablesHashMap;
const Lex = @import("./lex.zig").Lex;
const Token = @import("./lex.zig").Lex.Token;
const Expr = @import("./expr.zig");
const Chameleon = @import("chameleon");
const Scope = @import("./scopes.zig").Scope;
const ScopeStack = @import("./scopes.zig").ScopeStack;
const Stack = @import("./stack.zig");

pub const stdin = std.io.getStdIn().reader();
pub const stdout = std.io.getStdOut().writer();
var scopesStack: ScopeStack = undefined;

fn get_filename(args: [][]u8) ![]const u8 {
    if (args.len < 2) {
        return error.FileFieldEmpty;
    }

    const file_name: []const u8 = args[1];
    return file_name;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    const file_name: ?[]const u8 = get_filename(args) catch |err| switch (err) {
        error.FileFieldEmpty => null,
        else => return err,
    };

    if (file_name) |f| {
        // Abrindo o arquivo
        var file = std.fs.cwd().openFile(f, .{ .mode = .read_only }) catch |err| switch (err) {
            error.FileNotFound => {
                panic("File Not Found!", .{});
                return;
            },
            else => return err,
        };
        defer file.close();

        const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(content);

        // Deixando o conteúdo imutável (boas práticas)
        const file_content: []const u8 = content;

        _ = try tokenizer(file_content, allocator, null);
    } else {
        try interactive(allocator);
    }
}

var interactive_mode = false;
var blockCount: usize = 0;
fn interactive(allocator: std.mem.Allocator) !void {
    interactive_mode = true;
    try stdout.print("Marte 0.0.1 Copyright (C) 2024 Giancarlo Bonvenuto\n", .{});
    var arrList: std.ArrayList(Token) = undefined;
    scopesStack = ScopeStack.init(allocator);
    try scopesStack.pushEmpty(null, undefined, null, .none);
    var outerScope = scopesStack.peek().?;
    defer {
        scopesStack.deinit();
    }
    while (true) {
        // Se o blockCount for maior que zero, então estamos dentro de um bloco
        if (blockCount > 0) {
            // If arrList is not null, then we are inside a block
            try stdout.print(">> ", .{});
            var buf: [1000]u8 = undefined;
            const line = try stdin.readUntilDelimiter(&buf, '\n');
            arrList = try tokenizer(line, allocator, arrList);
        }
        // Se o blockCount for menor que zero então temos muitos tokens end
        else if (blockCount < 0) {
            panic("Unexpected \"end\"", .{});
        }
        // Se o blockCount for zero, então já estamos no scopo externo
        else {
            try stdout.print("> ", .{});
            var buf: [1000]u8 = undefined;
            const line = try stdin.readUntilDelimiter(&buf, '\n');
            arrList = try tokenizer(line, allocator, null);
        }
        if (blockCount == 0) {
            outerScope.code = arrList.items;
            _ = try outerScope.processScope(&scopesStack);
        }
    }
}

pub fn tokenizer(content: []const u8, allocator: std.mem.Allocator, arrayList: ?std.ArrayList(Token)) !std.ArrayList(Token) {
    var i: usize = 0;

    var arrList: std.ArrayList(Token) = undefined;

    if (arrayList == null) {
        arrList = std.ArrayList(Token).init(allocator);
    } else {
        arrList = arrayList.?;
    }

    var token: ?Lex.Token = null;

    while (i < content.len) : (i += 1) {

        // Imprimir os tokens
        defer {
            if (token) |t| {
                // t.print() catch {};
                arrList.append(t) catch |err| {
                    std.debug.print("deu alguma bosta aqui {}", .{err});
                };
                token = null;
            }
        }

        const char = content[i];

        // Se for o caracter nulo, terminar
        if (char == 0) {
            break;
        }

        // Se for whitespace a gente ignora
        if (std.ascii.isWhitespace(char)) {
            continue;
        }

        // Se for um número, aplicamos um parser próprio
        if (char >= '0' and char <= '9') {
            const ret = try Lex.numbers(content, i);
            i = ret.index;
            token = ret.token;
            continue;
        }

        // Se for um caracter de operador, tratamos aqui
        i, token = Lex.operators(content, i) catch |err| switch (err) {
            error.UnknownOperator => .{ i, null }, //Ignorar o erro
            else => return err,
        };
        // Se já tivermos encontrado o token continuamos o loop
        if (token != null) {
            continue;
        }

        // Se for um caracter de keyword, tratamos aqui
        i, token = Lex.keywords(content, i);
        // Se já tivermos encontrado o token continuamos o loop
        if (token != null) {
            switch (token.?.value.keyword) {
                // Se for algum desses então estamos entrando em um bloco
                // e a linha agora não termina na quebra de linha, mas sim no
                // `end`
                .@"if", .@"for", .@"while", .@"else" => {
                    blockCount += 1;
                },
                .end => {
                    blockCount -= 1;
                },
                else => {},
            }
            continue;
        }

        // Se for algo que não conhecemos, então é uma variável
        i, token = try Lex.variables(content, i, allocator);
    }
    return arrList;
}

fn panic(comptime message: []const u8, args: anytype) noreturn {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var cham = Chameleon.initRuntime(.{ .allocator = allocator });
    defer cham.deinit();

    cham.red().bold().printOut(message, args) catch {};
    std.posix.exit(1);

    unreachable;
}
