package interpreter

import "core:fmt"

Interpreter :: struct {
    
}

get_exp_value :: proc(expr: Expression) -> rawptr {
    res: rawptr

    switch e in expr {
    case ^Unary: get_unary_exp_value(e)
    case ^Binary: get_binary_exp_value(e)
    case ^Ternary: get_unary_exp_value(e)
    case ^Literal: res = get_literal_exp_value(e)
    case ^Grouping: res = get_grouping_exp_value(e)
    }

    return res
}

get_literal_exp_value :: proc(expr: ^Literal) -> rawptr {
    return expr.value
}

get_grouping_exp_value :: proc(expr: ^Grouping) -> rawptr {
    return get_exp_value(expr.expr)
}

get_unary_exp_value :: proc(expr: ^Unary) -> Maybe(f64) {
    right := get_exp_value(expr.right)

    #partial switch expr.operator.type {
        case .Bang: is_truthy(right)
        case .Minus: {
            f := (^f64)(right)
            return f^ * -1
        }
    }

    return nil
}

get_binary_exp_value :: proc(expr: ^Binary) -> rawptr {
    left := get_exp_value(expr.left)
    right := get_exp_value(expr.right)

    #partial switch expr.operator.type {
        case .Greater: {
            g := (^f64)(left)^ > (^f64)(right)^
            return &g
        }
        case .Greater_Equal: {
            ge := (^f64)(left)^ >= (^f64)(right)^
            return &ge
        }
        case .Less: {
            l := (^f64)(left)^ < (^f64)(right)^
            return &l
        }
        case .Less_Equal: {
            le := (^f64)(left)^ <= (^f64)(right)^
            return &le
        }
        case .Minus: {
            sub := (^f64)(left)^ - (^f64)(right)^
            return &sub
        }
        case .Plus: {
            if type_of(left) == f64 && type_of(right) == f64 {
                sum := (^f64)(left)^ + (^f64)(right)^
                return &sum
            }

            if type_of(left) == string && type_of(right) == string {
                s := fmt.tprintf("%v %v", (^string)(left)^, (^string)(right)^)
                return &s
            }
        }
        case .Slash: {
            slash := (^f64)(left)^ / (^f64)(right)^
            return &slash
        }
        case .Star: {
            star := (^f64)(left)^ * (^f64)(right)^ 
            return &star
        }
    }
    return nil
}

is_truthy :: proc(value: rawptr) -> bool {
    if value == nil { return false }
    if type_of(value) == bool {
        return (^bool)(value)^
    }
    
    return false
}
