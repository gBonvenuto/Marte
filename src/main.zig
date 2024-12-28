const std = @import("std");
const hashmap = @import("./varhashmap.zig");
const Lex = @import("./lex.zig").Lex;
const Token = @import("./lex.zig").Lex.Token;
const Expr = @import("./expr.zig");
const Chameleon = @import("chameleon");

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
        variablesHashMap = try hashmap.VariablesHashMap.init(allocator);
        try interactive(allocator);
    }
}

var interactive_mode = false;
var insideBlock = false;
fn interactive(allocator: std.mem.Allocator) !void {
    interactive_mode = true;
    try stdout.print("Marte 0.0.1 Copyright (C) 2024 Giancarlo Bonvenuto\n", .{});
    var arrList: ?std.ArrayList(Token) = null;
    while (true) {
        if (arrList) |list| {
            std.log.info("insideBlock = true", .{});
            try stdout.print(">> ", .{});
            var buf: [1000]u8 = undefined;
            const line = try stdin.readUntilDelimiter(&buf, '\n');
            arrList = try tokenizer(line, allocator, list);
        } else {
            try stdout.print("> ", .{});
            var buf: [1000]u8 = undefined;
            const line = try stdin.readUntilDelimiter(&buf, '\n');
            arrList = try tokenizer(line, allocator, null);
        }
    }
}

pub fn tokenizer(content: []const u8, allocator: std.mem.Allocator, arrayList: ?std.ArrayList(Token)) !?std.ArrayList(Token) {
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

            //Se o whitespace for um \n, então vemos se tem uma expressão pendente
            if (char == '\n' or char == 0) {
                if (insideBlock) {
                    return arrList;
                } else {
                    try processLine(arrList, allocator);
                    continue;
                }
            } else {
                continue;
            }
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
                    insideBlock = true;
                },
                .end => insideBlock = false,
                else => {},
            }
            continue;
        }

        // Se for algo que não conhecemos, então é uma variável
        i, token = try Lex.variables(content, i, allocator);
    }
    if (insideBlock) {
        return arrList;
    } else {
        try processLine(arrList, allocator);
        arrList.deinit();
        return null;
    }
}

fn processLine(arrList: std.ArrayList(Token), allocator: std.mem.Allocator) !void {
    const arr = arrList.items;
    var i: usize = 0;

    while (i < arr.len) : (i += 1) {
        const token = arr[i];
        switch (token.type) {
            .keyword => {
                switch (token.value.keyword) {
                    // WARNING: Acho que isso aqui não vai funcionar. Acho que preciso
                    // criar um stack de blocos de alguma forma
                    .@"if", .@"for", .@"while", .elif => {
                        std.log.debug("token = {}\n", .{token});
                        const ret = Expr.ExprAnalyzer.analyse(&variablesHashMap.?, arr[i + 1 ..], allocator) catch |err| switch (err) {
                            error.VarNonexistent => panic("Trying to evaluate non existent variable", .{}),
                            error.MissingThenOrDoKeyword => panic("Did not find \"do\" or \"then\" keyword", .{}),
                            else => return err,
                        };
                        std.log.debug("ret = {}\n", .{ret});
                        if (ret.type != .boolean) {
                            panic("Avaliando {}, (não booleano)", .{ret});
                        }
                        // Se a condição é falsa, então pulamos tudo o que está dentro do bloco
                        if (ret.value.boolean == false) {
                            var t: Token = token;
                            while (!(t.type == .keyword and t.value.keyword == .end)) {
                                i += 1;
                                t = arrList.items[i];
                            }
                        }
                        // Se a condição é verdadeira, então seguimos normalmente
                    },
                    // TODO:
                    .@"else" => {
                        panic("Unexpected \"else\" keyword\n", .{});
                    },
                    .end => {
                        panic("Unexpected \"end\" keyword\n", .{});
                    },
                    .@"break" => {},
                    .@"continue" => {},
                    .do, .then => {},
                }
            },
            .variable => {
                // Se for apenas uma única variável, então significa que devemos
                // imprimi-la
                if (arr.len == 1) {
                    var buf: [50]u8 = undefined;
                    const val = try variablesHashMap.?.getVar(token);
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
                            panic("(=) at beginning of line", .{});
                        }

                        if (arr[i - 1].type != Token.Types.variable) {
                            panic("Trying to assign value to not a variable", .{});
                        }

                        if (i >= arr.len) {
                            panic("Trying to assign nothing to variable", .{});
                        }

                        const ret = Expr.ExprAnalyzer.analyse(&variablesHashMap.?, arr[i + 1 ..], allocator) catch |err| switch (err) {
                            error.VarNonexistent => panic("Trying to evaluate non existent variable", .{}),
                            else => return err,
                        };

                        try variablesHashMap.?.assignVar(arr[i - 1], ret);
                    },
                    else => {},
                }
            },
            else => {},
        }
    }
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
