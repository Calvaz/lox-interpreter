package interpreter

@private
Parser :: struct {
    tokens: [dynamic]Token,
    current: u32,
}

new_parser :: proc(tokens: [dynamic]Token) -> Parser {
    return Parser{ tokens, 0 }
}

@private
expression :: proc() -> Expression {
    return equality()
}

evaluate_expression :: proc(parser: ^Parser, handler: proc(parser) -> Expression, types: ..Token_Type) -> Expression {
    expr := handler()

    for match(parser, types) {
        operator := previous(parser)
        right := handler()
        expr = new_expression(.Binary)
    }

    return expr
}

@private
equality :: proc(parser: ^Parser) -> Expression {
    return evaluate_expression(parser, comparison(parser), .Bang_Equal, .Equal_Equal)
}

@private
comparison :: proc(parser: ^Parser) -> Expression {
    return evaluate_expression(parser, term(parser), .Greater, .Greater_Equal, .Less, .Less_Equal)
}

@private
term :: proc(parser: ^Parser) -> Expression {
    return evaluate_expression(parser, factor(parser), .Minus, .Plus)
}

@private
factor :: proc(parser: ^Parser) -> Expression {
    return evaluate_expression(parser, unary(parser), .Slash, .Star)
}

unary :: proc(parser: ^Parser) -> Expression {
    for match(parser, .Bang, .Minus) {
        operator := previous(parser)
        right := unary(parser)
        expr = new_expression(.Unary)
    }

    return expr
}

match :: proc(parser: ^Parser, types: ..Token_Type) {
    for t in types {
        if is_of_type(parser, t) {
            advance_parser(parser)
            return true
        }
    }

    return false
}

is_of_type :: proc(type: Token_Type) -> bool {
    if is_at_end() { return false }
    return look_ahead(scanner).type == type
}

advance_parser :: proc(parser: ^Parser) -> Token {
    if !is_at_parser_end(parser) { current += 1 }
    return previous(parser)
}

is_at_parser_end :: proc(parser: ^Parser) -> bool {
    return parser_look_ahead(parser).type == .Eof
}

parser_look_ahead :: proc(parser: ^Parser) -> Token {
    return parser.tokens[current]
}

previous :: proc(parser: ^Parser) -> Token {
    return parser.tokens[current - 1]
}

