package interpreter

import "core:fmt"
import "core:strings"

@private
Environment :: struct {
    values: map[string]Token_Value,
    scope: ^Environment,
}

Token_Value :: union {
    f64,
    string,
    bool,
}

new_environment :: proc(scope: ^Environment = nil) -> Environment {
    m := make(map[string]Token_Value)
    return Environment { m, scope }
}

delete_environment :: proc(environment: ^Environment) {
    delete(environment.values)
}

define_value :: proc(environment: ^Environment, name: string, value: Token_Value) {
    environment.values[strings.clone(name)] = value
}

assign_environment_value :: proc(environment: ^Environment, name: Token, value: Token_Value) {
    if ok := name.lexeme in environment.values; ok {
        environment^.values[name.lexeme] = value
        return
    }

    if environment.scope != nil {
        assign_environment_value(environment^.scope, name, value)
        return
    }

    runtime_error(Runtime_Error{ name, fmt.tprintf("Undefined variable '%v'", name.lexeme) })
}

get_environment_value :: proc(environment: ^Environment, name: Token) -> (Token_Value, Error) {
    if ok := name.lexeme in environment.values; ok {
        return environment.values[name.lexeme], .None
    }

    if environment.scope != nil {
        return get_environment_value(environment.scope, name)
    }

    err := Runtime_Error{token = name, message = fmt.tprintf("Undefined variable '%v'.", name.lexeme)}
    return nil, err
}

