package interpreter

import "core:fmt"

@private
Parser :: struct {
    tokens: [dynamic]Token,
    current: u32,
}

new_parser :: proc(tokens: [dynamic]Token) -> Parser {
    return Parser{ tokens, 0 }
}

parse :: proc(parser: ^Parser) -> Expression {
    expr, err := expression(parser)
    if err != .None {
        return nil
    }
    fmt.println(expr)
    return expr
}

/*
expression     → literal | unary | binary | grouping  
literal        → NUMBER | STRING | true | false | nil 
grouping       → ( expression ) 
unary          → ( - | ! ) expression
binary         → expression operator expression
operator       → == | != | < | <= | > | >= | + | - | * | /


-- PRIORITY --

expression     → ternary
ternary        → equality ? { expression : expression }?
equality       → comparison {{ != | == } comparison }*
comparison     → term {{ > | >= | < | <= } term }*
term           → factor {{ - | + } factor }*
factor         → unary {{ / | * } unary }*
unary          → { ! | - } unary | primary
primary        → NUMBER | STRING | true | false | nil | ( expression )
*/

evaluate_expression :: proc(parser: ^Parser, handler: proc(parser: ^Parser) -> (Expression, Error), types: ..Token_Type) -> (Expression, Error) {
    expr, err := handler(parser)
    if err != .None {
        return nil, err
    }

    for match(parser, types[:]) {
        operator := previous(parser)
        right, err := handler(parser)
        if err != .None {
            return nil, err
        }
        expr = &Binary{expr, operator, right}
    }

    return expr, nil
}

@private
expression :: proc(parser: ^Parser) -> (Expression, Error) {
    return ternary(parser)
}

@private
ternary :: proc(parser: ^Parser) -> (Expression, Error) {
    equal, err := equality(parser)
    if err != .None {
        return nil, err
    }

    if parser_look_ahead(parser).type != .Question {
        return equal, .None
    }
    first_op, first_op_err := consume(parser, .Question, "Missing '?' for ternary operator.")
    if first_op_err != .None {
        return nil, first_op_err
    }

    expr1, expr1_err := expression(parser)
    if expr1_err != .None {
        return nil, expr1_err
    }

    second_op, second_op_err := consume(parser, .Colon, "Missing ':' for ternary operator.")
    if second_op_err != .None {
        return nil, second_op_err
    }

    expr2, expr2_err := expression(parser)
    if expr2_err != .None {
        return nil, expr2_err
    }

    expr := &Ternary{equal, first_op.(Token), expr1, second_op.(Token), expr2}
    return expr, nil
}

@private
equality :: proc(parser: ^Parser) -> (Expression, Error) {
    return evaluate_expression(parser, comparison, .Bang_Equal, .Equal_Equal)
}

@private
comparison :: proc(parser: ^Parser) -> (Expression, Error) {
    return evaluate_expression(parser, term, .Greater, .Greater_Equal, .Less, .Less_Equal)
}

@private
term :: proc(parser: ^Parser) -> (Expression, Error) {
    return evaluate_expression(parser, factor, .Minus, .Plus)
}

@private
factor :: proc(parser: ^Parser) -> (Expression, Error) {
    return evaluate_expression(parser, unary, .Slash, .Star)
}

@private
unary :: proc(parser: ^Parser) -> (Expression, Error) {
    expr: Expression
    for match(parser, []Token_Type{.Bang, .Minus}) {
        operator := previous(parser)
        right, err := unary(parser)
        if err != .None {
            return nil, err
        }

        expr = &Unary{operator, right}
        return expr, nil
    }

    return primary(parser)
}

@private
primary :: proc(parser: ^Parser) -> (Expression, Error) {
    expr: Expression
    err: Error
    if match(parser, []Token_Type{.False, .True, .Nil, .Number, .String}) { 
        expr = &Literal { previous(parser).literal }
        return expr, nil
    }

    if match(parser, []Token_Type{.Left_Paren}) {
        expr, err = expression(parser)
        _, err = consume(parser, .Right_Paren, "Expect ')' after expression")
        if err != .None {
            return nil, err
        }

        expr = &Grouping{ expr }
    }

    return nil, _parser_error(parser_look_ahead(parser), "Expected an expression.")
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
    if !is_at_parser_end(parser) { parser.current += 1 }
    return previous(parser)
}

is_at_parser_end :: proc(parser: ^Parser) -> bool {
    return parser_look_ahead(parser).type == .Eof
}

parser_look_ahead :: proc(parser: ^Parser) -> Token {
    return parser.tokens[parser.current]
}

previous :: proc(parser: ^Parser) -> Token {
    return parser.tokens[parser.current - 1]
}

consume :: proc(parser: ^Parser, type: Token_Type, message: string) -> (Maybe(Token), Error) {
    if is_of_type(parser, type) { 
        token := advance_parser(parser)
        return token, nil
    }
    
    return nil, _parser_error(parser_look_ahead(parser), message)
}

synchronize :: proc(parser: ^Parser) {
    advance_parser(parser)

    for is_at_parser_end(parser) {
        if previous(parser).type == .Semicolon { return }

        #partial switch parser_look_ahead(parser).type {
        case .Class:
        case .Fun:
        case .Var:
        case .For:
        case .If:
        case .While:
        case .Print:
        case .Return:
            return
        }

        advance_parser(parser)
    }
}

@private
_parser_error :: proc(token: Token, message: string) -> Parse_Error {
    error(token, message)

    return Parse_Error{ token, message }
}

