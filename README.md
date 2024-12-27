# Motivation

I'm a big fan of the [Lua programming language](https://www.lua.org/). Also I wanted to learn more about Zig and how to make my own language. So I decided to create Marte (Mars in the Portuguese language).

The goal is to fix some of the issues I found while coding in Lua while giving it a bigger purpose. The planned features are as follows:

- [ ] `continue` keyword, so we can reduce the use of labels
- [ ] The ability to execute shell programs easily
- [ ] Variables are always local unless declared as global

I **do not** plan to change the starting index from 1 to 0. This is a core feature of Lua and encourages the programmer to use iterators instead of indexes. And it would probably break Lua code when run with Marte intepreter.It's not a priority to make Marte Lua-compatible, but I won't lose this ability over such a simple thing. 

If you have any suggestions to the code or to the project, feel free to create a new Issue. I'm new to both the Zig language and creating a programming language so any help is welcome 😁.

# The codebase

The codebase is a mess for two reasons:

1. This is just a personal project and still in development (when the project is more advanced, I'll probably refactor it)
2. I'm exploring different Zig coding patterns, so this codebase does not have yet a pattern intentionally

# Marte

- [ ] TODO: write some Marte code examples.
