const std = @import("std");
const hashmap = @import("./varhashmap.zig");
const Lex = @import("./lex.zig").Lex;
const Token = @import("./lex.zig").Lex.Token;
const Expr = @import("./expr.zig");

const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();
var variablesHashMap: ?hashmap.VariablesHashMap = null;

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
        variablesHashMap = try hashmap.VariablesHashMap.init(allocator);
        // Abrindo o arquivo
        var file = std.fs.cwd().openFile(f, .{ .mode = .read_only }) catch |err| switch (err) {
            error.FileNotFound => {
                std.debug.print("File Not found!", .{});
                return;
            },
            else => return err,
        };
        defer file.close();

        const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(content);

        // Deixando o conteúdo imutável (boas práticas)
        const file_content: []const u8 = content;

        tokenizer(file_content, allocator) catch |err| switch (err) {
            else => return err,
        };
    } else {
        try interactive(allocator);
    }
}

fn interactive(allocator: std.mem.Allocator) !void {
    try stdout.print("Marte 0.0.1 Copyright (C) 2024 Giancarlo Bonvenuto\n", .{});

    while (true) {
        try stdout.print("> ", .{});
        var buf: [1000]u8 = undefined;
        const line = try stdin.readUntilDelimiter(&buf, '\n');
        try tokenizer(line, allocator);
    }
}

pub fn tokenizer(content: []const u8, allocator: std.mem.Allocator) !void {
    var i: usize = 0;
    var arrList = std.ArrayList(Lex.Token).init(allocator);
    var pendingExpr = false;
    var pendingAssignment = false;
    var token: ?Lex.Token = null;

    while (i < content.len) : (i += 1) {

        // Imprimir os tokens
        defer {
            if (token) |t| {
                t.print() catch {};
                arrList.append(t) catch |err| {
                    std.debug.print("deu alguma bosta aqui {}", .{err});
                };
            }
        }

        const char = content[i];

        // Se for o caracter nulo, terminar
        if (char == 0) {
            break;
        }

        // Se for whitespace a gente ignora
        if (std.ascii.isWhitespace(char)) {

            // Se o whitespace for um \n, então vemos se tem uma expressão pendente
            if (char == '\n' or char == 0) {
                try processLine(arrList);
            }
            continue;
        }

        // Se for um número, aplicamos um parser próprio
        if (char >= '0' and char <= '9') {
            pendingExpr = true;
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
            if (token.?.value.op == .@"=") {
                pendingAssignment = true;
            }
            continue;
        }

        // Se for algo que não conhecemos, então é uma variável
        i, token = Lex.variables(content, i);
        pendingExpr = true;
    }
    try processLine(arrList);
}

fn processLine(arrList: std.ArrayList(Token)) !void {
    const arr = arrList.items;
    std.debug.print("Processing line {any}", .{arr});
    for (arr, 0..) |token, i| {
        switch (token.type) {
            .op => {
                switch (token.value.op) {
                    // Um igual significa que é um assignment
                    .@"=" => {
                        // Verificando se o igual não está no começo da linha
                        if (i <= 0) {
                            panic("(=) at beginning of line");
                        }
                    },
                    else => unreachable,
                }
            },
            else => unreachable,
        }
    }
}

fn panic(message: []const u8) noreturn {
    std.debug.print("\n{}ALERTA ALERTA ALERTA {s}", .{std.io.tty.Color.red, message});
    std.posix.exit(1);
    unreachable;
}
