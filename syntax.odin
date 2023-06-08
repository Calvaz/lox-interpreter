package interpreter

@private
Expression_Types :: union {
    Literal,
    Unary,
    Binary,
    Grouping,
}

Operator :: enum {

}

Binary :: struct {
    expr: Expression,
    operator: Operator,
    right: Expression
}

Unary :: struct {
    left: Operator,
    expr: Expression,
}

@private
Expression :: struct {
    type: Expression_Types,
}

new_expression :: proc(type: Expression_Types) -> Expression {
    return Expression{ type }
}
