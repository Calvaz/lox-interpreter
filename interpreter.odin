package interpreter

import "core:fmt"

Interpreter :: struct {
    environment: Environment,
}

interpret :: proc(statements: [dynamic]Statement) {
    interpreter := Interpreter { new_environment() }
    defer delete_environment(&interpreter.environment)

    for st in statements {
        if _, err := get_exp_value(&interpreter, st); err != .None {
            runtime_error(err.(Runtime_Error))
        }
    }
}

get_exp_value :: proc(interpreter: ^Interpreter, stmt: Statement) -> (rawptr, Error) {
    res: rawptr
    err: Error = .None
    switch s in stmt {
    case ^Print: res, err = get_print_stmt_value(interpreter, s)
    case ^Var: res, err = get_var_stmt_value(interpreter, s)
    case Expression: {
        switch e in s {
        case ^Unary: res, err = get_unary_exp_value(interpreter, e)
        case ^Binary: res, err = get_binary_exp_value(interpreter, e)
        case ^Ternary: res, err = get_ternary_exp_value(interpreter, e)
        case ^Literal: res, err = get_literal_exp_value(interpreter, e)
        case ^Grouping: res, err = get_grouping_exp_value(interpreter, e)
        case ^Variable: res, err = get_variable_exp_value(interpreter, e)
        }
        }
    }
    return res, err
}

get_literal_exp_value :: proc(interpreter: ^Interpreter, expr: ^Literal) -> (rawptr, Error)  {
    return expr.value, .None
}

get_grouping_exp_value :: proc(interpreter: ^Interpreter, expr: ^Grouping) -> (rawptr, Error) {
    return get_exp_value(interpreter, expr.expr)
}

get_unary_exp_value :: proc(interpreter: ^Interpreter, expr: ^Unary) -> (rawptr, Error) {
    right, err := get_exp_value(interpreter, expr.right)
    if err != .None {
        return nil, err
    }

    #partial switch expr.operator.type {
        case .Bang: {
            ok := is_truthy(right)
            return &ok, .None
        }
        case .Minus: {
            f := (^f64)(right)
            return &f, .None
        }
    }

    return nil, .None
}

get_binary_exp_value :: proc(interpreter: ^Interpreter, expr: ^Binary) -> (rawptr, Error) {
    left, err_l := get_exp_value(interpreter, expr.left)
    if err_l != .None { return nil, err_l }

    right, err_r := get_exp_value(interpreter, expr.right)
    if err_l != .None { return nil, err_r }

    res: rawptr
    err: Error = .None
    #partial switch expr.operator.type {
        case .Greater: {
            g := (^f64)(left)^ > (^f64)(right)^
            res = &g
        }
        case .Greater_Equal: {
            ge := (^f64)(left)^ >= (^f64)(right)^
            res = &ge
        }
        case .Less: {
            l := (^f64)(left)^ < (^f64)(right)^
            res = &l
        }
        case .Less_Equal: {
            le := (^f64)(left)^ <= (^f64)(right)^
            res = &le
        }
        case .Minus: {
            sub := (^f64)(left)^ - (^f64)(right)^
            res = &sub
        }
        case .Plus: {
            if type_of(left) == f64 && type_of(right) == f64 {
                sum := (^f64)(left)^ + (^f64)(right)^
                res = &sum
            }

            if type_of(left) == string && type_of(right) == string {
                s := fmt.tprintf("%v %v", (^string)(left)^, (^string)(right)^)
                res = &s
            }

            err = Runtime_Error{expr.operator, "Operands must be two numbers or two strings"}
        }
        case .Slash: {
            slash := (^f64)(left)^ / (^f64)(right)^
            res = &slash
        }
        case .Star: {
            star := (^f64)(left)^ * (^f64)(right)^ 
            res = &star
        }
        case .Bang_Equal: {
            ok := is_equal(left, right)
            res = &ok
        }
        case .Equal_Equal: {
            ok := is_equal(left, right)
            res = &ok
        }
    }
    return res, err
}

get_ternary_exp_value :: proc(interpreter: ^Interpreter, expr: ^Ternary) -> (rawptr, Error) {
    left, err_l := get_exp_value(interpreter, expr.left)
    if err_l != .None { return nil, err_l }

    second_exp, err_r := get_exp_value(interpreter, expr.second_exp)
    if err_r != .None { return nil, err_r }

    first_exp, err_c := get_exp_value(interpreter, expr.first_exp)
    if err_c != .None { return nil, err_c }

    if is_truthy(left) {
        return first_exp, .None
    }
    return second_exp, .None
}

get_variable_exp_value :: proc(interpreter: ^Interpreter, variable: ^Variable) -> (rawptr, Error) {
    return get_environment_value(&interpreter.environment, variable.name)
}

get_print_stmt_value :: proc(interpreter: ^Interpreter, expr: ^Print) -> (rawptr, Error) {
    value, err := get_exp_value(interpreter, expr.expr)
    if err != .None {
        return nil, err
    }
    fmt.println(stringify(value))
    return nil, .None
}

get_var_stmt_value :: proc(interpreter: ^Interpreter, stmt: ^Var) -> (rawptr, Error) {
    value: rawptr
    err: Error
    if stmt.initializer != nil {
        value, err = get_exp_value(interpreter, stmt.initializer)
        if err != .None {
            return nil, err
        }
    }

    define_value(&interpreter.environment, stmt.name.lexeme, value)
    return nil, .None
}

is_truthy :: proc(value: rawptr) -> bool {
    if value == nil { return false }
    if type_of(value) == bool {
        return (^bool)(value)^
    }
    
    return false
}

is_equal :: proc(a: rawptr, b: rawptr) -> bool {
    if a == nil && b == nil {
        return true
    }

    if a == nil {
        return false
    }
    return a == b
}

cast_error :: proc() -> Error {
    return .Cast
}

stringify :: proc(value: rawptr) -> string {
    if value == nil {
        return "nil"
    }

    return ((^string)(value))^
}
