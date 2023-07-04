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

delete_parser :: proc(parser: ^Parser) {
    for t in parser.tokens {
    }
}

parse :: proc(parser: ^Parser) -> [dynamic]Statement {
    statements: [dynamic]Statement
    for (!is_at_parser_end(parser)) {
        stmt, err := new_declaration(parser)
        if err != .None {
            return nil
        }

        append(&statements, stmt)
    }
    return statements
}

@private
new_declaration :: proc(parser: ^Parser) -> (Statement, Error) {
    decl: Statement
    err: Error = .None
    if match(parser, []Token_Type{.Var}) {
        decl, err = var_declaration(parser)

    } else if match(parser, []Token_Type{.Print}) {
        decl, err = print_statement(parser)

    } else if match(parser,  []Token_Type{.Left_Brace}) {
        decl, err = block_statement(parser)

    } else {
        decl, err = expression_statement(parser)
    }

    if _, ok := err.(Parse_Error); ok {
        synchronize(parser)
        return nil, .None
    }

    return decl, .None
}

var_declaration :: proc(parser: ^Parser) -> (Statement, Error) {
    name, c_err := consume(parser, .Identifier, "Expect variable name.")
    if c_err != .None {
        return nil, c_err
    }

    initializer: Expression
    if (match(parser, []Token_Type{.Equal})) {
        err: Error
        initializer, err = expression(parser)
        if err != .None {
            return nil, err
        }
    }

    _, c_err = consume(parser, .Semicolon, "Expect ';' after variable declaration.")
    if c_err != .None {
        return nil, c_err
    }

    var := new(Var)
    var.name = name.?
    var.initializer = initializer
    return var, .None
}

print_statement :: proc(parser: ^Parser) -> (Statement, Error) {
    expr, err := expression(parser)
    if err != .None {
        return nil, err
    }
    _, c_err := consume(parser, .Semicolon, "Expect ';' after expression.")
    if c_err != .None {
        return nil, c_err
    }
    stmt := new(Print)
    stmt.expr = expr
    return stmt, .None
}

expression_statement :: proc(parser: ^Parser) -> (Statement, Error) {
    expr, err := expression(parser)
    if err != .None {
        return nil, err
    }
    _, c_err := consume(parser, .Semicolon, "Expect ';' after expression.")
    if c_err != .None {
        return nil, c_err
    }
    return expr, .None
}

block_statement :: proc(parser: ^Parser) -> (Statement, Error) {
    statements: [dynamic]Statement

    for !is_of_type(parser, .Right_Brace) && !is_at_parser_end(parser) {
        decl, err := new_declaration(parser)
        if err != .None {
            return nil, err
        }
        append(&statements, decl)
    }

    consume(parser, .Right_Brace, "Expect '}' after a block.")
    stmt := new(Block)
    stmt.statements = statements
    return stmt, .None
}

/*
expression     → literal | unary | binary | grouping  
literal        → NUMBER | STRING | true | false | nil 
grouping       → ( expression ) 
unary          → ( - | ! ) expression
binary         → expression operator expression
operator       → == | != | < | <= | > | >= | + | - | * | /


-- PRIORITY --

expression     → assignment
assignment     → IDENTIFIER = assignment | equality ;
ternary        → equality ? { expression : expression }?
equality       → comparison {{ != | == } comparison }*
comparison     → term {{ > | >= | < | <= } term }*
term           → factor {{ - | + } factor }*
factor         → unary {{ / | * } unary }*
unary          → { ! | - } unary | primary
primary        → NUMBER | STRING | true | false | nil | ( expression ) | IDENTIFIER
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

    return expr, .None
}

@private
expression :: proc(parser: ^Parser) -> (Expression, Error) {
    return assignment(parser)
}

@private
assignment :: proc(parser: ^Parser) -> (Expression, Error) {
    expr, err := ternary(parser)
    if err != .None {
        return nil, err
    }

    if match(parser, []Token_Type{.Equal}) {
        equals := previous(parser)
        value, a_err := assignment(parser)

        if var, ok := expr.(^Variable); ok {
            name := var.name
            assign := Assign{name, value}
            return &assign, .None
        }

        parser_error(equals, "Invalid assignment target.")
    }
    return expr, .None
}

@private
ternary :: proc(parser: ^Parser) -> (Expression, Error) {
    equal, err := equality(parser)
    if err != .None {
        return nil, err
    }

    if !match(parser, []Token_Type{.Question}) {
        return equal, .None
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

    expr := &Ternary{equal, expr1, expr2}
    return expr, .None
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
    for match(parser, []Token_Type{.Bang, .Minus}) {
        operator := previous(parser)
        right, err := unary(parser)
        if err != .None {
            return nil, err
        }

        expr := &Unary{operator, right}
        return expr, .None
    }

    return primary(parser)
}

@private
primary :: proc(parser: ^Parser) -> (Expression, Error) {
    if match(parser, []Token_Type{.False, .True, .Nil, .Number, .String}) {
        a := previous(parser)
        expr := &Literal{ previous(parser).literal }
        return expr, .None
    }

    if match(parser, []Token_Type{.Identifier}) {
        var := &Variable{ previous(parser) }
        return var, .None
    }

    if match(parser, []Token_Type{.Left_Paren}) {
        expr, err := expression(parser)
        _, err = consume(parser, .Right_Paren, "Expect ')' after expression")
        if err != .None {
            return nil, err
        }

        expr = &Grouping{ expr }
        return expr, .None
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
        return token, .None
    }
    
    return nil, _parser_error(parser_look_ahead(parser), message)
}

synchronize :: proc(parser: ^Parser) {
    advance_parser(parser)

    for !is_at_parser_end(parser) {
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

