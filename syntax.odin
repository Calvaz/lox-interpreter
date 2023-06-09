package interpreter

import "core:strings"
import "core:fmt"
import "core:mem"

Expression :: union {
    ^Unary,
    ^Binary,
    ^Ternary,
    ^Literal,
    ^Grouping,
}

Unary :: struct {
    operator: Token,
    right: Expression,
}

Binary :: struct {
    left: Expression,
    operator: Token,
    right: Expression,
}

Ternary :: struct {
    left: Expression,
    first_operator: Token,
    middle: Expression,
    second_operator: Token,
    right: Expression,
}

Literal :: struct {
    value: rawptr,
}

Grouping :: struct {
    expr: Expression,
}

print_expression :: proc{
    print_binary_expression,
    print_grouping_expression,
    print_literal_expression,
    print_unary_expression,
}

print_binary_expression :: proc(bin: Binary) -> string {
    return add_paren(bin.operator.lexeme, bin.left, bin.right)
}

print_grouping_expression :: proc(ex: Grouping) -> string {
    return add_paren("group", ex.expr)
}

print_literal_expression :: proc(ex: Literal) -> string {
    if ex.value == nil { return "nil" }
    s := cast(^string)mem.alloc(size_of(string), align_of(string))
    return fmt.tprintf(s^)
}

print_unary_expression :: proc(ex: Unary) -> string {
    return add_paren(ex.operator.lexeme, ex.right)
}

@private
add_paren :: proc(name: string, exprs: ..Expression) -> string {
    res: [dynamic]string = make([dynamic]string)
    
    append(&res, "(")
    append(&res, name)
    for ex in exprs {
        append(&res, " ")
    }
    append(&res, ")")
    return strings.concatenate(res[:])
}

