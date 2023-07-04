package interpreter

import "core:fmt"

Interpreter :: struct {
    environment: Environment,
}

interpret :: proc(interpreter: ^Interpreter, statements: [dynamic]Statement) {
    for st in statements {
        if _, err := get_exp_value(interpreter, st); err != .None {
            runtime_error(err.(Runtime_Error))
        }
    }
}

get_exp_value :: proc(interpreter: ^Interpreter, stmt: Statement) -> (Token_Value, Error) {
    res: Token_Value 
    err: Error = .None
    switch s in stmt {
    case ^Print: res, err = get_print_stmt_value(interpreter, s)
    case ^Var: res, err = get_var_stmt_value(interpreter, s)
    case ^Block: 
    case Expression: {
        switch e in s {
        case ^Unary: res, err = get_unary_exp_value(interpreter, e)
        case ^Binary: res, err = get_binary_exp_value(interpreter, e)
        case ^Assign: res, err = get_assign_exp_value(interpreter, e)
        case ^Ternary: res, err = get_ternary_exp_value(interpreter, e)
        case ^Literal: res, err = get_literal_exp_value(interpreter, e)
        case ^Grouping: res, err = get_grouping_exp_value(interpreter, e)
        case ^Variable: res, err = get_variable_exp_value(interpreter, e)
        }
        }
    }
    return res, err
}

get_literal_exp_value :: proc(interpreter: ^Interpreter, expr: ^Literal) -> (Token_Value, Error)  {
    return expr.value, .None
}

get_grouping_exp_value :: proc(interpreter: ^Interpreter, expr: ^Grouping) -> (Token_Value, Error) {
    return get_exp_value(interpreter, expr.expr)
}

get_unary_exp_value :: proc(interpreter: ^Interpreter, expr: ^Unary) -> (Token_Value, Error) {
    right, err := get_exp_value(interpreter, expr.right)
    if err != .None {
        return nil, err
    }

    #partial switch expr.operator.type {
        case .Bang: {
            return is_truthy(right), .None
        }
        case .Minus: {
            return right.(f64), .None
        }
    }

    return nil, .None
}

get_binary_exp_value :: proc(interpreter: ^Interpreter, expr: ^Binary) -> (Token_Value, Error) {
    left, err_l := get_exp_value(interpreter, expr.left)
    if err_l != .None { return nil, err_l }

    right, err_r := get_exp_value(interpreter, expr.right)
    if err_l != .None { return nil, err_r }

    res: Token_Value
    err: Error = .None
    #partial switch expr.operator.type {
        case .Greater: {
            res = left.(f64) > right.(f64)
        }
        case .Greater_Equal: {
            res = left.(f64) >= right.(f64)
        }
        case .Less: {
            res = left.(f64) < right.(f64)
        }
        case .Less_Equal: {
            res = left.(f64) <= right.(f64)
        }
        case .Minus: {
            res = left.(f64) - right.(f64)
        }
        case .Plus: {
            if type_of(left) == f64 && type_of(right) == f64 {
                res = left.(f64) + right.(f64)
            }

            if type_of(left) == string && type_of(right) == string {
                res = fmt.tprintf("%v %v", left.(string), right.(string))
            }

            err = Runtime_Error{expr.operator, "Operands must be two numbers or two strings"}
        }
        case .Slash: {
            res := left.(f64) / right.(f64)
        }
        case .Star: {
            res := left.(f64) * right.(f64)
        }
        case .Bang_Equal: {
            res := is_equal(left, right)
        }
        case .Equal_Equal: {
            res := is_equal(left, right)
        }
    }
    return res.(bool), err
}

get_ternary_exp_value :: proc(interpreter: ^Interpreter, expr: ^Ternary) -> (Token_Value, Error) {
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

get_assign_exp_value :: proc(interpreter: ^Interpreter, expr: ^Assign) -> (Token_Value, Error) {
    value, err := get_exp_value(interpreter, expr.value)
    if err != .None {
        return nil, err
    }
    assign_environment_value(&interpreter.environment, expr.name, value)
    return value, .None
}

get_variable_exp_value :: proc(interpreter: ^Interpreter, variable: ^Variable) -> (Token_Value, Error) {
    return get_environment_value(&interpreter.environment, variable^.name)
}

get_print_stmt_value :: proc(interpreter: ^Interpreter, expr: ^Print) -> (Token_Value, Error) {
    value, err := get_exp_value(interpreter, expr.expr)
    if err != .None {
        return nil, err
    }
    fmt.println(stringify(value))
    return nil, .None
}

get_var_stmt_value :: proc(interpreter: ^Interpreter, stmt: ^Var) -> (Token_Value, Error) {
    value: Token_Value
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

get_block_stmt_value :: proc(interpreter: ^Interpreter, block: ^Block) -> (Token_Value, Error) {
    previous := interpreter.environment
    interpreter.environment = new_environment(&interpreter.environment)

    err: Error = .None
    for st in block.statements {
        _, e_err := get_exp_value(interpreter, st)
        if e_err != .None {
            err = e_err
        }
    }

    interpreter.environment = previous
    return nil, err
}

is_truthy :: proc(value: Token_Value) -> bool {
    if value == nil { return false }
    if type_of(value) == bool {
        return value.(bool)
    }
    
    return false
}

is_equal :: proc(a: Token_Value, b: Token_Value) -> bool {
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

stringify :: proc(value: Token_Value) -> Token_Value {
    if value == nil {
        return "nil"
    }

    return value
}
