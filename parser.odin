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
expression :: proc(parser: ^Parser) -> Expression {
    return equality(parser)
}

evaluate_expression :: proc(parser: ^Parser, handler: proc(parser: ^Parser) -> Expression, types: ..Token_Type) -> Expression {
    expr := handler(parser)

    for match(parser, types[:]) {
        operator := previous(parser)
        right := handler(parser)
        expr = &Binary{expr, operator, right}
    }

    return expr
}

@private
equality :: proc(parser: ^Parser) -> Expression {
    return evaluate_expression(parser, comparison, .Bang_Equal, .Equal_Equal)
}

@private
comparison :: proc(parser: ^Parser) -> Expression {
    return evaluate_expression(parser, term, .Greater, .Greater_Equal, .Less, .Less_Equal)
}

@private
term :: proc(parser: ^Parser) -> Expression {
    return evaluate_expression(parser, factor, .Minus, .Plus)
}

@private
factor :: proc(parser: ^Parser) -> Expression {
    return evaluate_expression(parser, unary, .Slash, .Star)
}

@private
unary :: proc(parser: ^Parser) -> Expression {
    expr: Expression
    for match(parser, []Token_Type{.Bang, .Minus}) {
        operator := previous(parser)
        right := unary(parser)
        expr = &Unary{operator, right}
        return expr
    }

    return primary(parser)
}

@private
primary :: proc(parser: ^Parser) -> Expression {
    expr: Expression
    if match(parser, []Token_Type{.False, .True, .Nil, .Number, .String}) { 
        expr = &Literal { previous(parser).literal }
        return expr
    }

    if match(parser, []Token_Type{.Left_Paren}) {
        expr = expression(parser)
        consume(parser, .Right_Paren, "Expect ')' after expression")
        expr = &Grouping{ expr }
    }
    return expr
}

match :: proc(parser: ^Parser, types: []Token_Type) -> bool {
    for t in types {
        if is_of_type(parser, t) {
            advance_parser(parser)
            return true
        }
    }

    return false
}

is_of_type :: proc(parser: ^Parser, type: Token_Type) -> bool {
    if is_at_parser_end(parser) { return false }
    return parser_look_ahead(parser).type == type
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

consume :: proc(parser: ^Parser, type: Token_Type, message: string) -> (Maybe(Token), Maybe(Parse_Error)){
    if is_of_type(parser, type) { 
        return advance_parser(parser), nil
    }
    
    return nil, _parser_error(parser_look_ahead(parser), message)
}

@private
_parser_error :: proc(token: Token, message: string) -> Parse_Error {
    error(token, message)

    return Parse_Error{ token, message }
}

