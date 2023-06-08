package interpreter

Expression :: union {
    ^Unary,
    ^Binary,
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

Literal :: struct {
    value: rawptr,
}

Grouping :: struct {
    expr: Expression,
}

